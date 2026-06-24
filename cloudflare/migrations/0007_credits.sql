-- Usage credits + subscription plan (freemium).
-- credits: remaining free renders; plan: 'free' | 'pro'; share_unlocks_used:
-- how many "share on X to earn credits" rewards have been claimed.
ALTER TABLE users ADD COLUMN credits INTEGER NOT NULL DEFAULT 5;
ALTER TABLE users ADD COLUMN plan TEXT NOT NULL DEFAULT 'free';
ALTER TABLE users ADD COLUMN share_unlocks_used INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN stripe_customer_id TEXT;
