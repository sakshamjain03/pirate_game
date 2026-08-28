# Requirements Document

## Introduction

Milestone M15 adds Supabase-backed cloud save and optional account sign-in — the first real backend
this project has ever had. `docs/02_TECH_STACK.md` already names Supabase as "Backend (Future)";
`AGENTS.md` lists Cloud Saves under "Out of Scope (Version 1)... These are future milestones. Do
not implement unless instructed." This milestone is that explicit instruction, given 2026-08-27.

This is scoped as its own milestone, separate from M14 (Live Operations, pure content authoring),
because it's a genuinely new architectural surface — the game's first outbound network dependency,
its first user-identity concept, and its first server-authoritative data store — not more content
on existing systems. It can run before, after, or in parallel with M14; the two touch disjoint
systems (content data vs. account/network plumbing), the same relationship M8/M10 had.

**Product framing, decided 2026-08-26/27:** account sign-in is **optional and opt-in**. The game
must remain fully playable, forever, with zero account and zero network dependency — this is not
a soft launch default that becomes mandatory later, it's a permanent supported path, consistent
with `AGENTS.md`'s single-player-first design and its "never forced" monetization philosophy
applied to accounts. Cloud sync is something a player turns on because they want their empire on
a second device or backed up, not something the game requires to function. Supported sign-in
methods: **email + password** and **Google Sign-In**. No magic link, no anonymous accounts, no
other OAuth providers — deliberately minimal.

Full context: `docs/02_TECH_STACK.md` (backend framing), `docs/14_SYSTEM_INVENTORY.md` §5 (Cloud
saves, Save backup/versioning — M15 extends what M10/M12 already built rather than replacing it),
`docs/15_MASTER_PLAN.md`'s M15 entry.

---

## Prerequisites (external to this repo, needed before implementation starts)

1. A Supabase project (free tier is sufficient) — its Project URL and anon/public API key.
   **The `service_role` secret key must never be provided for client embedding.** Requirement 8
   (account deletion) is the one place this milestone uses it at all, and only inside a Supabase
   Edge Function running server-side — Supabase's own Edge Function secrets store holds it, it is
   configured directly in the Supabase dashboard/CLI when that function is deployed, and it is
   never pasted into a chat, a commit, or any client-side file. Everywhere else, Row Level
   Security policies are the actual security boundary, not key secrecy on an untrusted client.
2. A Google Cloud OAuth Client ID (Web application type) with its Client Secret registered in
   Supabase's Auth → Providers → Google settings, per Supabase's own Google-provider setup guide.
3. Once `.kiro/specs/milestone-m13-ship-it/`'s Android package id (Requirement 2 there) is
   settled: that package id plus a signing certificate SHA-1 fingerprint (a debug-keystore
   fingerprint is sufficient to start development), for Google Sign-In's Android-side
   configuration.
4. Awareness that a Supabase free-tier project **pauses after 7 days with no API activity** and
   needs to be manually resumed from the dashboard (or is auto-resumed by the next request, with a
   several-second cold-start delay) — a real operational characteristic to design around (Task 1
   of the design's rollout plan), not a blocker.

---

## Requirements

### Requirement 1 — Account creation and sign-in (opt-in)

**User Story:** As a player, I want to optionally create an account and sign in, so I can sync my
empire across devices — without ever being required to.

#### Acceptance Criteria

1. `SettingsMenu` SHALL gain an "Account" section, reachable the same way every other settings
   category already is, offering Sign Up, Sign In, and (once signed in) Sign Out and Account
   status.
2. Email + password sign-up/sign-in SHALL work via Supabase Auth's REST API
   (`/auth/v1/signup`, `/auth/v1/token?grant_type=password`), called via Godot's `HTTPRequest`
   node — no third-party Godot addon/SDK, consistent with `AGENTS.md`'s "no unnecessary
   dependencies."
3. Google Sign-In SHALL work via Supabase Auth's OAuth flow (system browser handoff, deep-link
   back into the app) — see Requirement 2 for the mechanics.
4. A player who never opens the Account section, or opens it and closes it without signing in,
   SHALL experience **zero behavior change** from today's fully-local game — no network calls, no
   prompts, no nagging.
5. Sign-in state (a valid Supabase session) SHALL persist across app restarts without requiring
   the player to sign in every session, using Supabase's refresh-token flow.
6. Any network failure during sign-in/sign-up SHALL surface a clear, themed error message (reusing
   M9's framed-announcement pattern) and SHALL NOT crash, hang, or block the player from returning
   to local play.

### Requirement 2 — Google Sign-In deep-link handling on Android

**User Story:** As a player, I want to sign in with my existing Google account in one tap, so I
don't need to create and remember a new password.

#### Acceptance Criteria

1. Tapping "Sign in with Google" SHALL open Supabase's OAuth authorize URL
   (`/auth/v1/authorize?provider=google&redirect_to=<app-scheme>`) in the system browser (Godot's
   `OS.shell_open()`), not an embedded webview — required for Google's own OAuth policy and
   simpler than embedding a webview in Godot.
2. A custom URI scheme (e.g. `pirateempire://auth-callback`) SHALL be registered in the Android
   export's manifest (`export_presets.cfg`/AndroidManifest additions) so Supabase's redirect after
   a successful Google sign-in returns control to the app.
3. The app SHALL receive and parse the returned access/refresh tokens from that deep link and
   complete the same session-establishment path email/password sign-in uses (Requirement 1.5) —
   one session representation, not two.
4. **This is flagged as the highest-uncertainty item in this milestone.** Godot's deep-link/intent
   handling on Android is not a built-in, one-line feature — it typically requires either a small
   custom Android plugin (a `.aar`) or verifying whatever the current Godot Android export
   template supports natively as of this project's Godot version. Investigate and confirm the
   actual mechanism **before** committing to the OAuth flow design in `design.md`'s Requirement 2
   section being final — if it proves disproportionately complex, email + password alone (already
   required, Requirement 1) is a completely acceptable fallback for this milestone's initial
   ship, with Google Sign-In following once the Android plumbing is confirmed.

### Requirement 3 — Cloud save schema and Row Level Security

**User Story:** As a player, I want my cloud-saved empire to be readable and writable only by me,
so my progress can't be seen or tampered with by anyone else, including via Supabase's own public
API surface.

#### Acceptance Criteria

1. A `player_saves` table SHALL exist in the Supabase Postgres database: `id` (uuid, pk),
   `user_id` (uuid, references `auth.users`, not null), `save_data` (jsonb), `save_schema_version`
   (int, reusing the field M10 added to local saves), `client_updated_at` (timestamptz, set by the
   client to the moment the save was produced, distinct from Postgres's own `updated_at`), `id`
   unique per `user_id` (one save row per account — this project has no multi-slot save concept
   locally either, per `docs/14_SYSTEM_INVENTORY.md`'s "Save file" row).
2. Row Level Security SHALL be enabled on `player_saves` with policies restricting `SELECT`,
   `INSERT`, and `UPDATE` to rows where `user_id = auth.uid()`, and denying `DELETE` entirely (a
   player can overwrite their save; losing it outright is not a supported action from the client).
3. The anon/public API key alone, with **no** valid user session, SHALL NOT be able to read or
   write any row in `player_saves` — verified explicitly as part of this milestone's checkpoint,
   not assumed from the policy text.
4. `save_data`'s JSON shape SHALL exactly match `SaveManager`'s existing local save format (same
   `get_save_data()`/`load_save_data()` round-trip already used for `user://save_data.json`) — the
   cloud store is a mirror of the existing format, not a second schema to maintain.

### Requirement 4 — Sync behavior

**User Story:** As a player with an account, I want my local and cloud saves to stay in sync
without silently losing progress on either side.

#### Acceptance Criteria

1. On first sign-in on a device that already has local save data, if a cloud save **also**
   already exists for that account (e.g. signing in on a second device, or re-signing-in after
   playing locally for a while), the player SHALL be shown an explicit choice — keep local, keep
   cloud, — before either one is overwritten. **Never silently pick one.**
2. After that initial reconciliation (or immediately, if no conflict existed), ongoing sync SHALL
   push to Supabase on every local save event (extending `SaveManager.save_game()`'s existing call
   site, not a second save-triggering mechanism), best-effort and non-blocking — a network failure
   during a routine sync SHALL NOT interrupt or delay gameplay.
3. On app launch while signed in, if the cloud save's `client_updated_at` is newer than the local
   save's, the player SHALL be prompted the same way as 4.1 before the local save is overwritten
   — a background process must never silently discard local progress newer than what the player
   sees on screen.
4. A failed sync SHALL be retried (e.g. on the next successful save event, or a lightweight retry
   timer) rather than silently abandoned — but a queue of failed syncs SHALL NOT grow unbounded;
   only the latest local save state needs to eventually reach the cloud, not every intermediate
   one.
5. Signing out SHALL NOT delete the local save — the player keeps playing locally exactly as
   before signing in.

### Requirement 5 — Session security and storage

**User Story:** As a player, I want my session credentials handled responsibly, so signing in
doesn't create a new risk the local-only game never had.

#### Acceptance Criteria

1. The Supabase session refresh token SHALL be stored in `user://` (Godot's sandboxed per-app
   storage, matching where `save_data.json`/`settings.cfg` already live) — acceptable for this
   milestone's scope; a hardened secure-storage upgrade (Android Keystore-backed) is explicitly
   deferred (see Non-Goals), not silently skipped without acknowledgment.
2. The anon/public API key is the only Supabase credential embedded in the client — confirmed via
   this milestone's checkpoint that no `service_role` key or equivalent secret appears anywhere in
   the exported build or version control.
3. A sign-out SHALL invalidate/clear the locally-stored session (best-effort revocation via
   Supabase's sign-out endpoint, plus unconditional local token deletion regardless of whether the
   network call succeeds).

### Requirement 6 — Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an "M15 — Backend & Cloud Services" section.
2. `docs/14_SYSTEM_INVENTORY.md`'s "Cloud saves" row SHALL move from 🚫 to ✅ (or 🟡 with an
   honest note if Google Sign-In was deferred per Requirement 2.4's fallback).
3. `docs/02_TECH_STACK.md`'s Supabase entry SHALL move from "Future" to describing what's actually
   integrated.
4. `docs/15_MASTER_PLAN.md`'s M15 exit-criteria results SHALL be filled in.
5. A short **`docs/SUPABASE_SETUP.md`** (or equivalent) SHALL document the actual Supabase project
   configuration (table schema, RLS policies, auth provider settings) so the project isn't
   dependent on someone remembering dashboard clicks that aren't in version control — the SQL for
   the table/policies SHALL be checked in (e.g. `supabase/schema.sql`), even though this project
   has no local Supabase CLI/migration tooling set up (see Non-Goals).

---

### Requirement 7 — Password reset

**User Story:** As a player who forgot their password, I want to reset it by email, so I'm not
permanently locked out of a cloud save I can't reach any other way.

#### Acceptance Criteria

1. `SettingsMenu`'s Account section SHALL offer "Forgot password?" from the sign-in form, calling
   Supabase's `/auth/v1/recover` with the player's email.
2. The reset email's link SHALL return to the app via the same custom-URI-scheme deep-link
   mechanism Requirement 2 builds for Google Sign-In (one deep-link receipt path, not two) and
   land the player on a "set a new password" screen while a temporary recovery session is active.
3. Setting a new password SHALL call Supabase's `/auth/v1/user` (update) endpoint with the active
   recovery session's token, then establish a normal signed-in session exactly as a fresh sign-in
   would (Requirement 1.5) — no separate session type for "just reset a password."
4. A player with no email/network access at all SHALL simply be unable to use this path — cloud
   sync remains opt-in, and losing cloud-account access SHALL NEVER threaten the player's local
   save (Requirement 4.5 already guarantees this; restated here since it's the exact scenario this
   requirement exists for).

### Requirement 8 — Account deletion

**User Story:** As a player, I want to permanently delete my account and cloud data if I choose
to, both from inside the game and without needing the app installed, so I have real control over
my data — and so this project can comply with Google Play's account-deletion policy once it
supports account creation at all.

#### Acceptance Criteria

1. `SettingsMenu`'s Account section SHALL offer "Delete my account" while signed in, behind an
   explicit confirmation step (a themed confirmation dialog, not a single accidental tap).
2. Deletion SHALL be immediate and permanent — no soft-delete/undo grace period (this project's
   scale doesn't justify the added complexity of a deferred-purge system).
3. Deletion SHALL remove the player's `player_saves` row and their `auth.users` account entirely.
   Since the anon key alone cannot delete an `auth.users` row (that requires Supabase's
   service-role-gated Admin API, which must never run client-side per this spec's own Prerequisite
   1), this SHALL be implemented via a Supabase Edge Function that the client calls with the
   player's own valid session token — the Edge Function verifies the token server-side and only
   then performs the privileged deletion. This is the one place in this milestone the
   service-role key is used at all, and it is used only inside Supabase's own server-side Edge
   Function runtime, never sent to or held by the client.
4. The player's **local save SHALL be completely untouched** by account deletion — deleting a
   cloud account never deletes local progress; the player keeps playing locally exactly as if they
   had signed out (Requirement 4.5).
5. A web-accessible account-deletion path SHALL exist and be reachable without the app installed,
   per Google Play's User Data policy — a documented support-contact process (a published email
   address / contact method on the same hosted page as the privacy policy, see
   `.kiro/specs/milestone-m13-ship-it/`) is sufficient; a self-service web deletion form is
   explicitly not required at this project's scale (see Non-Goals).

### Requirement 9 — Terms acceptance and data-collection disclosure

**User Story:** As a player creating an account, I want to know what data is collected and agree
to it, so signing up is informed, not a surprise — and so this project has an accurate source of
truth for its Play Console Data Safety declaration.

#### Acceptance Criteria

1. The sign-up form (email/password and, once built, Google) SHALL show a checkbox — "I agree to
   the Terms of Service and Privacy Policy" — linking to the pages
   `.kiro/specs/milestone-m13-ship-it/` hosts, and SHALL gate the sign-up action on it being
   checked.
2. This requirement SHALL enumerate, precisely, everything M15 causes to be collected: **email
   address** (auth), **gameplay save data** (`player_saves.save_data`, the same JSON already
   stored locally). Nothing else — no device identifiers, no analytics tied to account identity
   (M12's analytics stays anonymous/device-scoped, deliberately not cross-referenced with account
   id, keeping this list short and accurate).
3. This enumeration SHALL be the literal source `.kiro/specs/milestone-m13-ship-it/`'s privacy
   policy content and Play Console Data Safety form are written against — not a second,
   independently-guessed list.

### Requirement 10 — Auth hardening (Supabase dashboard configuration)

**User Story:** As a maintainer, I want basic, low-effort account-security protections enabled,
so adding auth doesn't introduce easy, well-known abuse vectors.

#### Acceptance Criteria

1. Supabase Auth's leaked-password protection (a free, built-in check against known-compromised
   passwords at sign-up and password-change) SHALL be enabled in the project dashboard.
2. This SHALL be a dashboard-configuration task, not code — logged in `docs/SUPABASE_SETUP.md`
   (Requirement 6.5) so it's not an undocumented click nobody remembers making.

### Requirement 11 — Remote config / feature flags

**User Story:** As a maintainer, I want a small set of values the game reads from the backend at
runtime, so live content (seasonal event windows, an emergency kill-switch for broken content) can
be adjusted without an app-store resubmission.

#### Acceptance Criteria

1. A `remote_config` table SHALL exist (`key text primary key`, `value jsonb`), publicly readable
   with no per-row restriction — this is not per-user data, so it uses the same anon-key access
   pattern as any other public read, not the RLS-scoped pattern `player_saves` uses.
2. The client SHALL fetch the full table once per session (or once per some reasonable interval —
   not polled continuously) and cache it in memory.
3. Every reader of a remote-config value SHALL have a safe, sensible local default — if the fetch
   fails, hasn't completed yet, or a specific key is absent, the game SHALL behave as if remote
   config doesn't exist at all, never block or degrade gameplay waiting on it. This is the same
   "never block on network" discipline Requirement 1.4 already establishes for auth.
4. This milestone SHALL NOT define what values live in the table beyond proving the mechanism
   works end-to-end (fetch, cache, fall back) — the actual seasonal-event-window and kill-switch
   keys are `.kiro/specs/milestone-m14-live-operations/`'s content to define and consume, once
   this plumbing exists.

## Non-Goals

- Making an account mandatory — permanently ruled out per this milestone's own framing above, not
  just deferred.
- Magic-link or any OAuth provider beyond Google — deliberately minimal scope; more can be added
  later without restructuring anything this milestone builds (Supabase Auth supports arbitrary
  additional providers as pure dashboard configuration).
- Leaderboards, social features, or any player-visible-to-other-players data — `AGENTS.md`
  forbids multiplayer/social features in v1 outright; this milestone's database usage is strictly
  private per-user save storage, not a step toward that.
- Server-authoritative validation / anti-cheat (Supabase Edge Functions checking save-data
  plausibility) — a legitimate future hardening step once cloud save exists, not required for
  this milestone, and this is a single-player game where "cheating" has no competitive victim.
- Android Keystore-backed secure token storage — `user://` storage is accepted for this
  milestone (Requirement 5.1); flagged as a real, specific follow-up, not silently deferred.
- A local Supabase CLI/migration-based schema-management workflow — the schema is checked in as
  plain SQL (Requirement 6.5) and applied manually via the Supabase dashboard's SQL editor for
  this milestone; a proper migration pipeline is future tooling investment, not blocking one
  small table's worth of schema.
- iOS — Google Sign-In's Android-specific deep-link work in Requirement 2 is Android-only by
  design; `docs/02_TECH_STACK.md` already names iOS as future, not v1/this-milestone scope.
- CAPTCHA on auth endpoints (hCaptcha/Turnstile) — a real future hardening step if bot signups
  become an actual problem; not built now (Requirement 10).
- A self-service web account-deletion form/portal — the documented support-contact path
  (Requirement 8.5) satisfies Google Play's policy at this project's scale; revisit only if
  deletion request volume ever justifies the added engineering.
- Changing email address, or any other account-management action beyond password reset and
  deletion — deliberately minimal scope, consistent with this milestone's overall "no magic link,
  no anonymous accounts" minimalism.
- Per-user targeting, rollout percentages, or A/B testing in remote config (Requirement 11) — a
  flat, global key/value table is all this project's scale justifies; a targeting layer is a much
  larger system this milestone does not build.
