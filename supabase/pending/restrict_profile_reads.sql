-- Stage 2 of the profiles lock-down: each user can read only their own
-- profiles row; everyone else is read through public_profiles (created in
-- migrations/20261008000300_lock_down_profiles.sql), which leaves out
-- location, fcm_token, balances, purchases and entitlements.
--
-- Not a migration yet, on purpose: app versions before the public_profiles
-- change read other users straight from profiles, so on those versions
-- Discover, Liked You, chats and matches would come up empty. Decided
-- 2026-10-08: move this into migrations/ (with a timestamp) about two weeks
-- after the app release that reads public_profiles.
drop policy if exists "Allow authenticated users to view profiles" on public.profiles;
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;

-- The live own-row SELECT policy is misnamed "Users can update their own
-- profile."; replace it with one that says what it does.
drop policy if exists "Users can update their own profile." on public.profiles;
drop policy if exists "Users can view their own profile" on public.profiles;
create policy "Users can view their own profile" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);
