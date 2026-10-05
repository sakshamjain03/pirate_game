-- M30 W0-3.3: Purchases ledger for server-side verification
-- Fixes S3, S6: Stores verified purchases from app stores

-- Create the purchases table (service-role only)
create table if not exists purchases (
  order_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text,
  sku text,
  token_hash text,
  state text,
  verified_at timestamptz,
  refunded_at timestamptz
);

-- Enable RLS (no client policies - service role writes only)
alter table purchases enable row level security;

-- Deny all access to authenticated users and anon
create policy "Purchases are not visible to clients"
  on purchases for select
  using (false);

create policy "Purchases cannot be inserted by clients"
  on purchases for insert
  with check (false);

create policy "Purchases cannot be updated by clients"
  on purchases for update
  using (false)
  with check (false);

create policy "Purchases cannot be deleted by clients"
  on purchases for delete
  using (false);
