-- M30 Wave 0 (0.12): server-side Eights wallet and append-only ledger.
-- Clients can READ their own wallet and ledger and can write NEITHER: every
-- change goes through the service role (an Edge Function / RPC that verifies
-- the reason: a verified purchase, a chapter reward, a Maelstrom result).
-- A client-insertable ledger would let anyone mint Eights.
-- Nothing reads these yet: the client wallet stays in the save until MP-0
-- migrates it (dual-write, then switch). Idempotent: safe to re-run.

create table if not exists public.player_wallet (
  user_id uuid primary key references auth.users(id) on delete cascade,
  eights bigint not null default 0 check (eights >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.eights_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  delta integer not null,
  reason text not null,
  idempotency_key text unique,
  created_at timestamptz not null default now()
);

alter table public.player_wallet enable row level security;
alter table public.eights_ledger enable row level security;

drop policy if exists "Users can view their own wallet" on public.player_wallet;
create policy "Users can view their own wallet"
  on public.player_wallet for select
  using (auth.uid() = user_id);

drop policy if exists "Users can view their own eights ledger" on public.eights_ledger;
create policy "Users can view their own eights ledger"
  on public.eights_ledger for select
  using (auth.uid() = user_id);

-- No client insert/update/delete policy on either table, and no grants either.
drop policy if exists "Users can insert to their own eights ledger" on public.eights_ledger;
revoke insert, update, delete on public.player_wallet from anon, authenticated;
revoke insert, update, delete on public.eights_ledger from anon, authenticated;
revoke usage, select on sequence public.eights_ledger_id_seq from anon, authenticated;
