# Supabase Setup

The real Supabase project configuration behind M15 (Backend & Cloud Services), documented so it's
reconstructable from the repo rather than depending on someone remembering dashboard clicks —
per `.kiro/specs/milestone-m15-backend-cloud-services/requirements.md` Requirement 6.5/10.2.

## Project

- **Project ref:** `tuhkhsqcnnszjnczkuzq`
- **URL:** `https://tuhkhsqcnnszjnczkuzq.supabase.co`
- **Anon/publishable key:** committed as a plain const in `scripts/managers/AuthManager.gd`
  (`SUPABASE_ANON_KEY`) — safe to embed client-side; Row Level Security is the actual security
  boundary, not key secrecy.
- **`service_role` key:** never leaves Supabase's own Edge Function secrets store. Not in this
  repo, not in `.env`, not held by any client. The only place it's used at all is inside
  `delete-account`'s server-side runtime (auto-injected by Supabase into every deployed Edge
  Function's environment — never manually configured or typed anywhere).
- **Free tier note:** the project pauses after 7 days with no API activity; the next request
  auto-resumes it with a several-second cold-start delay. A real operational characteristic, not
  a bug — `SaveManager`'s sync failures already retry non-blockingly rather than hard-failing.

## Schema

Checked in as `supabase/schema.sql`, applied via the Supabase MCP server's `apply_migration` tool
(functionally equivalent to the dashboard's SQL editor this project has no local CLI/migration
tooling for — see the milestone's Non-Goals). Two tables:

- **`player_saves`** — `id` (uuid, pk), `user_id` (uuid, unique, references `auth.users`),
  `save_data` (jsonb, mirrors `SaveManager`'s local save format exactly), `save_schema_version`
  (int), `client_updated_at` (timestamptz, client-set), `updated_at` (timestamptz, server default).
  RLS enabled: `select`/`insert`/`update` policies all scope to `auth.uid() = user_id`; no `delete`
  policy exists at all, so delete is denied by default even with RLS enabled — the only sanctioned
  removal path is the `delete-account` Edge Function, which bypasses RLS via `service_role`.
- **`remote_config`** — `key` (text, pk), `value` (jsonb). RLS enabled with a single permissive
  `select` policy (`using (true)`) — public data, no per-row restriction, same anon-key access
  pattern as any other public read.

**RLS verified, twice:**
1. Anon key alone, no session: `player_saves` `SELECT` returns `[]`, `INSERT` returns `42501`
   (permission denied); `remote_config` `SELECT` returns real rows.
2. Two real, independently signed-in test accounts: each could read/write only its own
   `player_saves` row; a direct attempt by one account to overwrite the other's row (explicitly
   specifying the victim's `user_id`) was rejected with the same `42501`. Both test accounts were
   disposable and fully deleted afterward.

## Auth settings

- **Email confirmation:** **on** (Supabase's project default) — `sign_up()` on a project with this
  enabled returns a user object with no `access_token` until the player clicks the confirmation
  email's link; `AuthManager` handles this via `sign_up_pending_confirmation` rather than treating
  it as an error.
- **Email rate limiting:** Supabase's default free-tier limit on outbound auth emails is low
  (observed: two signups within the same short window triggered `over_email_send_rate_limit`,
  clearing roughly half an hour later) — a real operational characteristic worth knowing about
  before assuming a signup failure is a code bug.
- **Leaked-password protection** (Auth → Password → "Check against HaveIBeenPwned"): **not yet
  enabled.** Requirement 10.1's dashboard toggle — logged honestly as not done rather than assumed,
  since no session working on this repo has had a reason to click it yet. Flip this before shipping
  auth to real users.
- **Google OAuth provider:** **not configured.** Google Sign-In (Requirement 2) is deferred — see
  `.kiro/specs/milestone-m15-backend-cloud-services/design.md`'s Requirement 2 section for the
  investigation finding (Godot 4.3 has no native Android deep-link API, and M13 hasn't produced a
  working Android export to build a plugin against yet either). Nothing to configure here until
  that work is picked back up.

## Edge Functions

- **`delete-account`** (`supabase/functions/delete-account/index.ts`, checked in — the function's
  source is not a secret, only its configured `service_role` secret is, and that's never in the
  source) — deployed via the Supabase MCP server's `deploy_edge_function` tool, JWT verification
  **on** (the default; do not disable it). Verifies the caller's JWT server-side (never trusts a
  client-supplied user id), then deletes the caller's `player_saves` row and `auth.users` row using
  the service-role-only Admin API.
  - Verified for real: a successful call returns `{"success": true}`, and — confirmed via direct
    SQL against the live project, not just the response — both rows are actually gone afterward. A
    second call with the same now-stale access token returns `401` ("Invalid or expired session"),
    confirming the function re-verifies on every call rather than caching a decision.
  - Reachability/rejection also confirmed independently of the above: a request with no
    `Authorization` header returns `401` before the function's own code even runs (Supabase's
    platform-level JWT verification), and a request with a garbage bearer token returns `401` too.

## `remote_config` contents

Empty as of M15's checkpoint — this milestone only proved the fetch/cache/fallback mechanism
works (one throwaway key was inserted, fetched with just the anon key, then removed). Real keys
(seasonal-event windows, a content kill-switch) are
`.kiro/specs/milestone-m14-live-operations/`'s content to define and insert.

## What's not yet done here

- Leaked-password protection toggle (see above).
- Google OAuth provider configuration (blocked on the deep-link plugin work, itself blocked on
  M13's Android export pipeline).
- A management-facing UI/process for actually editing `remote_config` rows day-to-day — M14's
  concern once it has real keys to manage.
