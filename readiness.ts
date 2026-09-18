import { createClient } from '@supabase/supabase-js';

export async function GET() {
  const supabaseUrl = process.env.SUPABASE_URL || '';
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || '';
  const serverKey = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

  const configured = {
    supabaseUrl: Boolean(supabaseUrl),
    supabasePublishableKey: Boolean(publishableKey),
    supabaseServerKey: Boolean(serverKey),
    stripeSecretKey: Boolean(process.env.STRIPE_SECRET_KEY),
    stripeWebhookSecret: Boolean(process.env.STRIPE_WEBHOOK_SECRET),
    publicSiteUrl: Boolean(process.env.PUBLIC_SITE_URL)
  };

  const missing = Object.entries({
    SUPABASE_URL: configured.supabaseUrl,
    SUPABASE_PUBLISHABLE_KEY: configured.supabasePublishableKey,
    SUPABASE_SECRET_KEY: configured.supabaseServerKey
  }).filter(([, ok]) => !ok).map(([name]) => name);

  if (missing.length) {
    return Response.json({
      ok: false,
      stage: 'configuration',
      configured,
      missing,
      supabase: false,
      error: `Missing required environment variable(s): ${missing.join(', ')}`
    }, { status: 503, headers: { 'cache-control': 'no-store' } });
  }

  try {
    const admin = createClient(supabaseUrl, serverKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const { error } = await admin.from('profiles').select('id').limit(1);
    if (error) throw error;

    return Response.json({
      ok: true,
      stage: 'supabase',
      configured,
      supabase: true,
      message: 'Vercel can reach Supabase and the BEATLAB profiles table.'
    }, { status: 200, headers: { 'cache-control': 'no-store' } });
  } catch (error: any) {
    return Response.json({
      ok: false,
      stage: 'supabase',
      configured,
      supabase: false,
      error: error?.message || 'Supabase connection check failed'
    }, { status: 503, headers: { 'cache-control': 'no-store' } });
  }
}
