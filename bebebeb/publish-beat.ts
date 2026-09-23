import {admin,requireUser,json} from './_lib/server.js';
export async function POST(request:Request){
 try{
  const user=await requireUser(request), b=await request.json();
  const title=String(b.title||'').trim().slice(0,120); if(!title)return json({error:'Beat title required'},400);
  const prices=b.licensePrices||{};
  const clean:any={};
  for(const k of ['Basic','Premium','Unlimited','Exclusive']){const n=Number(prices[k]);if(Number.isFinite(n)&&n>=0&&n<=100000)clean[k]=Math.round(n*100)/100}
  if(clean.Basic==null)clean.Basic=19.99;
  const row={owner_id:user.id,client_id:String(b.clientId||('user-'+Date.now())).slice(0,120),title,producer_name:String(b.producerName||user.user_metadata?.display_name||'Creator').slice(0,120),genre:String(b.genre||'').slice(0,80)||null,bpm:b.bpm?Math.max(40,Math.min(260,Math.round(Number(b.bpm)))):null,music_key:String(b.musicKey||'').slice(0,20)||null,audio_url:String(b.audioUrl||'').slice(0,1000)||null,cover_url:String(b.coverUrl||'').slice(0,1000)||null,license_prices:clean,active:Boolean(b.active??true)};
  const {data,error}=await admin.from('beats').insert(row).select('id,client_id,title,producer_name,genre,bpm,music_key,license_prices,active,created_at').single();if(error)throw error;
  return json({beat:data});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Beat publish failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
