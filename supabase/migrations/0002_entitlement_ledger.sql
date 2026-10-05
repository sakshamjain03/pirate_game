-- M30 W0-3.3: Entitlement ledger for audit trail and revocation support
-- Fixes S2, S5: Prevents client-side entitlement manipulation and supports refunds

-- Create the entitlement_grants ledger table
create table if not exists entitlement_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entitlement_id text not null,
  source text not null default 'default'
    check (source in ('default', 'play', 'purchase', 'admin')),
  order_id text,
  platform text,
  granted_at timestamptz default now(),
  revoked_at timestamptz,
  unique(user_id, entitlement_id, order_id)
);

-- Enable RLS on entitlement_grants (select-own only)
alter table entitlement_grants enable row level security;

create policy "Users can view their own grants"
  on entitlement_grants for select
  using (auth.uid() = user_id);

-- Revoke insert, update, delete on player_entitlements from clients
revoke insert, update, delete on player_entitlements from anon, authenticated;

-- Drop old insert/update policies for player_entitlements if they exist
drop policy if exists "Users can insert their own entitlements" on player_entitlements;
drop policy if exists "Users can update their own entitlements" on player_entitlements;

-- Keep only the select policy for reading entitlements
