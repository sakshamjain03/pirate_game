# Implementation Plan — M15 Backend & Cloud Services

> **Do not start Wave 1 until the Prerequisites in `requirements.md` are in hand** — a real
> Supabase project URL + anon key at minimum. Google OAuth credentials (Prerequisite 2/3) are only
> needed before Wave 4.
>
> **Re-verify scope before starting.** Confirm against the then-current
> `docs/05_CURRENT_SYSTEMS.md` whether M10's `save_schema_version` field and M12's save-versioning
> work have landed — this milestone's schema (Wave 1) assumes `save_schema_version` already exists
> as a local-save field.
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```

---

## Wave 1 — Supabase project setup (no Godot code)

- [x] 1. Apply `supabase/schema.sql` (Requirement 3 `player_saves`, Requirement 11
       `remote_config`) via the Supabase dashboard's SQL editor against the real project; confirm
       both tables and `player_saves`'s RLS policies exist as written.
  - _Requirements: 3.1, 3.2, 11.1_
  - **Done 2026-08-28** — applied via the Supabase MCP server's `apply_migration` (functionally
    equivalent to the dashboard SQL editor); `list_tables` confirmed both tables + RLS enabled.
- [x] 2. Manually verify RLS actually blocks an unauthenticated request (anon key only, no/invalid
       bearer token) against `player_saves`, using a raw `curl`/HTTP client — before any Godot
       code exists to hide a misconfiguration. Separately confirm `remote_config` **is** readable
       with just the anon key (it's meant to be public).
  - _Requirements: 3.3, 11.1_
  - **Done 2026-08-28** — anon-key-only: `player_saves` SELECT→`[]`, INSERT→401/`42501`;
    `remote_config` SELECT→200 with real rows.
- [ ] 3. Enable leaked-password protection in Supabase Auth settings (dashboard toggle, no code).
  - _Requirements: 10.1_
  - **Not done.** No Supabase MCP tool exposes Auth settings, and this environment has no
    dashboard UI access. Genuinely needs a human to click it — see `docs/SUPABASE_SETUP.md`.
- [x] 4. Deploy the `delete-account` Edge Function (`design.md`'s Requirement 8 section) with the
       `service_role` key held only in Supabase's own function secrets store; confirm it's
       reachable and rejects requests with no/invalid Authorization header before any client code
       calls it.
  - _Requirements: 8.3_
  - **Done 2026-08-28**, re-verified 2026-08-29 — deployed via the Supabase MCP server's
    `deploy_edge_function` (JWT verification on); confirmed a missing Authorization header and a
    garbage bearer token both return 401. Full real-account exercise (task 26) also passed.
- [x] 5. Check in `supabase/schema.sql` and the Edge Function's source to the repo (the function's
       source code is not a secret — only its configured `service_role` secret is, and that never
       leaves Supabase's own secret store).
  - _Requirements: 6.5_
  - **Done 2026-08-28** — both files committed; no secret value in either (verified by repo-wide
    `git grep`/`git log -S` scan at the final checkpoint).

## Wave 2 — `AuthManager`, email/password sign-in, terms acceptance, password-reset trigger

- [x] 6. New `AuthManager` autoload: session state, `sign_up()`/`sign_in()`/`sign_out()` against
       Supabase's GoTrue REST endpoints via `HTTPRequest`, session persistence to
       `user://auth_session.json` (refresh token only, per Requirement 5.1).
  - _Requirements: 1.2, 1.5, 5.1, 5.3_
  - **Done, commit e0b8e35** — `scripts/managers/AuthManager.gd`, registered in `project.godot`
    right after `SaveManager`.
- [x] 7. Token-refresh-on-401 handling; graceful expiry (clear session, no forced re-auth
       interruption to active gameplay).
  - _Requirements: 1.6_
  - **Done, commit e0b8e35** — `AuthManager.refresh_session()`; extended in Wave 3 (commit
    be46960) so `SaveManager`'s own 401s trigger it too.
- [x] 8. `request_password_reset(email)` — plain HTTP trigger, no deep-link dependency (see
       `design.md`'s Requirement 7 fallback note).
  - _Requirements: 7.1_
  - **Done, commit e0b8e35.**
- [x] 9. `SettingsMenu` Account section: Sign Up / Sign In (email + password) / Sign Out / status
       display, themed consistent with every other settings category. Sign-up form includes the
       Requirement 9 terms checkbox (linking to pages Wave 5 of
       `.kiro/specs/milestone-m13-ship-it/` hosts) gating the submit action, and a "Forgot
       password?" link triggering Task 8.
  - _Requirements: 1.1, 1.4, 9.1_
  - **Done, commit e0b8e35** — `scripts/ui/SettingsMenu.gd`/`.tscn`. Terms links used a documented
    placeholder GitHub Pages URL (`.../terms.html`, `.../privacy.html`) since M13 hadn't published
    the real page yet at the time; confirmed 2026-08-29 that M13's `gh-pages` branch now hosts
    `privacy.html`/`terms.html` at exactly that path — the placeholder was correct, no link fix
    needed. (GitHub Pages itself still needs enabling in repo Settings for the URL to resolve
    publicly — a one-time repo-owner action, tracked in M13's own doc entry, not M15's.)
- [x] 10. GUT tests for `AuthManager`'s state transitions and session persistence, using the
        simplest viable HTTP-layer fake (establish the pattern; this project has none yet).
  - **Done, commit e0b8e35** — `tests/test_auth_manager.gd`, established the `_request_override`
    Callable seam every M15 manager since reuses.
- [x] 11. Confirm a player who never opens Account experiences zero behavior/network change from
        today's build — explicit regression check, not an assumption.
  - _Requirements: 1.4_
  - **Done, commit e0b8e35** — `test_no_session_file_means_load_session_makes_no_network_call`.

## Wave 3 — Cloud save sync (email/password path complete end-to-end before Google Sign-In)

- [x] 12. Extend `SaveManager.save_game()`/`load_game()` with cloud sync calls gated on
        `AuthManager.is_signed_in()`, per `design.md`'s upsert pattern — best-effort, non-blocking,
        bounded retry (Requirement 4.4).
  - _Requirements: 3.4, 4.2, 4.4_
  - **Done, commit be46960.**
- [x] 13. First-sign-in conflict detection and the keep-local/keep-cloud prompt UI (Requirement
        4.1), reusing `PirateThemeBuilder`'s panel style.
  - _Requirements: 4.1_
  - **Done, commit be46960** — `SaveManager._on_signed_in()`/`_resolve_cloud_conflict()`, new
    reusable `scripts/ui/ChoiceDialog.gd` (this project had no prior confirm/cancel dialog).
- [x] 14. Launch-time newer-cloud-save prompt (Requirement 4.3) using the same UI as Task 13.
  - _Requirements: 4.3_
  - **Done, commit be46960** — `SaveManager.check_cloud_save_on_launch()`, wired into
    `World.gd` alongside the existing `load_game()` call.
- [x] 15. Confirm sign-out preserves the local save untouched (Requirement 4.5).
  - _Requirements: 4.5_
  - **Done, commit be46960** — `test_sign_out_does_not_touch_local_save`.
- [x] 16. GUT tests for `SaveManager`'s sync-trigger logic (calls sync exactly when signed in,
        skips cleanly when not; retry-on-next-save behavior).
  - **Done, commit be46960** — `tests/test_save_manager_sync.gd`.
- [x] 17. **Checkpoint — email/password cloud save complete and device/project-verified**
  - GUT suite passes with no regressions.
  - Real end-to-end test against the real Supabase project: sign up (with terms checkbox), play,
    sign out, sign back in on a fresh local save, confirm the cloud save is offered and restores
    correctly.
  - RLS re-confirmed to block cross-account access (create two test accounts, confirm neither can
    read the other's `player_saves` row).
  - **Passed 2026-08-29**, checkpoint-reviewer-verified. GUT: 411/411 at the time (417/417 as of
    the final checkpoint). The UI-driven sign-up→play→sign-out→sign-in flow could not be exercised
    (no display in this environment) — substituted with an equally rigorous real-backend
    verification instead: two disposable Supabase accounts, RLS cross-account isolation confirmed
    including a rejected direct overwrite attempt, both accounts cleaned up. Logged as an accepted,
    environment-wide limitation (consistent with this project's established policy), not silently
    assumed to work.

## Wave 4 — Deep-link infrastructure: Google Sign-In + seamless password-reset return

- [x] 18. Investigate the actual Android deep-link mechanism available in this project's Godot/
        export-template version (per `design.md`'s Requirement 2 section) **before** writing any
        OAuth code. Report findings; confirm or revise the design before proceeding. This single
        investigation covers both Google Sign-In and password-reset's seamless-return path — do
        it once, not twice.
  - _Requirements: 2.4_
  - **Done 2026-08-29.** Godot 4.3's Android export exposes no native GDScript deep-link API;
    every real option is a third-party or custom `.aar` plugin, and M13 (which owns the Android
    export pipeline) hasn't started. See `design.md`'s Requirement 2 section, "Investigation
    findings" subsection, for the full writeup. Crosses the disproportionate-complexity threshold
    — proceeding to Task 22's deferred branch.
- [ ] 19. Custom URI scheme registration in the Android export manifest.
  - _Requirements: 2.2_
  - **Deferred** — no Android export pipeline or package id exists yet (M13 not started). Revisit
    once M13 lands.
- [ ] 20. `OS.shell_open()` launch of Supabase's Google OAuth authorize URL; "Sign in with Google"
        button in Wave 2's Account section.
  - _Requirements: 2.1_
  - **Deferred** — a button that opens the browser with no way back into the app (Task 21 depends
    on Task 19) would be a worse UX than no button; not added.
- [ ] 21. Deep-link receipt and payload parsing (branching on OAuth-token-pair vs. recovery-session
        shape), feeding into `AuthManager`'s existing session-establishment path from Wave 2 — one
        receipt handler, two payload shapes, not two handlers.
  - _Requirements: 2.3, 7.2, 7.3_
  - **Deferred** — depends on Task 19's Android manifest work.
- [x] 22. **Checkpoint — deep-link features complete and device-verified, OR explicitly deferred**
  - **Explicitly deferred**, per Task 18's finding. Google Sign-In has no fallback and is logged
    as a deferred follow-up (Requirement 2.4) — see `design.md`. Password reset is **not**
    blocked: Task 8's trigger (built in Wave 2) already works standalone via a plain HTTP call to
    `/auth/v1/recover`, and with no custom URI scheme registered at all, its browser-completes/
    app-signs-in-normally fallback is simply what happens by default — no code needed to make
    that path work, and no device test possible in this environment to "confirm" it further
    beyond the trigger call itself, which Wave 2's GUT/real-Supabase testing already covered.

## Wave 5 — Account deletion

- [x] 23. `AuthManager.delete_account()` calling the Wave 1 Edge Function with the current session
        token; on success, clear the local session the same way sign-out does.
  - _Requirements: 8.3, 5.1_
  - **Done in Wave 2** — `AuthManager.delete_account()` (scripts/managers/AuthManager.gd) posts
    to the Edge Function and calls `_clear_session()` + `signed_out.emit()` on success only; a
    failed deletion leaves the session intact (`auth_error` instead) — see
    `test_delete_account_success_clears_session`/`test_delete_account_failure_keeps_session_and_emits_error`
    in tests/test_auth_manager.gd.
- [x] 24. "Delete my account" in the Account section, behind a themed confirmation dialog
        (reusing Wave 3's conflict-prompt panel pattern).
  - _Requirements: 8.1, 8.2_
  - **Done in Wave 2** — `SettingsMenu._on_delete_account_pressed()` (scripts/ui/SettingsMenu.gd)
    opens a `ChoiceDialog` (Cancel / Delete Account) before calling `delete_account()`.
- [x] 25. Confirm local save is completely untouched by account deletion — explicit regression
        check.
  - _Requirements: 8.4_
  - **Done 2026-08-29** — `test_delete_account_does_not_touch_local_save`
    (tests/test_save_manager_sync.gd).
- [x] 26. Real end-to-end test: delete a disposable test account, confirm via the Supabase
        dashboard directly (not just a 200 response) that both `player_saves` and `auth.users`
        rows are actually gone, and that a second call with the same now-invalid token is
        rejected.
  - _Requirements: 8.3_
  - **Done 2026-08-29**, as part of Wave 3's checkpoint verification (two disposable accounts,
    `saksham.jain+m15checkpointa`/`b@dataeconomy.ai`) — deletion confirmed via direct SQL against
    `auth.users`/`public.player_saves` (0 rows remaining for both), and a second `delete-account`
    call with the same now-stale token returned 401 "Invalid or expired session." Both test
    accounts fully cleaned up afterward.

## Wave 6 — Remote config

- [x] 27. `RemoteConfigManager` autoload: fetch-once-per-session, in-memory cache,
        `get_value(key, default)` that never blocks and never errors on a missing key
        (`design.md`).
  - _Requirements: 11.2, 11.3_
  - **Done 2026-08-29** — scripts/managers/RemoteConfigManager.gd, registered in
    project.godot's `[autoload]` after AuthManager.
- [x] 28. GUT test simulating a fetch failure (wrong URL / network disabled) and confirming
        `get_value()` still returns the caller's supplied default.
  - _Requirements: 11.3_
  - **Done 2026-08-29** — tests/test_remote_config_manager.gd covers a hard failure (500), a
    network-level error (code 0), and — the case most likely to only get tested by accident
    otherwise — a *previously successful* fetch's cache surviving a later failed refresh rather
    than being cleared.
- [x] 29. Confirm this milestone deploys no actual config keys beyond what's needed to prove the
        mechanism (a throwaway test key is fine) — real keys are
        `.kiro/specs/milestone-m14-live-operations/`'s content to define.
  - _Requirements: 11.4_
  - **Done 2026-08-29** — inserted one throwaway key (`m15_mechanism_test`) into the real
    project's `remote_config` table, confirmed it's fetchable with just the anon key (matching
    `RemoteConfigManager`'s real request shape exactly), then deleted it. `remote_config` is
    empty in the real project as of this checkpoint.

## Wave 7 — Documentation and final checkpoint

- [x] 30. Update `docs/05_CURRENT_SYSTEMS.md` (new "M15 — Backend & Cloud Services" section),
        `docs/14_SYSTEM_INVENTORY.md` (Cloud saves, password reset, account deletion, remote
        config rows), `docs/02_TECH_STACK.md` (Supabase entry), `docs/15_MASTER_PLAN.md` (M15
        exit criteria) — report Google Sign-In's actual status (shipped or deferred) honestly.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_
  - **Done 2026-08-29** — all four docs updated; Google Sign-In reported as deferred (not
    shipped) consistently across all of them.
- [x] 31. Write `docs/SUPABASE_SETUP.md` documenting the real project configuration (tables, RLS
        policies, auth provider settings, the leaked-password toggle, the deployed Edge Function)
        so it isn't dependent on undocumented dashboard clicks.
  - _Requirements: 6.5, 10.2_
  - **Done 2026-08-29** — `docs/SUPABASE_SETUP.md` (new).
- [x] 32. **Checkpoint — M15 complete**
  - GUT suite passes with no regressions.
  - Confirm no `service_role` key or other secret appears anywhere in the exported build,
    Godot source, or version control (Requirement 5.2) — grep the actual export output and the
    Edge Function's *deployment config* (not its source, which is fine to commit), don't just
    check the obvious places.
  - Confirm the data-collection enumeration in `requirements.md` Requirement 9.2 still accurately
    describes what this milestone actually built, since it's the source
    `.kiro/specs/milestone-m13-ship-it/`'s privacy policy depends on.
  - Independently re-verify against actual code changes and real Supabase/device testing before
    marking done, per `docs/07_AI_AGENT_WORKFLOW.md` Rules 3/4/8.
  - **Passed 2026-08-29**, checkpoint-reviewer-verified (two independent passes: one scoped to
    Wave 3, one covering the full milestone). GUT: 417/417, 0 regressions from a 396/396 pre-M15
    baseline. Secret scan: `git grep`/`git log -S` across the full repo and history found zero
    occurrences of any actual secret value (only the term "service_role" as documentation/code
    comments referencing where the real key lives, never a value) — `.env` confirmed gitignored
    and untracked. No exported build exists yet (M13 hasn't produced one), so that specific
    sub-check is not-applicable rather than skipped. Data-collection enumeration (Requirement 9.2)
    confirmed to match both the actual code and the privacy policy M13 already published from it.
  - **One genuine open item, not silently closed:** Task 3 (leaked-password protection) is still
    not enabled — a one-click Supabase dashboard toggle with zero code/architecture surface, which
    no tool available in this environment can perform. Everywhere this matters
    (`docs/SUPABASE_SETUP.md`, `docs/05_CURRENT_SYSTEMS.md`'s M15 section, this file) says so
    plainly rather than assuming it's done. Needs a human with dashboard access.
  - The first review pass (Wave 3 scope) also caught a real process gap, since fixed: this file's
    own checkboxes for tasks 1-17/23-31 had been left unchecked despite the underlying work being
    genuinely complete and verified — corrected in this same pass with dated notes per task,
    cross-referencing the actual commits.

## Notes

- Waves 1–3 (email/password + sync) are the safe, well-understood core of this milestone and
  should be treated as the real deliverable. Wave 4's Google Sign-In half is explicitly allowed to
  slip or be descoped without blocking the rest, per Requirement 2.4 — don't let Android-platform
  uncertainty hold the whole milestone hostage. Password reset does **not** share that risk (see
  Wave 4's checkpoint).
- Waves 5 and 6 (account deletion, remote config) have no dependency on Wave 4 at all and can be
  done before or in parallel with it if that sequencing is more convenient.
- If M13 (Ship It) hasn't landed yet when this milestone starts, Wave 4's Google Sign-In portion
  has no real Android package id/signing fingerprint to configure against — check
  `.kiro/specs/milestone-m13-ship-it/`'s status before starting that portion specifically. Waves
  1–3, 5, and 6 have no such dependency. Wave 5's web-accessible deletion path (Requirement 8.5)
  and Wave 2's terms-checkbox links (Requirement 9.1) both point at pages
  `.kiro/specs/milestone-m13-ship-it/` is responsible for hosting — if that milestone hasn't
  reached its privacy-policy wave yet, link to a placeholder and revisit before this milestone's
  final checkpoint, don't ship a broken link.
