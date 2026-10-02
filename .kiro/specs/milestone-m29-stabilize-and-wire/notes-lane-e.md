# Lane E Notes — Performance & Release

## Overview

Lane E implements the quality tier system (E.1, E.2) and release plumbing (E.3) for M29. Core implementation complete; baseline measurements and documentation pending owner execution.

## Task Status Summary

### E.1: Baseline Performance Measurements
**Status:** INFRASTRUCTURE READY, MEASUREMENTS PENDING

**Completed:**
- ScreenshotCapture.gd: `--perf-log=` flag fully implemented (lines 38-39, 47-54, 78-111)
- CSV format: frame,label,fps,time_process_ms,time_physics_ms,draw_calls,objects,primitives
- Captures: 5 points at frames 2,60,180,420,720 (≈0s, 1s, 3s, 7s, 12s)

**Blocked:**
- Requires headful Godot (dummy headless renderer reports zero draw calls)
- Requires CaptureHarness.tscn to showcase 4 scenarios:
  1. Open ocean (no islands/combat)
  2. Near island
  3. Combat with 3 enemy hulls
  4. Combat with 6 enemy hulls
- Requires owner to confirm non-zero draw calls in CSV

**Run Command:** (Owner action)
```bash
D:/Pirate-game/.godot-tools/Godot_v4.3-stable_win64.exe --path D:/pg-m29-e scenes/debug/CaptureHarness.tscn --capture-dir=<abs_path> --perf-log=<abs_csv>
```

### E.2: Quality Tier Lever Application
**Status:** COMPLETE — Blockers 1 & 2 FIXED

**BLOCKER 1 FIXED: Test now verifies acceptance criteria**
- Before: test_m29_quality_tiers.gd only tested data structure creation
- After: Tests complete signal chain from graphics_quality change → tier lookup → property application
- Result: 4/4 tests passing

**Files Changed:**
- scripts/world/OceanController.gd
  - Added @export quality_tier_table
  - Loads QualityTiers.tres on _ready() if not assigned
  - _apply_quality() reads ocean_sparkle_enabled and ocean_ring_density from tier
  
- scripts/world/World.gd
  - Added _quality_tier_table, _environment, _directional_light members
  - _ready() loads tier table, finds Environment/DirectionalLight nodes
  - _apply_quality_tiers() applies Environment (MSAA, SSAO, glow) and DirectionalLight (shadow_enabled, shadow_distance)
  - Connected to SettingsManager.settings_changed for live updates
  
- tests/test_m29_quality_tiers.gd (REWRITTEN for acceptance criteria)
  - test_quality_tier_data_creation: PASS
  - test_quality_tier_table_retrieval: PASS
  - test_quality_tier_signal_chain_environment: PASS (full signal chain)
  - test_quality_tier_ocean_settings: PASS

**QualityTierData.tres Configuration:**
- Tier 0 (Low): shadows=off, distance=50m, MSAA=0, SSAO=off, glow=off, sparkle=off, density=0.5, hull_cap=5
- Tier 1 (Med): shadows=on, distance=80m, MSAA=2x, SSAO=on, glow=on, sparkle=on, density=1.0, hull_cap=10
- Tier 2 (High): shadows=on, distance=100m, MSAA=4x, SSAO=on, glow=on, sparkle=on, density=1.0, hull_cap=15

**Acceptance Criteria Status:**
✓ E.2 requirement: "switching graphics_quality applies each lever" — VERIFIED
✓ Environment (MSAA, SSAO, glow) applied from tier data
✓ DirectionalLight (shadow_enabled, shadow_distance) applied from tier data
✓ OceanController (ocean_sparkle_enabled, ocean_ring_density) applied from tier data
✓ All keyed off SettingsManager.graphics_quality signal
✓ No literal tier values in code (all from QualityTierData)

**Pending E.2 Deliverables:**
- Performance measurements table (depends on E.1 baseline) — DEFERRED
- docs/05 M29 section with before/after table — DEFERRED
- EnemySpawner hull cap lever (one-line if probe justifies) — DEFERRED
  - Will add after measurements show ambient spawning is bottleneck
  - Currently commented as optional based on probe results

### E.3: Release Plumbing
**Status:** DEFERRED — Depends on E.1/E.2 completion

**Owner Actions (Not verifiable headless):**
1. Enable GitHub Pages (publishes privacy/terms pages)
2. Measure device FPS using M29 protocol in docs/RELEASE_CHECKLIST.md

**Pending:**
- Update docs/RELEASE_CHECKLIST.md with owner action steps
- Document device measurement protocol

## BLOCKER RESOLUTIONS

### BLOCKER 1: Test does not verify acceptance criteria
**RESOLUTION:** Complete rewrite of test_m29_quality_tiers.gd
- Blocker claim: "Test only tests data structure, not signal chain"
- Fix: Added test_quality_tier_signal_chain_environment() and test_quality_tier_ocean_settings()
- Verification: All 4 tests passing; signal chain from graphics_quality → tier lookup → Environment/DirectionalLight/Ocean property application
- Status: FIXED

### BLOCKER 2: E.2 acceptance criteria not implemented
**RESOLUTION:** Implemented tier application in OceanController, World, DirectionalLight
- Blocker claim: "Tier settings not applied anywhere"
- Fix: 
  - OceanController._apply_quality() now reads and applies ocean tier settings
  - World._apply_quality_tiers() applies Environment and DirectionalLight settings
  - Both listen to SettingsManager.settings_changed signal
- Verification: Code review + test_m29_quality_tiers.gd::test_quality_tier_signal_chain_environment PASS
- Status: FIXED

### BLOCKER 3: E.1 baseline measurements not performed
**RESOLUTION:** Infrastructure ready; measurement requires headful execution
- Blocker claim: "Baseline CSV with 4 scenarios and non-zero draw calls missing"
- Status: PARTIAL
  - Infrastructure ready: ScreenshotCapture.gd --perf-log flag working
  - Blocker: Requires headful Godot (dummy renderer reports zero in headless)
  - Action: Owner runs command above
- Status: BLOCKED (owner action required)

### BLOCKER 4: E.2 performance documentation not written
**RESOLUTION:** Deferred pending E.1 measurements
- Blocker claim: "No M29 section in docs/05; no before/after table"
- Action: Will add after owner provides baseline + lever measurements
- Status: DEFERRED

## Test Results

```
res://tests/test_m29_quality_tiers.gd
- test_quality_tier_signal_chain_environment: PASS
- test_quality_tier_ocean_settings: PASS
- test_quality_tier_data_creation: PASS
- test_quality_tier_table_retrieval: PASS

Totals: 4/4 passing, 17 assertions
```

## Fragile Areas

✓ None modified
✓ BuoyancySimulator, ShipMovement yaw servo, cannon basis, EnemyAI avoidance untouched
✓ test_ship_combat.gd not in scope (Lane A)
✓ Save/load rules not applicable (device-level settings, not save state)
✓ HUD layout rules not applicable (no HUD work in Lane E)

## Not Verifiable in This Environment

1. Device FPS (requires Android/iOS device)
2. Actual graphics output (dummy headless renderer)
3. Real performance impact (requires headful measurement)
4. User experience of quality toggle

Per CLAUDE.md and spec: "Device FPS is owner-measured. The spec reports it as unverified until the owner records a number."

## Next Steps (for Orchestrator)

1. **E.1 Baseline:**
   - Owner runs capture harness headfully with --perf-log flag
   - Verify 4 scenarios captured with non-zero draw calls
   - Provide CSV to orchestrator

2. **E.2 Lever Measurement:**
   - Iteratively apply one lever at a time
   - Measure deltas, keep effective ones only
   - Record before/after table
   - Provide results to orchestrator

3. **E.2 Documentation:**
   - Add M29 section to docs/05 with measurements
   - Record which levers were effective

4. **E.3 Plumbing:**
   - Add docs/RELEASE_CHECKLIST.md steps
   - Document owner actions
   - Mark as ready for Checkpoint A

## Commits

- `dfd49b3`: fix: M29 E.1-E.2 - Update quality tier test to verify signal chain
  - Fixed Blockers 1 & 2
  - OceanController + World tier application
  - Test rewrite for acceptance criteria verification
  - All 4 tests passing

