# OpenMontage Studio — auth backend

A small Cloudflare Worker that handles accounts for the app: registration, login,
and session lookup. Backed by **D1** (the `users` table) and **KV** (sessions).
Passwords are hashed with PBKDF2 via Web Crypto — no plaintext, no native deps.

Deployed: `https://openmontage-auth.272876047.workers.dev`

## Endpoints

| Method & path | Body | Returns |
| --- | --- | --- |
| `GET /health` | — | `{ ok }` |
| `POST /auth/register` | `{ email, password, name? }` | `{ token, user }` |
| `POST /auth/login` | `{ email, password }` | `{ token, user }` |
| `GET /auth/me` | `Authorization: Bearer <token>` | `{ user }` |
| `POST /auth/logout` | `Authorization: Bearer <token>` | `{ ok }` |

`token` is an opaque 32-byte session id stored in KV with a 30-day TTL. The app
sends it as `Authorization: Bearer <token>`; users never see any Cloudflare
credential.

## Deploy / maintain

The Cloudflare **deploy token** lives only in `cloudflare/.env` (gitignored) and is
used by Wrangler — never shipped to the app. Load it, then run wrangler:

```bash
cd cloudflare
set -a; source .env; set +a          # exports CLOUDFLARE_API_TOKEN

npx wrangler deploy                   # deploy the Worker
npx wrangler d1 execute openmontage-auth --remote --file=schema.sql   # apply schema
npx wrangler tail                     # live logs
```

Bindings (already created, see `wrangler.toml`):
- D1 database `openmontage-auth` → binding `DB`
- KV namespace `SESSIONS` → binding `SESSIONS`

## Security & privacy notes

- **Rotate the deploy token** if it has been exposed; it only needs Workers
  Scripts / D1 / KV / Account Settings.
- **Collect the minimum.** The schema stores email, name, a password hash, and
  timestamps. Add fields deliberately, and don't store sensitive data you don't
  need.
- **Harden before real users:** add Cloudflare Turnstile on the signup path
  (bot defence), rate-limit `login`/`register`, and add email verification +
  password reset. Consider passkeys/OAuth to avoid storing passwords at all.
- If you serve EU/CA users, add consent + a privacy policy and a delete-account
  path (GDPR/CCPA).
