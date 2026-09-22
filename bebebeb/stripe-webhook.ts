import {stripe,admin,json} from './_lib/server.js';
const PLATFORM_FEE_PCT=0.10;
async function settleMarketplacePurchase(session:any){
 const purchaseId=String(session.metadata?.purchase_id||''); if(!purchaseId)return;
 await admin.from('purchases').update({status:'paid',stripe_payment_intent_id:String(session.payment_intent||'')}).eq('id',purchaseId);
 const {data:items}=await admin.from('purchase_items').select('*').eq('purchase_id',purchaseId);
 let sourceCharge:string|undefined;
 try{if(session.payment_intent){const pi:any=await stripe.paymentIntents.retrieve(String(session.payment_intent),{expand:['latest_charge']});sourceCharge=typeof pi.latest_charge==='string'?pi.latest_charge:pi.latest_charge?.id;}}catch(e){console.warn('charge lookup failed',e)}
 for(const item of items||[]){
  const gross=Number(item.amount_eur||0),fee=Math.round(gross*PLATFORM_FEE_PCT*100)/100,net=Math.max(0,Math.round((gross-fee)*100)/100);
  let status='pending_account',transferId:string|null=null;
  if(item.seller_id){const {data:seller}=await admin.from('profiles').select('stripe_account_id,stripe_charges_enabled').eq('id',item.seller_id).maybeSingle();
   if(seller?.stripe_account_id&&seller?.stripe_charges_enabled&&net>0){try{const tr=await stripe.transfers.create({amount:Math.round(net*100),currency:'eur',destination:seller.stripe_account_id,transfer_group:`purchase_${purchaseId}`,...(sourceCharge?{source_transaction:sourceCharge}:{})});transferId=tr.id;status='paid';}catch(e){console.error('seller transfer failed',e);status='transfer_failed';}}
  }
  await admin.from('creator_payout_ledger').upsert({purchase_item_id:item.id,seller_id:item.seller_id,gross_eur:gross,platform_fee_eur:fee,net_eur:net,stripe_transfer_id:transferId,status,paid_at:status==='paid'?new Date().toISOString():null},{onConflict:'purchase_item_id'});
  if(item.license==='Exclusive'&&item.beat_id){await admin.from('beats').update({exclusive_sold:true,exclusive_buyer_id:session.metadata?.user_id,exclusive_sold_at:new Date().toISOString(),active:false}).eq('id',item.beat_id);await admin.from('exclusive_reservations').delete().eq('beat_id',item.beat_id);}
 }
 await admin.from('notifications').insert({user_id:session.metadata.user_id,type:'purchase',body:'Your BEATLAB purchase is complete.',meta:{purchase_id:purchaseId}});
}
export async function POST(request:Request){const raw=await request.text();const sig=request.headers.get('stripe-signature');if(!sig||!process.env.STRIPE_WEBHOOK_SECRET)return json({error:'Webhook not configured'},400);let event:any;try{event=stripe.webhooks.constructEvent(raw,sig,process.env.STRIPE_WEBHOOK_SECRET)}catch(e:any){return json({error:'Invalid signature'},400)}
 try{
  if(event.type==='checkout.session.completed'){const s:any=event.data.object;const kind=s.metadata?.kind;
   if(kind==='cart')await settleMarketplacePurchase(s);
   if(kind==='promote'){const {data:old}=await admin.from('campaigns').select('*').eq('id',s.metadata.campaign_id).single();const days=Math.max(1,Math.min(90,Number(old?.days||30)));const {data:c}=await admin.from('campaigns').update({status:'ACTIVE',starts_at:new Date().toISOString(),ends_at:new Date(Date.now()+days*86400000).toISOString()}).eq('id',s.metadata.campaign_id).select().single();if(c)await admin.from('notifications').insert({user_id:c.owner_id,type:'promote',body:'Your promotion campaign is now active.',meta:{campaign_id:c.id}})}
   if(kind==='support'){await admin.from('support_payments').update({status:'paid'}).eq('stripe_session_id',s.id);await admin.from('notifications').insert({user_id:s.metadata.creator_id,type:'support',body:'Someone supported you on BEATLAB.',meta:{amount:s.metadata.amount}})}
  }
  if(event.type==='checkout.session.expired'){const s:any=event.data.object;if(s.metadata?.kind==='cart'&&s.metadata?.purchase_id){await admin.from('exclusive_reservations').delete().eq('purchase_id',s.metadata.purchase_id);await admin.from('purchases').update({status:'expired'}).eq('id',s.metadata.purchase_id)}}
  if(event.type==='account.updated'){const a:any=event.data.object;await admin.from('profiles').update({stripe_charges_enabled:Boolean(a.charges_enabled)}).eq('stripe_account_id',a.id)}
  return json({received:true});
 }catch(e:any){console.error(e);return json({error:'Webhook processing failed'},500)}}
