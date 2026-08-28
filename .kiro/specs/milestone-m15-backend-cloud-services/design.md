# Design Document — M15 Backend & Cloud Services

## Why this design shape

Supabase's client surface is just HTTP (PostgREST for the database, GoTrue for auth) — there is no
official Godot SDK, and the community ones are thin wrappers around the same REST calls this
design makes directly via `HTTPRequest`. Per `AGENTS.md`'s "no unnecessary dependencies," hand-
rolling the handful of endpoints this milestone actually needs is less risk than depending on a
third-party GDExtension of unknown maintenance status for a project's first-ever network
dependency. If the Android OAuth work (Requirement 2) turns out to need a native plugin regardless
(likely — see below), that plugin is scoped narrowly to "receive a deep link," not "be the
Supabase client."

**New autoload:** `AuthManager` — owns session state (access token, refresh token, current user
id), sign-in/sign-up/sign-out calls, and token refresh. Registered after `SaveManager` in
`project.godot`'s `[autoload]` list (it doesn't need `SaveManager`, but `SaveManager` needs it —
see below).

**Extended, not duplicated:** `SaveManager` gains cloud-sync calls at its existing `save_game()`/
`load_game()` call sites, reading `AuthManager.is_signed_in()`/`AuthManager.get_access_token()` —
there is no second save system. `SettingsMenu` gains an Account section using the same themed-panel
pattern every other settings category already uses.

---

## Requirement 1/5 — `AuthManager` and session handling

```gdscript
# scripts/managers/AuthManager.gd (new autoload)
signal signed_in(user_id: String)
signal signed_out()
signal auth_error(message: String)

const SUPABASE_URL := "https://<project-ref>.supabase.co"   # from Project Settings, not secret
const SUPABASE_ANON_KEY := "<anon-key>"                      # client-embeddable, RLS-gated

var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""

func is_signed_in() -> bool:
    return not _access_token.is_empty()

func sign_up(email: String, password: String) -> void:
    _post_auth("/auth/v1/signup", {"email": email, "password": password})

func sign_in(email: String, password: String) -> void:
    _post_auth("/auth/v1/token?grant_type=password", {"email": email, "password": password})

func sign_out() -> void:
    # Best-effort revoke; clear local state unconditionally regardless of network result.
    if is_signed_in():
        _post_auth_fire_and_forget("/auth/v1/logout", {})
    _clear_session()
    signed_out.emit()

func _on_auth_response(body: Dictionary) -> void:
    _access_token = body.get("access_token", "")
    _refresh_token = body.get("refresh_token", "")
    _user_id = body.get("user", {}).get("id", "")
    _persist_session()   # writes to user://auth_session.json — see Requirement 5.1
    signed_in.emit(_user_id)
```

All requests set `apikey: <anon key>` and, once signed in, `Authorization: Bearer <access_token>`.
Token refresh: on any `401` from a database call, attempt
`/auth/v1/token?grant_type=refresh_token` once before surfacing an error — if that also fails,
treat the session as expired (`_clear_session()`, prompt sign-in again next time the Account
section is opened, do not interrupt active gameplay to demand it).

Session persistence (Requirement 5.1): `user://auth_session.json` holding `{refresh_token,
user_id}` only — never the short-lived access token, which is re-derived from the refresh token on
launch. Loaded at `AuthManager._ready()`, silently ignored if absent (the default, fully-local
case).

---

## Requirement 2 — Google Sign-In / Android deep link

**Investigate before committing to this shape** (Requirement 2.4). The intended flow:

1. `OS.shell_open("%s/auth/v1/authorize?provider=google&redirect_to=pirateempire://auth-callback" % SUPABASE_URL)`
   opens the system browser.
2. Player completes Google sign-in in the browser (outside the app entirely).
3. Supabase redirects to `pirateempire://auth-callback#access_token=...&refresh_token=...`.
4. Android routes that custom-scheme URI back to the app via an intent filter declared in the
   export's Android manifest additions
   (`export_presets.cfg`'s `android/modify_gradle_build`-based manifest customization, or a small
   plugin's own manifest merge — confirm which mechanism this project's Godot/export-template
   version actually supports).
5. Godot receives the incoming intent. **This is the uncertain step.** Options, in order of
   preference:
   - If the current Godot Android export template exposes deep-link intents to GDScript natively
     (check Godot 4.7's changelog/docs for this specifically — support here has evolved across
     Godot 4.x versions), use that directly.
   - Otherwise, a minimal custom Android plugin (`.aar`, per Godot's Android plugin system) whose
     only job is catching the `onNewIntent()` callback and forwarding the URI string to GDScript
     via a signal — deliberately the smallest possible plugin, not a general-purpose one.
6. Parse the URI fragment for `access_token`/`refresh_token`, feed them into the same
   `AuthManager._on_auth_response()`-equivalent path email/password sign-in uses, so there is one
   session-establishment code path, not two.

**Fallback if step 5 proves disproportionately complex for this milestone:** ship Requirement 1
(email/password) alone, document Google Sign-In as a follow-up once the Android plugin work is
scoped on its own, per Requirement 2.4's explicit permission to do this. Don't let an
Android-platform uncertainty block cloud save for players willing to use email/password.

---

**Investigation findings (2026-08-29, Wave 4 Task 18) — the fallback above is what this milestone
ships.** Researched Godot 4.3's actual Android export capabilities before writing any OAuth code,
per this section's own instruction:

- Godot 4.3's Android export template exposes **no native GDScript API** for receiving a deep-link
  intent (custom URI scheme or App Link). This isn't a version-specific gap that later 4.x releases
  closed either — every community solution found (`godot-sdk-integrations/godot-deeplink`,
  `cengiz-pz/godot-android-deeplink-plugin`, `timoschwarzer/godot-applinks`,
  `godot-sdk-integrations/godot-oauth2`, which itself depends on the deeplink plugin) is a
  third-party or hand-written Android plugin (`.aar`) catching `onNewIntent()` natively and
  forwarding the URI to GDScript via a signal — confirming step 5's "otherwise" branch, not the
  "if natively exposed" branch, is the only real option.
- Building or vendoring that plugin requires a real Android export pipeline (export templates,
  Gradle/Android SDK build tooling, a signing setup) to compile and test against — none of which
  exists in this project yet. `.kiro/specs/milestone-m13-ship-it/` (Wave 1: engine version, export
  templates, signing keystore, first successful `.apk`/`.aab` export) owns standing that up, and
  as of this investigation M13 has not started (every task in its `tasks.md` is still unchecked) —
  there is no real Android package id or signing fingerprint to configure a plugin or an OAuth
  client against yet regardless of the plugin question.
- Verdict: this crosses Requirement 2.4's "disproportionately complex" threshold for this
  milestone's scope, on both axes (no native path exists, *and* the prerequisite Android pipeline
  it would need doesn't exist yet either). Google Sign-In (Wave 4 tasks 19-21) is deferred as a
  follow-up, to be scoped deliberately once M13 lands a real Android export pipeline and package
  id/signing fingerprint — at that point, evaluate the community deeplink plugins above against
  writing a minimal custom one before defaulting to either.
- Password reset is **not** affected — Wave 2 already shipped `AuthManager.request_password_reset()`
  as a plain HTTP trigger (no deep-link dependency), and with no custom URI scheme registered at
  all, the reset link naturally falls through to Supabase's own hosted confirmation page in the
  browser, then the player returns to the app and signs in normally — exactly the fully-functional
  fallback this section's Requirement 7 note already anticipated, working automatically rather than
  needing separate code.

---

## Requirement 3 — Schema and RLS

```sql
-- supabase/schema.sql (checked in, applied via the Supabase dashboard SQL editor)

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
```

`user_id unique` enforces the "one save row per account" rule (Requirement 3.1) at the database
level, not just in client logic — an `upsert` (`POST .../player_saves?on_conflict=user_id` with the
`Prefer: resolution=merge-duplicates` header) is the single call site both "create my first cloud
save" and "update my existing one" use, rather than separate insert/update code paths.

Requirement 3.3's verification: attempt a `GET`/`POST` against `player_saves` using only the anon
key, no `Authorization` bearer token (or an invalid one) — confirm it returns zero rows / a
permission-denied error, not real data. Do this for real at this milestone's checkpoint, the same
"don't trust the policy text, verify the behavior" discipline `docs/07_AI_AGENT_WORKFLOW.md`
requires everywhere else.

---

## Requirement 4 — Sync behavior

```gdscript
# SaveManager.gd — extending, not duplicating, the existing save_game()/load_game()
func save_game() -> void:
    var data := _build_save_dict()   # existing logic, unchanged
    _write_local(data)               # existing local write, unchanged
    if AuthManager.is_signed_in():
        _sync_to_cloud(data)         # new, best-effort, non-blocking

func _sync_to_cloud(data: Dictionary) -> void:
    var payload := {
        "user_id": AuthManager.get_user_id(),
        "save_data": data,
        "save_schema_version": SAVE_SCHEMA_VERSION,
        "client_updated_at": Time.get_datetime_string_from_system(true),
    }
    # POST .../rest/v1/player_saves?on_conflict=user_id, Prefer: resolution=merge-duplicates
    # Fire-and-forget: on failure, set _pending_cloud_sync = true and retry on the next save_game()
    # call rather than blocking gameplay or queuing unboundedly (Requirement 4.4).
```

Conflict prompt (Requirements 4.1/4.3): a single shared UI moment — "Cloud save found. Keep this
device's empire, or the cloud one?" — reusing `PirateThemeBuilder`'s panel style, shown before any
overwrite in either direction, never defaulted silently. Compare `client_updated_at` (client-set
timestamp, not Postgres's own `updated_at`, since the two devices' clocks matter more than server
write order here) to decide whether a prompt is even needed — if the cloud save is trivially
identical (same `client_updated_at` down to the second) skip the prompt, it's the same save.

---

## Requirement 7 — Password reset

Reuses the deep-link receipt mechanism Requirement 2 already builds for Google Sign-In — one
listener for "the app was opened via `pirateempire://...`," branching on whether the payload is an
OAuth token pair or a recovery session, rather than two separate deep-link handlers.

```gdscript
# AuthManager.gd
func request_password_reset(email: String) -> void:
    _post_auth("/auth/v1/recover", {"email": email})   # no session change; just triggers the email

func complete_password_reset(new_password: String) -> void:
    # Called once the recovery deep link has established a temporary session (same receipt path
    # as Requirement 2's OAuth callback — see design.md's Requirement 2 section).
    _patch_auth("/auth/v1/user", {"password": new_password})
    # Supabase returns a normal user object; feed it through the same
    # _on_auth_response() a fresh sign-in already uses (Requirement 1.5) — one session
    # establishment path, not a special case for "came from a reset link."
```

UI: a "Forgot password?" link on the sign-in form (not a separate screen) opens a themed dialog
for the email address, then shows a themed confirmation ("check your email") — reusing the same
panel/dialog pattern Requirement 4's sync-conflict prompt already establishes.

**Password reset is not actually blocked by Requirement 2's deep-link uncertainty.** Triggering
the reset email (`request_password_reset()`) is a plain HTTP call, buildable in Wave 2 alongside
the rest of `AuthManager`, independent of any Android plumbing. Only the *seamless one-tap return
to the app* depends on the deep-link mechanism. If that investigation (Requirement 2.4) comes back
too complex to build, the fallback for password reset specifically is: the reset link opens
Supabase's own default hosted confirmation page in the browser, the player sets their new password
there, then returns to the app and signs in normally (Requirement 1.2) with it — clunkier, but
fully functional with zero Android-specific code. Google Sign-In has no equivalent fallback (OAuth
fundamentally requires handing control back to the app); password reset does. Scope Wave 4/the
deep-link investigation accordingly — build the trigger-email half unconditionally, treat the
seamless-return half as the part genuinely gated on Requirement 2's findings.

## Requirement 8 — Account deletion

The one genuinely new piece of server-side infrastructure this milestone adds. Everything else in
M15 is either a direct REST call from the client or a database RLS policy; deleting an
`auth.users` row is privileged and cannot be done with the anon key, by design.

```sql
-- supabase/functions/delete-account/index.ts (Supabase Edge Function, Deno runtime)
-- Pseudocode shape, not final TypeScript:
-- 1. Read the caller's JWT from the Authorization header (the player's own access token).
-- 2. Verify it with Supabase's own auth helper (confirms it's a real, unexpired session — the
--    function does NOT trust a client-supplied user id, it derives the id from the verified token).
-- 3. Using the service_role key (held only in this function's Supabase-managed secrets, never in
--    the repo), delete the caller's `player_saves` row, then delete the caller's `auth.users` row
--    via Supabase's Admin API.
-- 4. Return success/failure to the client.
```

```gdscript
# AuthManager.gd
func delete_account() -> void:
    # POST to the deployed Edge Function URL, Authorization: Bearer <current access token>.
    # On success: _clear_session() (Requirement 5.1's existing local-clear path) and signed_out.emit().
    # Local save is never touched by this call — SaveManager has no involvement here at all.
```

This is the only Edge Function this milestone deploys. Deploying it (Supabase CLI or dashboard
function editor) and configuring its `service_role` secret are Wave 1 (project-setup) tasks, not
something the Godot client build ever handles.

**Web-accessible deletion path (Requirement 8.5):** the same hosted page
`.kiro/specs/milestone-m13-ship-it/` builds for the privacy policy carries a "Request account
deletion" section with a support contact — a plain static addition to that page, not a second
piece of infrastructure. No Godot/client work; cross-referenced here so it isn't forgotten as
"someone else's problem."

## Requirement 9 — Terms acceptance and disclosure

Pure UI (a `CheckBox` + two `LinkButton`s opening the hosted ToS/Privacy URLs via
`OS.shell_open()`) gating the existing sign-up call from Requirement 1 — no new backend surface.
The actual enumeration in `requirements.md` Requirement 9.2 is the artifact that matters; keep it
accurate as the single source `docs/SUPABASE_SETUP.md` and the M13 privacy policy page both quote
from, rather than letting either drift independently.

## Requirement 10 — Auth hardening

Dashboard-only: Supabase Auth settings → Password → enable "Check against HaveIBeenPwned." No
client or server code. Recorded in `docs/SUPABASE_SETUP.md` alongside the schema/RLS/provider
settings that already need documenting there (Requirement 6.5), so this project's actual Supabase
configuration is fully reconstructable from the repo, not from memory of dashboard clicks.

## Requirement 11 — Remote config

```sql
-- supabase/schema.sql, appended
create table public.remote_config (
    key text primary key,
    value jsonb not null
);
-- Publicly readable by design (not per-user data) — RLS can stay disabled on this table, or be
-- enabled with a single permissive "anyone can select" policy if project-wide RLS-by-default is
-- preferred for consistency; either is correct, pick one and document it.
```

```gdscript
# New: scripts/managers/RemoteConfigManager.gd (autoload) — deliberately separate from
# AuthManager: this data is public and needs no session, unlike everything else M15 builds.
var _cache: Dictionary = {}
var _fetched: bool = false

func _ready() -> void:
    _fetch()   # fire-and-forget; never blocks _ready()

func get_value(key: String, default_value):
    return _cache.get(key, default_value)   # always returns a usable value, fetched or not

func _fetch() -> void:
    # GET .../rest/v1/remote_config?select=key,value, apikey header only (no auth needed).
    # On success: populate _cache. On any failure: leave _cache as whatever it already was
    # (empty on first launch, stale-but-usable on a later failed refresh) — never clear it out
    # from under a caller mid-session.
```

`get_value(key, default)`'s two-argument, always-returns-something shape is the entire contract —
every future caller (M14's seasonal-event window, its kill-switch flag, anything else added later)
is structurally incapable of blocking on this or treating an absent key as an error, which is what
Requirement 11.3 actually requires.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

New GUT coverage: `AuthManager` sign-in/sign-out state transitions and session persistence
(mockable via dependency-injecting the HTTP layer or a lightweight fake — this project doesn't
currently have a pattern for mocking `HTTPRequest`; establish the simplest one that works rather
than importing a mocking framework), and `SaveManager`'s cloud-sync trigger logic (does it call
sync exactly when signed in, does it skip cleanly when not).

**Cannot be verified by GUT alone, requires a real Supabase project and (for Requirement 2) a real
Android device:**
- The actual RLS policy behavior (Requirement 3.3) — needs a real Supabase project, not a mock.
- The Google Sign-In deep-link round trip (Requirement 2) — needs a real Android device/emulator
  with a real browser completing a real Google OAuth flow.
- Sync behavior across two actual devices/sessions (Requirement 4's conflict prompt firing
  correctly) — best simulated with two local save files and a manually-edited cloud row for the
  first pass, confirmed on real hardware before this milestone's checkpoint closes.
- The password-reset deep link (Requirement 7) — same device/browser requirement as Google
  Sign-In, and shares its receipt code path, so verifying one after the other on the same device
  session is efficient.
- The account-deletion Edge Function (Requirement 8) — deploy it to the real Supabase project and
  call it for real with a disposable test account; confirm both the `player_saves` row and the
  `auth.users` row are actually gone afterward (query the dashboard directly, don't just trust a
  200 response), and confirm a second call with the same now-invalid token is rejected rather than
  silently succeeding.
- Remote config's fetch-fail fallback (Requirement 11.3) — deliberately point the client at a
  wrong URL or disable network and confirm `get_value()` still returns sane defaults rather than
  blocking or crashing; this failure path is exactly the one most likely to only get tested by
  accident otherwise.

Log each of these explicitly as device/project-verified or not-yet-verified at checkpoint time,
per this project's established discipline — do not assume they work because the HTTP calls
"look right."
