-- M30 Wave 0 (0.12): entitlement grant ledger (audit trail, refunds).
-- Additive only. Client writes to player_entitlements are NOT locked here:
-- the shipped client still upserts its entitlement set (EntitlementManager),
-- so locking them before a server-side grant path exists would break sync.
-- That lock lives in 0007 and waits for the server grant path (MP-0).
-- Idempotent: safe to re-run.

create table if not exists public.entitlement_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entitlement_id text not null,
  source text not null default 'default'
    check (source in ('default', 'play', 'purchase', 'admin')),
  order_id text,
  platform text,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, entitlement_id, order_id)
);

alter table public.entitlement_grants enable row level security;

-- Clients may read their own grants; only the service role (Edge Functions) writes.
drop policy if exists "Users can view their own grants" on public.entitlement_grants;
create policy "Users can view their own grants"
  on public.entitlement_grants for select
  using (auth.uid() = user_id);

revoke insert, update, delete on public.entitlement_grants from anon, authenticated;
