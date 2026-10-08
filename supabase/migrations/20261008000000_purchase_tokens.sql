-- One row per granted purchase. The primary key is what stops a purchase token
-- from being redeemed twice: verify-google-purchase and handle-google-rtdn insert
-- here first and only grant benefits when the insert succeeds.
-- `period` is '' for one-time products; for subscriptions it is the expiry
-- (expiryTimeMillis) of the billing period, since renewals reuse the same token.
create table if not exists public.purchase_tokens (
  purchase_token text not null,
  period         text not null default '',
  user_id        uuid not null references auth.users (id) on delete cascade,
  product_id     text not null,
  created_at     timestamptz not null default now(),
  primary key (purchase_token, period)
);

-- Service role only: RLS on with no policies, so anon/authenticated get nothing.
alter table public.purchase_tokens enable row level security;
