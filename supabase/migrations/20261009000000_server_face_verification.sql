-- Face verification moves to the server. Until now the app compared the
-- selfie on the phone and wrote is_verified itself, so the app key alone could
-- set the verified badge. The verify-face edge function now does the
-- comparison and is the only writer; app writes of is_verified are ignored,
-- the same way as the other server-owned columns.
create or replace function public.guard_profile_columns()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  -- A badge earned against one set of photos says nothing about new ones, so
  -- adding a photo drops it until verify-face is passed again
  photos_added boolean := tg_op = 'UPDATE'
    and exists (select unnest(new.image_urls) except select unnest(old.image_urls));
begin
  if current_user not in ('authenticated', 'anon') then
    -- handle_profile_upsert runs as postgres; only verify-face (service_role)
    -- sets the badge
    if photos_added and current_user <> 'service_role' then
      new.is_verified := false;
    end if;
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

  -- is_verified is set only by the verify-face edge function
  new.is_verified := old.is_verified and not photos_added;
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

-- One row per verify-face call: caps attempts per day and keeps a record of
-- how each badge was earned. Service role only.
create table if not exists public.face_verification_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  verified boolean not null,
  similarity real
);

create index if not exists face_verification_attempts_user_created_idx
  on public.face_verification_attempts (user_id, created_at desc);

alter table public.face_verification_attempts enable row level security;
revoke all on public.face_verification_attempts from public, anon, authenticated;
grant all on public.face_verification_attempts to service_role;
