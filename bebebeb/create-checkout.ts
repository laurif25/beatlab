import {stripe,admin,requireUser,json,baseUrl,demoCatalog} from './_lib/server.js';
const allowedLicenses=['Basic','Premium','Unlimited','Exclusive'];
export async function POST(request:Request){try{
 const user=await requireUser(request); const body=await request.json(); const kind=String(body.kind||''); const origin=baseUrl(request);
 if(!process.env.STRIPE_SECRET_KEY)return json({error:'Stripe is not configured'},503);
 if(kind==='cart'){
  const items=Array.isArray(body.items)?body.items.slice(0,20):[]; if(!items.length)return json({error:'Cart is empty'},400);
  const line_items:any[]=[]; const metadataItems:any[]=[];
  for(const row of items){const localId=String(row.beatId);const normalizedId=/^b\d+$/i.test(localId)?localId.slice(1):localId;const license=allowedLicenses.includes(row.license)?row.license:'Basic';let title='',amount=0,sellerId:null,beatUuid:null;
   const lookupIds=[localId,...(normalizedId!==localId?[normalizedId]:[])];const {data:dbBeats,error:beatLookupError}=await admin.from('beats').select('*').in('client_id',lookupIds).eq('active',true).limit(1);if(beatLookupError)throw beatLookupError;const dbBeat=dbBeats?.[0]||null;
   if(dbBeat){title=dbBeat.title;beatUuid=dbBeat.id;sellerId=dbBeat.owner_id;amount=Number((dbBeat.license_prices||{})[license]??0)}else{const d=demoCatalog[localId]||demoCatalog[normalizedId];if(!d)return json({error:'Beat not found: '+localId},404);title=d.title;amount=Number(d.prices[license]??0)}
   if(amount<0||amount>10000)throw new Error('Invalid price'); line_items.push({quantity:1,price_data:{currency:'eur',unit_amount:Math.round(amount*100),product_data:{name:`${title} · ${license} License`,metadata:{beat_client_id:localId,license}}}});metadataItems.push({beatClientId:localId,beatId:beatUuid,title,license,amount,sellerId});
  }
  const total=metadataItems.reduce((a,x)=>a+x.amount,0);const {data:purchase,error}=await admin.from('purchases').insert({user_id:user.id,status:'pending',total_eur:total}).select().single();if(error)throw error;
  for(const x of metadataItems.filter(x=>x.license==='Exclusive'&&x.beatId)){const {data:ok,error:lockErr}=await admin.rpc('reserve_exclusive_beat',{p_beat_id:x.beatId,p_buyer_id:user.id,p_purchase_id:purchase.id});if(lockErr||!ok){await admin.from('purchases').delete().eq('id',purchase.id);return json({error:`Exclusive license is currently unavailable: ${x.title}`},409)}}
  await admin.from('purchase_items').insert(metadataItems.map(x=>({purchase_id:purchase.id,beat_id:x.beatId,beat_client_id:x.beatClientId,title:x.title,license:x.license,amount_eur:x.amount,seller_id:x.sellerId})));
  const session=await stripe.checkout.sessions.create({mode:'payment',line_items,success_url:`${origin}/?payment=success&session_id={CHECKOUT_SESSION_ID}`,cancel_url:`${origin}/?payment=cancelled`,customer_email:user.email||undefined,metadata:{kind:'cart',user_id:user.id,purchase_id:purchase.id}});
  await admin.from('purchases').update({stripe_session_id:session.id}).eq('id',purchase.id);return json({url:session.url});
 }
 if(kind==='promote'){
  const campaignId=String(body.campaignId||'');const {data:c,error}=await admin.from('campaigns').select('*').eq('id',campaignId).eq('owner_id',user.id).single();if(error||!c)return json({error:'Campaign not found'},404);
  const amount=Number(c.amount_eur);const session=await stripe.checkout.sessions.create({mode:'payment',line_items:[{quantity:1,price_data:{currency:'eur',unit_amount:Math.round(amount*100),product_data:{name:`BEATLAB Promote · ${c.kind}`,description:`${c.days} day campaign · ${c.target_label||'BEATLAB placement'}`}}}],success_url:`${origin}/?payment=success&campaign=${c.id}`,cancel_url:`${origin}/?payment=cancelled`,customer_email:user.email||undefined,metadata:{kind:'promote',user_id:user.id,campaign_id:c.id}});await admin.from('campaigns').update({stripe_session_id:session.id}).eq('id',c.id);return json({url:session.url});
 }
 if(kind==='support'){
  const creatorId=String(body.creatorId||'');const amount=Number(body.amount);if(![2,5,10,25,50].includes(amount))return json({error:'Unsupported amount'},400);const {data:creator}=await admin.from('profiles').select('id,display_name,stripe_account_id,stripe_charges_enabled').eq('id',creatorId).single();if(!creator)return json({error:'Creator not found'},404);
  const opts:any={mode:'payment',line_items:[{quantity:1,price_data:{currency:'eur',unit_amount:amount*100,product_data:{name:`Support ${creator.display_name} on BEATLAB`}}}],success_url:`${origin}/?payment=success`,cancel_url:`${origin}/?payment=cancelled`,customer_email:user.email||undefined,metadata:{kind:'support',user_id:user.id,creator_id:creatorId,amount:String(amount)}};
  if(creator.stripe_account_id&&creator.stripe_charges_enabled){opts.payment_intent_data={application_fee_amount:Math.max(1,Math.round(amount*100*0.1)),transfer_data:{destination:creator.stripe_account_id}}}
  const session=await stripe.checkout.sessions.create(opts);await admin.from('support_payments').insert({supporter_id:user.id,creator_id:creatorId,stripe_session_id:session.id,amount_eur:amount,status:'pending'});return json({url:session.url});
 }
 return json({error:'Unsupported checkout kind'},400);
}catch(e:any){console.error(e);return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Checkout failed'},e?.message==='AUTH_REQUIRED'?401:500)}}
