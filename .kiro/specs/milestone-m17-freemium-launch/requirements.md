# Requirements Document

## Introduction

Milestone M17 is the milestone where the game starts earning money. It attaches Google Play
Billing, a store surface, and opt-in rewarded advertisements to the entitlement system M16
already built and proved.

**This milestone is hard-gated on M13 having launched.** `AGENTS.md`, as amended 2026-08-27,
reads: "No paid feature ships before the M13 launch build." That is not a soft preference. The
sequence is deliberate — ship a complete, free, finished game first, let it be judged on its own
merits, and only then add a way to support it. Shipping monetization in the launch build would
invert the relationship the whole model depends on: `docs/00_VISION.md` §19, "players should pay
because they enjoy the game."

**What already exists and needs no work here.** M16 built `EntitlementManager`, the account-level
entitlement store, `CosmeticData`, `CosmeticCatalogue`, the wardrobe screen, and a single
`grant(id, source)` write path. M17 adds a fourth grant source — `purchase` — and must not
introduce a second write path. M15 built Supabase accounts and cloud sync, which is where
entitlements gain cross-device durability. M12 built the analytics pipeline the §6 targets are
measured with.

**What this milestone builds.** The billing integration behind a platform-abstracted interface
(so M20's StoreKit is an implementation of an existing seam, not a second billing system), the
store surface, restore-purchases, the ad SDK with its consent and age-gate prerequisites, the
three permitted rewarded-ad surfaces with their caps, refund revocation, and the legal/compliance
artifacts that shipping any of this requires.

Full context: `docs/17_MONETIZATION.md` is the design of record and **takes precedence over this
document** where they differ. Also `docs/00_VISION.md` §19/§19.1, `docs/20_PLATFORM_MATRIX.md` §4,
and `AGENTS.md`'s amended monetization rules and PR checklist.

---

## Prerequisites (external to this repo, needed before implementation starts)

1. **M13 must have shipped.** Not "be nearly done" — shipped.
2. A Google Play Console account with the app published (from M13), and the in-app products
   configured: the Supporter Pack as a **non-consumable managed product**, and each paid cosmetic
   likewise. No subscriptions, no consumables.
3. A license testing account configured in Play Console, so purchase and refund flows can be
   exercised without real money.
4. An ad network account (AdMob or equivalent) with rewarded-ad ad units created, plus its test
   ad unit ids for development.
5. A hosted privacy policy and terms URL — M13 already owns hosting these; M17 revises the content.
6. A decision on the support contact route (email address or form) for §4.3 layer 3.

---

## Glossary

- **Non-consumable managed product** — a store product bought once and owned forever. The only
  product type this game uses. There are no consumables and no subscriptions, because there is no
  currency and nothing is ever spent.
- **Billing interface** — the platform-agnostic seam (`IStoreBackend`-shaped) through which the
  game requests products, initiates purchase, and queries owned items. Play Billing implements it
  in M17; StoreKit implements it in M20. Game code never calls a platform SDK directly.
- **Rewarded surface** — one of the three (and only three) places the game may offer an
  advertisement, enumerated in `docs/17_MONETIZATION.md` §2.3.
- **Ad-free entitlement** — the entitlement granted by the Supporter Pack that causes every
  rewarded surface to grant its reward directly, with no advertisement, at the same value.
- **Revocation** — removing an entitlement because the store reported a refund or chargeback. The
  one and only circumstance in which an entitlement is ever removed.

---

## Requirements

### Requirement 1: Platform-abstracted billing

**User Story:** As a maintainer, I want billing behind one interface, so that adding iOS later is
an implementation rather than a second storefront.

#### Acceptance Criteria

1. THE system SHALL define a platform-agnostic billing interface covering: query products,
   initiate purchase, query owned items, and acknowledge a purchase.
2. Game code, UI, and `EntitlementManager` SHALL call only that interface and SHALL NOT reference
   a platform billing SDK directly.
3. THE system SHALL provide a Google Play Billing implementation of the interface.
4. THE system SHALL provide a no-op/stub implementation used on desktop and in tests, so the
   entire purchase state machine is testable headlessly.
5. IF billing is unavailable (no store, no network, unsupported platform) THE game SHALL remain
   fully playable and SHALL degrade to hiding store affordances, not to an error state.
6. A purchase SHALL be acknowledged to the store within the store's required window, and an
   unacknowledged purchase SHALL be re-acknowledged on next launch.

### Requirement 2: Purchase grants an entitlement

**User Story:** As a player, I want what I bought to appear immediately and stay mine.

#### Acceptance Criteria

1. A successful purchase SHALL grant its entitlement through M16's existing
   `EntitlementManager.grant()` — the system SHALL NOT introduce a second write path.
2. THE grant SHALL record `source: "purchase"` and the store order id.
3. Purchase grants SHALL be idempotent — a replayed or re-queried purchase SHALL NOT duplicate.
4. WHEN the Supporter Pack is purchased THE ad-free entitlement and every bundled cosmetic SHALL
   be granted atomically — a partial grant SHALL NOT be possible.
5. A cancelled or failed purchase SHALL grant nothing and SHALL return the player to where they
   were, with no error modal for a simple cancellation.
6. Purchase state SHALL survive the app being killed mid-flow.

### Requirement 3: Restore

**User Story:** As a player who reinstalled, I want my purchases back without contacting anyone.

#### Acceptance Criteria

1. ON launch THE system SHALL query owned non-consumables from the store and grant any missing
   entitlement, silently.
2. THE system SHALL provide an explicit "Restore purchases" action.
3. WHERE an M15 account is signed in THE system SHALL sync entitlements to and from the cloud, so
   they follow the account across devices.
4. IF M15 has not shipped THE system SHALL ship with store-restore and the manual support path
   only, and this SHALL be recorded as an explicit decision rather than a silent omission.
5. THE system SHALL provide a purchase-support screen surfacing the order id and the contact route.
6. WHEN store restore and cloud sync disagree THE union SHALL be taken — entitlements are never
   removed by a sync, only by Requirement 8 revocation.

### Requirement 4: The store surface

**User Story:** As a player, I want to see what I can buy without the game nagging me about it.

#### Acceptance Criteria

1. THE store SHALL be reachable from the wardrobe and from the main menu, and SHALL NOT be
   presented unprompted.
2. THE store SHALL display real localized prices fetched from the store, and SHALL NOT hardcode
   any price string.
3. THE store SHALL clearly mark owned items as owned and SHALL NOT offer them again.
4. THE store SHALL state, in plain language, that purchases are cosmetic and affect no gameplay.
5. THE store SHALL contain no countdown timer, no scarcity claim, no "limited time" framing, and
   no randomized reward.
6. THE store SHALL use the M9 theme, be responsive, and meet the mechanically-testable subset of
   `docs/18_ACCESSIBILITY.md` §6.
7. IF prices cannot be fetched THE store SHALL show an unavailable state rather than a wrong or
   placeholder price.

### Requirement 5: Age gate and consent, before any ad

**User Story:** As a parent, I want a game that does not serve my child targeted advertising.

#### Acceptance Criteria

1. THE system SHALL present an age gate before any advertisement is ever requested.
2. THE age gate SHALL be neutral — it SHALL NOT be phrased or defaulted to encourage an
   over-age answer.
3. WHERE the player is under the applicable age threshold THE system SHALL request only
   non-personalized advertising, or none, per the ad network's child-directed settings.
4. THE system SHALL present a UMP-equivalent consent flow in GDPR/DMA territories, with a genuine
   decline path that falls back to non-personalized ads rather than blocking play.
5. No advertisement SHALL be requested, and no advertising identifier SHALL be read, before both
   the age gate and consent have resolved.
6. THE player SHALL be able to review and change their consent choice later, from settings.

### Requirement 6: Rewarded advertisements

**User Story:** As a player, I want the option to watch an ad for a bonus, and to never be shown
one I did not ask for.

#### Acceptance Criteria

1. THE system SHALL implement exactly the three rewarded surfaces enumerated in
   `docs/17_MONETIZATION.md` §2.3, and no others.
2. No advertisement SHALL play except as the direct result of the player pressing a control whose
   label states that an advertisement will play.
3. THE system SHALL enforce the per-surface and per-day caps in that table.
4. WHEN the player declines an offer THE offer SHALL NOT be re-presented for that surface until
   its next natural occurrence, and THE system SHALL NOT present a confirmation prompt.
5. THE reward SHALL always be a bonus on an amount already granted — the system SHALL NOT reduce
   a baseline in order to sell its restoration.
6. No advertisement SHALL be offered during the tutorial, during the first session, or between a
   battle ending and its result being shown.
7. WHERE the ad-free entitlement is held THE reward SHALL be granted directly at the same value,
   with no advertisement and no delay.
8. IF an advertisement fails to load or fails to complete THE player SHALL NOT lose the offer or
   the underlying baseline reward.

### Requirement 7: Nothing gameplay-affecting is ever sold

**User Story:** As a player, I want to know the game is fair.

#### Acceptance Criteria

1. No purchasable product SHALL grant a stat, ship, captain, island, tech, region, chapter, or
   any gameplay-affecting value.
2. No advertisement reward SHALL grant anything beyond a bounded multiple of an amount the player
   already earned.
3. THE system SHALL NOT introduce a currency, wallet, or spendable balance.
4. THE system SHALL NOT introduce a timer whose removal is purchasable.
5. THE system SHALL NOT randomize any paid reward.
6. Any cosmetic sold SHALL retain its earnable path if one existed, per M16 Requirement 5.4.
7. THESE constraints SHALL be enforced by automated tests, not by review alone.

### Requirement 8: Refunds and revocation

#### Acceptance Criteria

1. WHEN the store reports a purchase as refunded or revoked THE system SHALL remove the
   corresponding entitlement.
2. Revocation SHALL NOT corrupt, truncate, or fail the save.
3. IF a revoked cosmetic is currently equipped THE system SHALL fall back to the default
   appearance without error.
4. Revocation SHALL be the only path that removes an entitlement.

### Requirement 9: Legal and compliance artifacts

#### Acceptance Criteria

1. THE privacy policy SHALL be revised to accurately describe advertising identifiers, purchase
   history, and any data the ad SDK collects.
2. THE terms SHALL be revised to cover purchases and refunds.
3. THE Play Console Data Safety declaration SHALL be updated before release.
4. THE system SHALL enumerate, in this spec, exactly what data the shipped build collects — so
   that the declaration is derived from fact rather than assumption.
5. Store price tiers SHALL be configured per market.

### Requirement 10: Measurement and the retention kill switch

#### Acceptance Criteria

1. THE system SHALL emit analytics events, through M12's pipeline, for: store opened, product
   viewed, purchase started, purchase completed, purchase cancelled, ad offered, ad accepted, ad
   declined, ad completed, ad failed.
2. THE system SHALL NOT emit any personally identifying data in these events.
3. D1 and D7 retention SHALL be compared before and after this milestone ships.
4. IF retention drops measurably THE monetization SHALL be rolled back rather than tuned for
   revenue — per `docs/17_MONETIZATION.md` §6.

### Requirement 11: Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an M17 section.
2. `docs/14_SYSTEM_INVENTORY.md` rows for billing, ads, consent, and age gate SHALL move off ❌.
3. `docs/17_MONETIZATION.md` SHALL be reconciled against what actually shipped, including final
   real prices.
4. `docs/20_PLATFORM_MATRIX.md` §4.1 SHALL be updated with the actual Play obligations met.

---

## Out of Scope

- **iOS and StoreKit.** M20. This milestone owes the *interface*, not a second implementation.
- **Battle Pass, season pass, premium account.** Deferred and not committed
  (`docs/00_VISION.md` §19.1).
- **Premium currency, wallets, balances.** Permanently banned.
- **Server-authoritative entitlement verification.** Deliberately not built —
  `docs/17_MONETIZATION.md` §4.4 explains why, and M21 covers the light integrity work instead.
- **Anti-cheat.** Same reasoning.
- **Banner or interstitial advertising of any kind.** Permanently banned.
- **New rewarded surfaces beyond the three enumerated.** Adding one requires amending
  `docs/17_MONETIZATION.md` first.
- **Retention mechanics.** M18 — and per `docs/19_RETENTION_AND_LIVEOPS.md` rule 8, retention
  surfaces must never contain a purchase prompt, so the two milestones stay deliberately apart.
- **New cosmetics.** M16 authored the catalogue; M17 prices part of it.
