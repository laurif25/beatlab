import { createClient } from '@supabase/supabase-js';
import Stripe from 'stripe';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseServerKey = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_missing');
export const admin = createClient(supabaseUrl, supabaseServerKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

export async function requireUser(request) {
  const token = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) throw new Error('AUTH_REQUIRED');
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new Error('AUTH_REQUIRED');
  return data.user;
}

export function json(data, status = 200) {
  return Response.json(data, { status, headers: { 'cache-control': 'no-store' } });
}

export function baseUrl(request) {
  return process.env.PUBLIC_SITE_URL || new URL(request.url).origin;
}

export const demoCatalog = {
  '1': {title:'MOTION',producer:'ALEX',prices:{Basic:19.99,Premium:29.99,Unlimited:49.99,Exclusive:149.99}},
  '2': {title:'NIGHT SHIFT',producer:'NOVA',prices:{Basic:29.99,Premium:44.99,Unlimited:69.99,Exclusive:199.99}},
  '3': {title:'BLUE ROOM',producer:'REX',prices:{Basic:14.99,Premium:24.99,Unlimited:44.99,Exclusive:129.99}},
  '4': {title:'CITY LIGHTS',producer:'KAY',prices:{Basic:18.99,Premium:28.99,Unlimited:48.99,Exclusive:149.99}},
  '5': {title:'HEAT',producer:'MILO',prices:{Basic:24.99,Premium:39.99,Unlimited:64.99,Exclusive:189.99}},
  '6': {title:'VOID',producer:'SAGE',prices:{Basic:34.99,Premium:49.99,Unlimited:79.99,Exclusive:249.99}},
  '7': {title:'RAIN WINDOW',producer:'LUNA',prices:{Basic:9.99,Premium:19.99,Unlimited:34.99,Exclusive:99.99}},
  '8': {title:'NEON',producer:'KAI',prices:{Basic:39.99,Premium:59.99,Unlimited:89.99,Exclusive:299.99}},
  '9': {title:'SUNSET',producer:'JAY',prices:{Basic:17.99,Premium:27.99,Unlimited:47.99,Exclusive:139.99}},
  '10': {title:'AFTER DARK',producer:'NOVA',prices:{Basic:22.99,Premium:34.99,Unlimited:54.99,Exclusive:169.99}},
  '11': {title:'FREE FALL',producer:'REX',prices:{Basic:0,Premium:0,Unlimited:0,Exclusive:0}},
  '12': {title:'PRESSURE',producer:'MILO',prices:{Basic:27.99,Premium:42.99,Unlimited:67.99,Exclusive:209.99}}
};
