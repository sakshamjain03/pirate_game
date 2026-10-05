-- M30 W0-3.3: Server-side wallet and eights ledger
-- Fixes S4: Prevents client-side manipulation of premium currency

-- Create the player_wallet table
create table if not exists player_wallet (
  user_id uuid primary key references auth.users(id) on delete cascade,
  eights bigint not null default 0
    check (eights >= 0)
);

-- Create the eights_ledger table (append-only)
create table if not exists eights_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  delta integer not null,
  reason text,
  idempotency_key text unique,
  created_at timestamptz default now()
);

-- Make eights_ledger append-only (no updates or deletes)
revoke update, delete on eights_ledger from anon, authenticated, postgres;
grant insert, select on eights_ledger to anon, authenticated;

-- Enable RLS on both tables (select-own only)
alter table player_wallet enable row level security;
alter table eights_ledger enable row level security;

create policy "Users can view their own wallet"
  on player_wallet for select
  using (auth.uid() = user_id);

create policy "Users can view their own eights ledger"
  on eights_ledger for select
  using (auth.uid() = user_id);

create policy "Users can insert to their own eights ledger"
  on eights_ledger for insert
  with check (auth.uid() = user_id);

-- Deny direct updates/deletes even for authenticated users
revoke insert, update, delete on player_wallet from anon, authenticated;
