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

- [ ] 1. `SeasonalEventData` resource (`design.md`'s field list) and `SeasonalEventManager`
       autoload: active-window check, per-window completion tracking, `has_ever_completed()`.
  - _Requirements: 3.1_
- [ ] 2. `get_save_data()`/`load_save_data()` round-trip for `SeasonalEventManager`'s completed-
       windows history through `SaveManager`, matching the established manager convention.
  - _Requirements: 3.1_
- [ ] 3. Objective dispatch integration — read `CampaignManager`'s actual current dispatch code
       first and decide the least-duplicative extension point (`design.md`) before writing this.
  - _Requirements: 3.1_
- [ ] 4. GUT tests using an injectable/fake "current date" (establish this pattern if absent) —
       window boundaries, repeat-completion tracking, `has_ever_completed()`.

## Wave 2 — Chapters 6–10 and the content-authoring guide (validated together)

- [ ] 5. Start `docs/CONTENT_AUTHORING_GUIDE.md` alongside authoring — write each schema section
       as its content is actually authored, not before or after in isolation.
  - _Requirements: 4.1_
- [ ] 6. Author Ch6 (The Wandering Widow) first, as the exit-proof chapter — confirm zero script
       changes were needed to load it, the literal M7 verification method.
  - _Requirements: 1.1, 1.2_
- [ ] 7. Author Ch7 (Marguerite's Harbour), Ch10 (The Cove Without a King) — both normal one-time
       chapters, no new mechanism needed.
  - _Requirements: 1.1, 1.2_
- [ ] 8. Author Ch8 (The Spring Crossing) using Wave 1's `SeasonalEventData`, not `ChapterData`.
  - _Requirements: 1.1, 3.2_
- [ ] 9. Author Ch9 (An Unwelcome Ally), gated on `SeasonalEventManager.has_ever_completed(
       "spring_crossing")` per `design.md`'s resolution of the Ch8→Ch9 gate question.
  - _Requirements: 1.1, 1.2_
- [ ] 10. If any of Tasks 6/7/8/9 surfaced a real data-model gap, design and implement the minimal
        fix; document the finding either way (gap found and fixed, or model held up as claimed).
  - _Requirements: 1.3_
- [ ] 11. Finish `docs/CONTENT_AUTHORING_GUIDE.md`; confirm whoever authored Tasks 6–9 used only
        the documented process and fix any point where it was wrong or incomplete.
  - _Requirements: 4.1, 4.2_

## Wave 3 — Regions 4/5

- [ ] 12. Author `RegionData` for Region 4 (Ancient Ocean, tier 4, threshold 300) and Region 5
        (Ghost Reaches, tier 5, threshold 500), using `EmpireManager`'s existing activation model.
  - _Requirements: 2.1_
- [ ] 13. Author at least one island per region with `world_position`/`region_id`/`IslandType`/
        faction ownership.
  - _Requirements: 2.2_
- [ ] 14. Give the Ghost Fleet real mechanical presence in Region 5 (real ships/combat/boarding)
        per `design.md`'s "mechanically real, supernaturally still ambiguous" resolution — not
        flavor text alone.
  - _Requirements: 2.3_
- [ ] 15. Fresh headful `CaptureHarness` review of both regions' terrain/content — visual/content
        work needs a human look, same discipline as every milestone since M9.

## Wave 4 — What's New panel

- [ ] 16. `WhatsNewScreen` following `CaptainsLog`'s exact pattern; patch-notes data resource.
  - _Requirements: 5.1, 5.3_
- [ ] 17. One-time auto-show on first launch after a content-adding update, reusing the M5
        "while you were away" one-time-notice pattern.
  - _Requirements: 5.2_
- [ ] 18. Author patch notes for this milestone's own content (Chapters 6–10, Regions 4/5, Spring
        Crossing) as the first real entries.

## Wave 5 — Remote-config consumption (soft dependency on M15 — see header note)

- [ ] 19. `LiveOpsConfig` wrapper: `get_seasonal_window()`, `is_content_enabled()`, both with a
        local-fallback path that requires no M15 presence at all.
  - _Requirements: 6.1, 6.2_
- [ ] 20. Wire Wave 1's `SeasonalEventManager` to read the window through `LiveOpsConfig` instead
        of its own authored fallback directly (the fallback becomes `LiveOpsConfig`'s local-path
        answer, not a separate code path `SeasonalEventManager` maintains itself).
  - _Requirements: 6.1_
- [ ] 21. Confirm Wave 2's newly-added ambient content (if any) and Wave 1's seasonal event both
        check `is_content_enabled()` before starting.
  - _Requirements: 6.1_
- [ ] 22. **If M15 has landed:** configure the real Spring Crossing window in `remote_config`;
        confirm removing that key falls back to the authored local window correctly (proving
        Requirement 6.3's degradation is real). **If M15 hasn't landed:** confirm the whole
        milestone still works correctly with `LiveOpsConfig` always taking its local-fallback
        path — this is not a skipped task, it's this task's actual pass condition in that case.
  - _Requirements: 6.2, 6.3_

## Wave 6 — Documentation and checkpoint

- [ ] 23. Update `docs/05_CURRENT_SYSTEMS.md` (new "M14 — Live Operations" section),
        `docs/14_SYSTEM_INVENTORY.md` (content-volume table), `docs/11_WORLD_MAP.md` (Region 4/5
        entries), `docs/15_MASTER_PLAN.md` (M14 exit criteria, including remote-config status).
  - _Requirements: 7.1, 7.2, 7.3, 7.4_
- [ ] 24. **Checkpoint — M14 complete**
  - GUT suite passes with no regressions.
  - Fresh headful capture reviewed by a human for Regions 4/5's visual content and the What's New
    panel.
  - Ch6's zero-script-change claim (Task 6) is re-confirmed against the actual final diff, not
    just remembered from when it was authored.
  - Independently re-verify against actual code changes and a real GUT run before marking done,
    per `docs/07_AI_AGENT_WORKFLOW.md` Rules 3/4/8.

## Notes

- This milestone has no hard dependency on `.kiro/specs/milestone-m15-backend-cloud-services/` —
  only Wave 5 references it at all, and Wave 5 is explicitly designed to succeed either way
  (Task 22's two pass conditions). Don't let M15's status block starting any other wave.
- Wave 1 must land before Wave 2's Task 8 (Ch8 authoring) — the only real cross-wave ordering
  constraint in this milestone.
