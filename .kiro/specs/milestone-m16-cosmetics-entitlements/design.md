# Design Document: Milestone M16 — Cosmetics & Entitlements

## 1. Why this design shape

The guiding principle is `AGENTS.md`'s "never duplicate systems". Three existing systems already
do most of what this milestone needs, and the design's job is to extend them rather than stand up
parallels:

- **`scripts/world/ShipVisuals.gd`** already owns every material touch on a ship — model rebuild
  (`_rebuild_model`), albedo caching (`_cache_clean_albedo`), damage tinting
  (`_apply_damage_tint`), and colour application (`_apply_color_to_meshes`). A hull or sail skin
  is *another albedo source*, not a new visual pipeline. This is the highest-risk integration
  point in the milestone and §4 covers it in detail.
- **The manager + `get_save_data()`/`load_save_data()` convention** in `scripts/managers/`.
  `EntitlementManager` follows it exactly; only its *destination* differs.
- **The `Resource`-driven data pattern** (`CaptainData`, `ShipStats`, `BuildingData`, …) in
  `resources/`. `CosmeticData` is the same shape, with the D3/D14 rule in force: the script's
  `@export`s are the schema, and a `.tres` setting a non-exported property fails silently.

The one genuinely new concept is **account-scoped persistence**. Nothing in the project currently
persists anything outside `user://save_data.json`. §3 defines that narrowly and resists the
temptation to generalize it into a settings framework — `SettingsManager` already exists for
settings.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/managers/EntitlementManager.gd` | **New.** Autoload. Owns entitlement set, equip state routing, grant paths. |
| `project.godot` | **Changed.** Register `EntitlementManager` in `[autoload]`, after `SaveManager` and before `CampaignManager`. |
| `scripts/core/CosmeticData.gd` | **New.** `Resource` schema for one cosmetic. |
| `scripts/core/CosmeticCatalogue.gd` | **New.** Loads and indexes every `CosmeticData` under `resources/cosmetics/`, detects duplicate ids. |
| `resources/cosmetics/hull/*.tres` etc. | **New.** ≥10 authored cosmetics across ≥4 slots. |
| `scripts/world/ShipVisuals.gd` | **Changed.** Accept a cosmetic override for `hull`/`sails`/`flag`/`figurehead`; re-cache clean albedo after any skin change. |
| `scripts/ui/WardrobeScreen.gd` + `scenes/ui/WardrobeScreen.tscn` | **New.** Browse, preview, equip. M9 theme, responsive. |
| `scripts/ui/IslandMenu.gd` or `MainMenu` | **Changed.** One entry point to the wardrobe. |
| `scripts/managers/SaveManager.gd` | **Changed.** Round-trip *equipped selection* only (not ownership). |
| `tests/test_entitlements.gd`, `tests/test_cosmetics.gd`, `tests/test_wardrobe_layout.gd` | **New.** Flat under `tests/`, per the GUT no-recursion rule in `CLAUDE.md`. |

## 3. Account-scoped persistence

### 3.1 The split, stated once

Two different things persist in two different places, and conflating them is the defect this
design exists to prevent:

| What | Where | Survives new game? |
|---|---|---|
| **Ownership** (which cosmetics are entitled) | `user://account_data.json` | **Yes** |
| **Selection** (which cosmetic is equipped in which slot) | `user://save_data.json`, via `SaveManager` | No — per-campaign |

`EntitlementManager` writes ownership itself, on grant, immediately — it does **not** wait for
`SaveManager.save_game()`. An entitlement granted and then lost to a crash before the next save
is a support ticket in M17, so it is written eagerly from day one.

### 3.2 Shape

```gdscript
# user://account_data.json
{
  "account_schema_version": 1,
  "entitlements": {
    "hull_blackened_oak": { "source": "default",     "granted_at": 1756272000 },
    "sail_storm_torn":    { "source": "chapter_3",   "granted_at": 1756358400 }
  }
}
```

`source` is free-form and records the grant path. In M17 it gains values like `purchase` and
carries the store order id. **There is deliberately no quantity field** — adding one would make
this a wallet, which `AGENTS.md` forbids outright. Requirement 1.6 exists to make that
non-negotiable, and `test_entitlements.gd` asserts it.

`account_schema_version` mirrors `SaveManager.SAVE_SCHEMA_VERSION` (currently 1) so the M12
migration work has a hook to grab when it lands.

### 3.3 Failure behaviour

A missing, empty, or malformed `account_data.json` is **not** an error state — it is a first run.
The manager logs once, seeds the `default_owned` set, and continues. It must never block startup
and must never propagate a failure into `SaveManager.load_game()`, which has its own D64 history
of load-order sensitivity.

## 4. The `ShipVisuals` integration — the real hazard

This is where this milestone will break if it is implemented carelessly, so it is specified
exactly.

`ShipVisuals` currently keeps `_clean_albedo: Dictionary` — a cache, populated by
`_cache_clean_albedo()` during `_rebuild_model()`, of each mesh's *undamaged* albedo.
`_apply_damage_tint(severity)` lerps from that cached value toward `scorch_tint_color`, and
restores from it when damage clears.

**The hazard:** equipping a hull skin changes the base albedo. If `_clean_albedo` is not
re-populated at that moment, then the first time damage clears, `_apply_damage_tint(0.0)` will
restore the *pre-skin* albedo and silently revert the cosmetic. The player equips a skin, takes a
hit, repairs, and their purchase visually disappears. In M17 that is a refund request.

**The rule:** any code path that changes base appearance MUST call `_cache_clean_albedo()`
immediately after applying it, and MUST re-apply the current damage tint afterwards.

```gdscript
func apply_cosmetic(slot: String, cosmetic: CosmeticData) -> void:
    match slot:
        "hull":       _apply_hull_skin(cosmetic)
        "sails":      _apply_sail_pattern(cosmetic)
        "flag":       _apply_flag(cosmetic)
        "figurehead": _apply_figurehead(cosmetic)
        _:            push_warning("ShipVisuals: unknown cosmetic slot '%s'" % slot); return

    # ORDER IS LOAD-BEARING. See design.md §4.
    _cache_clean_albedo()                      # new base is now the clean state
    _apply_damage_tint(_current_damage_severity)   # re-assert damage on top of it
```

`_current_damage_severity` must be promoted from a local in `_on_damage_pool_changed` to a
member, so it can be re-asserted here. That is the only change to the damage system.

**Ordering with `_rebuild_model()`:** `_rebuild_model()` destroys and recreates
`_model_instance`, discarding applied cosmetics. Every cosmetic must therefore be re-applied at
the end of `_rebuild_model()`, before its existing `_cache_clean_albedo()` call — not by a
deferred call afterwards, which is the D45 `CameraRig` defer-chain failure mode.

**Damage precedence (Requirement 3.4):** the damage overlay always wins. A cosmetic supplies the
clean albedo; it never suppresses the tint, the smoke (`_ensure_smoke`), or the sinking list
(`_apply_list`). A dark hull skin plus heavy scorch must still read as damaged — this is a
readability requirement, not a preference, and it is also `docs/18_ACCESSIBILITY.md` §2's
"damage state readable" row.

## 5. `CosmeticData` schema

```gdscript
class_name CosmeticData extends Resource

@export var id: StringName                      # unique; collision is an error (Req 2.6)
@export var display_name: String
@export var description: String
@export_enum("hull", "sails", "flag", "figurehead", "decoration") var slot: String
@export var rarity_label: String                # cosmetic label only, never a stat
@export var icon: Texture2D
@export var default_owned: bool = false

@export_group("Visual payload")
@export var albedo_texture: Texture2D           # hull / sails
@export var tint: Color = Color.WHITE
@export var mesh_override: PackedScene          # figurehead / decoration only
```

Deliberately absent, and enforced by `test_cosmetics.gd`: any stat, modifier, collision shape,
hitbox, camera value, or gameplay reference. The test walks `get_property_list()` on every
authored `.tres` and fails on any property name outside this schema — which also catches the
D3/D14 silent-typo class of bug for free.

## 6. `CosmeticCatalogue`

A plain static/utility class, not an autoload — there is no per-frame state and no signal to
emit, so it does not earn a fourteenth singleton.

- Scans `resources/cosmetics/**/*.tres` once, lazily, on first access.
- Builds `id -> CosmeticData` and `slot -> Array[CosmeticData]` indices.
- On duplicate `id`, `push_error` naming **both** resource paths (Requirement 2.6). Silently
  preferring one is exactly the failure mode `docs/05_CURRENT_SYSTEMS.md` D3/D14 documents.
- A cosmetic id referenced but absent resolves to `null`, and every caller treats `null` as
  "use default appearance" (Requirement 3.6). No caller may assume non-null.

## 7. Grant paths

All three free paths route through one function, so M17 can add a fourth without touching them:

```gdscript
func grant(id: StringName, source: String) -> void:
    if _entitlements.has(id):
        return                              # idempotent (Req 5.3)
    if CosmeticCatalogue.get_cosmetic(id) == null:
        push_error("EntitlementManager: grant of unknown cosmetic '%s'" % id)
        return
    _entitlements[id] = { "source": source, "granted_at": _now_unix() }
    _write_account_data()                   # eager, not deferred (§3.1)
    entitlement_granted.emit(id)
```

Play-earned grants (Requirement 5.2) connect to **existing** signals rather than adding
bookkeeping — `CampaignManager`'s chapter completion, `ShipCombat.died` filtered to boss
encounters, and `EmpireManager`'s island capture. Per `AGENTS.md`, prefer connecting to an
existing signal over adding a new call path.

**Hazard:** `SaveManager.game_loaded` fires on every load, and several subscribers already act on
it (D15). Grant conditions must be evaluated from *state*, not from a load event, or loading a
completed save will re-emit `entitlement_granted` on every launch. The idempotence guard in
`grant()` makes that harmless, but the signal noise would still be wrong, so the connection is to
the completion signals, not to `game_loaded`.

## 8. Wardrobe screen

Follows the M9 themed-screen pattern. Two structural rules carried from that milestone's bug
list:

- **Responsive, not fixed-pixel.** V17 was `IslandMenu`'s hardcoded 600×400 panel; the wardrobe
  must size from anchors and containers so it survives the M19 200%-text-scale requirement.
- **HUD arbitration.** The wardrobe is a full-screen modal and must participate in whatever panel
  arbitration M9 established (V14 was tutorial and combat HUD rendering stacked). It must not
  simply be added on top.

Preview reuses the live ship where one exists, rather than instancing a second preview ship — a
second ship instance would need its own buoyancy and camera, which is a duplicate system.

**Requirement 4.5 is a hard constraint:** no purchase affordance, price, currency, or store link
appears in this screen in M16. Not hidden behind a flag, not commented out — absent. `AGENTS.md`
forbids any paid feature before M13 launches, and a disabled buy button is still a paid feature
in the tree.

## 9. Test strategy

All test files flat under `tests/` (GUT's `-gdir` does not recurse here). Baseline is 326/326;
this milestone must not reduce that count.

| Test | Asserts |
|---|---|
| `test_entitlements.gd` | Idempotent grant · no quantity field ever appears · survives simulated new-game · survives simulated save deletion · malformed account file yields defaults without throwing |
| `test_cosmetics.gd` | Every authored `.tres` matches the schema exactly · no duplicate ids · no gameplay-affecting property · every `default_owned` id resolves |
| `test_wardrobe_layout.gd` | Follows `tests/test_world_hud_layout.gd`'s existing pattern: no fixed-pixel panel size, minimum touch-target size, no overlap at the reference resolution |

**Cannot be verified headlessly**, and must be reported as unverified rather than claimed
(`CLAUDE.md`): that a skin actually looks right on the ship, that damage remains readable over a
dark skin, and that the preview reads correctly at combat camera distance. These need a headful
pass — the same class of check that found D64 and V12 when the test suite could not.
