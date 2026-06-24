# Billing setup (Stripe)

The freemium credit system works without Stripe — users get free renders, can
share on X for more, and earn credits by inviting friends. To turn on the **Pro
subscription** ("Upgrade" in the paywall), connect Stripe. Until then,
`/billing/checkout` returns `501 billing not configured` and the app shows
"Pro checkout is coming soon."

## One-time setup

1. Create a [Stripe](https://dashboard.stripe.com) account.
2. **Product → add a Product** named `OpenMontage Pro` with a **recurring Price**
   (e.g. monthly). Copy the price id (`price_...`).
3. **Developers → Webhooks → add endpoint**:
   - URL: `https://auth.opencli.ai/billing/webhook`
   - Events: `checkout.session.completed`, `customer.subscription.deleted`
   - Copy the signing secret (`whsec_...`).
4. Set the three secrets on the Worker (run in `cloudflare/`):

   ```bash
   npx wrangler secret put STRIPE_SECRET_KEY      # sk_live_... (or sk_test_...)
   npx wrangler secret put STRIPE_PRICE_ID        # price_...
   npx wrangler secret put STRIPE_WEBHOOK_SECRET  # whsec_...
   ```

That's it — the next deploy isn't even required; secrets take effect immediately.
The webhook flips an account to `plan = 'pro'` on payment and back to `free` on
cancellation. Test with Stripe test mode keys + a `4242 4242 4242 4242` card first.

## Pricing knobs (in `src/index.ts`)

- `FREE_CREDITS` — free renders per new account (currently 5).
- `SHARE_REWARD` / `SHARE_MAX` — credits per X share and how many times.
- `REFERRAL_CREDIT` — credits granted to the referrer per signup.
