import {admin,requireUser,json} from './_lib/server.js';
export async function POST(request:Request){
 try{
  const user=await requireUser(request);const {purchaseItemId}=await request.json();const itemId=String(purchaseItemId||'');
  const {data:item,error}=await admin.from('purchase_items').select('id,title,license,beat_client_id,purchases!inner(status,user_id)').eq('id',itemId).eq('purchases.user_id',user.id).eq('purchases.status','paid').maybeSingle();
  if(error)throw error;if(!item)return json({error:'Paid purchase item not found'},404);
  const {data:existing}=await admin.from('project_rooms').select('id').eq('purchase_item_id',item.id).eq('owner_id',user.id).maybeSingle();if(existing?.id)return json({project_room_id:existing.id,reused:true});
  const {data:room,error:roomErr}=await admin.from('project_rooms').insert({owner_id:user.id,title:`${item.title} — Project`,status:'Open',source_type:'purchase_item',source_id:item.id,source_client_id:item.beat_client_id,license_name:item.license,release_readiness:15,purchase_item_id:item.id}).select('id').single();if(roomErr)throw roomErr;
  await admin.from('project_members').upsert({project_room_id:room.id,user_id:user.id,role:'owner'},{onConflict:'project_room_id,user_id'});
  return json({project_room_id:room.id,reused:false});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Project creation failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
