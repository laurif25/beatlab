import {admin,requireUser,json} from './_lib/server.js';
const allowed=new Set(['play','stream','complete','like','save','repost','comment','reaction','profile_view','follow']);
export async function POST(request:Request){
 try{
  const user=await requireUser(request);const b=await request.json();const eventType=String(b.event_type||'');if(!allowed.has(eventType))return json({error:'Unsupported event'},400);
  const trackId=String(b.track_id||'');const {data:t}=await admin.from('tracks').select('id,owner_id').eq('id',trackId).maybeSingle();if(!t)return json({error:'Track not found'},404);
  const duration=Math.max(0,Math.min(86400,Number(b.duration_seconds||0)));const meta=(b.meta&&typeof b.meta==='object')?b.meta:{};
  const row={user_id:user.id,creator_id:t.owner_id,track_id:t.id,event_type:eventType,duration_seconds:duration,source:String(b.source||'beatlab').slice(0,80),is_promoted:Boolean(b.is_promoted),country_code:null,country_name:null,city:null,meta};
  const {error}=await admin.from('analytics_events').insert(row);if(error)throw error;return json({ok:true});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Analytics event failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
