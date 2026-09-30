# BEATLAB v17 Functional Core

Built on the confirmed v16.0.4 checkpoint. No visual redesign.

Included/connected:
- Cloud Marketplace loads active Supabase beats so creator uploads can appear in Marketplace/Search.
- Creator Beat Upload uses Storage for preview audio/cover and server API for beat metadata/pricing.
- Existing private Project Files and persistent Project Tasks retained.
- Existing secure Library/download endpoint retained for licensed assets.
- Existing Open Track server flow retained (create, submit, accept -> Project Room).
- Existing Stripe Sandbox checkout/Connect/webhook marketplace code retained.
- Creator Dashboard endpoint is wired into Studio analytics.
- Audience Globe now slowly auto-rotates, pauses/locks on country selection, and resumes after deselection/manual interaction.
- RLS UPDATE hardening applied for conversations and Open Track submissions.

QA is intentionally deferred until the planned page-by-page functional pass.
