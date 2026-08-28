# Implementation Plan: Milestone M16 — Cosmetics & Entitlements

## Overview

**Do not start this milestone until M9's final checkpoint has passed and M11/M12/M13 are
sequenced ahead of it.** This spec was scaffolded on 2026-08-27 as part of a forward-planning
pass, alongside M17–M21 — it is a planning artifact, not a queue-jump. `docs/07_AI_AGENT_WORKFLOW.md`
Rule 8 (milestones are strictly sequential, never parallel-started) still governs.

Read `docs/05_CURRENT_SYSTEMS.md`, `docs/17_MONETIZATION.md`, and this spec's `design.md` — in
particular **§4, the `ShipVisuals` albedo-cache hazard** — before Task 1. That section describes a
failure that the test suite cannot see and that would silently revert a player's cosmetic.

M16 ships **no paid feature** and so does not itself depend on M13 having launched. M17 does.

## Tasks

### Wave 0 — Data foundation

- [ ] 1. Create `scripts/core/CosmeticData.gd` with exactly the schema in `design.md` §5.
  - Every field `@export`ed; no stat, modifier, collision, hitbox, or camera field.
  - **Verify:** create one `.tres` from it in the inspector and confirm every field appears;
    confirm a deliberately misspelled property in a hand-edited `.tres` is visibly ignored (the
    D3/D14 behaviour) — this is why Task 3's test exists.
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 2. Create `scripts/core/CosmeticCatalogue.gd` — lazy scan of `resources/cosmetics/**`,
        `id`→resource and `slot`→array indices, `push_error` naming both paths on duplicate id,
        `null` return for unknown id.
  - **Verify:** add two `.tres` files sharing an id; confirm the error names both paths and the
    suite does not silently pick one.
  - _Requirements: 2.4, 2.6, 3.6_

- [ ] 3. Write `tests/test_cosmetics.gd` — schema conformance over every authored `.tres`, no
        duplicate ids, no gameplay-affecting property, every `default_owned` id resolves.
  - **Verify:** `<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cosmetics.gd -gexit` passes.
  - _Requirements: 2.1, 2.3, 2.6_

- [ ] 4. Author the first 4 cosmetics — one per ship slot (`hull`, `sails`, `flag`, `figurehead`)
        — reusing the existing Kenney-derived material pipeline. Mark at least one `default_owned`.
  - **Verify:** `test_cosmetics.gd` still passes and the catalogue reports 4 across 4 slots.
  - _Requirements: 2.5_

### Wave 1 — Entitlements

- [ ] 5. Create `scripts/managers/EntitlementManager.gd` with the account store from `design.md`
        §3.2 — eager write on grant, `get_save_data()`/`load_save_data()` pair, `entitlement_granted`
        signal, **no quantity field**.
  - **Verify:** grant an id, kill the process before any `SaveManager.save_game()`, relaunch, and
    confirm the entitlement survived.
  - _Requirements: 1.1, 1.2, 1.5, 1.6, 1.8_

- [ ] 6. Register `EntitlementManager` in `project.godot` `[autoload]`, after `SaveManager` and
        before `CampaignManager`.
  - **Verify:** full GUT suite still passes at the 326 baseline — an autoload ordering mistake
    surfaces as broad unrelated failures, so a green suite is the real check here.
  - _Requirements: 1.1_

- [ ] 7. Implement the failure path — missing, empty, or malformed `account_data.json` seeds the
        `default_owned` set, logs once, and never blocks startup or `SaveManager.load_game()`.
  - **Verify:** write `{` into `user://account_data.json`, launch, confirm the game reaches the
    main menu with defaults owned and no error dialog.
  - _Requirements: 1.7_

- [ ] 8. Implement `grant(id, source)` per `design.md` §7 — idempotent, rejects unknown ids,
        writes eagerly, emits.
  - **Verify:** call `grant()` twice with the same id; assert the entitlement dictionary has one
    entry and the signal fired once.
  - _Requirements: 5.1, 5.3_

- [ ] 9. Write `tests/test_entitlements.gd` covering the full §9 table — idempotence, no quantity
        field, survives new game, survives save deletion, malformed file yields defaults.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 1.3, 1.4, 1.6, 1.7, 5.3_

- [ ] 10. **Checkpoint — data and entitlement layer**
  - Full GUT suite at or above the 326 baseline, no new failures.
  - Confirm by grep that no quantity, count, balance, or currency field exists anywhere in
    `EntitlementManager` or `CosmeticData` — this is the `AGENTS.md` no-currency rule and is
    easier to enforce now than to remove later.
  - Confirm entitlement data is written outside `user://save_data.json`.
  - Re-verify independently against the actual diff, not against this session's self-report, per
    `docs/07_AI_AGENT_WORKFLOW.md` Rules 3/4/8 — use the `checkpoint-reviewer` agent.

### Wave 2 — Appearance

- [ ] 11. Promote the damage severity local in `ShipVisuals._on_damage_pool_changed` to a member
         (`_current_damage_severity`), with no behavioural change.
  - **Verify:** `tests/test_ship_damage_visuals.gd` passes unchanged.
  - _Requirements: 3.4_

- [ ] 12. Add `ShipVisuals.apply_cosmetic(slot, cosmetic)` implementing `design.md` §4 exactly —
         apply, then `_cache_clean_albedo()`, then re-assert `_apply_damage_tint()`. **The order
         is load-bearing.**
  - **Verify:** equip a hull skin, apply damage, clear damage, and confirm the skin is still
    present — this is the §4 hazard and the one thing in this milestone most likely to be wrong.
  - _Requirements: 3.2, 3.3, 3.4_

- [ ] 13. Re-apply equipped cosmetics at the end of `_rebuild_model()`, before its existing
         `_cache_clean_albedo()` call — inline, not via `call_deferred` (the D45 defer-chain
         failure mode).
  - **Verify:** trigger a model rebuild with a cosmetic equipped; confirm it survives.
  - _Requirements: 3.2, 3.3_

- [ ] 14. Persist equipped *selection* through `SaveManager` (slot-scoped), keeping ownership
         account-scoped. Unknown or unowned cosmetic id in a save falls back to default silently.
  - **Verify:** hand-edit a save to reference a nonexistent cosmetic id; load it; confirm the
    default appearance and no null-material error (the V5 defect class).
  - _Requirements: 3.5, 3.6_

- [ ] 15. Author the remaining cosmetics to reach **at least 10 across at least 4 slots**,
         including the `decoration` slot using `Island.gd`'s existing `Marker3D` slot-snapping.
  - **Verify:** catalogue reports ≥10 across ≥4 slots; `test_cosmetics.gd` passes.
  - _Requirements: 2.5_

### Wave 3 — Surface

- [ ] 16. Build `scenes/ui/WardrobeScreen.tscn` + `scripts/ui/WardrobeScreen.gd` — grouped by
         slot, owned/unowned state, M9 theme, anchor-based sizing (no fixed-pixel panel).
  - **Verify:** render at 3 aspect ratios and confirm no clipping — and per `CLAUDE.md`, report
    the visual result as an actual headful observation, not a headless inference.
  - _Requirements: 4.1, 4.2, 4.4_

- [ ] 17. Implement live preview on the existing player ship (no second ship instance), and
         equip-on-confirm.
  - **Verify:** preview a cosmetic, back out without confirming, and confirm the ship reverts.
  - _Requirements: 4.3, 3.1, 3.2_

- [ ] 18. Add one wardrobe entry point to the existing menu structure, participating in M9's
         panel arbitration rather than stacking on top (the V14 defect class).
  - **Verify:** open the wardrobe while the tutorial dialogue and combat HUD are active; confirm
    exactly one panel owns the screen.
  - _Requirements: 4.1_

- [ ] 19. Write `tests/test_wardrobe_layout.gd`, following `tests/test_world_hud_layout.gd`'s
         existing pattern — no fixed-pixel sizing, 48dp minimum touch targets, no overlap.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 4.4, 4.6_

- [ ] 20. Wire the 3 play-earned grants to existing completion signals per `design.md` §7 — **not**
         to `SaveManager.game_loaded` (D15 subscriber-replay hazard).
  - **Verify:** complete the triggering condition, confirm one grant; reload the save and confirm
    no second `entitlement_granted` emission.
  - _Requirements: 5.2, 5.3_

- [ ] 21. Confirm Requirement 4.5 by inspection: no purchase affordance, price, currency, or store
         link exists anywhere in the wardrobe scene or script — absent, not disabled.
  - **Verify:** grep the scene and script for price/buy/purchase/store/currency; expect zero hits.
  - _Requirements: 4.5_

### Wave 4 — Documentation and final checkpoint

- [ ] 22. Update `docs/05_CURRENT_SYSTEMS.md` (new M16 section), `docs/14_SYSTEM_INVENTORY.md`
         (cosmetic/entitlement rows off ❌), `docs/10_ASSET_REQUESTS.md` (cosmetic category), and
         reconcile `docs/17_MONETIZATION.md` §2.1 against what was actually authored.
  - **Verify:** run the `sync-systems-doc` skill and confirm it reports no undocumented M16 system.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 23. Record every play-earned cosmetic's earnable path in `docs/17_MONETIZATION.md`, so M17
         cannot sell one without preserving that path.
  - **Verify:** each of the 3 play-earned ids appears in doc 17 with its condition.
  - _Requirements: 5.4_

- [ ] 24. **Checkpoint — M16 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Independently re-verify the §4 albedo-cache ordering in the actual diff — equip, damage,
    repair, confirm the cosmetic survives. Do not accept a self-report on this one.
  - Confirm no money, price, SKU, currency, or store reference exists anywhere in the milestone's
    diff.
  - Confirm entitlements survive both a new game and a full save deletion, tested for real rather
    than asserted.
  - Explicitly list which visual checks were **not** verifiable headlessly, per `CLAUDE.md`.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.

## Notes

- **The single riskiest thing in this milestone is `design.md` §4.** The albedo cache in
  `ShipVisuals` is invisible unless you have read it, and getting the order wrong produces a bug
  that only appears after a damage-and-repair cycle — which no current test performs. Task 12's
  Verify step exists specifically to force that cycle.
- Wave 0 and Wave 1 are independent of each other and can be interleaved. Wave 2 depends on both.
  Wave 3 depends on Wave 2.
- **M17 depends on this milestone's `grant()` being the only write path into the entitlement set.**
  If a second write path is added anywhere during implementation, M17's purchase flow will have
  two sources of truth. Keep it single.
- Cosmetic *art quality* is deliberately not gated here. Authoring against the existing Kenney
  material pipeline is sufficient; bespoke art is an asset request in doc 10, and blocking this
  milestone on art would leave the entitlement system unproven going into M17.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4"] },
    { "id": 1, "tasks": ["5", "6", "7", "8", "9", "10"] },
    { "id": 2, "tasks": ["11", "12", "13", "14", "15"] },
    { "id": 3, "tasks": ["16", "17", "18", "19", "20", "21"] },
    { "id": 4, "tasks": ["22", "23", "24"] }
  ]
}
```
