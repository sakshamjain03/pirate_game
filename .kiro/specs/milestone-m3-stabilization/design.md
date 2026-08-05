# Design Document: Milestone M3 — Stabilization

## 1. Approach

This milestone is a punch-list, not a system design. Each defect from
`docs/05_CURRENT_SYSTEMS.md` §2 gets its own task with a mechanical, checkable fix. There is no
new architecture here — every fix stays inside the file(s) that already own the broken behavior.

Order matters: fixes are sequenced so that later fixes can be manually verified in a game that
already boots correctly (D4 and D1 are fixed first because they affect whether you can trust
what you see when testing everything after them).

---

## 2. Fix specifications

### D1 — Duplicate EventManager

**Decision:** Keep the autoload as the single source of truth. Remove the scene-local
`Systems/EventManager` node from `World.tscn`. Update `WorldManager.gd` to call the autoload
(`EventManager.xxx(...)`) directly instead of `get_node_or_null("../EventManager")`.

Rationale: the autoload already exists and is simpler to keep as the one instance — removing an
autoload that other code might implicitly depend on (via `EventManager.` global name resolution)
is riskier than removing a scene node.

### D2 — Missing PlayerFaction.tres

**Decision:** Create `resources/factions/PlayerFaction.tres` following the exact schema of the
existing `resources/factions/PirateClans.tres` (copy its structure, change `id`/`name`/colors,
set `is_hostile = false`).

### D3 — GhostShipStats property mismatch

**Decision:** Rewrite `resources/enemies/GhostShipStats.tres` using only real `ShipStats`
property names. Read `scripts/world/ShipStats.gd`'s full `@export` list first to get every name
right, not just the three called out in the audit.

### D4 — ScreenshotHarness in production autoloads

**Decision:** Remove `ScreenshotHarness="*res://scripts/tests/ScreenshotHarness.gd"` from
`project.godot`. If screenshot capture is still wanted for manual QA, document (in a comment at
the top of `ScreenshotHarness.gd`) that it must be run via
`godot --headless -s res://scripts/tests/ScreenshotHarness.gd` on demand, not as an autoload.

### D5 — Dead code

**Decision:** Delete `scripts/core/ScenePaths.gd` and `scripts/core/UIConstants.gd` after
confirming zero references via grep. Delete `resources/world/ShipStats.tres` and
`resources/world/IslandData.tres` after confirming zero `.tscn`/`.gd` references.

### D6 — (folded into D5)

### D7 — Stale SaveManager doc header

**Decision:** Rewrite the header only. Do not touch the implementation.

### D8 — Empty M2 property tests

**Decision:** Implement each of the 5 files against the corresponding Properties already
specified in `.kiro/specs/milestone-m2-playable-world/design.md` §6. Follow the existing pattern
in `tests/test_settings_manager.gd` (GUT `extends GutTest`, `func test_property_x():` with a loop
generating varied inputs). Do not invent new properties — implement the ones already written.

### D9 — Camera collision + mode stubs

**Decision:** Add `SpringArm3D` collision mask/shape-cast configuration to `CameraRig.tscn`/
`CameraRig.gd` so it retracts on obstruction (Godot's `SpringArm3D` has built-in shape-cast
collision — this is a configuration fix, not new logic). For ORBIT/LOOK: either implement
distinct camera-position logic per mode, or collapse the enum to just FOLLOW with a code comment
noting ORBIT/LOOK are deferred. Prefer collapsing unless implementing them is trivial — new
camera-mode logic is a feature, not a stabilization fix, and belongs in a future milestone if
it's non-trivial.

### D10 — Gamepad bindings

**Decision:** Add joypad button/axis events to each relevant `[input]` action in
`project.godot`, additive to existing keyboard/mouse events. Reassign `interact` off of `E`
(suggest `F` is already `dock` — use `G` or a controller-friendly default) to resolve the
`camera_rotate_right` conflict.

### D11 — Ocean/buoyancy visual mismatch

**Decision:** Read `resources/shaders/water.gdshader`'s `uniform` declarations and
`OceanController._apply_settings()`'s `set_shader_parameter()` calls side by side; fix whichever
names don't match. Then update `WaveGenerator.gd` to read its wave height/length/speed/wind
parameters from the same `OceanSettings` resource the shader uses (single source of truth for
wave parameters), rather than hardcoded/independent values, so CPU buoyancy and GPU rendering
move in sync.

---

## 3. Correctness Properties

### Property M3-1: EventManager singularity
*For any* point during World.tscn gameplay, exactly one `EventManager` node/instance is
processing the ocean-event timer — never zero, never two.
**Validates: Requirement 1**

### Property M3-2: Colonize flow always succeeds for valid state
*For any* NEUTRAL island and any gold amount ≥ the island's colonization cost,
`Island.capture_island()` completes without error and the island's owning faction becomes the
player's faction.
**Validates: Requirement 2**

### Property M3-3: GhostShipStats loads intended values
*For any* property read from a loaded `GhostShipStats.tres`, the value SHALL match a property
that actually exists on `ShipStats`, and no `@export`ed `ShipStats` property SHALL silently keep
its class-default value when `GhostShipStats.tres` intended to override it.
**Validates: Requirement 3**

### Property M3-4: No debug autoloads in the autoload list
*For any* entry in `project.godot`'s `[autoload]` section, the entry is a system the game
depends on at runtime for real players — not a development/diagnostic tool.
**Validates: Requirement 4**

### Property M3-5: Dead code has zero references
*For any* file deleted under Requirement 5, a full-project text search for its class/file name
(excluding the file itself, pre-deletion) returns zero matches.
**Validates: Requirement 5**

### Property M3-6: Camera never intersects blocking geometry
*For any* ship position and nearby island/terrain geometry, the rendered camera position is
between the spring arm's origin and the point of first collision — never beyond it.
**Validates: Requirement 8**

### Property M3-7: Every input action has both a keyboard/mouse and a gamepad binding
*For any* action in the list in Requirement 9 Acceptance Criterion 1, the action's event list
contains at least one `InputEventKey`/`InputEventMouseButton` AND at least one
`InputEventJoypadButton`/`InputEventJoypadMotion`.
**Validates: Requirement 9**

---

## 4. Files touched (summary)

| File | Change |
|------|--------|
| `project.godot` | Remove `ScreenshotHarness` autoload; add gamepad input events; fix `interact` key conflict |
| `scenes/world/World.tscn` | Remove scene-local `Systems/EventManager` node |
| `scripts/managers/WorldManager.gd` | Call `EventManager` autoload directly instead of `get_node_or_null` |
| `resources/factions/PlayerFaction.tres` | New file |
| `resources/enemies/GhostShipStats.tres` | Rewrite with correct property names |
| `scripts/managers/SaveManager.gd` | Doc header rewrite only |
| `scripts/core/ScenePaths.gd`, `scripts/core/UIConstants.gd` | Delete |
| `resources/world/ShipStats.tres`, `resources/world/IslandData.tres` | Delete |
| `tests/world/test_camera_properties.gd`, `test_docking_properties.gd`, `test_input_properties.gd`, `test_ocean_properties.gd`, `test_ship_properties.gd` | Implement (currently 0 bytes) |
| `scripts/world/CameraRig.gd`, `scenes/world/CameraRig.tscn` | Add collision; resolve ORBIT/LOOK stub modes |
| `scripts/world/WaveGenerator.gd`, `scripts/world/OceanController.gd`, `resources/shaders/water.gdshader` | Align uniform names and wave parameter source |
