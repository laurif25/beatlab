drop policy if exists "project_files_member_read" on storage.objects;
create policy "project_files_member_read"
on storage.objects for select to authenticated
using (
  bucket_id = 'project-files'
  and array_length(storage.foldername(name),1) >= 2
  and public.is_project_member(((storage.foldername(name))[2])::uuid)
);
