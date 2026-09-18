import {admin,requireUser,json} from './_lib/server.js';
const allowedByLicense:any={Basic:['MP3'],Premium:['MP3','WAV'],Unlimited:['MP3','WAV','STEMS'],Exclusive:['MP3','WAV','STEMS']};
export async function POST(request:Request){
 try{
  const user=await requireUser(request);const {purchaseItemId,assetType}=await request.json();const type=String(assetType||'').toUpperCase();
  const {data:item,error}=await admin.from('purchase_items').select('id,license,beat_id,purchases!inner(status,user_id)').eq('id',String(purchaseItemId||'')).eq('purchases.user_id',user.id).eq('purchases.status','paid').maybeSingle();
  if(error)throw error;if(!item)return json({error:'Licensed purchase not found'},404);
  if(!(allowedByLicense[item.license]||[]).includes(type))return json({error:'Asset is not included in this license'},403);
  if(!item.beat_id)return json({error:'This demo catalog item has no cloud asset yet'},404);
  const {data:asset}=await admin.from('beat_assets').select('storage_path,asset_type').eq('beat_id',item.beat_id).eq('asset_type',type).maybeSingle();
  if(!asset)return json({error:'Asset has not been uploaded by the producer yet'},404);
  const {data:signed,error:signErr}=await admin.storage.from('licensed-assets').createSignedUrl(asset.storage_path,300,{download:true});if(signErr)throw signErr;
  return json({url:signed.signedUrl,expires_in:300,asset_type:type});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Download failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
