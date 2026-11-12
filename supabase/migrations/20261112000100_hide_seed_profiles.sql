-- Hide the made-up (seed) profiles from real members. Nobody answers as them,
-- so a real like or paid message sent to one is wasted. Rows stay stored.
-- Seed accounts (the screenshot test account) still see them, so store
-- screenshots keep working. To undo: re-create the view without the where.
create or replace view public.public_profiles
with (security_barrier = true)
as
select
  id, created_at, name, age, image_urls, best_photo_index, gender, pronouns,
  ethnicity, work, religion, height_cm, weight_kg, dominant_hand,
  device_preference, interested_in, bio_topics, city, metric_system,
  public_key, is_verified, is_ghost_mode_enabled,
  case when is_ghost_mode_enabled then null else last_seen end as last_seen,
  updated_at
from public.profiles p
where not p.is_seed_profile
   or exists (select 1 from public.profiles me
              where me.id = auth.uid() and me.is_seed_profile);

revoke all on public.public_profiles from public, anon, authenticated;
grant select on public.public_profiles to authenticated, service_role;
