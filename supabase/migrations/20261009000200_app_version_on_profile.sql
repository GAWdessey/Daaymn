-- The app version each user last opened, so "wait until most active users are
-- on the new version" (before supabase/pending/restrict_profile_reads.sql) is a
-- number rather than a guess. Versions before 77 never report, so an active
-- user with no version is on 76 or older. public_profiles lists its columns,
-- so other users don't see these.
alter table public.profiles
  add column if not exists app_version_code integer,
  add column if not exists app_version_reported_at timestamptz;

create or replace function public.report_app_version(p_version_code integer)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is not null and p_version_code > 0 then
    update public.profiles
    set app_version_code = p_version_code,
        app_version_reported_at = now()
    where id = auth.uid();
  end if;
end;
$$;

revoke execute on function public.report_app_version(integer) from public, anon;
grant execute on function public.report_app_version(integer) to authenticated, service_role;

-- Users seen in the last 14 days, by version. Read it from the dashboard:
--   select * from app_version_adoption;
create or replace view public.app_version_adoption as
select
  coalesce(app_version_code::text, 'before 77') as app_version,
  count(*) as active_users,
  round(100.0 * count(*) / sum(count(*)) over (), 1) as percent
from public.profiles
where last_seen > now() - interval '14 days'
  and not is_seed_profile
group by app_version_code
order by app_version_code desc nulls last;

revoke all on public.app_version_adoption from public, anon, authenticated;
grant select on public.app_version_adoption to service_role;
