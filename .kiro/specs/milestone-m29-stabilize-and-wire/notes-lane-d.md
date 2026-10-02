# Lane D Implementation Notes

## Blocker Fix: Resource Lint Test Script Correlation

### Issue
The `test_lint_resource_exports.gd` test had broken script correlation logic that caused 471 false violations on files like MaelstromCurve.tres. The test was checking all properties in a file against only the last `[ext_resource type="Script"]` definition instead of correctly matching each `[resource]` and `[sub_resource]` section to its corresponding script via the `script = ExtResource("id")` reference.

### Root Cause
When a .tres file contains multiple sub_resources with different scripts (e.g., MaelstromCurve.tres has MaelstromCurveData for the main resource and MaelstromBandData for multiple sub_resources), the original test would:
1. Load all ext_resource scripts sequentially
2. Keep overwriting `current_script` with each one
3. End up checking all properties against the last script loaded
4. Report violations for properties that existed on their actual script but not on the wrong one

### Fix Applied
Rewrote the test to use a two-pass approach:
1. **First pass**: Parse all `[ext_resource type="Script" ...]` lines and build a lookup table mapping resource ids to script paths
2. **Second pass**: For each `[resource]` or `[sub_resource]`:
   - Look for the `script = ExtResource("id")` line
   - Resolve that id to get the actual script for this section
   - Check properties only against that script

This ensures each section is validated against its correct script, eliminating false positives.

### Test Results
- Test now passes: `Resource Lint: PASS (all .tres properties are defined)`
- Verified the fix works with MaelstromCurve.tres (which has multiple sub_resources with different scripts)
- Verified the fix works with campaign chapter files (which have multiple sub_resources of the same script type)

### Files Changed
- `tests/test_lint_resource_exports.gd`: Complete rewrite of property-checking logic with proper script-to-resource correlation

### Status
- ✅ Blocker fixed and verified
- Test file can now accurately validate requirement D.4.1

## Task Status

### D.1 - Event banner (Not started)
Not started yet - awaiting orchestrator merge or sequential task start.

### D.2 - Event schedule persistence (Not started)
Not started yet - awaiting orchestrator merge or sequential task start.

### D.3 - Resource lint violations (Blocked)
Blocked on D.4 blocker fix (completed).

### D.4 - Persistence and signal lint (Blocked)
D.4 blocker (resource lint test) is now fixed. Remaining lint tests (persistence and signal) not yet started.

## Notes for Merge
- The resource lint test is now ready to identify actual violations if they exist
- All properties in the project's .tres files are correctly matched to their corresponding scripts
- The test properly handles:
  - Multiple scripts in a single .tres file
  - Multiple sub_resources of the same script type
  - Multiple sub_resources of different script types
