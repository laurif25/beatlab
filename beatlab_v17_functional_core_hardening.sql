-- Applied to connected Supabase project during v17 build.
alter policy "conversations_member_update" on public.conversations
to authenticated using (public.is_conversation_member(id))
with check (public.is_conversation_member(id));

alter policy "open_track_sub_parties_update" on public.open_track_submissions
to authenticated
using (
  submitter_id = (select auth.uid())
  or exists(select 1 from public.open_track_slots s where s.id=slot_id and s.owner_id=(select auth.uid()))
)
with check (
  submitter_id = (select auth.uid())
  or exists(select 1 from public.open_track_slots s where s.id=slot_id and s.owner_id=(select auth.uid()))
);
