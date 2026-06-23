-- Users for OpenMontage Studio accounts (full schema for a fresh database).
-- For an existing database, apply migrations/ instead.
--
-- Keep this minimal and consented: email/name/password to authenticate; the
-- marketing_* fields are collected only on explicit opt-in (marketing_consent),
-- with consent_at recording when. Passwords are never stored in clear text.
CREATE TABLE IF NOT EXISTS users (
  id                TEXT PRIMARY KEY,
  email             TEXT UNIQUE NOT NULL,
  name              TEXT,
  password_hash     TEXT NOT NULL,
  created_at        TEXT NOT NULL,
  last_login_at     TEXT,
  marketing_consent INTEGER NOT NULL DEFAULT 0,
  consent_at        TEXT,
  marketing_source  TEXT,   -- how they heard about us (acquisition channel)
  use_case          TEXT,   -- what they want to make (segmentation)
  country           TEXT,   -- from Cloudflare request geo
  locale            TEXT
);
