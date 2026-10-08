-- The profiles UPDATE policy lets a signed-in user write every column of their
-- own row, so the app key alone could set like_count, subscription_tier,
-- one_time_report_credits and the rest. This guard keeps those columns for the
-- server: edge functions (service_role) and SECURITY DEFINER RPCs (postgres)
-- pass through, while writes from the app silently keep the stored value, so
-- installed app versions that still send them don't start failing.
create or replace function public.guard_profile_columns()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.created_at := now();
    new.like_count := 6;
    new.last_like_granted_at := null;
    new.is_verified := false;
    new.is_ghost_mode_enabled := false;
    new.infinite_scroll_until := null;
    new.ghost_mode_until := null;
    new.purchased_infinite_scroll_until := null;
    new.purchased_ghost_mode_until := null;
    new.last_ad_like_at := null;
    new.last_ad_scroll_at := null;
    new.last_ad_ghost_at := null;
    new.subscription_tier := null;
    new.subscription_expires_at := null;
    new.store_transaction_id := null;
    new.obfuscated_external_account_id := null;
    new.monthly_report_credit_tier := null;
    new.has_claimed_monthly_report := false;
    new.one_time_report_credits := '{}'::jsonb;
    new.last_free_report_claimed_at := null;
    new.is_seed_profile := false;
    return new;
  end if;

  -- Daily free like, as app versions before request_daily_like did it: one
  -- like at a time, below 6, at least 20 hours after the last one.
  if new.like_count = old.like_count + 1
     and old.like_count < 6
     and old.last_like_granted_at <= now() - interval '20 hours' then
    new.last_like_granted_at := now();
  else
    new.like_count := old.like_count;
    -- Starting the timer is allowed; the time is always the server's
    if new.last_like_granted_at is distinct from old.last_like_granted_at
       and old.last_like_granted_at is null and old.like_count < 6 then
      new.last_like_granted_at := now();
    else
      new.last_like_granted_at := old.last_like_granted_at;
    end if;
  end if;

  -- Ghost mode can only be switched on while it's paid for
  if new.is_ghost_mode_enabled and not coalesce(old.is_ghost_mode_enabled, false)
     and coalesce(greatest(old.ghost_mode_until, old.purchased_ghost_mode_until), '-infinity') <= now() then
    new.is_ghost_mode_enabled := old.is_ghost_mode_enabled;
  end if;

  -- is_verified stays writable: the face check runs on the device, so there
  -- is nothing on the server to verify it against yet.
  new.created_at := old.created_at;
  new.infinite_scroll_until := old.infinite_scroll_until;
  new.ghost_mode_until := old.ghost_mode_until;
  new.purchased_infinite_scroll_until := old.purchased_infinite_scroll_until;
  new.purchased_ghost_mode_until := old.purchased_ghost_mode_until;
  new.last_ad_like_at := old.last_ad_like_at;
  new.last_ad_scroll_at := old.last_ad_scroll_at;
  new.last_ad_ghost_at := old.last_ad_ghost_at;
  new.subscription_tier := old.subscription_tier;
  new.subscription_expires_at := old.subscription_expires_at;
  new.store_transaction_id := old.store_transaction_id;
  new.obfuscated_external_account_id := old.obfuscated_external_account_id;
  new.monthly_report_credit_tier := old.monthly_report_credit_tier;
  new.has_claimed_monthly_report := old.has_claimed_monthly_report;
  new.one_time_report_credits := old.one_time_report_credits;
  new.last_free_report_claimed_at := old.last_free_report_claimed_at;
  new.is_seed_profile := old.is_seed_profile;
  return new;
end;
$$;

drop trigger if exists guard_profile_columns on public.profiles;
create trigger guard_profile_columns
  before insert or update on public.profiles
  for each row execute function public.guard_profile_columns();

-- These SECURITY DEFINER RPCs were callable by any client: add_likes and
-- purchase_likes add likes to the caller's own row with no purchase check,
-- decrement_user_like_count drains anyone's likes, decrement_report_credit
-- edits anyone's credits, and debug_reset_ad_timestamps skips ad cooldowns.
-- The app calls none of them; claim-one-time-report calls
-- decrement_report_credit with the service role.
revoke execute on function public.add_likes(integer) from public, anon, authenticated;
revoke execute on function public.purchase_likes(integer, integer, text, text) from public, anon, authenticated;
revoke execute on function public.decrement_user_like_count(uuid) from public, anon, authenticated;
revoke execute on function public.decrement_report_credit(uuid, text) from public, anon, authenticated;
revoke execute on function public.debug_reset_ad_timestamps() from public, anon, authenticated;
grant execute on function public.add_likes(integer) to service_role;
grant execute on function public.purchase_likes(integer, integer, text, text) to service_role;
grant execute on function public.decrement_user_like_count(uuid) to service_role;
grant execute on function public.decrement_report_credit(uuid, text) to service_role;
grant execute on function public.debug_reset_ad_timestamps() to service_role;

-- What one user may see of another: no location, push token, balances,
-- purchases or entitlements. last_seen is hidden while ghost mode is on, which
-- is what ghost mode promises. Owned by postgres, so it reads every row even
-- once profiles SELECT is limited to the caller's own row
-- (supabase/pending/restrict_profile_reads.sql).
create or replace view public.public_profiles
with (security_barrier = true)
as
select
  id,
  created_at,
  name,
  age,
  image_urls,
  best_photo_index,
  gender,
  pronouns,
  ethnicity,
  work,
  religion,
  height_cm,
  weight_kg,
  dominant_hand,
  device_preference,
  interested_in,
  bio_topics,
  city,
  metric_system,
  public_key,
  is_verified,
  is_ghost_mode_enabled,
  case when is_ghost_mode_enabled then null else last_seen end as last_seen,
  updated_at
from public.profiles;

revoke all on public.public_profiles from public, anon, authenticated;
grant select on public.public_profiles to authenticated, service_role;
