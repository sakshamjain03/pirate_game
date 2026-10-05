-- M30 Wave 0 (0.12): player_saves hardening.
-- * save_revision column (the client already writes save_revision inside
--   save_data; this column lets a later RPC compare revisions server-side).
-- * a 1 MB size cap on save_data.
-- * updated_at always set by the server, never trusted from the client.
-- * the UPDATE policy gains WITH CHECK, so a row can't be re-pointed to
--   another user_id.
-- Idempotent: safe to re-run.

alter table public.player_saves
  add column if not exists save_revision integer not null default 0;

alter table public.player_saves drop constraint if exists save_data_size_check;
alter table public.player_saves
  add constraint save_data_size_check check (pg_column_size(save_data) < 1048576);

-- The function must exist before the trigger that calls it.
create or replace function public.set_updated_at_now()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists player_saves_set_updated_at on public.player_saves;
create trigger player_saves_set_updated_at
  before insert or update on public.player_saves
  for each row execute function public.set_updated_at_now();

-- Policy names match supabase/schema.sql exactly.
drop policy if exists "Users can update their own save" on public.player_saves;
create policy "Users can update their own save"
  on public.player_saves for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own entitlements" on public.player_entitlements;
create policy "Users can update their own entitlements"
  on public.player_entitlements for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
