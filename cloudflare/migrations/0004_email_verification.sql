-- Email verification state.
-- Apply once to the live DB:
--   npx wrangler d1 execute openmontage-auth --remote --file=migrations/0004_email_verification.sql
ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN verified_at TEXT;
