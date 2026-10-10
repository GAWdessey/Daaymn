-- Spending limit for verify-face: it counts its Rekognition CompareFaces calls
-- per attempt and stops for the rest of the calendar month (UTC) at
-- face_compare_monthly_cap.
--
-- The cap starts at 0 because the Daaymn AWS account has no free allowance
-- (Paid plan, no credits: every call is billed, about $0.001 each) and nothing
-- is to be spent until the app earns money. So adding an AWS key alone can't
-- cost anything; raising the cap is the decision to spend (900 is about $0.90 a
-- month at most). Change it in the dashboard, no release needed.
alter table public.face_verification_attempts
  add column if not exists compare_calls smallint not null default 0;

insert into public.app_config (key, value)
values ('face_compare_monthly_cap', '0'::jsonb)
on conflict (key) do nothing;
