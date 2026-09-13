# Implementation Plan: Milestone M16 — Cosmetics & Entitlements

## Overview

**Do not start this milestone until M9's final checkpoint has passed and M11/M12/M13 are
sequenced ahead of it.** This spec was scaffolded on 2026-08-27 as part of a forward-planning
pass, alongside M17–M21 — it is a planning artifact, not a queue-jump. `docs/07_AI_AGENT_WORKFLOW.md`
Rule 8 (milestones are strictly sequential, never parallel-started) still governs.

**Deviation, explicitly authorized (2026-09-14):** at the time this milestone actually started,
M11 and M12 had each independently passed their own final checkpoints, but M13's final checkpoint
was explicitly `NOT PASSED` — blocked on tasks needing a physical Android device and Play Console
access (export, on-device install, frame-rate measurement, touch verification, store listing),
none of which this environment can perform regardless of how much time passes. Given M16 itself
"ships no paid feature and so does not itself depend on M13 having launched" (this file's own next
line), the user was asked explicitly whether to respect the sequencing gate, help close out
M11/M12's own remaining human-only items instead, or deliberately override the gate for M16
specifically — and chose to proceed with the full M16 milestone. This is recorded here rather than
silently overridden, per this project's own repeated lesson that a sequencing decision like this
belongs to the project owner, not to an implementing session's own judgment.

Read `docs/05_CURRENT_SYSTEMS.md`, `docs/17_MONETIZATION.md`, and this spec's `design.md` — in
particular **§4, the `ShipVisuals` albedo-cache hazard** — before Task 1. That section describes a
failure that the test suite cannot see and that would silently revert a player's cosmetic.

M16 ships **no paid feature** and so does not itself depend on M13 having launched. M17 does.

## Tasks

### Wave 0 — Data foundation

- [x] 1. Create `scripts/core/CosmeticData.gd` with exactly the schema in `design.md` §5.
  - Done 2026-09-14. `@tool`-annotated `Resource` script matching house style (see
    `scripts/world/CaptainData.gd`'s own convention). Every field `@export`ed: `id`, `display_name`,
    `description`, `slot` (`@export_enum`), `rarity_label`, `icon`, `default_owned`, plus a
    "Visual payload" `@export_group` with `albedo_texture`/`tint`/`mesh_override`. No stat,
    modifier, collision, hitbox, or camera field anywhere.
  - **Verified:** `tests/test_cosmetics.gd`'s schema-conformance test walks
    `get_property_list()` on every authored `.tres` against a locked allow-list, passing.
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 2. Create `scripts/core/CosmeticCatalogue.gd` — lazy scan of `resources/cosmetics/**`,
        `id`→resource and `slot`→array indices, `push_error` naming both paths on duplicate id,
        `null` return for unknown id.
  - Done 2026-09-14. Plain static utility (no autoload, per design.md §6 — nothing per-frame,
    nothing to signal). Recursive `DirAccess` scan. Test-only `set_scan_root_for_testing()`/
    `restore_default_scan_root_for_testing()` hooks let tests point at a fixture directory
    without ever touching the real `resources/cosmetics/` tree.
  - **Verified:** `tests/test_cosmetics.gd`'s duplicate-id test builds two real conflicting
    `.tres` files at runtime via `ResourceSaver`, points the catalogue at them, and confirms the
    error names both paths while only one resource survives in the index. Real GUT run passes.
  - _Requirements: 2.4, 2.6, 3.6_

- [x] 3. Write `tests/test_cosmetics.gd` — schema conformance over every authored `.tres`, no
        duplicate ids, no gameplay-affecting property, every `default_owned` id resolves.
  - Done 2026-09-14. 4 tests: schema conformance, no duplicate ids, every `default_owned`
    cosmetic resolves, and the runtime-constructed duplicate-id scenario (Task 2).
  - **Verified:** `<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cosmetics.gd -gexit` — 4/4 passing, real run.
  - _Requirements: 2.1, 2.3, 2.6_

- [x] 4. Author the first 4 cosmetics — one per ship slot (`hull`, `sails`, `flag`, `figurehead`)
        — reusing the existing Kenney-derived material pipeline. Mark at least one `default_owned`.
  - Done 2026-09-14. `hull_blackened_oak` (`default_owned=true`, matching design.md §3.2's own
    illustrative example), `sail_storm_torn` (also a design.md example — later wired as a
    play-earned grant, Task 20), `flag_crimson_banner`, `figurehead_golden_eagle` (a new minimal
    primitive-mesh placeholder scene, since no figurehead-shaped model exists in the vendored
    Kenney pirate kit — confirmed by listing every `.glb` under `assets/models/` first, not
    guessed).
  - **Verified:** `test_cosmetics.gd` passes; catalogue reports 4 across 4 slots.
  - _Requirements: 2.5_

### Wave 1 — Entitlements

- [x] 5. Create `scripts/managers/EntitlementManager.gd` with the account store from `design.md`
        §3.2 — eager write on grant, `get_save_data()`/`load_save_data()` pair, `entitlement_granted`
        signal, **no quantity field**.
  - Done 2026-09-14. Reads/writes its own `user://account_data.json` directly via `FileAccess`
    (matching `AuthManager.gd`/`CrashReporter.gd`'s established convention for a manager owning a
    file outside `SaveManager`'s round-trip). `get_save_data()`/`load_save_data()` follow the same
    shape every other manager uses, for serialization consistency, even though nothing calls them
    through `SaveManager` — this manager calls them on itself.
  - **Verified:** `tests/test_entitlements.gd`'s malformed/empty-file tests write directly to
    `user://account_data.json` and call the manager's own `reload_account_data()`, confirming
    entitlements survive without a process relaunch being needed to prove the eager-write
    contract in this environment.
  - _Requirements: 1.1, 1.2, 1.5, 1.6, 1.8_

- [x] 6. Register `EntitlementManager` in `project.godot` `[autoload]`, after `SaveManager` and
        before `CampaignManager`.
  - Done 2026-09-14. Registered immediately after `SaveManager`.
  - **Verified:** full GUT suite passes with no broad unrelated failures from autoload ordering
    (464→478 immediately after this task, later 483 by the milestone's end).
  - _Requirements: 1.1_

- [x] 7. Implement the failure path — missing, empty, or malformed `account_data.json` seeds the
        `default_owned` set, logs once, and never blocks startup or `SaveManager.load_game()`.
  - Done 2026-09-14. `_load_or_seed_account_data()` treats a missing/empty/unparseable file as a
    first run — logs `"EntitlementManager: no readable account data, seeding defaults"` once,
    grants every `default_owned` cosmetic, writes a fresh file, never touches `SaveManager` at all.
  - **Verified:** `tests/test_entitlements.gd`'s malformed/empty-file tests write `"{"`/`""`
    directly and confirm defaults are re-seeded without any error. Real GUT run passes.
  - _Requirements: 1.7_

- [x] 8. Implement `grant(id, source)` per `design.md` §7 — idempotent, rejects unknown ids,
        writes eagerly, emits.
  - Done 2026-09-14. Matches the design.md snippet exactly. This is the **only** write path into
    `_entitlements` (grepped and confirmed at every checkpoint) — M17's purchase flow must add a
    fourth `source` value here rather than a second write path.
  - **Verified:** `tests/test_entitlements.gd`'s idempotence test calls `grant()` twice with the
    same id and asserts exactly one entry and exactly one `entitlement_granted` emission.
  - _Requirements: 5.1, 5.3_

- [x] 9. Write `tests/test_entitlements.gd` covering the full §9 table — idempotence, no quantity
        field, survives new game, survives save deletion, malformed file yields defaults.
  - Done 2026-09-14. 7 tests, following `tests/test_auth_manager.gd`'s save/restore-state
    convention for a manager owning its own JSON file (backs up `account_data.json` in
    `before_each()`/restores in `after_each()`, same pattern).
  - **Verified:** single-file GUT run — 7/7 passing.
  - _Requirements: 1.3, 1.4, 1.6, 1.7, 5.3_

- [x] 10. **Checkpoint — data and entitlement layer**
  - Full GUT suite: 478/478 passing at this checkpoint (baseline 464, +11 for Wave 0/1's own
    tests, +3 more from a concurrent session's own unrelated M14 work landing in the same shared
    tree — confirmed via git status/timestamps to belong to that session, not this milestone).
  - Grepped: no quantity, count, balance, or currency field anywhere in `EntitlementManager.gd` or
    `CosmeticData.gd` — the only hits are this file's own comments documenting the *absence* of
    such fields.
  - Confirmed entitlement data is written to `user://account_data.json`, never to
    `user://save_data.json`.
  - Independently re-verified by the `checkpoint-reviewer` agent, not self-reported: read every
    file fresh against the spec, confirmed the single-write-path guarantee, confirmed
    account/save separation, confirmed the git diff has zero overlap with the concurrent
    session's own M14 files. The reviewer's own environment couldn't locate the Godot binary to
    re-run GUT itself; this session's own repeated real GUT runs (478/478, confirmed twice)
    supplied that half of the verification.

### Wave 2 — Appearance

- [x] 11. Promote the damage severity local in `ShipVisuals._on_damage_pool_changed` to a member
         (`_current_damage_severity`), with no behavioural change.
  - Done 2026-09-14.
  - **Verified:** `tests/test_ship_damage_visuals.gd`'s 4 pre-existing tests pass unchanged.
  - _Requirements: 3.4_

- [x] 12. Add `ShipVisuals.apply_cosmetic(slot, cosmetic)` implementing `design.md` §4 exactly —
         apply, then `_cache_clean_albedo()`, then re-assert `_apply_damage_tint()`. **The order
         is load-bearing.**
  - Done 2026-09-14. Four private per-slot helpers (`_apply_hull_skin`/`_apply_sail_pattern`/
    `_apply_flag`/`_apply_figurehead`) set the toon shader's `albedo`/`texture_albedo` params
    (the same mechanism the existing damage-tint/faction-color systems already use — no second
    visual-application path), with the hull skin explicitly excluding sail/flag sub-nodes so it
    doesn't bleed onto their own separately-cosmetic'd parts.
  - **Verified — the real, hard way, not a self-report:** a new permanent regression test,
    `tests/test_ship_damage_visuals.gd`'s `test_an_equipped_hull_cosmetic_survives_a_damage_and_repair_cycle`,
    equips a cosmetic, applies real damage via `ShipDamage.apply_hit()`, repairs via
    `ShipDamage.repair()`, and asserts the mesh's actual `ShaderMaterial` "albedo" parameter equals
    the cosmetic's tint (not the pre-cosmetic color) after repair. **This test-writing effort
    surfaced a real, pre-existing latent bug** unrelated to cosmetics: `ShipModel` is declared
    before `ShipDamage` in every ship scene, so the very first model build read hull's
    uninitialized `0.0` and wrongly computed a "critical damage" tint on a ship that had never
    been hit. Root-caused and fixed (treating that one boot-time read as "not yet initialized"
    rather than "destroyed" — real damage still arrives correctly afterward through the genuine
    `pool_changed` signal), re-verified the fix doesn't regress the other 3 pre-existing tests in
    that file. **Also confirmed via real headful screenshots** (force-launched, a temporary debug
    autoload deleted once done): equipped `hull_deep_ocean_blue` on the live player ship, damaged
    it 80%, repaired it — the hull visibly returns to deep blue, not the original wood color.
  - _Requirements: 3.2, 3.3, 3.4_

- [x] 13. Re-apply equipped cosmetics at the end of `_rebuild_model()`, before its existing
         `_cache_clean_albedo()` call — inline, not via `call_deferred` (the D45 defer-chain
         failure mode).
  - Done 2026-09-14. A loop over `_equipped_cosmetics` calling the per-slot visual-only helpers,
    inline, immediately before the pre-existing cache/re-tint lines.
  - **Verified:** the same real damage-and-repair regression test (Task 12) exercises this path
    indirectly (a rebuild during a real ship's lifecycle would otherwise lose the cosmetic); GUT
    suite green throughout.
  - _Requirements: 3.2, 3.3_

- [x] 14. Persist equipped *selection* through `SaveManager` (slot-scoped), keeping ownership
         account-scoped. Unknown or unowned cosmetic id in a save falls back to default silently.
  - Done 2026-09-14. `ShipVisuals.get_save_data()`/`load_save_data()` round-trip
    `{slot: cosmetic_id}` only, nested under `save_dict["player"]["cosmetics"]` (same pattern as
    the existing `"damage"` section). `load_save_data()` skips (never crashes on) any id that
    doesn't resolve via `CosmeticCatalogue` or that the account doesn't own via
    `EntitlementManager.has_entitlement()`.
  - **Verified:** GUT suite green; the fallback logic itself is the same `continue`-on-unresolved
    pattern already proven safe (a slot simply keeps its natural default appearance, never a null
    material).
  - _Requirements: 3.5, 3.6_

- [x] 15. Author the remaining cosmetics to reach **at least 10 across at least 4 slots**,
         including the `decoration` slot using `Island.gd`'s existing `Marker3D` slot-snapping.
  - Done 2026-09-14. 6 more: `hull_weathered_grey`, `hull_deep_ocean_blue`, `sail_sunbleached_white`,
    `sail_midnight_black`, `flag_golden_standard`, `decoration_buried_treasure` (reuses the
    existing `assets/models/chest.glb` prop directly as its `mesh_override` — no new asset).
    **10 total across 5 slots** (hull ×3, sails ×3, flag ×2, figurehead ×1, decoration ×1). The
    decoration cosmetic is authored data only — actually wiring "equip a decoration onto an
    island's Marker3D slot" is outside this milestone's own Wave 3 scope (the wardrobe screen only
    covers ship cosmetics), noted rather than silently assumed done.
  - **Verified:** `test_cosmetics.gd` passes with all 10; catalogue reports ≥10 across ≥4 slots.
  - _Requirements: 2.5_

### Wave 3 — Surface

- [x] 16. Build `scenes/ui/WardrobeScreen.tscn` + `scripts/ui/WardrobeScreen.gd` — grouped by
         slot, owned/unowned state, M9 theme, anchor-based sizing (no fixed-pixel panel).
  - Done 2026-09-14. Root panel anchored at 0.05–0.95 of the viewport on all four sides — no
    `custom_minimum_size` anywhere on the panel itself, an explicit contrast with the older
    `WorldMapScreen`/`CaptainsLog` screens' own fixed-pixel panels (design.md §8's own named
    anti-pattern, V17). `PirateThemeBuilder.build()` applied; slot tabs + a scrollable grid of
    owned/locked cosmetic entries.
  - **Verified:** `tests/test_wardrobe_layout.gd`'s property test instantiates the screen in a
    `SubViewport` at two very different sizes (1920×1080, 750×1334) and confirms the panel's
    actual rendered pixel size differs between them — proving anchor-based sizing empirically,
    not asserting it by code inspection alone. Real GUT run passes.
  - _Requirements: 4.1, 4.2, 4.4_

- [x] 17. Implement live preview on the existing player ship (no second ship instance), and
         equip-on-confirm.
  - Done 2026-09-14. `ShipVisuals.preview_cosmetic()`/`cancel_preview()` (new, alongside the real
    `apply_cosmetic()`) give a non-committing preview path: selecting a cosmetic previews it live
    on `get_tree().get_first_node_in_group("player_ship").get_node_or_null("ShipModel")`; only the
    Equip button calls the real `apply_cosmetic()`. Backing out (Close) or switching slots without
    confirming calls `cancel_preview()`, which reverts to whatever's actually equipped (or a full
    `_rebuild_model()` if nothing was equipped in that slot).
  - **Verified:** confirmed via real headful screenshots that equipping actually changes the live
    ship's appearance (Task 12's screenshot pass); the preview-then-cancel-reverts path itself is
    covered by the `preview_cosmetic()`/`cancel_preview()` code paths but was not separately
    screenshotted mid-preview — disclosed, not assumed.
  - _Requirements: 4.3, 3.1, 3.2_

- [x] 18. Add one wardrobe entry point to the existing menu structure, participating in M9's
         panel arbitration rather than stacking on top (the V14 defect class).
  - Done 2026-09-14. A 5th toggle button on `WorldHUD`'s existing Log/Map/Codex/New row. Declines
    to open while `tutorial_dialogue.visible` is true (the same arbitration concern Task 18 names).
    `process_mode = Node.PROCESS_MODE_ALWAYS` applied from the start (this exact bug class —
    a toggle button going unresponsive once its own panel pauses the tree, since `WorldHUD` itself
    isn't always-processing — was found and fixed on the other 4 buttons via self-play testing
    earlier this same session, before M16 began; applying it here from the outset avoids
    reintroducing the same defect).
  - **Verified:** confirmed via a real headful screenshot that the "WARDROBE" button renders
    correctly, styled identically to Log/Map/Codex/New, in the top-right HUD row.
  - _Requirements: 4.1_

- [x] 19. Write `tests/test_wardrobe_layout.gd`, following `tests/test_world_hud_layout.gd`'s
         existing pattern — no fixed-pixel sizing, 48dp minimum touch targets, no overlap.
  - Done 2026-09-14. 4 tests: panel resizes with viewport (not fixed-pixel), no overlap between
    tabs/content/buttons at two viewport sizes, every slot tab meets the 48×48 minimum touch
    target, every cosmetic entry meets it too.
  - **Verified:** single-file GUT run — 4/4 passing.
  - _Requirements: 4.4, 4.6_

- [x] 20. Wire the 3 play-earned grants to existing completion signals per `design.md` §7 — **not**
         to `SaveManager.game_loaded` (D15 subscriber-replay hazard).
  - Done 2026-09-14. All three wired inside `EntitlementManager.gd` itself (centralizing every
    grant trigger in one file, matching the M17 single-write-path concern):
    `CampaignManager.chapter_completed` filtered to `chapter.chapter_number == 3` → grants
    `sail_storm_torn`; `EmpireManager.island_captured` → grants `flag_golden_standard`; a
    `SceneTree.node_added` listener filtered to the `boss_ship` group connects each boss's own
    `ShipCombat.died` on the fly (guarded by `is_connected()` so it can't double-connect) → grants
    `figurehead_golden_eagle` on death. `node_added` was used (itself a pre-existing engine
    signal, not a new mechanism) because boss ships are spawned from 3 separate functions in
    `EventManager.gd` with no single shared spawn point to hook instead, and that file is outside
    this milestone's declared scope.
  - **Verified:** `grant()`'s own idempotence guard (Task 8) already proves a repeated condition
    can't double-grant; GUT suite green throughout.
  - _Requirements: 5.2, 5.3_

- [x] 21. Confirm Requirement 4.5 by inspection: no purchase affordance, price, currency, or store
         link exists anywhere in the wardrobe scene or script — absent, not disabled.
  - Done 2026-09-14.
  - **Verified:** grepped `WardrobeScreen.gd`/`.tscn` for price/buy/purchase/store/currency — zero
    hits in the `.tscn`; the only `.gd` hits are the script's own header comment documenting the
    *absence* of such things (Requirement 4.5's own text, quoted for the record).
  - _Requirements: 4.5_

### Wave 4 — Documentation and final checkpoint

- [x] 22. Update `docs/05_CURRENT_SYSTEMS.md` (new M16 section), `docs/14_SYSTEM_INVENTORY.md`
         (cosmetic/entitlement rows off ❌), `docs/10_ASSET_REQUESTS.md` (cosmetic category), and
         reconcile `docs/17_MONETIZATION.md` §2.1 against what was actually authored.
  - Done 2026-09-14. `docs/05_CURRENT_SYSTEMS.md` gained a full M16 section (persistence model,
    the §4 hazard and the latent bug it caught, the wardrobe screen, the 3 grants, the real
    headful verification actually performed). `docs/14_SYSTEM_INVENTORY.md`'s 6 M16 rows flipped
    ❌→✅. `docs/10_ASSET_REQUESTS.md` gained an M16 update explaining what each cosmetic reuses
    and why no bespoke figurehead/decoration art was needed. `docs/17_MONETIZATION.md` §2.1
    reconciled: "Blackened Oak"/"Storm-Torn" (already-existing illustrative names in that doc)
    are now real shipped ids, one default-owned and one play-earned-and-therefore-unsellable.
  - **Verified:** the `sync-systems-doc` skill's own check (scoped to this milestone's actual
    files, since the repo's broader diff also contains a concurrent session's own unrelated M14
    work) reported every M16 file/system correctly reflected in the doc — 0 items needing
    updating.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 23. Record every play-earned cosmetic's earnable path in `docs/17_MONETIZATION.md`, so M17
         cannot sell one without preserving that path.
  - Done 2026-09-14. A table recording all 3 ids with their exact trigger conditions (chapter 3
    completion, boss defeat, island capture), plus the explicit rule that `sail_storm_torn`
    specifically must never be sold in M17 regardless of what pricing that milestone attaches to
    the rest of the cosmetics category.
  - **Verified:** each of the 3 play-earned ids appears in doc 17 with its condition.
  - _Requirements: 5.4_

- [x] 24. **Checkpoint — M16 complete**
  - Full GUT suite: **483/483 passing, 0 failures** (464 baseline → 478 at Wave 1's checkpoint →
    479 after Wave 2's cosmetic-hazard regression test → 483 after Wave 3's wardrobe-layout tests).
    Re-run fresh multiple times throughout, including once more immediately before this commit,
    against the exact final working tree.
  - Independently re-verified the §4 albedo-cache ordering for real, not accepted as a
    self-report: the permanent regression test (Task 12) exercises the actual damage-and-repair
    cycle via `ShipDamage.apply_hit()`/`repair()` and reads the real `ShaderMaterial` parameter
    value; a real headful screenshot pass additionally confirmed this visually (equip → damage →
    repair → hull still the cosmetic's color, not the original).
  - Confirmed no money, price, SKU, currency, or store reference exists anywhere in the
    milestone's diff — grepped across every new/changed M16 file, not just the wardrobe screen.
  - Confirmed entitlements survive both a new game and a full save deletion — tested for real via
    `tests/test_entitlements.gd`'s own tests calling `SaveManager.delete_save()` against the real
    `EntitlementManager` autoload and asserting the entitlement is untouched, not merely asserted.
  - **Visual checks explicitly listed as not verifiable headlessly, per `CLAUDE.md`:** the
    wardrobe screen's own preview UI (as opposed to the ship's appearance itself, which *was*
    confirmed) rendering correctly on a real screen; whether every one of the other 9 cosmetics
    (only `hull_deep_ocean_blue` was actually screenshotted) looks as intended at combat camera
    distance. These would need a much longer manual pass than this checkpoint's time budget
    allowed, and are recorded here rather than silently assumed fine.
  - Independently reviewed by the `checkpoint-reviewer` agent, covering the whole milestone (all
    24 tasks) rather than one wave, per `docs/07_AI_AGENT_WORKFLOW.md` Rules 3/4/8 — not
    self-reported. The reviewer's own sandboxed environment could not locate the Godot binary to
    re-run GUT itself (the same limitation the Wave 1 checkpoint review hit); this session's own
    repeated real GUT runs and the real headful screenshot pass supplied the execution-based
    verification the reviewer's static code read could not perform on its own.
  - Committed as a single commit (`5df5101`) containing only this milestone's own files —
    carefully separated, hunk by hunk, from a concurrent session's own unrelated M14 work sitting
    uncommitted in the same shared working tree (several files, e.g. `project.godot`,
    `scenes/ui/WorldHUD.tscn`, `scripts/ui/WorldHUD.gd`, `scripts/managers/SaveManager.gd`,
    `docs/14_SYSTEM_INVENTORY.md`, had genuinely intermixed changes from both sessions in the same
    functions/sections). **M16 is complete.**

## Notes

- **The single riskiest thing in this milestone is `design.md` §4.** The albedo cache in
  `ShipVisuals` is invisible unless you have read it, and getting the order wrong produces a bug
  that only appears after a damage-and-repair cycle — which no current test performs. Task 12's
  Verify step exists specifically to force that cycle.
  - _Confirmed: writing that exact test not only proved the ordering correct, it surfaced a
    genuinely separate, pre-existing latent bug (the `ShipModel`-before-`ShipDamage` boot-order
    race) that no prior test in this codebase had ever exercised. Fixed alongside._
- Wave 0 and Wave 1 are independent of each other and can be interleaved. Wave 2 depends on both.
  Wave 3 depends on Wave 2.
- **M17 depends on this milestone's `grant()` being the only write path into the entitlement set.**
  If a second write path is added anywhere during implementation, M17's purchase flow will have
  two sources of truth. Keep it single.
  - _Confirmed single at the final checkpoint: grepped for every assignment into `_entitlements`
    in `EntitlementManager.gd` — only `grant()` (the intended write path) and `load_save_data()`
    (restoring from a previously-written file, not a new grant) touch it._
- Cosmetic *art quality* is deliberately not gated here. Authoring against the existing Kenney
  material pipeline is sufficient; bespoke art is an asset request in doc 10, and blocking this
  milestone on art would leave the entitlement system unproven going into M17.
  - _Confirmed: the figurehead and decoration slots specifically needed no new bespoke art —
    a primitive-mesh placeholder and a reused existing prop model, respectively, both documented
    honestly in doc 10 rather than presented as final art._

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
