-- Users for OpenMontage Studio accounts.
-- Keep this minimal: store what you need to authenticate and contact a user.
-- email is UNIQUE (which also indexes it). Passwords are never stored in clear
-- text — password_hash holds a PBKDF2 digest.
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  name          TEXT,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL,
  last_login_at TEXT
);
