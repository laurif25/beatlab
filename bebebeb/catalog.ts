import type { VercelRequest, VercelResponse } from '@vercel/node';
import { admin } from './_lib/server.js';

export default async function handler(req: VercelRequest,res: VercelResponse){
  if(req.method!=='GET') return res.status(405).json({error:'Method not allowed'});
  const {data,error}=await admin.from('beats')
    .select('id,client_id,title,producer_name,genre,bpm,music_key,audio_url,cover_url,license_prices,exclusive_sold,active,owner_id,created_at')
    .eq('active',true).eq('exclusive_sold',false)
    .order('created_at',{ascending:false}).limit(200);
  if(error) return res.status(500).json({error:error.message});
  return res.status(200).json({ok:true,beats:data||[]});
}
