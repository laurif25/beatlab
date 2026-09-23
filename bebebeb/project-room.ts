import {admin,requireUser,json} from './_lib/server.js';

async function membership(userId:string, roomId:string){
  const {data:room,error}=await admin.from('project_rooms')
    .select('id,owner_id,title,status,source_type,source_id,source_client_id,license_name,release_readiness,purchase_item_id,created_at')
    .eq('id',roomId).maybeSingle();
  if(error) throw error;
  if(!room) return null;
  if(room.owner_id===userId) return {room,role:'owner'};
  const {data:member,error:memberErr}=await admin.from('project_members')
    .select('role').eq('project_room_id',roomId).eq('user_id',userId).maybeSingle();
  if(memberErr) throw memberErr;
  return member ? {room,role:member.role||'member'} : null;
}

export async function GET(request:Request){
  try{
    const user=await requireUser(request);
    const roomId=new URL(request.url).searchParams.get('id')||'';
    const access=await membership(user.id,roomId);
    if(!access)return json({error:'Project Room not found or access denied'},404);
    const [members,tasks,files,splits]=await Promise.all([
      admin.from('project_members').select('user_id,role,joined_at,profiles(username,display_name,avatar_url)').eq('project_room_id',roomId),
      admin.from('project_tasks').select('id,creator_id,assignee_id,title,status,due_at,created_at').eq('project_room_id',roomId).order('created_at'),
      admin.from('project_files').select('id,uploader_id,name,file_url,file_size,mime_type,created_at').eq('project_room_id',roomId).order('created_at',{ascending:false}),
      admin.from('project_splits').select('user_id,percentage,role,confirmed,updated_at').eq('project_room_id',roomId)
    ]);
    for(const r of [members,tasks,files,splits])if(r.error)throw r.error;
    return json({room:access.room,role:access.role,members:members.data||[],tasks:tasks.data||[],files:files.data||[],splits:splits.data||[]});
  }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Project Room failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}

export async function POST(request:Request){
  try{
    const user=await requireUser(request);
    const body=await request.json();
    const roomId=String(body.roomId||'');
    const action=String(body.action||'');
    const access=await membership(user.id,roomId);
    if(!access)return json({error:'Project Room not found or access denied'},404);

    if(action==='add_task'){
      const title=String(body.title||'').trim().slice(0,180);
      if(!title)return json({error:'Task title required'},400);
      const {data,error}=await admin.from('project_tasks').insert({project_room_id:roomId,creator_id:user.id,assignee_id:user.id,title,status:'open'}).select('*').single();
      if(error)throw error; return json({task:data});
    }
    if(action==='toggle_task'){
      const taskId=String(body.taskId||'');
      const {data:task,error:qErr}=await admin.from('project_tasks').select('id,status').eq('id',taskId).eq('project_room_id',roomId).maybeSingle();
      if(qErr)throw qErr;if(!task)return json({error:'Task not found'},404);
      const status=task.status==='done'?'open':'done';
      const {error}=await admin.from('project_tasks').update({status}).eq('id',taskId).eq('project_room_id',roomId);if(error)throw error;
      return json({ok:true,status});
    }
    if(action==='save_split'){
      const percentage=Number(body.percentage);
      if(!Number.isFinite(percentage)||percentage<0||percentage>100)return json({error:'Split must be between 0 and 100'},400);
      const {error}=await admin.from('project_splits').upsert({project_room_id:roomId,user_id:user.id,percentage,role:String(body.role||access.role||'member').slice(0,80),confirmed:Boolean(body.confirmed),updated_at:new Date().toISOString()},{onConflict:'project_room_id,user_id'});
      if(error)throw error;return json({ok:true});
    }
    if(action==='set_readiness'){
      if(access.role!=='owner')return json({error:'Only the Project Room owner can change readiness'},403);
      const readiness=Math.max(0,Math.min(100,Math.round(Number(body.readiness)||0)));
      const {error}=await admin.from('project_rooms').update({release_readiness:readiness}).eq('id',roomId).eq('owner_id',user.id);if(error)throw error;
      return json({ok:true,readiness});
    }
    return json({error:'Unknown Project Room action'},400);
  }catch(e:any){return json({error:e?.message==='AUTH_REQUIRED'?'Sign in required':e?.message||'Project Room action failed'},e?.message==='AUTH_REQUIRED'?401:500)}
}
