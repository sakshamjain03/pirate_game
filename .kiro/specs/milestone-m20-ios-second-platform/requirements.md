# Requirements Document

## Introduction

Milestone M20 puts the game on iOS, and builds the store-presence assets that neither M13 nor M17
covered.

A gap audit on 2026-08-27 found M13 (Ship It) is **Android-only** and that iOS appeared nowhere in
the roadmap — despite being roughly half the addressable revenue for a paid-cosmetics model in
most markets. The same audit found M13 covers store listing *text* but not the assets that
actually drive install conversion: a trailer, a repeatable screenshot pipeline, or a press kit.
Both gaps land here, so one pass serves both stores.

**The architectural bet this milestone cashes in.** M17 built billing behind a platform-agnostic
interface (`IStoreBackend`) specifically so that iOS would be an *implementation of an existing
seam* rather than a second storefront. If that seam held, this milestone's billing work is one
new file. If it did not hold, this milestone will discover it — and the fix is to restore the
seam, not to add a parallel path (`AGENTS.md`: never duplicate systems).

**What already exists and needs no work here.** M13 built the Android export pipeline, release
checklist, privacy policy hosting, and store listing text. M17 built the billing interface, the
consent/age-gate state machine, and the entitlement model. M19 built accessibility features worth
declaring in a listing. The `ScreenshotHarness` autoload already exists and should be the
screenshot source rather than hand-captured frames.

**The engine-version question lands here.** `docs/20_PLATFORM_MATRIX.md` §2 decided to stay on
Godot 4.3 through M13, and named the pre-M20 window as the revisit point — iOS export is the
strongest argument for a newer 4.x, and doing the upgrade between stores is lower risk than
before the first one.

Full context: `docs/20_PLATFORM_MATRIX.md` is the platform record and **takes precedence over
this document** where they differ.

---

## Prerequisites (external to this repo)

1. Apple Developer Program membership, with signing certificates and provisioning profiles.
2. A macOS machine or CI runner — iOS builds cannot be produced on Windows, which is this
   project's development platform. **This is a real logistical prerequisite, not a formality.**
3. App Store Connect app record, with in-app purchases configured as **non-consumable** products
   mirroring the M17 SKU set.
4. A sandbox tester account for purchase and restore testing.

---

## Glossary

- **The seam** — `IStoreBackend`, M17's platform-agnostic billing interface. StoreKit implements
  it; no game code learns which implementation it got.
- **ASO** — App Store Optimization: the listing assets (trailer, screenshots, icon, copy) that
  determine whether a store visitor installs.
- **Parity** — a feature behaving equivalently on both platforms. Full parity is the target;
  any deviation must be recorded, not discovered.

---

## Requirements

### Requirement 1: Engine version decision

**User Story:** As a maintainer, I want the engine question settled deliberately rather than by
drift.

#### Acceptance Criteria

1. THE engine version SHALL be re-evaluated before iOS work begins, per
   `docs/20_PLATFORM_MATRIX.md` §2.
2. IF an upgrade is taken THE upgrade SHALL be its own task with its own checkpoint and SHALL NOT
   be bundled into a feature task.
3. AN upgrade SHALL exit only on: the full GUT suite at or above the then-current baseline, plus a
   headful visual pass covering the ocean, ship damage visuals, and toon shading.
4. IF no upgrade is taken THE decision and its reasoning SHALL be recorded in
   `docs/20_PLATFORM_MATRIX.md` §2.

### Requirement 2: iOS export

#### Acceptance Criteria

1. THE project SHALL produce a signed, installable iOS build.
2. THE build SHALL run on iPhone and iPad, at the minimum OS target in
   `docs/20_PLATFORM_MATRIX.md` §3.
3. Touch controls SHALL be verified on a physical device, not in a simulator alone.
4. THE build SHALL meet App Review guidelines, including the export-compliance declaration.
5. App Privacy nutrition labels SHALL accurately describe what the build collects, derived from
   M17's data enumeration rather than restated from assumption.

### Requirement 3: StoreKit behind the existing seam

#### Acceptance Criteria

1. StoreKit SHALL be implemented as an implementation of M17's `IStoreBackend` interface.
2. No game code, UI, or manager SHALL reference StoreKit directly.
3. IF the M17 seam proves insufficient THE interface SHALL be extended and **both**
   implementations updated — a parallel billing path SHALL NOT be created.
4. Purchase, restore, and refund revocation SHALL behave equivalently to the Play implementation.
5. Apple's restore-purchases requirement SHALL be satisfied by the existing explicit restore
   action from M17 Requirement 3.2.
6. THE SKU set SHALL mirror Play's, and price tiers SHALL be configured per market.

### Requirement 4: Advertising on iOS

#### Acceptance Criteria

1. THE App Tracking Transparency prompt SHALL be presented before any personalized advertising.
2. ATT SHALL be integrated into M17's existing consent state machine and SHALL NOT create a
   second permission path.
3. IF ATT is declined THE game SHALL request non-personalized advertising and SHALL remain fully
   playable.
4. No advertisement SHALL be requested and no advertising identifier read before ATT, the age
   gate, and consent have all resolved.

### Requirement 5: Parity

#### Acceptance Criteria

1. Every feature SHALL behave equivalently on both platforms, or the deviation SHALL be recorded
   in `docs/20_PLATFORM_MATRIX.md`.
2. Save data SHALL be compatible across platforms where an M15 account links them.
3. Entitlements purchased on one platform SHALL be honoured on the other WHERE an M15 account is
   signed in, and this limitation SHALL be stated plainly to the player where it does not hold.
4. Accessibility features from M19 SHALL be present and functional on iOS.

### Requirement 6: Store presence assets (ASO)

**User Story:** As someone who found the store page, I want to understand the game in 30 seconds.

#### Acceptance Criteria

1. THE system SHALL produce a trailer of roughly 30 seconds showing the **empire-building**
   fantasy, not only ship combat.
2. Screenshots SHALL be produced by a repeatable pipeline driven by the existing
   `ScreenshotHarness`, so they can be regenerated per release and per locale.
3. THE system SHALL produce feature graphics and icon variants meeting each store's specs.
4. THE system SHALL produce a press kit: description, key art, logo, fact sheet, contact.
5. Listing copy SHALL be localized for the top target markets, distinct from M12's in-game string
   localization.
6. Listings SHALL declare the M19 accessibility features.

### Requirement 7: Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an M20 section.
2. `docs/20_PLATFORM_MATRIX.md` SHALL move iOS/iPadOS from 📋 Planned to shipped, record the
   engine decision, and record every parity deviation.
3. `docs/14_SYSTEM_INVENTORY.md` iOS and ASO rows SHALL move off ❌.
4. `docs/17_MONETIZATION.md` SHALL record the iOS SKU set and real prices.

---

## Out of Scope

- **A second billing system.** Requirement 3.3 is explicit: extend the seam, never parallel it.
- **New gameplay features.** M20 is a platform milestone.
- **macOS, tvOS, or any Apple platform other than iPhone and iPad.**
- **Desktop or Steam.** Permanently out of scope (`docs/20_PLATFORM_MATRIX.md` §1).
- **Android improvements**, except where a shared-code change is required for parity.
- **New monetization products.** M17 defined the SKU set; M20 mirrors it.
- **Server-side receipt validation.** Deliberately not built on either platform
  (`docs/17_MONETIZATION.md` §4.4).
- **In-game string localization.** M12 owns it. Requirement 6.5 covers *listing* copy only.
