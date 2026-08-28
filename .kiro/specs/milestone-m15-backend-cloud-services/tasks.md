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

- [ ] 1. Apply `supabase/schema.sql` (Requirement 3 `player_saves`, Requirement 11
       `remote_config`) via the Supabase dashboard's SQL editor against the real project; confirm
       both tables and `player_saves`'s RLS policies exist as written.
  - _Requirements: 3.1, 3.2, 11.1_
- [ ] 2. Manually verify RLS actually blocks an unauthenticated request (anon key only, no/invalid
       bearer token) against `player_saves`, using a raw `curl`/HTTP client — before any Godot
       code exists to hide a misconfiguration. Separately confirm `remote_config` **is** readable
       with just the anon key (it's meant to be public).
  - _Requirements: 3.3, 11.1_
- [ ] 3. Enable leaked-password protection in Supabase Auth settings (dashboard toggle, no code).
  - _Requirements: 10.1_
- [ ] 4. Deploy the `delete-account` Edge Function (`design.md`'s Requirement 8 section) with the
       `service_role` key held only in Supabase's own function secrets store; confirm it's
       reachable and rejects requests with no/invalid Authorization header before any client code
       calls it.
  - _Requirements: 8.3_
- [ ] 5. Check in `supabase/schema.sql` and the Edge Function's source to the repo (the function's
       source code is not a secret — only its configured `service_role` secret is, and that never
       leaves Supabase's own secret store).
  - _Requirements: 6.5_

## Wave 2 — `AuthManager`, email/password sign-in, terms acceptance, password-reset trigger

- [ ] 6. New `AuthManager` autoload: session state, `sign_up()`/`sign_in()`/`sign_out()` against
       Supabase's GoTrue REST endpoints via `HTTPRequest`, session persistence to
       `user://auth_session.json` (refresh token only, per Requirement 5.1).
  - _Requirements: 1.2, 1.5, 5.1, 5.3_
- [ ] 7. Token-refresh-on-401 handling; graceful expiry (clear session, no forced re-auth
       interruption to active gameplay).
  - _Requirements: 1.6_
- [ ] 8. `request_password_reset(email)` — plain HTTP trigger, no deep-link dependency (see
       `design.md`'s Requirement 7 fallback note).
  - _Requirements: 7.1_
- [ ] 9. `SettingsMenu` Account section: Sign Up / Sign In (email + password) / Sign Out / status
       display, themed consistent with every other settings category. Sign-up form includes the
       Requirement 9 terms checkbox (linking to pages Wave 5 of
       `.kiro/specs/milestone-m13-ship-it/` hosts) gating the submit action, and a "Forgot
       password?" link triggering Task 8.
  - _Requirements: 1.1, 1.4, 9.1_
- [ ] 10. GUT tests for `AuthManager`'s state transitions and session persistence, using the
        simplest viable HTTP-layer fake (establish the pattern; this project has none yet).
- [ ] 11. Confirm a player who never opens Account experiences zero behavior/network change from
        today's build — explicit regression check, not an assumption.
  - _Requirements: 1.4_

## Wave 3 — Cloud save sync (email/password path complete end-to-end before Google Sign-In)

- [ ] 12. Extend `SaveManager.save_game()`/`load_game()` with cloud sync calls gated on
        `AuthManager.is_signed_in()`, per `design.md`'s upsert pattern — best-effort, non-blocking,
        bounded retry (Requirement 4.4).
  - _Requirements: 3.4, 4.2, 4.4_
- [ ] 13. First-sign-in conflict detection and the keep-local/keep-cloud prompt UI (Requirement
        4.1), reusing `PirateThemeBuilder`'s panel style.
  - _Requirements: 4.1_
- [ ] 14. Launch-time newer-cloud-save prompt (Requirement 4.3) using the same UI as Task 13.
  - _Requirements: 4.3_
- [ ] 15. Confirm sign-out preserves the local save untouched (Requirement 4.5).
  - _Requirements: 4.5_
- [ ] 16. GUT tests for `SaveManager`'s sync-trigger logic (calls sync exactly when signed in,
        skips cleanly when not; retry-on-next-save behavior).
- [ ] 17. **Checkpoint — email/password cloud save complete and device/project-verified**
  - GUT suite passes with no regressions.
  - Real end-to-end test against the real Supabase project: sign up (with terms checkbox), play,
    sign out, sign back in on a fresh local save, confirm the cloud save is offered and restores
    correctly.
  - RLS re-confirmed to block cross-account access (create two test accounts, confirm neither can
    read the other's `player_saves` row).

## Wave 4 — Deep-link infrastructure: Google Sign-In + seamless password-reset return

- [ ] 18. Investigate the actual Android deep-link mechanism available in this project's Godot/
        export-template version (per `design.md`'s Requirement 2 section) **before** writing any
        OAuth code. Report findings; confirm or revise the design before proceeding. This single
        investigation covers both Google Sign-In and password-reset's seamless-return path — do
        it once, not twice.
  - _Requirements: 2.4_
- [ ] 19. Custom URI scheme registration in the Android export manifest.
  - _Requirements: 2.2_
- [ ] 20. `OS.shell_open()` launch of Supabase's Google OAuth authorize URL; "Sign in with Google"
        button in Wave 2's Account section.
  - _Requirements: 2.1_
- [ ] 21. Deep-link receipt and payload parsing (branching on OAuth-token-pair vs. recovery-session
        shape), feeding into `AuthManager`'s existing session-establishment path from Wave 2 — one
        receipt handler, two payload shapes, not two handlers.
  - _Requirements: 2.3, 7.2, 7.3_
- [ ] 22. **Checkpoint — deep-link features complete and device-verified, OR explicitly deferred**
  - If Task 18 found the Android plumbing disproportionately complex for this milestone: stop
    here, document the finding. Google Sign-In has no fallback and is logged as a deferred
    follow-up (Requirement 2.4). Password reset is **not** blocked either way — Task 8's trigger
    already works standalone, and its browser-completes/app-signs-in-normally fallback
    (`design.md`) is confirmed working even without this wave's deep-link plumbing.
  - If completed: real end-to-end device test for both — Google Sign-In lands back in the app
    signed in with no manual URL pasting; a password-reset email's link also returns to the app
    and completes the flow without the browser-only fallback being needed.

## Wave 5 — Account deletion

- [ ] 23. `AuthManager.delete_account()` calling the Wave 1 Edge Function with the current session
        token; on success, clear the local session the same way sign-out does.
  - _Requirements: 8.3, 5.1_
- [ ] 24. "Delete my account" in the Account section, behind a themed confirmation dialog
        (reusing Wave 3's conflict-prompt panel pattern).
  - _Requirements: 8.1, 8.2_
- [ ] 25. Confirm local save is completely untouched by account deletion — explicit regression
        check.
  - _Requirements: 8.4_
- [ ] 26. Real end-to-end test: delete a disposable test account, confirm via the Supabase
        dashboard directly (not just a 200 response) that both `player_saves` and `auth.users`
        rows are actually gone, and that a second call with the same now-invalid token is
        rejected.
  - _Requirements: 8.3_

## Wave 6 — Remote config

- [ ] 27. `RemoteConfigManager` autoload: fetch-once-per-session, in-memory cache,
        `get_value(key, default)` that never blocks and never errors on a missing key
        (`design.md`).
  - _Requirements: 11.2, 11.3_
- [ ] 28. GUT test simulating a fetch failure (wrong URL / network disabled) and confirming
        `get_value()` still returns the caller's supplied default.
  - _Requirements: 11.3_
- [ ] 29. Confirm this milestone deploys no actual config keys beyond what's needed to prove the
        mechanism (a throwaway test key is fine) — real keys are
        `.kiro/specs/milestone-m14-live-operations/`'s content to define.
  - _Requirements: 11.4_

## Wave 7 — Documentation and final checkpoint

- [ ] 30. Update `docs/05_CURRENT_SYSTEMS.md` (new "M15 — Backend & Cloud Services" section),
        `docs/14_SYSTEM_INVENTORY.md` (Cloud saves, password reset, account deletion, remote
        config rows), `docs/02_TECH_STACK.md` (Supabase entry), `docs/15_MASTER_PLAN.md` (M15
        exit criteria) — report Google Sign-In's actual status (shipped or deferred) honestly.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_
- [ ] 31. Write `docs/SUPABASE_SETUP.md` documenting the real project configuration (tables, RLS
        policies, auth provider settings, the leaked-password toggle, the deployed Edge Function)
        so it isn't dependent on undocumented dashboard clicks.
  - _Requirements: 6.5, 10.2_
- [ ] 32. **Checkpoint — M15 complete**
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
