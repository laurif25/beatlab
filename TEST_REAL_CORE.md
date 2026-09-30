# BEATLAB v15 — Real Core activation

This version keeps Home and the final visual redesign frozen. The goal is to prove the real cloud flows.

## 1. Supabase
Run `supabase_schema.sql` on a fresh/test project, then configure the environment variables from `.env.example`.

Create two normal test accounts from the app (Producer + Artist). Do not use real payment data while validating the product.

## 2. Required cloud smoke test
Install dependencies and run:

`npm run test:cloud`

The test creates temporary users and validates paid purchase → private Project Room, idempotency and RLS isolation, then deletes the temporary auth users.

## 3. Marketplace test path
Producer: upload a beat and, for delivery tests, create `beat_assets` rows whose `storage_path` points to private objects in the `licensed-assets` bucket.

Artist: add license → Stripe test checkout → webhook changes purchase to `paid` → Library appears → request licensed asset → start Project Room.

Asset entitlements:
- Basic: MP3
- Premium: MP3 + WAV
- Unlimited: MP3 + WAV + STEMS
- Exclusive: MP3 + WAV + STEMS

The browser never receives the Supabase secret/server key and never gets permanent private file URLs. `/api/download-asset` generates a 5-minute signed URL only after verifying the authenticated paid purchase and license.

## 4. Stripe test mode
Configure a Stripe test webhook for `/api/stripe-webhook`. Validate success, cancellation, expiration and an Exclusive purchase before enabling any live-money configuration.

## 5. Definition of pass
Do not call the flow production-ready until two separate normal accounts can complete the path and an unrelated third account cannot read the purchase, project, private submission or private file.


## v15.1 connection check
After deployment, open `/api/readiness`. It should report `ok: true` and `supabase: true`. The endpoint exposes booleans only, never key values.


## v15.2.2 Beat ID / Stripe Checkout Fix
- Resolves frontend IDs such as `b1` against both `b1` and normalized `1` in Supabase.
- Demo catalog fallback also resolves `b1` -> `1`.
