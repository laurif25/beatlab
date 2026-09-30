
-- BEATLAB v9 FULLSTACK SCHEMA (Supabase/Postgres)
-- Run in Supabase SQL Editor on a fresh project. Uses RLS everywhere.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check (char_length(username) between 2 and 32),
 display_name text not null,
 role text not null default 'Artist', bio text default '', avatar_url text, country text,
 social_links jsonb not null default '{}'::jsonb,
 stripe_account_id text, stripe_charges_enabled boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.tracks (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
 client_id text not null, title text not null, artist_name text not null, producer_name text, genre text, description text default '',
 tags text[] not null default '{}', credits text default '', visibility text not null default 'Public' check (visibility in ('Public','Private','Unlisted')),
 release_type text default 'Single', release_date date, featuring text, songwriters text, explicit boolean not null default false,
 allow_comments boolean not null default true, allow_downloads boolean not null default false,
 audio_url text, cover_url text, duration_text text, plays bigint not null default 0, likes_count bigint not null default 0, reposts_count bigint not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(owner_id,client_id)
);
create table if not exists public.beats (
 id uuid primary key default gen_random_uuid(), owner_id uuid references public.profiles(id) on delete set null, client_id text unique,
 title text not null, producer_name text not null, genre text, bpm int, music_key text, audio_url text, cover_url text,
 license_prices jsonb not null default '{"Basic":19.99,"Premium":39.99,"Unlimited":79.99,"Exclusive":199.99}'::jsonb,
 exclusive_sold boolean not null default false, active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.follows (follower_id uuid references public.profiles(id) on delete cascade, following_id uuid references public.profiles(id) on delete cascade, created_at timestamptz default now(), primary key(follower_id,following_id), check(follower_id<>following_id));
create table if not exists public.track_likes (track_id uuid references public.tracks(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, created_at timestamptz default now(), primary key(track_id,user_id));
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(), track_id uuid not null references public.tracks(id) on delete cascade, author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 3000), timestamp_seconds numeric not null default 0, likes_count int not null default 0,
 parent_id uuid references public.comments(id) on delete cascade, pinned boolean not null default false, artist_hearted boolean not null default false, created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.conversations (id uuid primary key default gen_random_uuid(), title text, project_room_id uuid, created_by uuid not null references public.profiles(id) on delete cascade, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.conversation_members (conversation_id uuid references public.conversations(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, joined_at timestamptz default now(), primary key(conversation_id,user_id));
create table if not exists public.messages (id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.conversations(id) on delete cascade, sender_id uuid not null references public.profiles(id) on delete cascade, body text not null check(char_length(body) between 1 and 5000), created_at timestamptz default now(), edited_at timestamptz);
create table if not exists public.notifications (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, type text not null, body text not null, meta jsonb not null default '{}'::jsonb, read boolean not null default false, created_at timestamptz default now());
create table if not exists public.collab_posts (id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade, client_id text not null, title text not null, role_needed text, genre text, bpm int, music_key text, description text not null, status text not null default 'open', track_id uuid references public.tracks(id) on delete set null, created_at timestamptz default now(), unique(owner_id,client_id));
create table if not exists public.collab_applications (id uuid primary key default gen_random_uuid(), collab_post_id uuid not null references public.collab_posts(id) on delete cascade, applicant_id uuid not null references public.profiles(id) on delete cascade, note text, status text not null default 'interested', created_at timestamptz default now(), unique(collab_post_id,applicant_id));
create table if not exists public.project_rooms (id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade, title text not null, status text not null default 'Open', source_type text, source_id uuid, created_at timestamptz default now());
create table if not exists public.project_members (project_room_id uuid references public.project_rooms(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, role text default 'member', joined_at timestamptz default now(), primary key(project_room_id,user_id));
create table if not exists public.project_versions (id uuid primary key default gen_random_uuid(), project_room_id uuid not null references public.project_rooms(id) on delete cascade, uploader_id uuid not null references public.profiles(id) on delete cascade, name text not null, stage text, audio_url text, track_id uuid references public.tracks(id) on delete set null, created_at timestamptz default now());
create table if not exists public.project_notes (id uuid primary key default gen_random_uuid(), project_room_id uuid not null references public.project_rooms(id) on delete cascade, author_id uuid not null references public.profiles(id) on delete cascade, body text not null, resolved boolean not null default false, timestamp_seconds numeric, created_at timestamptz default now());
create table if not exists public.open_verses (id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade, client_id text not null, title text not null, track_id uuid references public.tracks(id) on delete set null, role_needed text, genre text, bpm int, music_key text, deadline date, instructions text, status text not null default 'OPEN', selected_submission_id uuid, created_at timestamptz default now(), unique(owner_id,client_id));
create table if not exists public.open_verse_submissions (id uuid primary key default gen_random_uuid(), open_verse_id uuid not null references public.open_verses(id) on delete cascade, submitter_id uuid not null references public.profiles(id) on delete cascade, note text, demo_url text, status text not null default 'NEW', created_at timestamptz default now(), unique(open_verse_id,submitter_id));
alter table public.open_verses drop constraint if exists open_verses_selected_submission_id_fkey;
alter table public.open_verses add constraint open_verses_selected_submission_id_fkey foreign key(selected_submission_id) references public.open_verse_submissions(id) on delete set null;
create table if not exists public.campaigns (id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade, client_id text, kind text not null, target_label text, target_id uuid, days int not null, amount_eur numeric(10,2) not null, status text not null default 'PENDING PAYMENT', stripe_session_id text, impressions bigint not null default 0, clicks bigint not null default 0, plays bigint not null default 0, follows bigint not null default 0, external_clicks bigint not null default 0, created_at timestamptz default now(), starts_at timestamptz, ends_at timestamptz);
create table if not exists public.purchases (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, stripe_session_id text unique, stripe_payment_intent_id text, status text not null default 'pending', total_eur numeric(10,2) not null default 0, created_at timestamptz default now());
create table if not exists public.purchase_items (id uuid primary key default gen_random_uuid(), purchase_id uuid not null references public.purchases(id) on delete cascade, beat_id uuid references public.beats(id) on delete set null, beat_client_id text, title text not null, license text not null, amount_eur numeric(10,2) not null, seller_id uuid references public.profiles(id) on delete set null, created_at timestamptz default now());
create table if not exists public.support_payments (id uuid primary key default gen_random_uuid(), supporter_id uuid references public.profiles(id) on delete set null, creator_id uuid not null references public.profiles(id) on delete cascade, stripe_session_id text unique, amount_eur numeric(10,2) not null, status text not null default 'pending', created_at timestamptz default now());
create table if not exists public.reports (id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id) on delete cascade, target_user_id uuid references public.profiles(id) on delete set null, target_track_id uuid references public.tracks(id) on delete set null, reason text not null, details text, status text not null default 'open', created_at timestamptz default now());
create table if not exists public.blocks (blocker_id uuid references public.profiles(id) on delete cascade, blocked_id uuid references public.profiles(id) on delete cascade, created_at timestamptz default now(), primary key(blocker_id,blocked_id));
create table if not exists public.playlists (id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade, name text not null, description text default '', visibility text not null default 'Public', created_at timestamptz default now());
create table if not exists public.playlist_items (playlist_id uuid references public.playlists(id) on delete cascade, track_id uuid references public.tracks(id) on delete cascade, position int not null default 0, added_at timestamptz default now(), primary key(playlist_id,track_id));
create table if not exists public.pre_saves (user_id uuid references public.profiles(id) on delete cascade, track_id uuid references public.tracks(id) on delete cascade, created_at timestamptz default now(), primary key(user_id,track_id));
create table if not exists public.fan_club_members (creator_id uuid references public.profiles(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, created_at timestamptz default now(), primary key(creator_id,user_id));

-- Helpful indexes
create index if not exists idx_messages_conversation_created on public.messages(conversation_id,created_at);
create index if not exists idx_comments_track_created on public.comments(track_id,created_at);
create index if not exists idx_notifications_user_created on public.notifications(user_id,created_at desc);
create index if not exists idx_openverse_owner on public.open_verses(owner_id,created_at desc);
create index if not exists idx_ovsubs_verse on public.open_verse_submissions(open_verse_id,created_at desc);

-- Auto profile for new auth users
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,username,display_name)
 values(new.id, coalesce(nullif(regexp_replace(split_part(new.email,'@',1),'[^a-zA-Z0-9_.-]','','g'),''),'user_'||substr(new.id::text,1,8)), coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)))
 on conflict(id) do nothing;
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Direct conversation RPC
create or replace function public.get_or_create_direct_conversation(other_user uuid, conversation_title text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 if auth.uid() is null or other_user=auth.uid() then raise exception 'unauthorized'; end if;
 select c.id into cid from conversations c
 join conversation_members a on a.conversation_id=c.id and a.user_id=auth.uid()
 join conversation_members b on b.conversation_id=c.id and b.user_id=other_user
 where (select count(*) from conversation_members x where x.conversation_id=c.id)=2 and c.project_room_id is null limit 1;
 if cid is null then
  insert into conversations(title,created_by) values(coalesce(conversation_title,'Direct message'),auth.uid()) returning id into cid;
  insert into conversation_members(conversation_id,user_id) values(cid,auth.uid()),(cid,other_user);
 end if;
 return cid;
end $$;

-- Open Verse accept: owner only; submission remains private
create or replace function public.accept_open_verse_submission(verse_id uuid, submission_id uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare v public.open_verses; s public.open_verse_submissions; room_id uuid;
begin
 select * into v from open_verses where id=verse_id for update;
 if v.id is null or v.owner_id<>auth.uid() then raise exception 'forbidden'; end if;
 select * into s from open_verse_submissions where id=submission_id and open_verse_id=verse_id;
 if s.id is null then raise exception 'submission not found'; end if;
 update open_verse_submissions set status=case when id=submission_id then 'ACCEPTED' when status<>'DECLINED' then 'NOT SELECTED' else status end where open_verse_id=verse_id;
 update open_verses set status='COLLAB SELECTED', selected_submission_id=submission_id where id=verse_id;
 insert into project_rooms(owner_id,title,status,source_type,source_id) values(v.owner_id,v.title,'Collaborating','open_verse',v.id) returning id into room_id;
 insert into project_members(project_room_id,user_id,role) values(room_id,v.owner_id,'owner'),(room_id,s.submitter_id,'collaborator') on conflict do nothing;
 return room_id;
end $$;

-- Keep track like counters server-truthful
create or replace function public.refresh_track_like_count() returns trigger language plpgsql security definer set search_path=public as $$
begin update tracks set likes_count=(select count(*) from track_likes where track_id=coalesce(new.track_id,old.track_id)) where id=coalesce(new.track_id,old.track_id);return coalesce(new,old);end $$;
drop trigger if exists track_like_count on public.track_likes;
create trigger track_like_count after insert or delete on public.track_likes for each row execute function public.refresh_track_like_count();

-- RLS helper functions (SECURITY DEFINER avoids recursive member-policy lookups)
create or replace function public.is_conversation_member(cid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from conversation_members m where m.conversation_id=cid and m.user_id=auth.uid());
$$;
create or replace function public.is_project_member(pid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from project_members m where m.project_room_id=pid and m.user_id=auth.uid());
$$;
create or replace function public.is_project_owner(pid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from project_rooms r where r.id=pid and r.owner_id=auth.uid());
$$;

-- RLS
alter table public.profiles enable row level security; alter table public.tracks enable row level security; alter table public.beats enable row level security;
alter table public.follows enable row level security; alter table public.track_likes enable row level security; alter table public.comments enable row level security;
alter table public.conversations enable row level security; alter table public.conversation_members enable row level security; alter table public.messages enable row level security;
alter table public.notifications enable row level security; alter table public.collab_posts enable row level security; alter table public.collab_applications enable row level security;
alter table public.project_rooms enable row level security; alter table public.project_members enable row level security; alter table public.project_versions enable row level security; alter table public.project_notes enable row level security;
alter table public.open_verses enable row level security; alter table public.open_verse_submissions enable row level security; alter table public.campaigns enable row level security;
alter table public.purchases enable row level security; alter table public.purchase_items enable row level security; alter table public.support_payments enable row level security;
alter table public.reports enable row level security; alter table public.blocks enable row level security; alter table public.playlists enable row level security; alter table public.playlist_items enable row level security; alter table public.pre_saves enable row level security; alter table public.fan_club_members enable row level security;

-- Drop/recreate named policies safely
DO $$ DECLARE r record; BEGIN FOR r IN select schemaname,tablename,policyname from pg_policies where schemaname='public' loop execute format('drop policy if exists %I on %I.%I',r.policyname,r.schemaname,r.tablename); end loop; END $$;

create policy profiles_read on profiles for select using (true); create policy profiles_self on profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy tracks_read on tracks for select using(visibility='Public' or owner_id=auth.uid()); create policy tracks_owner_write on tracks for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy beats_read on beats for select using(active=true or owner_id=auth.uid()); create policy beats_owner_write on beats for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy follows_read on follows for select using(true); create policy follows_self_write on follows for all using(follower_id=auth.uid()) with check(follower_id=auth.uid());
create policy likes_read on track_likes for select using(true); create policy likes_self_write on track_likes for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy comments_read on comments for select using(exists(select 1 from tracks t where t.id=track_id and (t.visibility='Public' or t.owner_id=auth.uid()))); create policy comments_self_insert on comments for insert with check(author_id=auth.uid()); create policy comments_self_update on comments for update using(author_id=auth.uid()) with check(author_id=auth.uid()); create policy comments_self_delete on comments for delete using(author_id=auth.uid());
create policy conversations_member_read on conversations for select using(public.is_conversation_member(id)); create policy conversations_creator_insert on conversations for insert with check(created_by=auth.uid()); create policy conversations_member_update on conversations for update using(public.is_conversation_member(id));
create policy conversation_members_member_read on conversation_members for select using(public.is_conversation_member(conversation_id)); create policy conversation_members_self_insert on conversation_members for insert with check(user_id=auth.uid() or exists(select 1 from conversations c where c.id=conversation_id and c.created_by=auth.uid()));
create policy messages_member_read on messages for select using(public.is_conversation_member(messages.conversation_id)); create policy messages_member_insert on messages for insert with check(sender_id=auth.uid() and public.is_conversation_member(messages.conversation_id)); create policy messages_self_update on messages for update using(sender_id=auth.uid()); create policy messages_self_delete on messages for delete using(sender_id=auth.uid());
create policy notifications_self on notifications for select using(user_id=auth.uid()); create policy notifications_self_update on notifications for update using(user_id=auth.uid());
create policy collabs_read on collab_posts for select using(true); create policy collabs_owner_write on collab_posts for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy collab_apps_private_read on collab_applications for select using(applicant_id=auth.uid() or exists(select 1 from collab_posts c where c.id=collab_post_id and c.owner_id=auth.uid())); create policy collab_apps_self_insert on collab_applications for insert with check(applicant_id=auth.uid()); create policy collab_apps_owner_or_self_update on collab_applications for update using(applicant_id=auth.uid() or exists(select 1 from collab_posts c where c.id=collab_post_id and c.owner_id=auth.uid()));
create policy rooms_member_read on project_rooms for select using(owner_id=auth.uid() or public.is_project_member(id)); create policy rooms_owner_write on project_rooms for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy room_members_read on project_members for select using(public.is_project_member(project_room_id)); create policy room_members_owner_write on project_members for all using(public.is_project_owner(project_room_id)) with check(public.is_project_owner(project_room_id));
create policy versions_members on project_versions for select using(public.is_project_member(project_room_id)); create policy versions_members_insert on project_versions for insert with check(uploader_id=auth.uid() and public.is_project_member(project_room_id));
create policy notes_members on project_notes for select using(public.is_project_member(project_room_id)); create policy notes_members_insert on project_notes for insert with check(author_id=auth.uid() and public.is_project_member(project_room_id)); create policy notes_author_update on project_notes for update using(author_id=auth.uid());
create policy openverse_read on open_verses for select using(true); create policy openverse_owner_write on open_verses for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
-- CRITICAL: submissions visible only to submitter OR owner of that Open Verse
create policy ovsubs_private_read on open_verse_submissions for select using(submitter_id=auth.uid() or exists(select 1 from open_verses v where v.id=open_verse_id and v.owner_id=auth.uid()));
create policy ovsubs_self_insert on open_verse_submissions for insert with check(submitter_id=auth.uid()); create policy ovsubs_self_or_owner_update on open_verse_submissions for update using(submitter_id=auth.uid() or exists(select 1 from open_verses v where v.id=open_verse_id and v.owner_id=auth.uid()));
create policy campaigns_self on campaigns for select using(owner_id=auth.uid()); create policy campaigns_self_insert on campaigns for insert with check(owner_id=auth.uid()); create policy campaigns_self_update on campaigns for update using(owner_id=auth.uid());
create policy purchases_self on purchases for select using(user_id=auth.uid()); create policy purchase_items_self on purchase_items for select using(exists(select 1 from purchases p where p.id=purchase_id and p.user_id=auth.uid()));
create policy support_self_read on support_payments for select using(supporter_id=auth.uid() or creator_id=auth.uid());
create policy reports_self_insert on reports for insert with check(reporter_id=auth.uid()); create policy reports_self_read on reports for select using(reporter_id=auth.uid());
create policy blocks_self on blocks for all using(blocker_id=auth.uid()) with check(blocker_id=auth.uid());
create policy playlists_read on playlists for select using(visibility='Public' or owner_id=auth.uid()); create policy playlists_owner on playlists for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy playlist_items_read on playlist_items for select using(exists(select 1 from playlists p where p.id=playlist_id and (p.visibility='Public' or p.owner_id=auth.uid()))); create policy playlist_items_owner on playlist_items for all using(exists(select 1 from playlists p where p.id=playlist_id and p.owner_id=auth.uid())) with check(exists(select 1 from playlists p where p.id=playlist_id and p.owner_id=auth.uid()));
create policy presaves_self on pre_saves for all using(user_id=auth.uid()) with check(user_id=auth.uid()); create policy fanclubs_read on fan_club_members for select using(true); create policy fanclubs_self on fan_club_members for all using(user_id=auth.uid()) with check(user_id=auth.uid());

-- Storage buckets + owner-folder policies
insert into storage.buckets(id,name,public) values('audio','audio',true),('covers','covers',true),('project-files','project-files',false) on conflict(id) do update set public=excluded.public;
insert into storage.buckets(id,name,public) values('licensed-assets','licensed-assets',false) on conflict(id) do update set public=false;
drop policy if exists bl_audio_insert on storage.objects; drop policy if exists bl_audio_update on storage.objects; drop policy if exists bl_audio_delete on storage.objects;
create policy bl_audio_insert on storage.objects for insert to authenticated with check(bucket_id in ('audio','covers','project-files','licensed-assets') and (storage.foldername(name))[1]=auth.uid()::text);
create policy bl_audio_update on storage.objects for update to authenticated using(bucket_id in ('audio','covers','project-files','licensed-assets') and owner_id=auth.uid()::text) with check((storage.foldername(name))[1]=auth.uid()::text);
create policy bl_audio_delete on storage.objects for delete to authenticated using(bucket_id in ('audio','covers','project-files','licensed-assets') and owner_id=auth.uid()::text);

-- Realtime publication for core live tables
DO $$ BEGIN
 alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.comments; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.track_likes; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.follows; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.open_verse_submissions; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.campaigns; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.purchase_items; exception when duplicate_object then null; END $$;


-- ============================================================
-- BEATLAB v10 FUNCTIONAL CORE EXTENSIONS
-- Run after the v9 schema. All creator/private data is RLS protected.
-- ============================================================
alter table public.beats add column if not exists exclusive_sold boolean not null default false;
alter table public.beats add column if not exists exclusive_buyer_id uuid references public.profiles(id) on delete set null;
alter table public.beats add column if not exists exclusive_sold_at timestamptz;

create table if not exists public.track_lyrics (
 track_id uuid primary key references public.tracks(id) on delete cascade,
 lyrics jsonb not null default '[]'::jsonb,
 synced boolean not null default false,
 updated_at timestamptz not null default now()
);
create table if not exists public.track_credits (
 id uuid primary key default gen_random_uuid(), track_id uuid not null references public.tracks(id) on delete cascade,
 role text not null, name text not null, profile_id uuid references public.profiles(id) on delete set null, sort_order int not null default 0
);
create table if not exists public.track_reposts (
 track_id uuid references public.tracks(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz default now(), primary key(track_id,user_id)
);
create table if not exists public.track_reactions (
 id uuid primary key default gen_random_uuid(), track_id uuid not null references public.tracks(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, emoji text not null, timestamp_seconds numeric,
 created_at timestamptz default now()
);
create table if not exists public.releases (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
 title text not null, release_type text not null default 'Single', cover_url text, release_date date,
 status text not null default 'draft', created_at timestamptz default now()
);
create table if not exists public.release_tracks (
 release_id uuid references public.releases(id) on delete cascade, track_id uuid references public.tracks(id) on delete cascade,
 position int not null default 0, primary key(release_id,track_id)
);
create table if not exists public.project_tasks (
 id uuid primary key default gen_random_uuid(), project_room_id uuid not null references public.project_rooms(id) on delete cascade,
 creator_id uuid not null references public.profiles(id) on delete cascade, assignee_id uuid references public.profiles(id) on delete set null,
 title text not null, status text not null default 'open', due_at timestamptz, created_at timestamptz default now()
);
create table if not exists public.project_files (
 id uuid primary key default gen_random_uuid(), project_room_id uuid not null references public.project_rooms(id) on delete cascade,
 uploader_id uuid not null references public.profiles(id) on delete cascade, name text not null, file_url text not null,
 file_size bigint, mime_type text, created_at timestamptz default now()
);
create table if not exists public.project_splits (
 project_room_id uuid references public.project_rooms(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade,
 percentage numeric(5,2) not null check(percentage>=0 and percentage<=100), role text, confirmed boolean not null default false,
 updated_at timestamptz default now(), primary key(project_room_id,user_id)
);
create table if not exists public.analytics_events (
 id bigint generated by default as identity primary key, user_id uuid references public.profiles(id) on delete set null,
 creator_id uuid references public.profiles(id) on delete set null, track_id uuid references public.tracks(id) on delete set null,
 event_type text not null, meta jsonb not null default '{}'::jsonb, created_at timestamptz default now()
);
create index if not exists analytics_creator_time_idx on public.analytics_events(creator_id,created_at desc);
create index if not exists analytics_track_time_idx on public.analytics_events(track_id,created_at desc);

create table if not exists public.exclusive_reservations (
 beat_id uuid primary key references public.beats(id) on delete cascade, buyer_id uuid not null references public.profiles(id) on delete cascade,
 purchase_id uuid references public.purchases(id) on delete cascade, expires_at timestamptz not null, created_at timestamptz default now()
);
create table if not exists public.creator_payout_ledger (
 id uuid primary key default gen_random_uuid(), purchase_item_id uuid unique references public.purchase_items(id) on delete cascade,
 seller_id uuid not null references public.profiles(id) on delete cascade, gross_eur numeric(10,2) not null,
 platform_fee_eur numeric(10,2) not null, net_eur numeric(10,2) not null, stripe_transfer_id text,
 status text not null default 'pending', created_at timestamptz default now(), paid_at timestamptz
);

alter table public.track_lyrics enable row level security; alter table public.track_credits enable row level security;
alter table public.track_reposts enable row level security; alter table public.track_reactions enable row level security;
alter table public.releases enable row level security; alter table public.release_tracks enable row level security;
alter table public.project_tasks enable row level security; alter table public.project_files enable row level security; alter table public.project_splits enable row level security;
alter table public.analytics_events enable row level security; alter table public.exclusive_reservations enable row level security; alter table public.creator_payout_ledger enable row level security;

create policy lyrics_read on public.track_lyrics for select using(exists(select 1 from public.tracks t where t.id=track_id and (t.visibility='Public' or t.owner_id=auth.uid())));
create policy lyrics_owner on public.track_lyrics for all using(exists(select 1 from public.tracks t where t.id=track_id and t.owner_id=auth.uid())) with check(exists(select 1 from public.tracks t where t.id=track_id and t.owner_id=auth.uid()));
create policy credits_read on public.track_credits for select using(exists(select 1 from public.tracks t where t.id=track_id and (t.visibility='Public' or t.owner_id=auth.uid())));
create policy credits_owner on public.track_credits for all using(exists(select 1 from public.tracks t where t.id=track_id and t.owner_id=auth.uid())) with check(exists(select 1 from public.tracks t where t.id=track_id and t.owner_id=auth.uid()));
create policy reposts_read on public.track_reposts for select using(true); create policy reposts_self on public.track_reposts for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy reactions_read on public.track_reactions for select using(true); create policy reactions_self on public.track_reactions for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy releases_read on public.releases for select using(status='released' or owner_id=auth.uid()); create policy releases_owner on public.releases for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy release_tracks_read on public.release_tracks for select using(exists(select 1 from public.releases r where r.id=release_id and (r.status='released' or r.owner_id=auth.uid())));
create policy release_tracks_owner on public.release_tracks for all using(exists(select 1 from public.releases r where r.id=release_id and r.owner_id=auth.uid())) with check(exists(select 1 from public.releases r where r.id=release_id and r.owner_id=auth.uid()));
create policy tasks_member_read on public.project_tasks for select using(public.is_project_member(project_room_id)); create policy tasks_member_insert on public.project_tasks for insert with check(creator_id=auth.uid() and public.is_project_member(project_room_id)); create policy tasks_member_update on public.project_tasks for update using(public.is_project_member(project_room_id));
create policy files_member_read on public.project_files for select using(public.is_project_member(project_room_id)); create policy files_member_insert on public.project_files for insert with check(uploader_id=auth.uid() and public.is_project_member(project_room_id)); create policy files_author_delete on public.project_files for delete using(uploader_id=auth.uid() or public.is_project_owner(project_room_id));
create policy splits_member_read on public.project_splits for select using(public.is_project_member(project_room_id)); create policy splits_self_write on public.project_splits for all using(user_id=auth.uid() and public.is_project_member(project_room_id)) with check(user_id=auth.uid() and public.is_project_member(project_room_id));
create policy analytics_self_insert on public.analytics_events for insert with check(user_id=auth.uid() and user_id is not null); create policy analytics_creator_read on public.analytics_events for select using(creator_id=auth.uid() or user_id=auth.uid());
create policy exclusive_buyer_read on public.exclusive_reservations for select using(buyer_id=auth.uid());
create policy ledger_seller_read on public.creator_payout_ledger for select using(seller_id=auth.uid());

create or replace function public.reserve_exclusive_beat(p_beat_id uuid,p_buyer_id uuid,p_purchase_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare sold boolean; existing uuid;
begin
 delete from exclusive_reservations where expires_at<now();
 select exclusive_sold into sold from beats where id=p_beat_id for update;
 if sold is null or sold then return false; end if;
 select buyer_id into existing from exclusive_reservations where beat_id=p_beat_id;
 if existing is not null and existing<>p_buyer_id then return false; end if;
 insert into exclusive_reservations(beat_id,buyer_id,purchase_id,expires_at) values(p_beat_id,p_buyer_id,p_purchase_id,now()+interval '30 minutes')
 on conflict(beat_id) do update set buyer_id=excluded.buyer_id,purchase_id=excluded.purchase_id,expires_at=excluded.expires_at;
 return true;
end $$;
revoke all on function public.reserve_exclusive_beat(uuid,uuid,uuid) from public,anon,authenticated;

DO $$ BEGIN alter publication supabase_realtime add table public.project_tasks; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.project_files; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.project_splits; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.track_reactions; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.track_reposts; exception when duplicate_object then null; END $$;

-- ============================================================
-- BEATLAB v13 CONNECTED CORE
-- Connects purchases -> projects -> releases and Open Track -> projects.
-- ============================================================

alter table public.project_rooms add column if not exists source_client_id text;
alter table public.project_rooms add column if not exists license_name text;
alter table public.project_rooms add column if not exists release_readiness int not null default 0 check(release_readiness between 0 and 100);
alter table public.project_rooms add column if not exists graduated_release_id uuid references public.releases(id) on delete set null;

alter table public.analytics_events add column if not exists session_id text;
alter table public.analytics_events add column if not exists country_code text;
alter table public.analytics_events add column if not exists country_name text;
alter table public.analytics_events add column if not exists city text;
alter table public.analytics_events add column if not exists duration_seconds numeric;
alter table public.analytics_events add column if not exists source text;
alter table public.analytics_events add column if not exists is_promoted boolean not null default false;
create index if not exists analytics_geo_idx on public.analytics_events(creator_id,country_code,city,created_at desc);
create index if not exists analytics_type_idx on public.analytics_events(creator_id,event_type,created_at desc);

create table if not exists public.sound_profiles (
 profile_id uuid primary key references public.profiles(id) on delete cascade,
 genre_weights jsonb not null default '{}'::jsonb,
 moods text[] not null default '{}',
 bpm_min int,
 bpm_max int,
 roles text[] not null default '{}',
 collaboration_preferences jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now()
);

create table if not exists public.open_track_slots (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 track_id uuid references public.tracks(id) on delete cascade,
 client_id text,
 slot_type text not null check(slot_type in ('VERSE','HOOK','PRODUCTION','MIX','REMIX','VISUAL')),
 role_needed text,
 start_seconds numeric,
 end_seconds numeric,
 brief text,
 status text not null default 'OPEN' check(status in ('OPEN','MATCHED','CLOSED')),
 deadline timestamptz,
 created_at timestamptz not null default now(),
 check(end_seconds is null or start_seconds is null or end_seconds > start_seconds)
);
create index if not exists open_track_owner_idx on public.open_track_slots(owner_id,created_at desc);
create index if not exists open_track_status_idx on public.open_track_slots(status,created_at desc);

create table if not exists public.open_track_submissions (
 id uuid primary key default gen_random_uuid(),
 slot_id uuid not null references public.open_track_slots(id) on delete cascade,
 submitter_id uuid not null references public.profiles(id) on delete cascade,
 note text,
 demo_url text,
 status text not null default 'PENDING' check(status in ('PENDING','SHORTLISTED','ACCEPTED','DECLINED')),
 created_at timestamptz not null default now(),
 unique(slot_id,submitter_id)
);
create index if not exists open_track_sub_slot_idx on public.open_track_submissions(slot_id,created_at desc);

alter table public.sound_profiles enable row level security;
alter table public.open_track_slots enable row level security;
alter table public.open_track_submissions enable row level security;

DO $$ BEGIN create policy sound_profiles_read on public.sound_profiles for select using(true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN create policy sound_profiles_self on public.sound_profiles for all using(profile_id=auth.uid()) with check(profile_id=auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN create policy open_track_slots_read on public.open_track_slots for select using(status='OPEN' or owner_id=auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN create policy open_track_slots_owner on public.open_track_slots for all using(owner_id=auth.uid()) with check(owner_id=auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN create policy open_track_sub_private_read on public.open_track_submissions for select using(submitter_id=auth.uid() or exists(select 1 from public.open_track_slots s where s.id=slot_id and s.owner_id=auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN create policy open_track_sub_self_insert on public.open_track_submissions for insert with check(submitter_id=auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN create policy open_track_sub_parties_update on public.open_track_submissions for update using(submitter_id=auth.uid() or exists(select 1 from public.open_track_slots s where s.id=slot_id and s.owner_id=auth.uid())); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Authenticated buyer can transform a paid purchase item into a private Project Room.
create or replace function public.create_project_from_purchase_item(p_item uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare it public.purchase_items; pur public.purchases; room_id uuid;
begin
 select * into it from public.purchase_items where id=p_item;
 if it.id is null then raise exception 'PURCHASE_ITEM_NOT_FOUND'; end if;
 select * into pur from public.purchases where id=it.purchase_id;
 if pur.user_id<>auth.uid() or lower(coalesce(pur.status,''))<>'paid' then raise exception 'NOT_AUTHORIZED'; end if;
 insert into public.project_rooms(owner_id,title,status,source_type,source_id,source_client_id,license_name,release_readiness)
 values(auth.uid(),it.title||' — Project','Open','purchase_item',it.id,it.beat_client_id,it.license,15)
 returning id into room_id;
 insert into public.project_members(project_room_id,user_id,role) values(room_id,auth.uid(),'owner') on conflict do nothing;
 return room_id;
end $$;
grant execute on function public.create_project_from_purchase_item(uuid) to authenticated;

-- Owner accepts a private Open Track submission and gets a private Project Room.
create or replace function public.accept_open_track_submission(p_submission uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare sub public.open_track_submissions; slot public.open_track_slots; room_id uuid; tr_title text;
begin
 select * into sub from public.open_track_submissions where id=p_submission for update;
 if sub.id is null then raise exception 'SUBMISSION_NOT_FOUND'; end if;
 select * into slot from public.open_track_slots where id=sub.slot_id for update;
 if slot.owner_id<>auth.uid() then raise exception 'NOT_SLOT_OWNER'; end if;
 if slot.track_id is not null then select title into tr_title from public.tracks where id=slot.track_id; end if;
 update public.open_track_submissions set status=case when id=sub.id then 'ACCEPTED' when status<>'DECLINED' then 'DECLINED' else status end where slot_id=slot.id;
 update public.open_track_slots set status='MATCHED' where id=slot.id;
 insert into public.project_rooms(owner_id,title,status,source_type,source_id,source_client_id,release_readiness)
 values(slot.owner_id,coalesce(tr_title,'Open Track')||' — Collaboration','Collaborating','open_track',slot.id,slot.client_id,20)
 returning id into room_id;
 insert into public.project_members(project_room_id,user_id,role) values(room_id,slot.owner_id,'owner') on conflict do nothing;
 insert into public.project_members(project_room_id,user_id,role) values(room_id,sub.submitter_id,coalesce(slot.role_needed,'collaborator')) on conflict do nothing;
 return room_id;
end $$;
grant execute on function public.accept_open_track_submission(uuid) to authenticated;

-- Project owner can graduate a room into a release draft without losing provenance.
create or replace function public.graduate_project_to_release(p_room uuid,p_title text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare room public.project_rooms; rel_id uuid; v_track uuid;
begin
 select * into room from public.project_rooms where id=p_room for update;
 if room.id is null or room.owner_id<>auth.uid() then raise exception 'NOT_PROJECT_OWNER'; end if;
 if room.release_readiness<70 then raise exception 'PROJECT_NOT_READY'; end if;
 insert into public.releases(owner_id,title,release_type,status)
 values(auth.uid(),coalesce(nullif(trim(p_title),''),room.title),'Single','draft') returning id into rel_id;
 select track_id into v_track from public.project_versions where project_room_id=p_room and track_id is not null order by created_at desc limit 1;
 if v_track is not null then insert into public.release_tracks(release_id,track_id,position) values(rel_id,v_track,1) on conflict do nothing; end if;
 update public.project_rooms set status='Graduated',release_readiness=100,graduated_release_id=rel_id where id=p_room;
 return rel_id;
end $$;
grant execute on function public.graduate_project_to_release(uuid,text) to authenticated;

DO $$ BEGIN alter publication supabase_realtime add table public.open_track_slots; exception when duplicate_object then null; END $$;
DO $$ BEGIN alter publication supabase_realtime add table public.open_track_submissions; exception when duplicate_object then null; END $$;

-- BEATLAB v14 pre-design completion additions
create table if not exists public.listener_geo_daily (
  id uuid primary key default gen_random_uuid(), creator_id uuid not null references public.profiles(id) on delete cascade,
  track_id uuid references public.tracks(id) on delete cascade, day date not null default current_date,
  country_code text, country_name text, city_name text, streams bigint not null default 0,
  unique_listeners bigint not null default 0, listening_seconds bigint not null default 0,
  completed_plays bigint not null default 0, followers_gained bigint not null default 0,
  organic_streams bigint not null default 0, promoted_streams bigint not null default 0,
  unique(creator_id,track_id,day,country_code,city_name)
);
create index if not exists listener_geo_daily_creator_day_idx on public.listener_geo_daily(creator_id,day desc);
alter table public.listener_geo_daily enable row level security;
drop policy if exists "creators read own geo aggregates" on public.listener_geo_daily;
create policy "creators read own geo aggregates" on public.listener_geo_daily for select using (auth.uid()=creator_id);

create table if not exists public.track_moments (
 id uuid primary key default gen_random_uuid(), track_id uuid not null references public.tracks(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, second integer not null check(second>=0),
 kind text not null check(kind in ('reaction','comment','replay','save')), emoji text, body text,
 created_at timestamptz not null default now()
);
create index if not exists track_moments_track_second_idx on public.track_moments(track_id,second);
alter table public.track_moments enable row level security;
drop policy if exists "public moments read" on public.track_moments;
create policy "public moments read" on public.track_moments for select using (true);
drop policy if exists "users create own moments" on public.track_moments;
create policy "users create own moments" on public.track_moments for insert with check(auth.uid()=user_id);

-- BEATLAB v15 REAL CORE: licensed asset delivery + idempotent connected-project creation
create table if not exists public.beat_assets (
 id uuid primary key default gen_random_uuid(),
 beat_id uuid not null references public.beats(id) on delete cascade,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 asset_type text not null check(asset_type in ('PREVIEW','MP3','WAV','STEMS')),
 storage_path text not null,
 bytes bigint,
 mime_type text,
 created_at timestamptz not null default now(),
 unique(beat_id,asset_type)
);
create index if not exists beat_assets_beat_idx on public.beat_assets(beat_id);
alter table public.beat_assets enable row level security;
drop policy if exists beat_assets_owner_read on public.beat_assets;
create policy beat_assets_owner_read on public.beat_assets for select using(owner_id=auth.uid());
drop policy if exists beat_assets_owner_write on public.beat_assets;
create policy beat_assets_owner_write on public.beat_assets for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());

alter table public.project_rooms add column if not exists purchase_item_id uuid references public.purchase_items(id) on delete set null;
create unique index if not exists project_rooms_purchase_item_unique on public.project_rooms(purchase_item_id) where purchase_item_id is not null;

create or replace function public.create_project_from_purchase_item(p_item uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare it public.purchase_items; pur public.purchases; room_id uuid;
begin
 select * into it from public.purchase_items where id=p_item;
 if it.id is null then raise exception 'PURCHASE_ITEM_NOT_FOUND'; end if;
 select * into pur from public.purchases where id=it.purchase_id;
 if pur.user_id<>auth.uid() or lower(coalesce(pur.status,''))<>'paid' then raise exception 'NOT_AUTHORIZED'; end if;
 select id into room_id from public.project_rooms where purchase_item_id=p_item limit 1;
 if room_id is not null then return room_id; end if;
 insert into public.project_rooms(owner_id,title,status,source_type,source_id,source_client_id,license_name,release_readiness,purchase_item_id)
 values(auth.uid(),it.title||' — Project','Open','purchase_item',it.id,it.beat_client_id,it.license,15,it.id)
 returning id into room_id;
 insert into public.project_members(project_room_id,user_id,role) values(room_id,auth.uid(),'owner') on conflict do nothing;
 return room_id;
end $$;
grant execute on function public.create_project_from_purchase_item(uuid) to authenticated;

-- Buyers may see only metadata for assets they are licensed to download; the actual signed URL is minted server-side.
create or replace function public.licensed_asset_types(p_item uuid)
returns table(asset_type text) language sql security definer set search_path=public stable as $$
 select a.asset_type
 from public.purchase_items i
 join public.purchases p on p.id=i.purchase_id
 join public.beat_assets a on a.beat_id=i.beat_id
 where i.id=p_item and p.user_id=auth.uid() and lower(p.status)='paid'
 and (
   a.asset_type='MP3'
   or (a.asset_type='WAV' and i.license in ('Premium','Unlimited','Exclusive'))
   or (a.asset_type='STEMS' and i.license in ('Unlimited','Exclusive'))
 );
$$;
grant execute on function public.licensed_asset_types(uuid) to authenticated;
