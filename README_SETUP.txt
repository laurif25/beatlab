BEATLAB v10 — FUNCTIONAL CORE

DESIGN LOCK
- The Kimi design remains the visual base.
- This build intentionally does NOT implement the three deferred visual projects: cinematic DJ/Home redesign, Reactive Genre Worlds, or new cover/artwork direction.

FUNCTIONAL UPGRADES
- Global player: synced lyrics drawer, credits, up-next queue, Media Session controls, swipe next/previous on mobile.
- Track pages: lyrics, credits, BEATLAB Track Passport, playlist/save/share workflow.
- Marketplace: license-rights matrix and server-side exclusive reservations.
- Multi-seller marketplace payout ledger with Stripe Connect separate charges/transfers after successful checkout.
- Profiles: Creator Passport, releases, selected credits, EPK/share utilities.
- Project Room: version upload, task board, file upload/storage, split-sheet project record.
- Creator Studio: geography, discovery sources, retention, revenue breakdown, payout ledger, CSV export.
- Mobile: Media Session + swipe now-playing behavior; existing Kimi mobile nav/player preserved.
- Analytics event model/API added for Creator Studio.
- New backend models: lyrics, credits, reposts, reactions, releases, release_tracks, project_tasks, project_files, project_splits, analytics_events, exclusive_reservations, creator_payout_ledger.

SETUP
1. Create a Supabase project.
2. Run supabase_schema.sql in Supabase SQL Editor. If v9 is already installed, the schema is idempotent for the new tables/columns/policies where possible.
3. Configure the Vercel environment variables from .env.example.
4. Configure Stripe webhook to /api/stripe-webhook.
5. Deploy this folder to Vercel.
6. Create/finish Stripe connected accounts only for creators who are legally/payment-provider eligible. Do not bypass Stripe identity, age, or account requirements.

IMPORTANT
- Demo mode still works without Supabase/Stripe.
- Real money flows require live Stripe/Supabase configuration and end-to-end testing.
- The split sheet inside Project Room is a project record, not a substitute for legal advice or a signed legal agreement.
- Multi-seller checkout uses platform charge + separate transfers. The platform is responsible for the payment/fees/refunds/chargebacks under this model; review Stripe Connect requirements before production.

BEATLAB v13 CONNECTED CORE
--------------------------
This build keeps Home and the final visual redesign intentionally untouched. It connects the product flows:
- checkout/demo purchase -> Library -> Project Room -> release draft
- Open Track private submission -> acceptance -> Project Room
- Project Room keeps source/license provenance and release readiness
- Creator Studio dashboard API can aggregate event geography (country/city), source and listening duration
- Sound profiles and Open Track data have RLS-protected tables

Important: SQL must be executed in a real Supabase project before cloud-only v13 functions work. Stripe/Supabase live flows still require test-mode end-to-end verification with real accounts. Demo/local flows remain available in the browser.

BEATLAB v14 FEATURE COMPLETE BEFORE DESIGN
-----------------------------------------
Home and the final visual redesign are intentionally frozen.
Added pre-design completion layers: contextual player/queue/history/offline-ready state, licensed Library file actions, universal search, deeper discovery modes, Creator Studio growth actions, Project Room credits/split/version pipeline, account/privacy surface, PWA shell, geo aggregate schema and track moments.

IMPORTANT PRODUCTION NOTES
- Demo/local flows are functional prototypes. Do not treat them as live payment, legal-license, or royalty systems.
- Execute and review the Supabase schema in a real project before enabling cloud features.
- Test Stripe Checkout + Connect in test mode end-to-end before accepting real payments.
- Creator payout availability depends on payment-provider eligibility, verification, age/account requirements and local law.
- Do not persist exact listener IP/address. Aggregate approximate country/city analytics server-side.
- PWA service worker intentionally does not cache API, private project files, or licensed audio assets.
- Final Home and final visual design are deferred by product decision.

BEATLAB v15 REAL CORE
---------------------
Home and the final visual redesign are intentionally unchanged.
New cloud-hardening pieces:
- authenticated /api/library
- licensed /api/download-asset with 5-minute signed URLs
- authenticated /api/create-project verifying paid ownership
- /api/analytics-event bound to the real track owner
- beat_assets entitlement table
- idempotent paid-purchase -> Project Room linkage
- scripts/e2e-cloud-smoke.mjs for 3-account RLS isolation checks
See TEST_REAL_CORE.md before calling the build production-ready.


BEATLAB v15.1 PRODUCTION CONNECTION READY
-----------------------------------------
- Server Supabase client now prefers SUPABASE_SECRET_KEY (sb_secret_...) with temporary legacy SUPABASE_SERVICE_ROLE_KEY fallback.
- Licensed MP3/WAV/STEMS delivery uses the private `licensed-assets` Storage bucket; public previews remain in `audio`.
- /api/readiness reports only boolean configuration/connectivity state and never returns secret values.
- Home and visual design remain unchanged.

BEATLAB v15.1.2 diagnostic readiness fix:
- /api/readiness is self-contained and no longer imports api/_lib/server.js.
- It reports missing Supabase environment variable names without exposing values.
- It only creates the Supabase client after required variables are confirmed present.


BEATLAB v16 CONNECTED PRODUCT CORE
- Checkout v15.2.3 preserved.
- Cloud Project Room read/write API with explicit membership authorization.
- Cloud tasks persist and sync.
- Per-member split persistence/confirmation.
- Open Track server API for create/submit/accept -> Project Room.
- Creator beat metadata publish API.
- No visual redesign; Kimi baseline remains frozen.
- Stripe remains Sandbox/Test for development.


v16.0.1 PROJECT ROOM INPUT FIX
- Fixes an infinite cloud-sync/render loop in Project Room.
- The loop continuously called route() after every Supabase load and could starve clicks.
- Cloud state now auto-loads once per Project Room entry; SYNC ROOM remains explicit.
- No visual/design changes.


v16.0.2 PROJECT ROOM CLOUD FIX
- Project Room task/split sync now uses the signed-in Supabase client directly.
- RLS is the authorization boundary; no secret/service key reaches the browser.
- Removes the fragile extra server hop for room tasks/splits.
- Errors now surface the actual Supabase message in the UI.
- No design changes; checkout untouched.


BEATLAB v16.0.3
- Marketplace live search added.
- Full deploy package retains all Vercel API routes and existing backend files from v16.0.2.
