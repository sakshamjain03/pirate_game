# Design Document: Milestone M20 — iOS & Second Platform

## 1. Why this design shape

**This milestone is mostly a test of a decision already made.** M17 put billing behind
`IStoreBackend` for exactly this moment. If that interface was designed well, StoreKit is one new
file and this milestone is short. If it leaked Play-specific assumptions, this milestone finds
them — and the response is to fix the interface and update both implementations, never to add a
second path. `AGENTS.md` forbids duplicating systems, and two storefronts diverging is the most
expensive form of that mistake.

**Permissions compose, they do not multiply.** ATT is a fourth state in M17's existing consent
state machine, not a parallel iOS-only permission flow. One machine, one place to reason about
"may we request an ad yet".

**Screenshots are generated, not captured.** `ScreenshotHarness` already exists. Using it means
screenshots can be regenerated for every release, every locale, and every store's aspect
requirements without a person re-staging thirteen scenes.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/core/StoreBackendIOS.gd` | **New.** StoreKit implementation of `IStoreBackend`. |
| `scripts/core/IStoreBackend.gd` | **Changed, only if required.** Any extension updates both implementations in the same change. |
| `scripts/managers/AdManager.gd` | **Changed.** ATT folded into the existing state machine. |
| `scripts/managers/StoreManager.gd` | **Changed.** Backend selection gains the iOS branch. |
| `export_presets.cfg` | **New/changed.** iOS preset. Note: this file does not currently exist in the repo — M13 creates it. |
| `tools/screenshot_pipeline/*` | **New.** Repeatable capture driven by `ScreenshotHarness`. |
| `tests/test_store_backend.gd` | **Changed.** Parametrized across both backends. |
| `tests/test_ad_gating.gd` | **Changed.** ATT states added. |

## 3. The seam, tested

M17's `StoreBackendStub` exists so the purchase state machine is testable headlessly. M20's
addition is to run the **same** test suite against every backend, so parity is asserted rather
than assumed:

```gdscript
# test_store_backend.gd — one suite, N backends
for backend in [StoreBackendStub.new(), StoreBackendIOS.new(), StoreBackendPlay.new()]:
    if not backend.is_available():
        continue          # skipped, and REPORTED as skipped — never silently passed
    _run_conformance_suite(backend)
```

The skip must be visible in the run output. A conformance suite that silently skips the only
backend that matters is worse than no suite, because it reports green.

**Expected seam pressure points** — the places Play and StoreKit differ, and where M17's interface
may need extending:

| Difference | Play | StoreKit | Handling |
|---|---|---|---|
| Acknowledgement | Explicit, windowed | `finishTransaction` | Both fit `acknowledge(order_id)` |
| Restore | `query_owned()` | Explicit restore required by Apple | Already in the interface |
| Deferred/pending purchase | Pending state | Ask-to-Buy (family approval) | **May need a new `purchase_deferred` signal** |
| Refund notification | Revoke signal | Less immediate | Reconcile at launch, as Play already does |

Ask-to-Buy is the most likely genuine extension: a child's purchase can sit approved-later for
days. If a signal is added, Play's implementation gains it too (as a no-op if unreachable) so the
consuming code has one shape.

## 4. ATT in the existing state machine

M17 `design.md` §5's machine gains one state:

```
CONSENT_PENDING ──(iOS only)──► ATT_PENDING ──(player answers)──► READY_PERSONALIZED | READY_NONPERSONALIZED
```

Invariants unchanged and still asserted: no SDK initialization, no ad request, and no advertising
identifier read outside `READY_*`. On iOS the identifier is unavailable until ATT is granted, so
a build that reads it early fails at review rather than in testing — which is why the existing
`test_ad_gating.gd` assertion is extended rather than a new iOS-specific check being written.

ATT declined is not an error state. Non-personalized ads, full playability, no nagging
(Requirement 4.3).

## 5. Cross-platform entitlements

Purchases are per-store. Apple does not honour a Play purchase and never will.

- **With an M15 account signed in:** entitlements sync through the backend, and a supporter on
  Android is a supporter on iOS. This is the strongest practical argument for M15 shipping before
  M20.
- **Without an account:** entitlements are per-store, and Requirement 5.3 demands this be stated
  plainly to the player rather than discovered as a bug report. The purchase-support screen from
  M17 is the right place for that sentence.

Union-not-intersection still holds (M17 `design.md` §8): sync only ever adds.

## 6. Screenshot pipeline

Driven by `ScreenshotHarness`, producing a named set at every required resolution for both stores.

- Deterministic scene setup — same save state, same camera, same time of day — so a regenerated
  set is comparable to the last one rather than subtly different.
- Emits every store aspect ratio from one run.
- Re-runnable per locale once M12's localization lands, which is what makes localized listings
  (Requirement 6.5) affordable rather than a manual re-shoot.

**Hazard:** `ScreenshotHarness` was flagged as a defect once already (D5, an autoload that should
not have been). Confirm its current state in `docs/05_CURRENT_SYSTEMS.md` before building on it,
and do not re-introduce whatever was removed.

## 7. The engine upgrade, if taken

Requirement 1.2 makes this its own task with its own checkpoint, never bundled. The risk profile
is specific to this codebase:

- The renderer is **Forward+**, and the ocean is a GPU wave shader with CPU buoyancy sampling that
  must stay in sync. D11 was precisely a wave-sync defect. A shader-compiler or renderer change
  across a minor version is the highest-risk possible change here.
- The toon shader was tuned by hand (D50, "chalky look").
- The GUT suite proves scripts parse; it does not prove the ocean still looks right. Requirement
  1.3's headful pass is not optional ceremony.

If the upgrade is deferred, record that in `docs/20_PLATFORM_MATRIX.md` §2 with its reasoning, so
the next person does not re-litigate it from scratch.

## 8. What cannot be verified headlessly, or on Windows

Per `CLAUDE.md`, and more sharply than usual here — this project develops on Windows and **iOS
builds cannot be produced on Windows at all**:

**Testable in the existing environment:** the backend conformance suite against the stub, the ad
permission state machine including ATT states, entitlement sync logic, and the screenshot
pipeline's determinism.

**Requires macOS:** any iOS build, at all.

**Requires a physical iOS device and a sandbox account:** purchase, restore, refund, Ask-to-Buy,
ATT prompt, touch controls, frame rate, and App Review. None of these may be reported as passing
from a headless Windows run, and the absence of a Mac is a hard blocker to be raised early rather
than discovered at Task 4.
