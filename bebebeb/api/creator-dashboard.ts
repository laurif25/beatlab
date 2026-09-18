import {admin,requireUser,json} from './_lib/server.js';
export async function GET(request:Request){
 try{
  const user=await requireUser(request);const url=new URL(request.url);
  const days=Math.max(1,Math.min(3650,Number(url.searchParams.get('days')||28)));
  const trackId=url.searchParams.get('track_id');const since=new Date(Date.now()-days*86400000).toISOString();
  let q=admin.from('analytics_events').select('event_type,meta,created_at,country_code,country_name,city,duration_seconds,source,is_promoted,track_id').eq('creator_id',user.id).gte('created_at',since).limit(20000);
  if(trackId) q=q.eq('track_id',trackId);
  const {data:events,error}=await q;if(error)throw error;
  const counts:any={},countries:any={},cities:any={},sources:any={};let duration=0,plays=0;
  for(const e of events||[]){
   counts[e.event_type]=(counts[e.event_type]||0)+1;
   if(e.event_type==='play'||e.event_type==='stream'){plays++;duration+=Number(e.duration_seconds||e.meta?.duration_seconds||0)}
   const cc=e.country_code||e.meta?.country_code,cn=e.country_name||e.meta?.country_name||cc,city=e.city||e.meta?.city,src=e.source||e.meta?.source||'unknown';
   if(cc){countries[cc]=countries[cc]||{code:cc,name:cn,streams:0,cities:{}};countries[cc].streams++;if(city)countries[cc].cities[city]=(countries[cc].cities[city]||0)+1}
   if(city)cities[city]=(cities[city]||0)+1;sources[src]=(sources[src]||0)+1;
  }
  const {data:ledger}=await admin.from('creator_payout_ledger').select('gross_eur,platform_fee_eur,net_eur,status,created_at').eq('seller_id',user.id).gte('created_at',since);
  const money=(ledger||[]).reduce((a:any,x:any)=>({gross:a.gross+Number(x.gross_eur||0),fees:a.fees+Number(x.platform_fee_eur||0),net:a.net+Number(x.net_eur||0)}),{gross:0,fees:0,net:0});
  const geo=Object.values(countries).map((c:any)=>({...c,cities:Object.entries(c.cities).sort((a:any,b:any)=>b[1]-a[1]).map(([name,streams])=>({name,streams}))})).sort((a:any,b:any)=>b.streams-a.streams);
  return json({days,track_id:trackId||null,counts,money,events:events?.length||0,plays,avg_listen_seconds:plays?duration/plays:0,geo,sources:Object.entries(sources).sort((a:any,b:any)=>b[1]-a[1]).map(([name,count])=>({name,count}))});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Dashboard failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
