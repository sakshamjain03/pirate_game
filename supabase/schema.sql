-- Pirate Empire — M15 Supabase schema
-- Applied manually via the Supabase dashboard's SQL editor (Non-Goal: no local CLI/migration
-- tooling for this milestone — see .kiro/specs/milestone-m15-backend-cloud-services/requirements.md).
-- Source of truth: .kiro/specs/milestone-m15-backend-cloud-services/design.md, Requirement 3 and
-- Requirement 11 sections.

-- ---------------------------------------------------------------------------
-- Requirement 3 — player_saves (per-user cloud save, RLS-gated)
-- ---------------------------------------------------------------------------

create table public.player_saves (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) unique,
    save_data jsonb not null,
    save_schema_version integer not null default 0,
    client_updated_at timestamptz not null,
    updated_at timestamptz not null default now()
);

alter table public.player_saves enable row level security;

create policy "Users can read their own save"
    on public.player_saves for select
    using (auth.uid() = user_id);

create policy "Users can insert their own save"
    on public.player_saves for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own save"
    on public.player_saves for update
    using (auth.uid() = user_id);

-- No delete policy at all — delete is denied by default with RLS enabled and no matching policy.
-- The delete-account Edge Function bypasses this via the service_role key, which is exempt from
-- RLS by design; that is the only sanctioned way a player_saves row is ever removed.

-- ---------------------------------------------------------------------------
-- Requirement 11 — remote_config (public read, no per-row restriction)
-- ---------------------------------------------------------------------------

create table public.remote_config (
    key text primary key,
    value jsonb not null
);

-- Enabled with a single permissive select policy for project-wide RLS-by-default consistency
-- (design.md notes either "RLS disabled" or "RLS + permissive select policy" is correct here
-- since this is not per-user data — this project picks the latter).
alter table public.remote_config enable row level security;

create policy "Anyone can read remote config"
    on public.remote_config for select
    using (true);
