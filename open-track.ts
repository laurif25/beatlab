import {admin,requireUser,json} from './_lib/server.js';

export async function GET(request:Request){
 try{
  const user=await requireUser(request);
  const url=new URL(request.url), mode=url.searchParams.get('mode')||'open', slotId=url.searchParams.get('slotId');
  if(mode==='submissions'&&slotId){
   const {data:slot,error:sErr}=await admin.from('open_track_slots').select('id,owner_id').eq('id',slotId).maybeSingle();if(sErr)throw sErr;
   if(!slot||slot.owner_id!==user.id)return json({error:'Open Track access denied'},403);
   const {data,error}=await admin.from('open_track_submissions').select('id,slot_id,submitter_id,note,demo_url,status,created_at,profiles(username,display_name,avatar_url)').eq('slot_id',slotId).order('created_at',{ascending:false});if(error)throw error;
   return json({submissions:data||[]});
  }
  const {data,error}=await admin.from('open_track_slots').select('id,owner_id,track_id,client_id,slot_type,role_needed,start_seconds,end_seconds,brief,status,deadline,created_at,profiles(username,display_name,avatar_url),tracks(title,cover_url,audio_url)').eq('status','OPEN').order('created_at',{ascending:false}).limit(100);if(error)throw error;
  return json({slots:data||[]});
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Open Track failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}

export async function POST(request:Request){
 try{
  const user=await requireUser(request), body=await request.json(), action=String(body.action||'');
  if(action==='create'){
   const slotType=String(body.slotType||'VERSE').toUpperCase();
   if(!['VERSE','HOOK','PRODUCTION','MIX','REMIX','VISUAL'].includes(slotType))return json({error:'Invalid slot type'},400);
   const {data,error}=await admin.from('open_track_slots').insert({owner_id:user.id,track_id:body.trackId||null,client_id:String(body.clientId||'').slice(0,120)||null,slot_type:slotType,role_needed:String(body.roleNeeded||'collaborator').slice(0,80),start_seconds:body.startSeconds??null,end_seconds:body.endSeconds??null,brief:String(body.brief||'').slice(0,1200),status:'OPEN',deadline:body.deadline||null}).select('*').single();if(error)throw error;
   return json({slot:data});
  }
  if(action==='submit'){
   const slotId=String(body.slotId||'');
   const {data:slot,error:sErr}=await admin.from('open_track_slots').select('id,owner_id,status').eq('id',slotId).maybeSingle();if(sErr)throw sErr;
   if(!slot||slot.status!=='OPEN')return json({error:'Open Track is not accepting submissions'},409);
   if(slot.owner_id===user.id)return json({error:'You cannot submit to your own Open Track'},400);
   const {data,error}=await admin.from('open_track_submissions').upsert({slot_id:slotId,submitter_id:user.id,note:String(body.note||'').slice(0,1200),demo_url:String(body.demoUrl||'').slice(0,1000)||null,status:'PENDING'},{onConflict:'slot_id,submitter_id'}).select('*').single();if(error)throw error;
   return json({submission:data});
  }
  if(action==='accept'){
   const submissionId=String(body.submissionId||'');
   const {data:sub,error:qErr}=await admin.from('open_track_submissions').select('id,slot_id').eq('id',submissionId).maybeSingle();if(qErr)throw qErr;if(!sub)return json({error:'Submission not found'},404);
   const {data:slot,error:sErr}=await admin.from('open_track_slots').select('owner_id').eq('id',sub.slot_id).maybeSingle();if(sErr)throw sErr;
   if(!slot||slot.owner_id!==user.id)return json({error:'Only the Open Track owner can accept'},403);
   // RPC itself also validates auth.uid(); use a user-scoped client by forwarding JWT would be ideal.
   // Here we reproduce the atomic outcome server-side under explicit owner check.
   const {data:accepted,error:aErr}=await admin.from('open_track_submissions').update({status:'ACCEPTED'}).eq('id',submissionId).select('*').single();if(aErr)throw aErr;
   await admin.from('open_track_submissions').update({status:'DECLINED'}).eq('slot_id',sub.slot_id).neq('id',submissionId).neq('status','DECLINED');
   await admin.from('open_track_slots').update({status:'MATCHED'}).eq('id',sub.slot_id);
   const {data:room,error:rErr}=await admin.from('project_rooms').insert({owner_id:user.id,title:'Open Track — Collaboration',status:'Collaborating',source_type:'open_track',source_id:sub.slot_id,release_readiness:20}).select('id').single();if(rErr)throw rErr;
   await admin.from('project_members').upsert([{project_room_id:room.id,user_id:user.id,role:'owner'},{project_room_id:room.id,user_id:accepted.submitter_id,role:'collaborator'}],{onConflict:'project_room_id,user_id'});
   return json({project_room_id:room.id});
  }
  return json({error:'Unknown Open Track action'},400);
 }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Open Track action failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
