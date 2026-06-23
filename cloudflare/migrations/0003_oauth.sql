-- Link third-party (Google/GitHub) identities to a user.
-- Apply once to the live DB:
--   npx wrangler d1 execute openmontage-auth --remote --file=migrations/0003_oauth.sql
ALTER TABLE users ADD COLUMN oauth_provider TEXT;
ALTER TABLE users ADD COLUMN oauth_id TEXT;
