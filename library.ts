import {admin,requireUser,json} from './_lib/server.js';
export async function GET(request:Request){
 try{
  const user=await requireUser(request);
  const {data,error}=await admin.from('purchase_items')
   .select('id,title,license,amount_eur,beat_client_id,beat_id,created_at,purchases!inner(id,status,user_id),beats(id,producer_name,cover_url)')
   .eq('purchases.user_id',user.id).eq('purchases.status','paid').order('created_at',{ascending:false});
  if(error)throw error;
  const items=(data||[]).map((x:any)=>({id:x.id,title:x.title,license:x.license,amount_eur:Number(x.amount_eur||0),beat_client_id:x.beat_client_id,beat_id:x.beat_id,created_at:x.created_at,producer_name:x.beats?.producer_name||'Creator',cover_url:x.beats?.cover_url||null,allowed_assets:x.license==='Basic'?['MP3']:x.license==='Premium'?['MP3','WAV']:['MP3','WAV','STEMS']}));
  return json({items});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Library failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
