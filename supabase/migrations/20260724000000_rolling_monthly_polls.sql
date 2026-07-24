-- ================= Rolling monthly community polls =================
-- Removes auto-generated placeholder junk, stands up one clean current
-- poll from a pool of real improvements, and installs a monthly roll:
-- top option WINS only if >10 votes -> archived + replaced by next pool
-- item; losers carry over (votes reset). If top<=10, nothing moves.

-- 0. Remove placeholder junk polls (auto-generated, zero real votes)
delete from public.poll_options
  where poll_id in (select id from public.polls where title like 'Future Poll Month %');
delete from public.polls where title like 'Future Poll Month %';

-- 1. Pool of real improvements (drawn one at a time to replace winners)
create table if not exists public.poll_option_pool (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null,
  position int not null,
  used_at timestamptz
);

insert into public.poll_option_pool (title, subtitle, position)
select v.title, v.subtitle, v.position from (values
  ('Voice notes in chat','Send quick voice messages in your conversations.',1),
  ('Video profile intros','Add a short video clip to your profile.',2),
  ('In-chat photo sharing','Share photos directly with your matches.',3),
  ('Advanced search filters','Filter matches by height, interests and more.',4),
  ('Travel mode','Match with people in other cities before you visit.',5),
  ('Compatibility quiz','Answer fun questions to find better matches.',6),
  ('Icebreaker prompts','Auto-suggested openers to start a chat.',7),
  ('Photo verification badge','Verify your photos for a trusted badge.',8),
  ('More colour themes','Choose from several app colour themes.',9),
  ('Undo last swipe','Take back an accidental pass.',10),
  ('See who liked you','Reveal everyone who liked your profile.',11),
  ('Profile boost','Be seen by more people for 30 minutes.',12),
  ('Super Like animations','Stand out with an eye-catching like.',13),
  ('Match mini-games','Play quick games with your matches.',14),
  ('Music on your profile','Show your favourite songs.',15),
  ('Prompt-based profiles','Answer prompts to show your personality.',16),
  ('Daily match picks','A curated handful of top matches each day.',17),
  ('In-app video calls','Call your matches safely inside the app.',18),
  ('Interest tags','Add tags so people find your hobbies.',19),
  ('Incognito browsing','Only people you like can see you.',20),
  ('Message reactions','React to messages with emojis.',21),
  ('Profile insights','See how your profile is performing.',22),
  ('Lifestyle badges','Show your sign, pets and habits.',23),
  ('Safety check-ins','Share your date location with a friend.',24),
  ('Unlimited rewind','Undo as many swipes as you like.',25),
  ('Mood status','Set what you are looking for right now.',26),
  ('GIF support in chat','Send GIFs in your conversations.',27),
  ('AI photo tips','Get suggestions for better profile photos.',28),
  ('Language filters','Match with people who speak your language.',29),
  ('Local date ideas','Suggested spots for your first date.',30),
  ('Daily streak rewards','Earn perks for staying active.',31),
  ('Blur photos until match','Reveal photos only after you match.',32),
  ('Interest communities','Join groups around shared hobbies.',33),
  ('Second-chance matches','Revisit past passes once a week.',34),
  ('Online status','Show when you are online and free to chat.',35),
  ('Smart notifications','Only get pinged for what matters.',36),
  ('Read receipts in chat','See when your messages have been read.',37),
  ('Group events','Meet matches at local meetups.',38),
  ('Verified age & height','Trusted profile details.',39),
  ('Saved profiles','Bookmark profiles to revisit later.',40),
  ('Date planner','Plan and confirm dates inside the app.',41),
  ('Weekly top match','A spotlight on your most compatible person.',42)
) as v(title, subtitle, position)
where not exists (select 1 from public.poll_option_pool);

-- 2. Winners archive
create table if not exists public.poll_winners (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid,
  title text,
  subtitle text,
  votes int,
  won_at timestamptz default now()
);

-- 3. Monthly roll: winner (>10 votes) archived + replaced; losers carry over
create or replace function public.roll_monthly_poll() returns void
language plpgsql security definer set search_path = public as $fn$
declare
  ended_poll public.polls%rowtype;
  win public.poll_options%rowtype;
  new_poll_id uuid;
  pool_item public.poll_option_pool%rowtype;
  mon_start timestamptz := date_trunc('month', now());
  mon_end   timestamptz := date_trunc('month', now()) + interval '1 month' - interval '1 second';
begin
  if exists (select 1 from public.polls where start_date = mon_start) then
    return;  -- this month's poll already exists
  end if;

  select * into ended_poll from public.polls where end_date < now() order by end_date desc limit 1;

  new_poll_id := gen_random_uuid();
  insert into public.polls (id, title, start_date, end_date)
  values (new_poll_id, to_char(now(),'FMMonth YYYY') || ' Community Poll', mon_start, mon_end);

  if ended_poll.id is null then
    for pool_item in select * from public.poll_option_pool where used_at is null order by position limit 3 loop
      insert into public.poll_options (poll_id, title, subtitle, votes) values (new_poll_id, pool_item.title, pool_item.subtitle, 0);
      update public.poll_option_pool set used_at = now() where id = pool_item.id;
    end loop;
    return;
  end if;

  select * into win from public.poll_options where poll_id = ended_poll.id order by votes desc limit 1;

  if win.id is not null and win.votes > 10 then
    insert into public.poll_winners (poll_id, title, subtitle, votes) values (ended_poll.id, win.title, win.subtitle, win.votes);
    insert into public.poll_options (poll_id, title, subtitle, votes)
      select new_poll_id, title, subtitle, 0 from public.poll_options where poll_id = ended_poll.id and id <> win.id;
    select * into pool_item from public.poll_option_pool where used_at is null order by position limit 1;
    if pool_item.id is not null then
      insert into public.poll_options (poll_id, title, subtitle, votes) values (new_poll_id, pool_item.title, pool_item.subtitle, 0);
      update public.poll_option_pool set used_at = now() where id = pool_item.id;
    else
      insert into public.poll_options (poll_id, title, subtitle, votes) values (new_poll_id, win.title, win.subtitle, 0);
    end if;
  else
    insert into public.poll_options (poll_id, title, subtitle, votes)
      select new_poll_id, title, subtitle, 0 from public.poll_options where poll_id = ended_poll.id;
  end if;
end;
$fn$;

-- 4. Bootstrap THIS month's clean poll with 3 fresh improvements
do $boot$
declare np uuid := gen_random_uuid(); it record;
begin
  if not exists (select 1 from public.polls where start_date = date_trunc('month', now())) then
    insert into public.polls (id, title, start_date, end_date)
    values (np, to_char(now(),'FMMonth YYYY')||' Community Poll',
            date_trunc('month',now()), date_trunc('month',now())+interval '1 month'-interval '1 second');
    for it in select * from public.poll_option_pool where used_at is null order by position limit 3 loop
      insert into public.poll_options (poll_id, title, subtitle, votes) values (np, it.title, it.subtitle, 0);
      update public.poll_option_pool set used_at = now() where id = it.id;
    end loop;
  end if;
end $boot$;

-- 5. Schedule monthly roll (idempotent)
create extension if not exists pg_cron;
select cron.unschedule('roll-monthly-poll') where exists (select 1 from cron.job where jobname='roll-monthly-poll');
select cron.schedule('roll-monthly-poll', '5 0 1 * *', $cron$select public.roll_monthly_poll();$cron$);

-- 6. Problem reports (Report-a-Problem feature)
create table if not exists public.problem_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  message text not null,
  created_at timestamptz default now()
);
alter table public.problem_reports enable row level security;
drop policy if exists "insert own report" on public.problem_reports;
create policy "insert own report" on public.problem_reports
  for insert to authenticated with check (auth.uid() = user_id);
