create or replace function grant_likes(user_id uuid, num_likes int)
returns void
language plpgsql
as $$
begin
  update public.profiles
  set likes_balance = likes_balance + num_likes
  where id = user_id;
end;
$$;