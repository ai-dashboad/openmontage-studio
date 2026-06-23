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
  };
}

function geoCountry(request: Request): string | null {
  const cf = (request as unknown as { cf?: { country?: string } }).cf;
  return cf?.country ?? null;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function loadUser(env: Env, id: string): Promise<UserRow | null> {
  return env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first<UserRow>();
}

// ---- handlers ----

async function register(request: Request, env: Env): Promise<Response> {
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

  await env.DB.prepare(
    `INSERT INTO users
       (id, email, name, password_hash, created_at,
        marketing_consent, consent_at, marketing_source, use_case, country, locale)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
    )
    .run();

  const token = await createSession(env, id);
  const row = await loadUser(env, id);
  return json({ token, user: publicUser(row!) });
}

async function login(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');

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
      if (method === 'GET' && pathname === '/auth/me') {
        return await me(request, env);
      }
      if (method === 'PATCH' && pathname === '/auth/profile') {
        return await updateProfile(request, env);
      }
      if (method === 'POST' && pathname === '/auth/logout') {
        return await logout(request, env);
      }
      return json({ error: 'not found' }, 404);
    } catch (err) {
      return json({ error: 'internal error', detail: String(err) }, 500);
    }
  },
};
