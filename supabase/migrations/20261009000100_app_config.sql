-- Settings the app reads at launch, changeable without a release.
-- min_android_version_code: installs below it get Play's immediate (blocking)
-- update instead of the flexible one. 77 is the first release that reads other
-- users through public_profiles; raise it when a later backend change would
-- break older versions (e.g. before supabase/pending/restrict_profile_reads.sql).
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null
);

alter table public.app_config enable row level security;
revoke all on public.app_config from public, anon, authenticated;
grant select on public.app_config to anon, authenticated;
grant all on public.app_config to service_role;

drop policy if exists "Anyone can read app config" on public.app_config;
create policy "Anyone can read app config" on public.app_config
  for select to anon, authenticated
  using (true);

insert into public.app_config (key, value)
values ('min_android_version_code', '77'::jsonb)
on conflict (key) do nothing;
