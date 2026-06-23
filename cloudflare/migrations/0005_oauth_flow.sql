-- The desktop OAuth handshake needs strong read-after-write consistency: the
-- /callback request writes the result, and the app's /exchange poll reads it
-- moments later, often from a different Worker invocation. KV is eventually
-- consistent (a write can take up to ~60s to be visible, and misses are
-- negatively cached), which made the poll hang on "waiting for the browser".
-- D1 is strongly consistent, so the poll sees the result immediately.
CREATE TABLE IF NOT EXISTS oauth_flow (
  state      TEXT PRIMARY KEY,   -- client-generated, ties /start -> /callback -> /exchange
  provider   TEXT NOT NULL,      -- 'google' | 'github'
  token      TEXT,               -- session token, set by /callback when sign-in succeeds
  created_at TEXT NOT NULL       -- ISO timestamp, used to expire stale flows
);
