-- M30 W0-3.3: Grant hygiene - revoke dangerous permissions from clients
-- Fixes S7: Prevents truncate, references, and trigger operations by authenticated users

-- Revoke dangerous permissions on all tables
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;

-- Revoke modify permissions on remote_config
revoke insert, update, delete on remote_config from anon, authenticated;

-- Ensure remote_config is read-only for clients
drop policy if exists "Anyone can read remote config" on remote_config;

create policy "Anyone can read remote config"
  on remote_config for select
  using (true);
