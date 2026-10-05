-- M30 W0-3.3: Player saves hardening for security and reliability
-- Fixes S7: Adds size limits, updated_at server-side, and save_revision for conflict resolution

-- Add save_revision column if it doesn't exist
alter table if exists player_saves
add column if not exists save_revision integer default 0;

-- Add check constraint for save_data size (1MB limit)
alter table if exists player_saves
add constraint save_data_size_check check (pg_column_size(save_data) < 1048576);

-- Recreate UPDATE policies with explicit WITH CHECK
drop policy if exists "Users can update their own saves" on player_saves;

create policy "Users can update their own saves"
  on player_saves for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Create trigger to set updated_at to current timestamp on insert/update
drop trigger if exists update_player_saves_updated_at on player_saves;
create trigger update_player_saves_updated_at
  before insert or update on player_saves
  for each row
  execute function update_updated_at_column();

-- Ensure the updated_at trigger function exists
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Drop old UPDATE policy for player_entitlements if it exists
drop policy if exists "Users can update their own entitlements" on player_entitlements;

-- Recreate UPDATE policies for player_entitlements with explicit WITH CHECK
create policy "Users can update their own entitlements"
  on player_entitlements for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
