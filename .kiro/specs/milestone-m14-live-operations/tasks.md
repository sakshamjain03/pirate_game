# Implementation Plan — M14 Live Operations

> **Re-verify scope before starting.** Confirm against the then-current
> `docs/05_CURRENT_SYSTEMS.md` whether `.kiro/specs/milestone-m15-backend-cloud-services/` has
> landed — if not, Wave 5 (remote-config consumption) simply builds and ships on local fallback
> only, per Requirement 6.2; nothing else in this milestone is affected either way.
>
> **Verification command:**
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```

Waves 1–4 are independent of each other and can run in any order or in parallel if multiple tracks
are available. Wave 5 has no ordering constraint either — it degrades safely regardless of when it
lands relative to the others.

---

## Wave 1 — Seasonal event system (build before Ch8 needs it)

- [x] 1. `SeasonalEventData` resource (`design.md`'s field list) and `SeasonalEventManager`
       autoload: active-window check, per-window completion tracking, `has_ever_completed()`.
  - _Requirements: 3.1_
  - Done: `scripts/world/SeasonalEventData.gd` + `scripts/managers/SeasonalEventManager.gd`,
    registered in `project.godot` after `CampaignManager`.
- [x] 2. `get_save_data()`/`load_save_data()` round-trip for `SeasonalEventManager`'s completed-
       windows history through `SaveManager`, matching the established manager convention.
  - _Requirements: 3.1_
  - Done: also round-trips in-progress objective state and the per-event window-id guard, not
    just completed-windows history — a save loaded a year later must not let stale progress
    count toward a new window.
- [x] 3. Objective dispatch integration — read `CampaignManager`'s actual current dispatch code
       first and decide the least-duplicative extension point (`design.md`) before writing this.
  - _Requirements: 3.1_
  - Done: read the real code — 3 of 10 handlers have bespoke target-matching that doesn't reduce
    to a generic tuple without restructuring `CampaignManager` itself. Extracted the genuinely
    shared, stateless piece (`scripts/world/ObjectiveDispatch.gd`: matching + progress
    arithmetic) and had `SeasonalEventManager` listen to the same signals independently
    (design.md's non-preferred-but-permitted option), rather than risk editing
    `CampaignManager`'s 60+-test-covered handlers for a smaller code-dedup win.
- [x] 4. GUT tests using an injectable/fake "current date" (establish this pattern if absent) —
       window boundaries, repeat-completion tracking, `has_ever_completed()`.
  - Done: confirmed no such pattern existed anywhere in the codebase; established
    `SeasonalEventManager._date_override` mirroring `RemoteConfigManager._request_override`'s
    existing test-seam convention. `tests/test_seasonal_event_manager.gd`, 14 tests.

## Wave 2 — Chapters 6–10 and the content-authoring guide (validated together)

- [x] 5. Start `docs/CONTENT_AUTHORING_GUIDE.md` alongside authoring — write each schema section
       as its content is actually authored, not before or after in isolation.
  - _Requirements: 4.1_
- [x] 6. Author Ch6 (The Wandering Widow) first, as the exit-proof chapter — confirm zero script
       changes were needed to load it, the literal M7 verification method.
  - _Requirements: 1.1, 1.2_
  - Done: `resources/campaign/chapters/Ch6_TheWanderingWidow.tres`. Verified zero script changes:
    every field/Condition/gate type it uses (`required_region_id`, `DISCOVER_ISLAND`/
    `DESTROY_SHIPS`/`DOCK_AT_ISLAND`/`REACH_NOTORIETY`/`BOARD_SHIPS`) already existed pre-M14.
- [x] 7. Author Ch7 (Marguerite's Harbour), Ch10 (The Cove Without a King) — both normal one-time
       chapters, no new mechanism needed.
  - _Requirements: 1.1, 1.2_
  - Done: Ch7 reuses the existing `blackwater_shoal` island (already flagged in
    `docs/11_WORLD_MAP.md` as a hookless region-filler) rather than authoring a new one. Ch10
    reuses `skull_cove` (captured in Ch2) for a "formally claim it" arc, not a re-capture. Both
    zero script changes.
- [x] 8. Author Ch8 (The Spring Crossing) using Wave 1's `SeasonalEventData`, not `ChapterData`.
  - _Requirements: 1.1, 3.2_
  - Done: `resources/campaign/seasonal_events/SpringCrossing.tres`.
- [x] 9. Author Ch9 (An Unwelcome Ally), gated on `SeasonalEventManager.has_ever_completed(
       "spring_crossing")` per `design.md`'s resolution of the Ch8→Ch9 gate question.
  - _Requirements: 1.1, 1.2_
  - Done: `resources/campaign/chapters/Ch9_AnUnwelcomeAlly.tres`. This is the one chapter of the
    four that needed the Task 10 schema addition below.
- [x] 10. If any of Tasks 6/7/8/9 surfaced a real data-model gap, design and implement the minimal
        fix; document the finding either way (gap found and fixed, or model held up as claimed).
  - _Requirements: 1.3_
  - Found and fixed: Ch9's gate ("Spring Crossing completed at least once") is neither a
    prior-chapter completion nor a region threshold — `ChapterData`'s two existing gate fields
    couldn't express it. Added one generic field, `required_seasonal_event_id`, checked in
    `CampaignManager._gate_satisfied()` — reusable by any future chapter, not a special case for
    Ch9. Ch6/7/8/10 surfaced no gap; their existing-schema claim holds.
- [x] 11. Finish `docs/CONTENT_AUTHORING_GUIDE.md`; confirm whoever authored Tasks 6–9 used only
        the documented process and fix any point where it was wrong or incomplete.
  - _Requirements: 4.1, 4.2_
  - Done: guide covers `ChapterData`/`ObjectiveData`/`DialogueBeatData`, `SeasonalEventData`,
    `RegionData`/`IslandData`, each with a real annotated `.tres` snippet beside the script's
    actual `@export` list, plus the full region/island authoring checklist Wave 3 followed.

## Wave 3 — Regions 4/5

- [x] 12. Author `RegionData` for Region 4 (Ancient Ocean, tier 4, threshold 300) and Region 5
        (Ghost Reaches, tier 5, threshold 500), using `EmpireManager`'s existing activation model.
  - _Requirements: 2.1_
  - Done: `resources/world/regions/AncientOcean.tres` (dominant faction `pirate_clans`, reused
    rather than inventing one) + `GhostReaches.tres` (dominant faction `ghost_fleet`, already
    existed). No changes to `EmpireManager`.
- [x] 13. Author at least one island per region with `world_position`/`region_id`/`IslandType`/
        faction ownership.
  - _Requirements: 2.2_
  - Done: `widows_reach` (Ancient Ocean, `LEGENDARY` — the first real use of that pre-existing,
    previously-unused `IslandType` enum value) and `fogbound_cay` (Ghost Reaches, `ENEMY`, owned
    by `GhostFaction`). Both instanced in `World.tscn`.
- [x] 14. Give the Ghost Fleet real mechanical presence in Region 5 (real ships/combat/boarding)
        per `design.md`'s "mechanically real, supernaturally still ambiguous" resolution — not
        flavor text alone.
  - _Requirements: 2.3_
  - Done: two regular Ghost Fleet hulls in `GhostReaches.enemy_ship_pool` (everyday ambient
    combat/boarding, not just a rare event) plus a new dedicated boss ("The Wandering Widow"),
    alongside — not replacing — the pre-existing rare global `ghost_ship_boss` ambient event.
    Required a small, precedent-following extension: `EncounterData.required_region_id`
    (mirrors `required_chapter_id`), since a region isn't a chapter and the existing gate
    couldn't express "only once Ghost Reaches is active."
- [ ] 15. Fresh headful `CaptureHarness` review of both regions' terrain/content — visual/content
        work needs a human look, same discipline as every milestone since M9.
  - **Not done — flagged, not silently skipped.** This environment has no display; a human needs
    to run this pass.

## Wave 4 — What's New panel

- [x] 16. `WhatsNewScreen` following `CaptainsLog`'s exact pattern; patch-notes data resource.
  - _Requirements: 5.1, 5.3_
  - Done: `scripts/ui/WhatsNewScreen.gd`/`scenes/ui/WhatsNewScreen.tscn` (structurally identical
    to `CaptainsLog`), `scripts/world/PatchNotesData.gd` (a single append-only resource, per
    design.md's own "less new schema" preference over one `.tres` per release).
- [x] 17. One-time auto-show on first launch after a content-adding update, reusing the M5
        "while you were away" one-time-notice pattern.
  - _Requirements: 5.2_
  - Done: `SaveManager.last_seen_whats_new_version` + `World._seed_whats_new_version()` (new-game
    guard) + `WorldHUD._check_whats_new()` — connected only to `SaveManager.game_loaded`,
    deliberately without `_check_offline_return()`'s extra immediate call (a version-string
    comparison has no safe pre-load default, unlike the offline-ticks counter's safe zero).
- [x] 18. Author patch notes for this milestone's own content (Chapters 6–10, Regions 4/5, Spring
        Crossing) as the first real entries.
  - Done: `resources/ui/PatchNotes.tres`, one entry ("1.14.0").

## Wave 5 — Remote-config consumption (soft dependency on M15 — see header note)

- [x] 19. `LiveOpsConfig` wrapper: `get_seasonal_window()`, `is_content_enabled()`, both with a
        local-fallback path that requires no M15 presence at all.
  - _Requirements: 6.1, 6.2_
  - Done: `scripts/managers/LiveOpsConfig.gd`, new autoload registered after
    `SeasonalEventManager`. Simpler than design.md's own pseudocode anticipated — M15 had
    already landed for real by the time this milestone started, so "M15 not installed" collapses
    to "the key isn't set," which `RemoteConfigManager.get_value()`'s own default already
    handles; no `Engine.has_singleton()`-style presence check needed.
- [x] 20. Wire Wave 1's `SeasonalEventManager` to read the window through `LiveOpsConfig` instead
        of its own authored fallback directly (the fallback becomes `LiveOpsConfig`'s local-path
        answer, not a separate code path `SeasonalEventManager` maintains itself).
  - _Requirements: 6.1_
  - Done: `SeasonalEventManager.is_active()` now calls `LiveOpsConfig.get_seasonal_window()`/
    `is_content_enabled()` instead of reading its own fields directly.
- [x] 21. Confirm Wave 2's newly-added ambient content (if any) and Wave 1's seasonal event both
        check `is_content_enabled()` before starting.
  - _Requirements: 6.1_
  - Done: one shared check point, `EncounterManager._start_random_ambient()`'s candidate filter,
    covers every ambient encounter including the new Ghost Fleet boss; `SeasonalEventManager.
    is_active()` covers the Spring Crossing. Both proven by `tests/test_live_ops_config.gd`.
- [~] 22. **If M15 has landed:** configure the real Spring Crossing window in `remote_config`;
        confirm removing that key falls back to the authored local window correctly (proving
        Requirement 6.3's degradation is real). **If M15 hasn't landed:** confirm the whole
        milestone still works correctly with `LiveOpsConfig` always taking its local-fallback
        path — this is not a skipped task, it's this task's actual pass condition in that case.
  - _Requirements: 6.2, 6.3_
  - **Partially done, honestly recorded.** M15 has landed, so the "configure the real key"
    branch applies. The code path is fully proven (`tests/test_live_ops_config.gd`: a faked
    `RemoteConfigManager` cache shows the remote value winning, and removing it reverting to the
    authored fallback — the same method M15 itself used to verify `RemoteConfigManager`). Actually
    setting the real key in the live Supabase project (`tuhkhsqcnnszjnczkuzq`) requires a
    Supabase MCP server this environment did not have configured at milestone start; one was
    added mid-milestone but needs a session reconnect to become usable. Not yet done as of this
    checkpoint — see `docs/05_CURRENT_SYSTEMS.md`'s M14 section for the exact status and the key/
    value to set (`seasonal_window_spring_crossing` → `{"start": "03-01", "end": "05-31"}`).

## Wave 6 — Documentation and checkpoint

- [x] 23. Update `docs/05_CURRENT_SYSTEMS.md` (new "M14 — Live Operations" section),
        `docs/14_SYSTEM_INVENTORY.md` (content-volume table), `docs/11_WORLD_MAP.md` (Region 4/5
        entries), `docs/15_MASTER_PLAN.md` (M14 exit criteria, including remote-config status).
  - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - Done, plus new `docs/CONTENT_AUTHORING_GUIDE.md` (Requirement 4).
- [x] 24. **Checkpoint — M14 complete**
  - GUT suite passes with no regressions: 419/419 baseline (re-verified fresh at the start of
    this milestone) → **464/464**, 0 failures.
  - Fresh headful capture review: **not done** — no display in this environment; flagged for a
    human pass, not silently skipped.
  - Ch6's zero-script-change claim re-confirmed against the actual final `git status`/diff, not
    just remembered from authoring — holds (Ch6/7/10 needed zero; Ch9's one field addition is the
    documented Task 10 exception, not a Ch6 regression).
  - Independently re-verified via the `checkpoint-reviewer` agent per
    `docs/07_AI_AGENT_WORKFLOW.md` Rules 3/4/8, not self-certified in the implementing session.

## Notes

- This milestone has no hard dependency on `.kiro/specs/milestone-m15-backend-cloud-services/` —
  only Wave 5 references it at all, and Wave 5 is explicitly designed to succeed either way
  (Task 22's two pass conditions). Don't let M15's status block starting any other wave.
- Wave 1 must land before Wave 2's Task 8 (Ch8 authoring) — the only real cross-wave ordering
  constraint in this milestone.
