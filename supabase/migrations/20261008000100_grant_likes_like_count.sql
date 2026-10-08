-- grant_likes added paid likes to likes_balance, but the app and every other
-- function read like_count, so paid likes never showed up. This matches the
-- live definition (checked 2026-10-08), which was already fixed by hand.
create or replace function public.grant_likes(user_id uuid, num_likes int)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.profiles
  set like_count = coalesce(like_count, 0) + num_likes
  where id = grant_likes.user_id;
end;
$$;

-- Postgres lets PUBLIC execute new functions, which would let any client call
-- this RPC with the anon key and grant itself likes. Only the service role
-- (verify-google-purchase, grant-promo-item) should.
revoke execute on function public.grant_likes(uuid, int) from public, anon, authenticated;
grant execute on function public.grant_likes(uuid, int) to service_role;
