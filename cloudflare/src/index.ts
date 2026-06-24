/**
 * OpenMontage Studio — auth & accounts Worker.
 *
 * Registration, login, session lookup, and profile/marketing-consent updates,
 * backed by D1 (users) and KV (sessions). Passwords are hashed with PBKDF2 via
 * the Web Crypto API (no native deps). The deploy API token is never seen here.
 *
 * Marketing data is collected only with explicit opt-in consent and can be
 * withdrawn via PATCH /auth/profile (set marketing_consent=false). Country is
 * read from Cloudflare's request geo (no extra collection from the user).
 *
 * Routes:
 *   POST  /auth/register {email,password,name?,marketing_consent?,
 *                         marketing_source?,use_case?,locale?}  -> {token,user}
 *   POST  /auth/login    {email,password}                       -> {token,user}
 *   GET   /auth/me        Authorization: Bearer ...              -> {user}
 *   PATCH /auth/profile   Authorization: Bearer ...             -> {user}
 *   POST  /auth/logout    Authorization: Bearer ...             -> {ok}
 *   GET   /health                                                -> {ok}
 */

export interface Env {
  DB: D1Database;
  SESSIONS: KVNamespace;
  // OAuth credentials (set via `wrangler secret put`). Optional so the Worker
  // deploys before they're configured; a provider is "off" until both are set.
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  GITHUB_CLIENT_ID?: string;
  GITHUB_CLIENT_SECRET?: string;
  // Email sending (Resend). Optional: without a key, verification emails are
  // simply not sent and accounts stay unverified.
  RESEND_API_KEY?: string;
  RESEND_FROM?: string;
  // Billing (Stripe). Optional: without these the billing endpoints report
  // "not configured" (501) and the rest of the app keeps working.
  STRIPE_SECRET_KEY?: string;
  STRIPE_PRICE_ID?: string;
  STRIPE_WEBHOOK_SECRET?: string;
}

interface UserRow {
  id: string;
  email: string;
  name: string | null;
  password_hash: string;
  created_at: string;
  last_login_at: string | null;
  marketing_consent: number;
  consent_at: string | null;
  marketing_source: string | null;
  use_case: string | null;
  country: string | null;
  locale: string | null;
  oauth_provider: string | null;
  oauth_id: string | null;
  email_verified: number;
  verified_at: string | null;
  referral_code: string | null;
  referred_by: string | null;
  credits: number;
  plan: string;
  share_unlocks_used: number;
  stripe_customer_id: string | null;
}

// Freemium tuning. New accounts get FREE_CREDITS renders; each render consumes
// one. Out of credits → subscribe, share on X (+SHARE_REWARD, up to SHARE_MAX
// times), or invite a friend (+REFERRAL_CREDIT each).
const FREE_CREDITS = 5;
const SHARE_REWARD = 3;
const SHARE_MAX = 2;
const REFERRAL_CREDIT = 3;

// "Invite to unlock" milestones. Inviting N friends who sign up unlocks a
// reward. Money never flows up a chain — this is a referral loop, not an MLM.
const REFERRAL_TIERS: { at: number; key: string; label: string }[] = [
  { at: 1, key: 'premium_voices', label: 'Premium cloud voices' },
  { at: 3, key: 'no_branding', label: 'Remove the end card' },
  { at: 5, key: 'pro_templates', label: 'Pro template pack' },
];

function unlocksFor(count: number): string[] {
  return REFERRAL_TIERS.filter((t) => count >= t.at).map((t) => t.key);
}

function nextTier(count: number): { at: number; key: string; label: string } | null {
  return REFERRAL_TIERS.find((t) => count < t.at) ?? null;
}

// A short, human-friendly, unambiguous code (no 0/O/1/I/L).
function newReferralCode(): string {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  let s = '';
  for (const b of bytes) s += alphabet[b % alphabet.length];
  return s;
}

async function uniqueReferralCode(env: Env): Promise<string> {
  for (let i = 0; i < 6; i++) {
    const code = newReferralCode();
    const clash = await env.DB.prepare(
      'SELECT id FROM users WHERE referral_code = ?',
    )
      .bind(code)
      .first();
    if (!clash) return code;
  }
  return newReferralCode();
}

// Backfills a referral code for users created before referrals existed.
async function ensureReferralCode(env: Env, row: UserRow): Promise<string> {
  if (row.referral_code) return row.referral_code;
  const code = await uniqueReferralCode(env);
  await env.DB.prepare('UPDATE users SET referral_code = ? WHERE id = ?')
    .bind(code, row.id)
    .run();
  row.referral_code = code;
  return code;
}

const SESSION_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days
const PBKDF2_ITERATIONS = 100_000;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PATCH,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

// ---- password hashing (PBKDF2 / Web Crypto) ----

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function fromHex(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

async function derive(
  password: string,
  salt: Uint8Array,
  iterations: number,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    key,
    256,
  );
  return toHex(new Uint8Array(bits));
}

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await derive(password, salt, PBKDF2_ITERATIONS);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${toHex(salt)}$${hash}`;
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iterations = parseInt(parts[1], 10);
  const candidate = await derive(password, fromHex(parts[2]), iterations);
  return timingSafeEqual(candidate, parts[3]);
}

// ---- sessions ----

async function createSession(env: Env, userId: string): Promise<string> {
  const token = toHex(crypto.getRandomValues(new Uint8Array(32)));
  await env.SESSIONS.put(`sess:${token}`, userId, {
    expirationTtl: SESSION_TTL_SECONDS,
  });
  return token;
}

function bearer(request: Request): string | null {
  const header = request.headers.get('Authorization') ?? '';
  return header.startsWith('Bearer ') ? header.slice(7) : null;
}

async function userIdFromSession(request: Request, env: Env): Promise<string | null> {
  const token = bearer(request);
  if (!token) return null;
  return env.SESSIONS.get(`sess:${token}`);
}

function publicUser(row: UserRow) {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    created_at: row.created_at,
    marketing_consent: row.marketing_consent === 1,
    marketing_source: row.marketing_source,
    use_case: row.use_case,
    country: row.country,
    email_verified: row.email_verified === 1,
    referral_code: row.referral_code,
    credits: row.credits,
    plan: row.plan,
  };
}

function geoCountry(request: Request): string | null {
  const cf = (request as unknown as { cf?: { country?: string } }).cf;
  return cf?.country ?? null;
}

function clientIp(request: Request): string {
  return request.headers.get('CF-Connecting-IP') ?? 'unknown';
}

/// Approximate fixed-window rate limiter backed by KV. Returns true if the call
/// is allowed, false if [key] has exceeded [limit] within [windowSec].
async function rateLimit(
  env: Env,
  key: string,
  limit: number,
  windowSec: number,
): Promise<boolean> {
  const k = `rl:${key}`;
  const count = parseInt((await env.SESSIONS.get(k)) ?? '0', 10);
  if (count >= limit) return false;
  await env.SESSIONS.put(k, String(count + 1), { expirationTtl: windowSec });
  return true;
}

// ---- email (Resend) + verification ----

const VERIFY_BASE = 'https://auth.opencli.ai/auth/verify';

async function sendEmail(
  env: Env,
  to: string,
  subject: string,
  html: string,
): Promise<boolean> {
  if (!env.RESEND_API_KEY) return false; // not configured — skip silently
  const from = env.RESEND_FROM ?? 'OpenMontage Studio <onboarding@resend.dev>';
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from, to: [to], subject, html }),
  });
  return res.ok;
}

async function sendVerification(
  env: Env,
  userId: string,
  email: string,
): Promise<void> {
  const token = toHex(crypto.getRandomValues(new Uint8Array(24)));
  await env.SESSIONS.put(`verify:${token}`, userId, { expirationTtl: 86400 });
  const link = `${VERIFY_BASE}?token=${token}`;
  await sendEmail(
    env,
    email,
    'Confirm your OpenMontage Studio email',
    `<div style="font-family:system-ui;max-width:480px;margin:auto">
       <h2>Welcome to OpenMontage Studio</h2>
       <p>Confirm this email address to finish setting up your account:</p>
       <p><a href="${link}" style="display:inline-block;background:#22D3EE;color:#0F172A;padding:10px 18px;border-radius:8px;text-decoration:none;font-weight:600">Verify email</a></p>
       <p style="color:#64748B;font-size:13px">Or paste this link: ${link}</p>
       <p style="color:#64748B;font-size:13px">This link expires in 24 hours. If you didn't sign up, ignore this email.</p>
     </div>`,
  );
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function loadUser(env: Env, id: string): Promise<UserRow | null> {
  return env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first<UserRow>();
}

// ---- handlers ----

async function register(request: Request, env: Env): Promise<Response> {
  // Throttle sign-ups per IP to blunt bulk/bot registration.
  if (!(await rateLimit(env, `reg:${clientIp(request)}`, 10, 3600))) {
    return json({ error: 'too many sign-up attempts, try again later' }, 429);
  }
  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');
  const name = body.name ? String(body.name).trim() : null;

  if (!EMAIL_RE.test(email)) return json({ error: 'invalid email' }, 400);
  if (password.length < 8) {
    return json({ error: 'password must be at least 8 characters' }, 400);
  }

  const existing = await env.DB.prepare('SELECT id FROM users WHERE email = ?')
    .bind(email)
    .first();
  if (existing) return json({ error: 'email already registered' }, 409);

  // Marketing data — collected only on explicit opt-in.
  const consent = body.marketing_consent === true;
  const now = new Date().toISOString();
  const source = body.marketing_source ? String(body.marketing_source).slice(0, 80) : null;
  const useCase = body.use_case ? String(body.use_case).slice(0, 200) : null;
  const locale = body.locale ? String(body.locale).slice(0, 20) : null;

  const id = crypto.randomUUID();
  const passwordHash = await hashPassword(password);

  // Referral attribution: if a valid code was supplied, link the new account to
  // its referrer. Give the new account its own shareable code too.
  const refCode = body.ref ? String(body.ref).trim().toUpperCase().slice(0, 12) : null;
  let referredBy: string | null = null;
  if (refCode) {
    const referrer = await env.DB.prepare(
      'SELECT id FROM users WHERE referral_code = ?',
    )
      .bind(refCode)
      .first<{ id: string }>();
    if (referrer && referrer.id !== id) referredBy = referrer.id;
  }
  const myReferralCode = await uniqueReferralCode(env);
  // Reward the referrer with credits for bringing someone in.
  if (referredBy) {
    await env.DB.prepare('UPDATE users SET credits = credits + ? WHERE id = ?')
      .bind(REFERRAL_CREDIT, referredBy)
      .run();
  }

  await env.DB.prepare(
    `INSERT INTO users
       (id, email, name, password_hash, created_at,
        marketing_consent, consent_at, marketing_source, use_case, country, locale,
        referral_code, referred_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      email,
      name,
      passwordHash,
      now,
      consent ? 1 : 0,
      consent ? now : null,
      source,
      useCase,
      geoCountry(request),
      locale,
      myReferralCode,
      referredBy,
    )
    .run();

  await sendVerification(env, id, email);
  const token = await createSession(env, id);
  const row = await loadUser(env, id);
  return json({ token, user: publicUser(row!) });
}

async function login(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');

  // Throttle by IP and by target email to blunt brute-force / credential
  // stuffing, before doing any password work.
  const okIp = await rateLimit(env, `login:${clientIp(request)}`, 20, 900);
  const okEmail = await rateLimit(env, `loginem:${email}`, 8, 900);
  if (!okIp || !okEmail) {
    return json({ error: 'too many attempts, try again later' }, 429);
  }

  const row = await env.DB.prepare('SELECT * FROM users WHERE email = ?')
    .bind(email)
    .first<UserRow>();
  const ok = row
    ? await verifyPassword(password, row.password_hash)
    : await verifyPassword(password, `pbkdf2$${PBKDF2_ITERATIONS}$00$00`);
  if (!row || !ok) return json({ error: 'invalid email or password' }, 401);

  await env.DB.prepare('UPDATE users SET last_login_at = ? WHERE id = ?')
    .bind(new Date().toISOString(), row.id)
    .run();

  const token = await createSession(env, row.id);
  return json({ token, user: publicUser(row) });
}

async function me(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);
  return json({ user: publicUser(row) });
}

// Referral status for the signed-in user: their shareable code/link, how many
// people they have brought in, and which rewards that unlocks.
async function referral(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);

  const code = await ensureReferralCode(env, row);
  const counted = await env.DB.prepare(
    'SELECT COUNT(*) AS n FROM users WHERE referred_by = ?',
  )
    .bind(userId)
    .first<{ n: number }>();
  const invited = counted?.n ?? 0;

  return json({
    code,
    link: `https://get.opencli.ai/?ref=${code}`,
    invited,
    unlocks: unlocksFor(invited),
    next: nextTier(invited),
    tiers: REFERRAL_TIERS,
  });
}

// ---- credits / billing (freemium) ----

function creditsView(row: UserRow) {
  return {
    credits: row.credits,
    plan: row.plan,
    is_pro: row.plan === 'pro',
    free_allowance: FREE_CREDITS,
    share_reward: SHARE_REWARD,
    share_unlocks_used: row.share_unlocks_used,
    share_unlocks_max: SHARE_MAX,
  };
}

// Current credit balance and plan for the signed-in user.
async function credits(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);
  return json(creditsView(row));
}

// Consumes one credit for a render/export. Pro users are never charged. Returns
// 402 when a free user is out of credits, so the app can show the paywall.
async function consumeCredit(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);

  if (row.plan === 'pro') {
    return json({ allowed: true, ...creditsView(row) });
  }
  if (row.credits <= 0) {
    return json({ allowed: false, ...creditsView(row), error: 'out of credits' }, 402);
  }
  // Decrement atomically and only when still positive, to avoid races.
  const res = await env.DB.prepare(
    'UPDATE users SET credits = credits - 1 WHERE id = ? AND credits > 0',
  )
    .bind(userId)
    .run();
  if (!res.meta.changes) {
    const fresh = await loadUser(env, userId);
    return json({ allowed: false, ...creditsView(fresh!), error: 'out of credits' }, 402);
  }
  const updated = await loadUser(env, userId);
  return json({ allowed: true, ...creditsView(updated!) });
}

// Grants SHARE_REWARD credits for sharing on X, up to SHARE_MAX times. The post
// itself can't be verified (no free X API), so this is trust-based and capped.
async function shareUnlock(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);
  if (row.share_unlocks_used >= SHARE_MAX) {
    return json({ ...creditsView(row), error: 'share reward limit reached' }, 409);
  }
  await env.DB.prepare(
    'UPDATE users SET credits = credits + ?, share_unlocks_used = share_unlocks_used + 1 WHERE id = ?',
  )
    .bind(SHARE_REWARD, userId)
    .run();
  const updated = await loadUser(env, userId);
  return json(creditsView(updated!));
}

// Creates a Stripe Checkout session for the Pro subscription and returns its URL.
async function billingCheckout(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  if (!env.STRIPE_SECRET_KEY || !env.STRIPE_PRICE_ID) {
    return json({ error: 'billing not configured' }, 501);
  }
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);

  const params = new URLSearchParams();
  params.set('mode', 'subscription');
  params.set('line_items[0][price]', env.STRIPE_PRICE_ID);
  params.set('line_items[0][quantity]', '1');
  params.set('success_url', 'https://get.opencli.ai/?upgraded=1');
  params.set('cancel_url', 'https://get.opencli.ai/');
  params.set('client_reference_id', userId);
  params.set('customer_email', row.email);
  const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params.toString(),
  });
  const data = (await res.json()) as { url?: string };
  if (!res.ok || !data.url) return json({ error: 'could not start checkout' }, 502);
  return json({ url: data.url });
}

async function verifyStripeSignature(
  payload: string,
  header: string,
  secret: string,
): Promise<boolean> {
  const parts = Object.fromEntries(
    header.split(',').map((p) => p.split('=') as [string, string]),
  );
  if (!parts.t || !parts.v1) return false;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${parts.t}.${payload}`),
  );
  return timingSafeEqual(toHex(new Uint8Array(mac)), parts.v1);
}

// Stripe webhook: flips the account to 'pro' on a completed checkout and back to
// 'free' when the subscription is cancelled.
async function billingWebhook(request: Request, env: Env): Promise<Response> {
  if (!env.STRIPE_WEBHOOK_SECRET) return json({ error: 'not configured' }, 501);
  const payload = await request.text();
  const sig = request.headers.get('Stripe-Signature') ?? '';
  if (!(await verifyStripeSignature(payload, sig, env.STRIPE_WEBHOOK_SECRET))) {
    return json({ error: 'bad signature' }, 400);
  }
  const event = JSON.parse(payload) as {
    type: string;
    data: { object: Record<string, unknown> };
  };
  const obj = event.data.object;
  if (event.type === 'checkout.session.completed') {
    const uid = obj.client_reference_id as string | undefined;
    const customer = (obj.customer as string | undefined) ?? null;
    if (uid) {
      await env.DB.prepare(
        'UPDATE users SET plan = ?, stripe_customer_id = ? WHERE id = ?',
      )
        .bind('pro', customer, uid)
        .run();
    }
  } else if (event.type === 'customer.subscription.deleted') {
    const customer = obj.customer as string | undefined;
    if (customer) {
      await env.DB.prepare(
        "UPDATE users SET plan = 'free' WHERE stripe_customer_id = ?",
      )
        .bind(customer)
        .run();
    }
  }
  return json({ received: true });
}

// Update name and marketing fields. Setting marketing_consent=false is the
// opt-out path; it clears consent_at.
async function updateProfile(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;

  const sets: string[] = [];
  const values: unknown[] = [];
  if (typeof body.name === 'string') {
    sets.push('name = ?');
    values.push(body.name.trim());
  }
  if (typeof body.marketing_source === 'string') {
    sets.push('marketing_source = ?');
    values.push(body.marketing_source.slice(0, 80));
  }
  if (typeof body.use_case === 'string') {
    sets.push('use_case = ?');
    values.push(body.use_case.slice(0, 200));
  }
  if (typeof body.marketing_consent === 'boolean') {
    sets.push('marketing_consent = ?', 'consent_at = ?');
    values.push(body.marketing_consent ? 1 : 0);
    values.push(body.marketing_consent ? new Date().toISOString() : null);
  }
  if (sets.length === 0) return json({ error: 'nothing to update' }, 400);

  values.push(userId);
  await env.DB.prepare(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`)
    .bind(...values)
    .run();
  const row = await loadUser(env, userId);
  return json({ user: publicUser(row!) });
}

async function logout(request: Request, env: Env): Promise<Response> {
  const token = bearer(request);
  if (token) await env.SESSIONS.delete(`sess:${token}`);
  return json({ ok: true });
}

// Clicked from the verification email.
async function verifyEmail(request: Request, env: Env): Promise<Response> {
  const token = new URL(request.url).searchParams.get('token');
  if (!token) return htmlPage('Invalid verification link');
  const userId = await env.SESSIONS.get(`verify:${token}`);
  if (!userId) return htmlPage('This link is invalid or has expired');
  await env.DB.prepare(
    'UPDATE users SET email_verified = 1, verified_at = ? WHERE id = ?',
  )
    .bind(new Date().toISOString(), userId)
    .run();
  await env.SESSIONS.delete(`verify:${token}`);
  return htmlPage('Email verified ✓');
}

// Re-send the verification email for the signed-in user.
async function resendVerification(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);
  if (row.email_verified === 1) return json({ ok: true, already_verified: true });
  if (!(await rateLimit(env, `resend:${userId}`, 5, 3600))) {
    return json({ error: 'too many requests, try again later' }, 429);
  }
  await sendVerification(env, row.id, row.email);
  return json({ ok: true });
}

// ---- password reset, change, account deletion ----

const RESET_BASE = 'https://auth.opencli.ai/auth/reset';

// Always returns ok (never leaks whether the email exists). Emails a reset link
// if the account exists.
async function forgotPassword(request: Request, env: Env): Promise<Response> {
  if (!(await rateLimit(env, `forgot:${clientIp(request)}`, 5, 3600))) {
    return json({ error: 'too many requests, try again later' }, 429);
  }
  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const email = String(body.email ?? '').trim().toLowerCase();
  const row = await env.DB.prepare('SELECT id FROM users WHERE email = ?')
    .bind(email)
    .first<{ id: string }>();
  if (row) {
    const token = toHex(crypto.getRandomValues(new Uint8Array(24)));
    await env.SESSIONS.put(`reset:${token}`, row.id, { expirationTtl: 3600 });
    const link = `${RESET_BASE}?token=${token}`;
    await sendEmail(
      env,
      email,
      'Reset your OpenMontage Studio password',
      `<div style="font-family:system-ui;max-width:480px;margin:auto">
         <h2>Reset your password</h2>
         <p>Click below to choose a new password. This link expires in 1 hour.</p>
         <p><a href="${link}" style="display:inline-block;background:#22D3EE;color:#0F172A;padding:10px 18px;border-radius:8px;text-decoration:none;font-weight:600">Reset password</a></p>
         <p style="color:#64748B;font-size:13px">If you didn't request this, ignore this email.</p>
       </div>`,
    );
  }
  return json({ ok: true });
}

// Served when the reset link is clicked: a small form that posts the new password.
function resetPage(token: string, message?: string): Response {
  const note = message
    ? `<p style="color:#F59E0B">${message}</p>`
    : '';
  return new Response(
    `<!doctype html><meta charset="utf-8"><body style="font-family:system-ui;background:#0F172A;color:#E2E8F0;display:grid;place-items:center;height:100vh;margin:0">
       <form method="post" action="/auth/reset" style="background:#1E293B;border:1px solid #2A3A52;border-radius:14px;padding:28px;width:340px">
         <h2 style="margin:0 0 12px">Choose a new password</h2>
         ${note}
         <input type="hidden" name="token" value="${token}">
         <input type="password" name="password" placeholder="New password (min 8 chars)" required minlength="8"
           style="width:100%;box-sizing:border-box;padding:12px;border-radius:8px;border:1px solid #2A3A52;background:#0F172A;color:#E2E8F0;margin-bottom:12px">
         <button type="submit" style="width:100%;padding:12px;border:0;border-radius:8px;background:#22D3EE;color:#0F172A;font-weight:600;cursor:pointer">Update password</button>
       </form>
     </body>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
}

async function resetPassword(request: Request, env: Env): Promise<Response> {
  let token: string | null = null;
  let password: string | null = null;
  if ((request.headers.get('Content-Type') ?? '').includes('application/json')) {
    const b = (await request.json().catch(() => ({}))) as Record<string, unknown>;
    token = (b.token as string) ?? null;
    password = (b.password as string) ?? null;
  } else {
    const f = await request.formData();
    token = (f.get('token') as string) ?? null;
    password = (f.get('password') as string) ?? null;
  }
  if (!token) return htmlPage('Invalid reset link');
  if (!password || password.length < 8) {
    return resetPage(token, 'Password must be at least 8 characters.');
  }
  const userId = await env.SESSIONS.get(`reset:${token}`);
  if (!userId) return htmlPage('This reset link is invalid or has expired');
  await env.DB.prepare('UPDATE users SET password_hash = ? WHERE id = ?')
    .bind(await hashPassword(password), userId)
    .run();
  await env.SESSIONS.delete(`reset:${token}`);
  return htmlPage('Password updated ✓ — you can sign in now');
}

// Change password for the signed-in user. OAuth-only accounts (no password yet)
// can set one without providing a current password.
async function changePassword(request: Request, env: Env): Promise<Response> {
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  const b = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const current = String(b.current ?? '');
  const next = String(b.new ?? '');
  if (next.length < 8) {
    return json({ error: 'new password must be at least 8 characters' }, 400);
  }
  const row = await loadUser(env, userId);
  if (!row) return json({ error: 'user not found' }, 404);
  if (row.password_hash && !(await verifyPassword(current, row.password_hash))) {
    return json({ error: 'current password is incorrect' }, 401);
  }
  await env.DB.prepare('UPDATE users SET password_hash = ? WHERE id = ?')
    .bind(await hashPassword(next), userId)
    .run();
  return json({ ok: true });
}

async function deleteAccount(request: Request, env: Env): Promise<Response> {
  const token = bearer(request);
  const userId = await userIdFromSession(request, env);
  if (!userId) return json({ error: 'invalid session' }, 401);
  await env.DB.prepare('DELETE FROM users WHERE id = ?').bind(userId).run();
  if (token) await env.SESSIONS.delete(`sess:${token}`);
  return json({ ok: true });
}

// ---- third-party (OAuth) sign-in: Google + GitHub ----
//
// Desktop flow: the app opens /auth/oauth/<provider>/start?state=S, the provider
// redirects back to /callback, the Worker exchanges the code (client secret stays
// here), upserts the user, mints a session, and stashes it under the state. The
// app then polls /auth/oauth/exchange?state=S to collect the session.

// Stays on workers.dev until the GitHub/Google OAuth apps' redirect URIs are
// updated to auth.opencli.ai — the callback must match a registered URI.
const OAUTH_BASE =
  'https://openmontage-auth.272876047.workers.dev/auth/oauth';

interface OAuthProfile {
  providerId: string;
  email: string | null;
  name: string | null;
}

interface OAuthProvider {
  authorizeUrl: string;
  tokenUrl: string;
  scope: string;
  id(env: Env): string | undefined;
  secret(env: Env): string | undefined;
  profile(accessToken: string): Promise<OAuthProfile>;
}

const PROVIDERS: Record<string, OAuthProvider> = {
  google: {
    authorizeUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenUrl: 'https://oauth2.googleapis.com/token',
    scope: 'openid email profile',
    id: (e) => e.GOOGLE_CLIENT_ID,
    secret: (e) => e.GOOGLE_CLIENT_SECRET,
    async profile(token) {
      const r = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
        headers: { Authorization: `Bearer ${token}` },
      });
      const j = (await r.json()) as Record<string, unknown>;
      return {
        providerId: String(j.sub),
        email: (j.email as string) ?? null,
        name: (j.name as string) ?? null,
      };
    },
  },
  github: {
    authorizeUrl: 'https://github.com/login/oauth/authorize',
    tokenUrl: 'https://github.com/login/oauth/access_token',
    scope: 'read:user user:email',
    id: (e) => e.GITHUB_CLIENT_ID,
    secret: (e) => e.GITHUB_CLIENT_SECRET,
    async profile(token) {
      const headers = {
        Authorization: `Bearer ${token}`,
        'User-Agent': 'openmontage-auth',
        Accept: 'application/vnd.github+json',
      };
      const u = (await (
        await fetch('https://api.github.com/user', { headers })
      ).json()) as Record<string, unknown>;
      let email = (u.email as string) ?? null;
      if (!email) {
        const list = (await (
          await fetch('https://api.github.com/user/emails', { headers })
        ).json()) as Array<{ email: string; primary: boolean; verified: boolean }>;
        const pick = list.find((e) => e.primary && e.verified) ??
          list.find((e) => e.verified);
        email = pick?.email ?? null;
      }
      return {
        providerId: String(u.id),
        email,
        name: (u.name as string) ?? (u.login as string) ?? null,
      };
    },
  },
};

function redirectUri(provider: string): string {
  return `${OAUTH_BASE}/${provider}/callback`;
}

async function oauthStart(
  provider: string,
  request: Request,
  env: Env,
): Promise<Response> {
  const cfg = PROVIDERS[provider];
  const clientId = cfg?.id(env);
  if (!cfg || !clientId) return json({ error: 'provider not configured' }, 400);
  const state = new URL(request.url).searchParams.get('state');
  if (!state) return json({ error: 'state is required' }, 400);

  // Persist the pending flow in D1 (strongly consistent) so /callback and the
  // app's /exchange poll read it reliably. Opportunistically drop stale flows.
  const cutoff = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  await env.DB.prepare('DELETE FROM oauth_flow WHERE created_at < ?')
    .bind(cutoff)
    .run();
  await env.DB.prepare(
    `INSERT INTO oauth_flow (state, provider, token, created_at)
     VALUES (?, ?, NULL, ?)
     ON CONFLICT(state) DO UPDATE SET provider = excluded.provider,
       token = NULL, created_at = excluded.created_at`,
  )
    .bind(state, provider, new Date().toISOString())
    .run();
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri(provider),
    response_type: 'code',
    scope: cfg.scope,
    state,
  });
  return Response.redirect(`${cfg.authorizeUrl}?${params.toString()}`, 302);
}

async function exchangeCode(
  cfg: OAuthProvider,
  provider: string,
  code: string,
  env: Env,
): Promise<string | null> {
  const res = await fetch(cfg.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams({
      client_id: cfg.id(env)!,
      client_secret: cfg.secret(env)!,
      code,
      redirect_uri: redirectUri(provider),
      grant_type: 'authorization_code',
    }),
  });
  const j = (await res.json()) as Record<string, unknown>;
  return (j.access_token as string) ?? null;
}

function htmlPage(message: string): Response {
  return new Response(
    `<!doctype html><meta charset="utf-8"><body style="font-family:system-ui;background:#0F172A;color:#E2E8F0;display:grid;place-items:center;height:100vh;margin:0"><div style="text-align:center"><h2>${message}</h2><p style="color:#94A3B8">You can return to OpenMontage Studio.</p></div></body>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
}

async function oauthCallback(
  provider: string,
  request: Request,
  env: Env,
): Promise<Response> {
  const cfg = PROVIDERS[provider];
  if (!cfg || !cfg.secret(env)) return htmlPage('Sign-in failed: provider off');
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  if (!code || !state) return htmlPage('Sign-in failed: missing code');
  const flow = await env.DB.prepare(
    'SELECT provider FROM oauth_flow WHERE state = ?',
  )
    .bind(state)
    .first<{ provider: string }>();
  if (!flow || flow.provider !== provider) {
    return htmlPage('Sign-in failed: bad state');
  }

  const accessToken = await exchangeCode(cfg, provider, code, env);
  if (!accessToken) return htmlPage('Sign-in failed: token exchange');
  const profile = await cfg.profile(accessToken);
  if (!profile.email) return htmlPage('Sign-in failed: no email from provider');

  const email = profile.email.toLowerCase();
  let row = await env.DB.prepare('SELECT * FROM users WHERE email = ?')
    .bind(email)
    .first<UserRow>();
  const now = new Date().toISOString();
  if (row) {
    await env.DB.prepare(
      'UPDATE users SET oauth_provider = ?, oauth_id = ?, last_login_at = ? WHERE id = ?',
    )
      .bind(provider, profile.providerId, now, row.id)
      .run();
  } else {
    const id = crypto.randomUUID();
    await env.DB.prepare(
      `INSERT INTO users
         (id, email, name, password_hash, created_at, last_login_at,
          marketing_consent, country, oauth_provider, oauth_id,
          email_verified, verified_at)
       VALUES (?, ?, ?, '', ?, ?, 0, ?, ?, ?, 1, ?)`,
    )
      .bind(
        id,
        email,
        profile.name,
        now,
        now,
        geoCountry(request),
        provider,
        profile.providerId,
        now,
      )
      .run();
    row = await loadUser(env, id);
  }

  const token = await createSession(env, row!.id);
  await env.DB.prepare('UPDATE oauth_flow SET token = ? WHERE state = ?')
    .bind(token, state)
    .run();
  return htmlPage('Signed in ✓');
}

// Polled by the app to collect the session once the browser flow completes.
// Reads from D1 so the result is visible immediately after /callback writes it.
async function oauthExchange(request: Request, env: Env): Promise<Response> {
  const state = new URL(request.url).searchParams.get('state');
  if (!state) return json({ error: 'state is required' }, 400);
  const flow = await env.DB.prepare(
    'SELECT token FROM oauth_flow WHERE state = ?',
  )
    .bind(state)
    .first<{ token: string | null }>();
  if (!flow || !flow.token) return json({ pending: true }, 202);
  const token = flow.token;
  await env.DB.prepare('DELETE FROM oauth_flow WHERE state = ?')
    .bind(state)
    .run(); // one-time
  const userId = await env.SESSIONS.get(`sess:${token}`);
  const row = userId ? await loadUser(env, userId) : null;
  if (!row) return json({ error: 'session expired' }, 410);
  return json({ token, user: publicUser(row) });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }
    const { pathname } = new URL(request.url);
    const { method } = request;
    try {
      if (method === 'GET' && pathname === '/health') {
        return json({ ok: true, service: 'openmontage-auth' });
      }
      if (method === 'POST' && pathname === '/auth/register') {
        return await register(request, env);
      }
      if (method === 'POST' && pathname === '/auth/login') {
        return await login(request, env);
      }
      if (method === 'GET' && pathname === '/referral') {
        return await referral(request, env);
      }
      if (method === 'GET' && pathname === '/credits') {
        return await credits(request, env);
      }
      if (method === 'POST' && pathname === '/credits/consume') {
        return await consumeCredit(request, env);
      }
      if (method === 'POST' && pathname === '/credits/share-unlock') {
        return await shareUnlock(request, env);
      }
      if (method === 'POST' && pathname === '/billing/checkout') {
        return await billingCheckout(request, env);
      }
      if (method === 'POST' && pathname === '/billing/webhook') {
        return await billingWebhook(request, env);
      }
      if (method === 'GET' && pathname === '/auth/me') {
        return await me(request, env);
      }
      if (method === 'PATCH' && pathname === '/auth/profile') {
        return await updateProfile(request, env);
      }
      if (method === 'POST' && pathname === '/auth/logout') {
        return await logout(request, env);
      }
      if (method === 'GET' && pathname === '/auth/verify') {
        return await verifyEmail(request, env);
      }
      if (method === 'POST' && pathname === '/auth/verify/resend') {
        return await resendVerification(request, env);
      }
      if (method === 'POST' && pathname === '/auth/forgot') {
        return await forgotPassword(request, env);
      }
      if (method === 'GET' && pathname === '/auth/reset') {
        const t = new URL(request.url).searchParams.get('token');
        return t ? resetPage(t) : htmlPage('Invalid reset link');
      }
      if (method === 'POST' && pathname === '/auth/reset') {
        return await resetPassword(request, env);
      }
      if (method === 'POST' && pathname === '/auth/password') {
        return await changePassword(request, env);
      }
      if (method === 'POST' && pathname === '/auth/delete') {
        return await deleteAccount(request, env);
      }
      // OAuth: /auth/oauth/<provider>/start|callback and /auth/oauth/exchange
      const oauth = pathname.match(/^\/auth\/oauth\/([a-z]+)\/(start|callback)$/);
      if (method === 'GET' && oauth) {
        const [, provider, action] = oauth;
        return action === 'start'
          ? await oauthStart(provider, request, env)
          : await oauthCallback(provider, request, env);
      }
      if (method === 'GET' && pathname === '/auth/oauth/exchange') {
        return await oauthExchange(request, env);
      }
      return json({ error: 'not found' }, 404);
    } catch (err) {
      return json({ error: 'internal error', detail: String(err) }, 500);
    }
  },
};
