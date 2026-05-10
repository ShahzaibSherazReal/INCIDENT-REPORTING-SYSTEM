-- Public Storage bucket for incident snapshot JPEGs (optional; API falls back to /snapshots/ if missing)
-- Run in Supabase SQL Editor after 0001, or include in your migration flow.

insert into storage.buckets (id, name, public)
values ('incident-snapshots', 'incident-snapshots', true)
on conflict (id) do nothing;

-- Allow read via public URLs for this bucket (adjust if your project uses stricter Storage RLS)
drop policy if exists "Allow public read incident-snapshots" on storage.objects;

create policy "Allow public read incident-snapshots"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'incident-snapshots');
