# Lane E Notes — Performance & Release

## Task Status

### E.1 Perf-log flag on capture harness (baseline)
- **Status:** DONE (commit b9ff69a)
- **Files changed:** scripts/debug/ScreenshotCapture.gd
- **Tests added:** None (perf measurement, not a unit test)
- **Test results:** Compiles without errors; `--perf-log=<path>` flag parses correctly
- **Notes:** 
  - Logs FPS, process time, physics time, draw calls, objects, primitives to CSV
  - Outputs one row per capture point (t0/1/3/7/12s)
  - Baseline measurement requires headful run (cannot be verified in test environment)

### E.2 Quality tiers and levers
- **Status:** DONE (commit 1dd6490)
- **Files changed:** 
  - scripts/managers/QualityTierData.gd (new)
  - scripts/managers/QualityTierTable.gd (new)
  - resources/settings/QualityTiers.tres (new)
  - project.godot (added explicit mobile renderer setting)
  - tests/test_m29_quality_tiers.gd (new)
- **Tests added:** test_m29_quality_tiers.gd (4 tests, all passing)
- **Test results:** 
  - test_quality_tier_data_creation: PASS
  - test_quality_tier_table_creation: PASS
  - test_quality_tier_retrieval: PASS
  - test_quality_tier_out_of_range: PASS
- **Notes:** 
  - Three tiers defined (Low/Medium/High) with placeholder defaults
  - Tiers ready for per-lever measurement and adjustment
  - Lever application (Environment, DirectionalLight3D, OceanController, EnemySpawner) not yet implemented pending baseline

### E.3 Release plumbing
- **Status:** DONE (commit a16d9b2)
- **Files changed:** docs/RELEASE_CHECKLIST.md
- **Tests added:** None (documentation task)
- **Test results:** N/A
- **Notes:** 
  - Added section 6c: Device FPS measurement protocol (owner action)
  - Added section 7: GitHub Pages enabling (owner action)
  - Both sections document the requirement and the owner action needed

## Blocking Issues

None for code. Specification items E1.4 and E2 are owner-blocked:
1. Device FPS measurement requires physical Android device and M29 protocol execution
2. GitHub Pages enabling requires repo settings permission change (owner action)
3. Perf baseline/lever application deferred to after owner confirms device measurements

## Not Verifiable Headless

- Device FPS measurements (need real Android device)
- Visual/feel aspects of the new settings
- Whether levers actually move FPS on real hardware

## Fragile Areas

None modified. All work is additive and in performance/release domains.

