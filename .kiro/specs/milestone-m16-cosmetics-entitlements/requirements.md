# Requirements Document

## Introduction

Milestone M16 builds the **cosmetic and entitlement system**, and ships every cosmetic in it for
free. No money changes hands in this milestone. That is deliberate: M17 attaches billing to this
system, and attaching billing to an unproven system is how storefronts ship broken. Build the
thing that will be sold, prove it works, then sell it.

This milestone is the first that exists under the amended `AGENTS.md`. Until 2026-08-27 the
constitution read "Never introduce paid features" / "Never introduce new currencies", which
contradicted `docs/00_VISION.md` §19's monetization philosophy and was inherited as a Non-Goal
into every spec from M9 to M15. That rule is now scoped: no paid feature ships before the M13
launch build, and monetization after it is bounded by `docs/00_VISION.md` §19.1 and
`docs/17_MONETIZATION.md`. **M16 ships no paid feature and therefore has no dependency on M13
having launched** — but M17 does, absolutely.

**What already exists and needs no work here.** `SaveManager` and the manager-level
`get_save_data()` / `load_save_data()` convention are built and working. `ShipVisuals` already
owns material application on ships and is the correct integration point for a hull skin — this
milestone must extend it, not build a parallel visual path (`AGENTS.md`: never duplicate
systems). `KenneyMaterialApplier` already handles tinting and theme override (D23/D24). The M9
themed-screen style is the pattern any new UI must follow. Island decoration `Marker3D` slots
already exist for buildings; `Island.gd`'s slot-snapping is the model for decoration placement.

**What does not exist and this milestone builds.** Any concept of the player *owning* a thing
that is not a save-game value. Any cosmetic data type. Any equip or preview surface.

Full context: `docs/17_MONETIZATION.md` (the model of record, especially §2.1 and §4),
`docs/00_VISION.md` §19.1, `docs/14_SYSTEM_INVENTORY.md`, `docs/05_CURRENT_SYSTEMS.md`.

---

## Glossary

- **Entitlement** — a durable, one-time, non-consumable, non-tradeable record that the player
  owns something. Account-scoped, never save-scoped. Never spent, never decremented. It is
  explicitly **not** a currency and must never acquire a balance.
- **Cosmetic** — a purely visual item defined by a `CosmeticData` resource. Changes appearance
  and nothing else. Never a stat, a hitbox, a collision shape, or a readability cue.
- **Account-scoped storage** — persistence that lives outside any save slot, survives starting a
  new game, and survives deleting every save. Distinct from the per-slot data `SaveManager`
  already round-trips.
- **Slot (cosmetic)** — a named appearance channel on an entity: `hull`, `sails`, `flag`,
  `figurehead` on a ship; `decoration` on an island. One equipped cosmetic per slot per entity.
- **Grant** — the act of conferring an entitlement. In M16 every grant is free (default,
  achievement, or streak). In M17 a grant may additionally originate from a purchase. The grant
  *path* differs; the entitlement it produces is identical.

---

## Requirements

### Requirement 1: Entitlement storage that survives a new game

**User Story:** As a player, I want the things I own to still be mine when I start a new
campaign, so that my collection is not punished for replaying the game.

#### Acceptance Criteria

1. THE system SHALL provide an `EntitlementManager` autoload that owns all entitlement state.
2. `EntitlementManager` SHALL persist to an **account-level** store, separate from any save slot.
3. WHEN a new game is started THE entitlement set SHALL be unchanged.
4. WHEN every save slot is deleted THE entitlement set SHALL be unchanged.
5. `EntitlementManager` SHALL expose `get_save_data()` and `load_save_data()` matching the
   existing manager convention, so its serialization is consistent with every other manager even
   though its destination differs.
6. THE entitlement record SHALL store, per entitlement: its id, the grant source, and the grant
   timestamp — and SHALL NOT store any quantity, count, or balance field.
7. IF the account store is missing or unreadable THE system SHALL start with the default
   entitlement set and SHALL NOT block startup or corrupt save loading.
8. `EntitlementManager` SHALL emit `entitlement_granted(id)` and SHALL NOT require polling.

### Requirement 2: Cosmetic data as resources

**User Story:** As a designer, I want to add a cosmetic by authoring a file, so that the
catalogue can grow without a script change.

#### Acceptance Criteria

1. THE system SHALL define a `CosmeticData` script whose `@export`ed fields are the complete
   schema, per the D3/D14 silent-failure hazard.
2. `CosmeticData` SHALL carry: `id`, `display_name`, `description`, `slot`, `rarity_label`,
   the visual payload (material/texture/mesh reference as appropriate to the slot), an icon, and
   a `default_owned` flag.
3. `CosmeticData` SHALL NOT contain any field that could affect gameplay — no stat, no modifier,
   no collision or hitbox reference.
4. WHEN a new `CosmeticData` `.tres` is added to the catalogue directory THE system SHALL list it
   without any script change.
5. THE system SHALL author at least **10** cosmetics across at least **4** slots.
6. IF two `CosmeticData` resources declare the same `id` THE system SHALL report the collision at
   load rather than silently preferring one.

### Requirement 3: Equipping and appearance

**User Story:** As a player, I want to change how my ship looks, so that my flagship feels like
mine.

#### Acceptance Criteria

1. THE system SHALL support exactly one equipped cosmetic per slot per entity.
2. WHEN a cosmetic is equipped THE ship's appearance SHALL update without requiring a scene
   reload.
3. Cosmetic appearance SHALL be applied through the existing `ShipVisuals` material path and
   SHALL NOT introduce a second visual-application system.
4. WHEN a cosmetic is equipped and damage visuals are active THE damage state SHALL remain
   readable, and the damage overlay SHALL take precedence over the cosmetic's appearance.
5. Equipped-cosmetic *selection* SHALL persist in the save slot; entitlement *ownership* SHALL
   persist at account level. IF a save references a cosmetic the account does not own THE system
   SHALL fall back to the default appearance without error.
6. IF a cosmetic resource referenced by a save is missing THE system SHALL fall back to the
   default appearance and SHALL NOT crash or produce a null-material error.

### Requirement 4: The wardrobe screen

**User Story:** As a player, I want to browse and preview cosmetics before equipping them, so
that I can see what I have.

#### Acceptance Criteria

1. THE system SHALL provide a wardrobe screen reachable from the existing menu structure.
2. THE wardrobe SHALL group cosmetics by slot and SHALL indicate owned versus not-yet-owned.
3. THE wardrobe SHALL preview a cosmetic before it is equipped.
4. THE wardrobe SHALL use the M9 theme and SHALL be responsive rather than fixed-pixel, per the
   V17 precedent.
5. THE wardrobe SHALL contain **no** purchase affordance, price, store link, or currency display
   in this milestone.
6. THE wardrobe SHALL satisfy the `docs/18_ACCESSIBILITY.md` §6 checklist items that are
   mechanically testable (contrast, colour-alone, touch target size, text reflow, gamepad
   navigation).

### Requirement 5: Free grant paths

**User Story:** As a player, I want to earn cosmetics by playing, so that the collection is part
of the game rather than a shop window.

#### Acceptance Criteria

1. THE system SHALL grant all `default_owned` cosmetics on first run.
2. THE system SHALL grant at least **3** cosmetics through play — tied to existing signals
   (a chapter completion, a boss defeat, a first island capture) rather than new bookkeeping.
3. WHEN a grant condition is met a second time THE system SHALL NOT duplicate the entitlement.
4. THE earnable path for any cosmetic granted through play SHALL be recorded in
   `docs/17_MONETIZATION.md` so that M17 cannot later sell it without preserving that path.

### Requirement 6: Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an M16 section describing what was actually built.
2. `docs/14_SYSTEM_INVENTORY.md` SHALL have its cosmetic/entitlement rows updated from ❌.
3. `docs/10_ASSET_REQUESTS.md` SHALL gain a cosmetic art category with the authored set listed.
4. `docs/17_MONETIZATION.md` §2.1 SHALL be reconciled against the cosmetics actually authored.

---

## Out of Scope

- **All billing, pricing, store UI, and purchase flow.** That is M17 and requires M13 to have
  launched first. Nothing in this milestone may reference money.
- **Rewarded advertisements.** M17.
- **Premium currency, wallets, balances.** Permanently banned (`AGENTS.md`,
  `docs/17_MONETIZATION.md` §3).
- **Cloud sync of entitlements.** Depends on M15; handled in M17 §4.3 layer 2.
- **Cosmetics that affect gameplay in any way.** Permanently banned.
- **Final production art.** M16 authors cosmetics using the existing Kenney-derived material
  pipeline; bespoke art is an asset request, tracked in doc 10, not a blocker here.
- **Island decoration slots beyond what `Island.gd` already provides.** No new free-placement
  system (still ❌ in doc 14, still out of scope).
- **The accessibility items requiring a headful pass** (one-handed reach, captions, reduced
  motion). Those are M19; M16 only owes the mechanically-testable subset.
