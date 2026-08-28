# Implementation Plan — M12 Playtest & Instrumentation

> **Re-verify scope before starting.** Confirm against the then-current
> `docs/05_CURRENT_SYSTEMS.md` that M10's `save_schema_version` field and M11's balance-model
> artifact both exist as expected — Wave 2 and Wave 5 respectively depend on them.
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```

---

## Wave 1 — Analytics and crash reporting

- [x] 1. `AnalyticsManager` autoload subscribing to existing gameplay signals; evaluate Firebase
       integration feasibility for Godot 4.7, document the decision either way.
  - _Requirements: 1.1, 1.2, 1.3_
  - _2026-08-28: JSON-lines local fallback chosen; focused GUT test passes (3/3)._ 
- [x] 2. Crash/abnormal-exit detection with an opt-in log-send prompt on next launch.
  - _Requirements: 2.1, 2.2_
  - _2026-08-28: local report bundle/prompt implemented; remote delivery needs an approved endpoint. Focused GUT test passes (2/2)._ 

## Wave 2 — Save robustness

- [x] 3. `SaveManager._migrate()` implementing the first real version transition on top of M10's
       `save_schema_version` field.
  - _Requirements: 3.1_
  - _2026-08-28: v0 island-array → v1 record migration; focused GUT test passes._ 
- [x] 4. Rotating single backup (`save_data.json.bak`) written before every overwrite; recovery
       path extending the existing `save_load_failed` signal.
  - _Requirements: 3.2, 3.3_
  - _2026-08-28: backup-before-write and backup recovery implemented; suite still required._ 

## Wave 3 — Localization infrastructure

- [x] 5. Extract inline strings to `tr()`-wrapped Godot translation entries for MainMenu, WorldHUD,
       IslandMenu, SettingsMenu, CaptainsLog; verify dynamic-string templates translate correctly
       (template wrapped, not the interpolated result).
  - _Requirements: 4.1, 4.2, 4.3_
  - _2026-08-28: all UI-chrome literals (labels, buttons, tooltips, format templates) in the 5
    named scripts wrapped in `tr()`, template-then-interpolate throughout; `translations/en.csv`
    grown from 21 to ~140 keys to match; `project.godot` given the `[internationalization]`
    section it was missing (the compiled `.translation` resource existed on disk but was never
    registered, so no `tr()` call actually resolved anything before this). `tests/test_localization.gd`
    added and passing (3/3), verifying the template-before-interpolation convention and that the
    translation resource loads. Full GUT suite: 394/394 passing, no regressions. Scope explicitly
    excludes strings sourced from `.tres` Resource data (building/tech/captain names &
    descriptions) — that's a separate, much larger content-localization effort left for a future
    milestone. Visual/on-screen confirmation of rendered translated text is not verifiable in this
    headless environment._

## Wave 4 — Playtest protocol and round

- [x] 6. Write the playtest protocol doc (recruitment, session structure, observation/logging
       template).
  - _Requirements: 5.1_
  - _2026-08-28: `docs/PLAYTEST_PROTOCOL.md` written (unnumbered, matching `docs/BALANCE_MODEL.md`'s
    precedent — the 00–21 numbered slots are already fully occupied by later milestones' own
    planning docs). Covers recruitment, build to give testers, session structure, when to
    intervene, observation focus (unassisted Chapter 1 completion per M7's flagged-but-unverified
    exit criterion), and a per-participant + round-summary logging template with an explicit
    honesty rule on participant count._
- [ ] 7. Run at least one real playtest round; log findings honestly, including the real number of
       participants reached — not asserted against the ≥10 target without evidence.
  - _Requirements: 5.2_
  - _2026-08-28: **Not run.** This genuinely cannot be executed by an AI coding agent alone — it
    requires recruiting and observing real external participants, which this session has no
    channel to do (same category of gap as M11 Task 13's human listening pass). Protocol (Task 6)
    is ready for the project owner to actually run; real participant count is 0 until then. Not
    asserted as done, per Requirement 5.2's own explicit instruction against unevidenced claims._

## Wave 5 — Balance spreadsheet completion

- [x] 8. Extend M11's balance model to cover every remaining unmodelled cost/reward in the game
       (buildings, ships, captains, loot, raid theft fractions).
  - _Requirements: 6.1, 6.2_
  - _2026-08-28: `docs/BALANCE_MODEL.md` extended with §5 buildings (uniform 3.5×/18× per-level
    curve confirmed across 4 building types), §6 ship modules (two price bands by modifier
    strength/count), §7 captains (cost ranges by unlock chapter, cross-referenced against the §1
    ship ladder), §8 raid theft fraction (the actual `EmpireManager._resolve_raid()` formula,
    previously undocumented), §9 loot tables → encounter mapping (verified each encounter's
    `ExtResource` loot_table reference resolves to the correct tier, not just an identical-looking
    local id). All numbers read directly from the real `.tres`/`.gd` files, not estimated. Ammo,
    battle upgrades, and AI profiles confirmed to have no cost/reward fields and are out of scope._

## Wave 6 — Codex / lore browser

- [x] 9. `CodexScreen` reusing `CaptainsLog`/`CaptainData`/`FactionData`'s existing data and gating
       logic — no new "have I met this" tracking mechanism.
  - _Requirements: 7.1, 7.2_
  - _2026-08-28: screen and HUD entry added; needs visual capture at checkpoint._ 

## Wave 7 — Push notifications

- [x] 10. Confirm current Godot 4.7 Android local-notification plugin support; scope Requirement
        8's "building complete" event correctly if construction turns out to be instant-on-
        purchase rather than timed (re-verify against current `Island.gd`).
  - _Requirements: 8.1_
  - _2026-08-28: Godot plugin adapter documented; building/missions have no real completion timer._ 
- [x] 11. Schedule notifications at raid-timer-start, mission-start (return time already known),
        and the build/upgrade event confirmed in Task 10 — reusing `announce_event()`'s message
        composition for body text.
  - _Requirements: 8.2_
  - _2026-08-28: **re-scoped on verified evidence, not assumed.** Read `EmpireManager.gd` and
    `FleetManager.gd` directly: raids are a stochastic per-`_process`-tick re-roll (a ~900s
    re-check cadence, not a fixed future resolution timestamp) — there is no "raid-timer-start"
    moment with a knowable delivery time to schedule against. Fleet missions
    (`FleetManager._on_economy_tick()`) are recurring/indefinite until manually recalled — no
    "return time" exists at all, contrary to this task's original premise. Building/upgrade was
    already confirmed instant in Task 10. The only real "resolves whether or not you're watching"
    event is raid resolution, already wired reactively via `EmpireManager.raid_resolved` →
    `LocalNotificationManager._on_raid_resolved()`. The actual gap found and fixed: raid wording
    was independently authored in two places (`RaidReportScreen.gd`'s full report and
    `LocalNotificationManager.get_raid_notification_body()`) — the exact "two surfaces drift out of
    sync" risk `announce_event()`'s reuse was meant to prevent, just for the real raid-outcome
    surface (`RaidReportScreen`, not `announce_event` — raids pause the game and show a full
    screen, they don't use the HUD banner). Extracted `EmpireManager.describe_raid_outcome()` as
    the single source of truth; both call sites now delegate to it. New GUT test asserts the two
    surfaces' text can't independently drift again._
- [x] 12. Platform permission flow: request appropriately, degrade silently if denied, no forced
        prompt loop.
  - _Requirements: 8.3, 8.4_
  - _2026-08-28: already substantially implemented in Task 10's `LocalNotificationManager`
    adapter — `_ensure_permission_or_plugin()` requests lazily (only at the moment a notification
    is actually needed, not eagerly at launch), persists a "requested" flag
    (`user://notification_permission_state.json`) so a denial is never re-prompted, and always
    live-checks `has_permission()` so a later OS-settings grant is picked up without needing a
    re-request. No plugin present → every call degrades to a silent no-op with zero gameplay
    impact. What was missing was test coverage for the "no forced prompt loop" acceptance
    criterion specifically — added a fake-plugin GUT test that calls `schedule_completion()` three
    times with permission denied and asserts exactly one `request_permission()` call. Device-level
    verification of the real Android permission dialog is not possible in this environment — see
    Task 14._

## Wave 8 — Documentation and checkpoint

- [x] 13. Update `docs/05_CURRENT_SYSTEMS.md`, `docs/14_SYSTEM_INVENTORY.md`,
        `docs/15_MASTER_PLAN.md` — report actual playtest numbers honestly.
  - _Requirements: 9.1, 9.2, 9.3_
  - _2026-08-28: `docs/05_CURRENT_SYSTEMS.md` gained a full "M12 — Playtest & Instrumentation"
    section (all 8 requirements, matching M11's section format) plus a refreshed test-suite count
    (396/396). `docs/14_SYSTEM_INVENTORY.md`'s M12-owned rows (Codex, localization, save backup/
    versioning, analytics, crash reporting, push notifications, balance model, playtest protocol)
    flipped from ❌ to ✅/🟡 with real detail, not just a status-symbol change. `docs/15_MASTER_PLAN.md`'s
    M12 entry got a status note. Playtest participant count reported as 0 (real, not rounded up);
    push-notification device verification reported as not done — both flagged, not asserted._
- [x] 14. **Checkpoint — M12 complete**
  - GUT suite passes with no regressions.
  - Playtest (Wave 4) and push-notification permission flow (Wave 7) explicitly logged as
    device-verified or flagged as not-yet-verifiable in this environment — do not assert either as
    passing without real evidence.
  - Independently re-verify against actual code changes and a real GUT run before marking done,
    per `docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8.
  - _2026-08-28: independently reviewed via the `checkpoint-reviewer` agent (not self-reported).
    Verdict on substance: every wave's claim spot-checked against real code/doc content (not
    tasks.md notes taken at face value) — `docs/BALANCE_MODEL.md` numbers traced to actual
    `.tres` files, the raid-wording shared-composer refactor confirmed real (both call sites
    delegate), `test_local_notification_manager.gd`'s new tests confirmed to exercise the claimed
    behavior, docs/05/14/15 confirmed actually edited. Fresh independent GUT run: 396/396 passing,
    0 regressions. M11 sanity check: wind mechanic, portrait/tribute UI, and trade-route mission
    type all confirmed intact, not reverted. Task 7 (real playtest round) and Android device
    verification confirmed genuinely NOT overclaimed as done anywhere. The reviewer additionally
    flagged that this work is uncommitted — expected, not a defect: this repo's established
    practice (per M9/M10's own doc notes) is multiple concurrent milestones sitting uncommitted in
    the shared working tree until the project owner chooses to commit; committing unprompted is
    outside this session's standing authorization. **Net verdict: implementation and verification
    pass; the two genuinely-unexecutable items (real human playtest round, Android device
    permission-dialog verification) remain honestly open, not falsely marked done.**_

## Notes

- Waves 1–3, 5, 6 are independent of each other. Wave 4 (playtest) benefits from running as early
  as practical within this milestone, since its findings may usefully inform later milestones'
  priorities — don't leave it until the very end by default.
- Wave 7 (push notifications) is the newest, least-precedented scope in this whole roadmap (added
  2026-08-26, no prior art in this codebase) — budget real investigation time for Task 10 before
  committing to an implementation approach.
