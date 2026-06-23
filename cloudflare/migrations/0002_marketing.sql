-- Adds consented marketing / segmentation fields to an existing users table.
-- Apply once to the live DB:
--   npx wrangler d1 execute openmontage-auth --remote --file=migrations/0002_marketing.sql
ALTER TABLE users ADD COLUMN marketing_consent INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN consent_at TEXT;
ALTER TABLE users ADD COLUMN marketing_source TEXT;
ALTER TABLE users ADD COLUMN use_case TEXT;
ALTER TABLE users ADD COLUMN country TEXT;
ALTER TABLE users ADD COLUMN locale TEXT;
