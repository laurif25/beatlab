import {createClient} from '@supabase/supabase-js';
const need=['SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY'];for(const k of need)if(!process.env[k])throw new Error(`Missing ${k}`);
const service=process.env.SUPABASE_SECRET_KEY||process.env.SUPABASE_SERVICE_ROLE_KEY;if(!service)throw new Error('Missing SUPABASE_SECRET_KEY (or legacy SUPABASE_SERVICE_ROLE_KEY)');
const url=process.env.SUPABASE_URL,pub=process.env.SUPABASE_PUBLISHABLE_KEY;
const admin=createClient(url,service,{auth:{persistSession:false}});
const stamp=Date.now();const sellerEmail=`beatlab-seller-${stamp}@example.test`,buyerEmail=`beatlab-buyer-${stamp}@example.test`,otherEmail=`beatlab-other-${stamp}@example.test`;const pass='BeatlabTest!'+stamp;
async function mk(email,name,role){const {data,error}=await admin.auth.admin.createUser({email,password:pass,email_confirm:true});if(error)throw error;await admin.from('profiles').upsert({id:data.user.id,username:`${name}${stamp}`.slice(0,30),display_name:name,role});return data.user}
async function sign(email){const c=createClient(url,pub,{auth:{persistSession:false}});const {error}=await c.auth.signInWithPassword({email,password:pass});if(error)throw error;return c}
let ids=[];try{
 const seller=await mk(sellerEmail,'SmokeSeller','Producer'),buyer=await mk(buyerEmail,'SmokeBuyer','Artist'),other=await mk(otherEmail,'SmokeOther','Artist');ids=[seller.id,buyer.id,other.id];
 const sellerC=await sign(sellerEmail),buyerC=await sign(buyerEmail),otherC=await sign(otherEmail);
 const {data:beat,error:be}=await sellerC.from('beats').insert({owner_id:seller.id,client_id:`smoke-${stamp}`,title:'SMOKE TEST BEAT',producer_name:'SmokeSeller',genre:'Test',bpm:120,music_key:'C Minor',license_prices:{Basic:10,Premium:20,Unlimited:30,Exclusive:100}}).select().single();if(be)throw be;
 const {data:purchase,error:pe}=await admin.from('purchases').insert({user_id:buyer.id,status:'paid',total_eur:20}).select().single();if(pe)throw pe;
 const {data:item,error:ie}=await admin.from('purchase_items').insert({purchase_id:purchase.id,beat_id:beat.id,beat_client_id:beat.client_id,title:beat.title,license:'Premium',amount_eur:20,seller_id:seller.id}).select().single();if(ie)throw ie;
 const {data:room1,error:r1}=await buyerC.rpc('create_project_from_purchase_item',{p_item:item.id});if(r1)throw r1;
 const {data:room2,error:r2}=await buyerC.rpc('create_project_from_purchase_item',{p_item:item.id});if(r2)throw r2;if(room1!==room2)throw new Error('Project creation is not idempotent');
 const {data:visible}=await buyerC.from('project_rooms').select('id').eq('id',room1);if(!visible?.length)throw new Error('Buyer cannot read own project');
 const {data:leak}=await otherC.from('project_rooms').select('id').eq('id',room1);if(leak?.length)throw new Error('RLS leak: unrelated user can read project');
 const {data:foreignPurch}=await otherC.from('purchase_items').select('id').eq('id',item.id);if(foreignPurch?.length)throw new Error('RLS leak: unrelated user can read purchase item');
 let denied=false;const {error:foreignRpc}=await otherC.rpc('create_project_from_purchase_item',{p_item:item.id});denied=Boolean(foreignRpc);if(!denied)throw new Error('RLS/RPC leak: unrelated user created project from foreign purchase');
 console.log(JSON.stringify({ok:true,beat_id:beat.id,purchase_item_id:item.id,project_room_id:room1,checks:['paid purchase -> project','idempotent project creation','project RLS','purchase RLS','foreign RPC denied']},null,2));
}finally{for(const id of ids){try{await admin.auth.admin.deleteUser(id)}catch{}}}
