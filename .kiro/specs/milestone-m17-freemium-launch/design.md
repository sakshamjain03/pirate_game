# Design Document: Milestone M17 — Freemium Launch

## 1. Why this design shape

Three principles drive every decision here.

**One write path.** M16 established `EntitlementManager.grant(id, source)` as the single way an
entitlement comes into existence. M17 adds a fourth `source` value and changes nothing else about
it. A purchase is not a special kind of ownership — it is an ordinary entitlement with a
different provenance. This is what keeps restore, cloud sync, and refund revocation from each
needing their own bespoke handling.

**One seam, two platforms.** Play Billing in M17 and StoreKit in M20 implement the same interface.
`AGENTS.md` forbids duplicating systems, and two parallel billing paths is the textbook case. The
interface is designed now, while there is only one implementation to shape it, rather than
retrofitted later when there are two.

**The ad system is a permission system first.** The ordering — age gate, then consent, then
initialization, then any request — is a legal requirement, not a UX preference, and it is the
part of this milestone most likely to be got subtly wrong. §5 specifies it as a state machine so
that "did we already check?" is never an implicit question.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/core/IStoreBackend.gd` | **New.** The platform-agnostic billing interface. |
| `scripts/core/StoreBackendStub.gd` | **New.** Deterministic no-op implementation for desktop and tests. |
| `scripts/core/StoreBackendPlay.gd` | **New.** Google Play Billing implementation. |
| `scripts/managers/StoreManager.gd` | **New.** Autoload. Owns product catalogue, purchase state machine, restore, acknowledgement, revocation. |
| `scripts/managers/AdManager.gd` | **New.** Autoload. Owns the consent/age state machine, ad loading, the three surfaces, and the caps ledger. |
| `scripts/managers/EntitlementManager.gd` | **Changed.** Accept `source: "purchase"` plus order id. Add `revoke()`. No new write path. |
| `scripts/core/ProductData.gd` | **New.** `Resource` mapping a store SKU to the entitlement id(s) it grants. |
| `resources/store/*.tres` | **New.** One `ProductData` per SKU. |
| `scripts/ui/StoreScreen.gd` + `scenes/ui/StoreScreen.tscn` | **New.** |
| `scripts/ui/AgeGate.gd`, `scripts/ui/ConsentPanel.gd` + scenes | **New.** |
| `scripts/ui/PurchaseSupportScreen.gd` + scene | **New.** |
| `scripts/ui/WardrobeScreen.gd` | **Changed.** Gains the store entry point M16 Requirement 4.5 forbade. |
| `scripts/ui/SettingsMenu.gd` | **Changed.** Consent review, restore purchases, support entry. |
| `tests/test_store_backend.gd`, `test_purchase_flow.gd`, `test_ad_gating.gd`, `test_monetization_invariants.gd` | **New.** Flat under `tests/`. |

## 3. The billing interface

```gdscript
class_name IStoreBackend extends RefCounted

signal products_ready(products: Array)          # [{sku, price_string, title}]
signal purchase_completed(sku: StringName, order_id: String)
signal purchase_cancelled(sku: StringName)
signal purchase_failed(sku: StringName, reason: String)
signal owned_items_ready(skus: Array)
signal item_revoked(sku: StringName)

func is_available() -> bool:            return false
func query_products(skus: Array) -> void:    pass
func begin_purchase(sku: StringName) -> void: pass
func query_owned() -> void:              pass
func acknowledge(order_id: String) -> void:   pass
```

`StoreManager` selects an implementation once at startup: Play on Android, stub everywhere else.
Nothing above `StoreManager` ever learns which one it got — that is what makes Requirement 1.4's
headless testability work, and what makes M20 an implementation task rather than a design task.

**`StoreBackendStub` is not a throwaway.** It is the reason the entire purchase state machine can
be tested in GUT. It must model the real thing faithfully: async signal emission (never
synchronous returns), cancellations, failures, an already-owned response, and a revocation. A
stub that only models the happy path tests nothing worth testing.

## 4. Purchase flow

```
 player taps Buy
   → StoreManager.begin_purchase(sku)              state: IDLE → PENDING
   → backend.purchase_completed(sku, order_id)
   → resolve ProductData for sku
   → for each entitlement id in product:
         EntitlementManager.grant(id, "purchase", order_id)   ← M16's only write path
   → EntitlementManager writes account data eagerly
   → backend.acknowledge(order_id)                 state: PENDING → IDLE
   → StoreScreen refreshes from entitlement state, not from a local flag
```

**Atomicity (Requirement 2.4).** The Supporter Pack grants several entitlements. They are written
as one `_write_account_data()` call after all `grant()`s have been staged, not one write per
grant — otherwise a crash mid-bundle leaves a player who paid for four things owning two.
`EntitlementManager` gains a `grant_batch(ids, source, order_id)` that stages then writes once.
This is the one addition to M16's API, and it is still a single write path.

**Acknowledgement (Requirement 1.6).** Play revokes and refunds a purchase that is not
acknowledged within its window. `StoreManager` re-runs `query_owned()` on every launch and
acknowledges anything unacknowledged. This is also what makes Requirement 2.6 (survives being
killed mid-flow) work: the purchase is durable on the store's side before the app knows about it,
and the launch-time reconciliation is the recovery path.

**Idempotence (Requirement 2.3)** comes for free from M16's `grant()` guard. The launch-time
`query_owned()` will replay every past purchase on every single launch; that must be silent and
cheap, not a stream of re-grants and signals.

**Cancellation (Requirement 2.5)** shows no modal. A player who backed out of a purchase knows
they backed out. An error dialog there reads as a nag.

## 5. The ad permission state machine

This is specified as an explicit state machine because "have we asked yet?" being implicit is how
a build ends up requesting an ad before consent — a real compliance failure, not a bug report.

```
UNKNOWN ──(first launch, not in tutorial, not first session)──► AGE_GATE_PENDING
AGE_GATE_PENDING ──(player answers)──► CONSENT_PENDING | CHILD_DIRECTED
CONSENT_PENDING ──(UMP resolves)──► READY_PERSONALIZED | READY_NONPERSONALIZED
CHILD_DIRECTED ──────────────────► READY_NONPERSONALIZED
any ──(player changes choice in settings)──► CONSENT_PENDING
```

**Invariants, asserted by `test_ad_gating.gd`:**

1. `AdManager` MUST NOT initialize the ad SDK, request an ad, or read an advertising identifier
   in any state other than `READY_*`. Requirement 5.5 is the whole point of this machine.
2. The state is persisted at **account level** (alongside entitlements, per M16 §3.1), not in the
   save. A new campaign must not re-ask a player their age.
3. `UNKNOWN` is the startup state and is entered on a fresh install. It never blocks play — the
   game is fully playable having never resolved past `UNKNOWN`, because ads are optional.
4. The age gate is neutrally phrased with no pre-selected answer (Requirement 5.2).

## 6. Rewarded surfaces and the caps ledger

Exactly three surfaces (`docs/17_MONETIZATION.md` §2.3). Each registers with `AdManager` by name;
`AdManager` owns the ledger, so no surface can accidentally implement its own counting.

```gdscript
# account-level, day-bucketed by local date
{ "ad_ledger": { "2026-08-27": { "offline_double": 1, "event_reroll": 0, "salvage_double": 2 } } }
```

**The reward-shape rule (Requirement 6.5) is the one that matters most.** The bonus is always
computed on an amount the player *has already been granted*:

```gdscript
# CORRECT — baseline already granted, ad adds a bonus on top
ResourceManager.add(offline_income)                       # happens regardless
if player_accepts_ad and ad_completed:
    ResourceManager.add(offline_income)                   # the bonus

# BANNED — baseline reduced so the ad restores it
ResourceManager.add(offline_income * 0.5)
if player_accepts_ad: ResourceManager.add(offline_income * 0.5)
```

The second form is a forced advertisement wearing a costume. It is banned by
`docs/17_MONETIZATION.md` §2.3 and asserted against in `test_monetization_invariants.gd`: the
baseline grant must be observable with the ad path entirely disabled, and must be identical.

**Ad-free short-circuit (Requirement 6.7).** With the ad-free entitlement held, the surface still
appears and still grants the bonus — it simply grants it immediately with no advertisement. It is
not hidden. The supporter is not shown a worse version of the offer; they are shown a better one.

**Failure (Requirement 6.8).** A failed load or an abandoned ad costs the player nothing: the
baseline was already granted, the cap is not decremented, and the offer stays available.

## 7. Revocation

The only removal path (Requirement 8.4).

```gdscript
func revoke(id: StringName) -> void:
    if not _entitlements.has(id): return
    _entitlements.erase(id)
    _write_account_data()
    entitlement_revoked.emit(id)
```

Two hazards:

- **Equipped-cosmetic fallback (8.3).** `ShipVisuals` must already handle an unresolvable cosmetic
  id by falling back to default appearance — M16 Requirement 3.6 built exactly that, for the
  missing-resource case. Revocation reuses it rather than adding a second fallback path. Verify
  it actually fires here; a null-material error at this point is the V5 defect class.
- **Save integrity (8.2).** Revocation touches account data only. It must never write to
  `user://save_data.json`, and must never run inside a save or load operation — `SaveManager` has
  documented load-order sensitivity (D64).

## 8. Cloud sync of entitlements

Layer 2 of `docs/17_MONETIZATION.md` §4.3, and the only part of this milestone with an external
dependency.

**Union, never intersection (Requirement 3.6).** Sync adds; it never removes. If the device has
an entitlement the cloud does not, it is pushed. If the cloud has one the device does not, it is
pulled. Disagreement is always resolved in the player's favour. Only §7 revocation removes.

**If M15 has not shipped (Requirement 3.4):** ship layers 1 and 3 only, write that decision into
`docs/17_MONETIZATION.md` §4.3 and into the M17 checkpoint notes, and do not leave it implicit.
Store restore alone genuinely covers reinstall on the same store account, which is the common
case; it does not cover a platform switch, which is what layer 2 adds.

## 9. Enforcing "nothing gameplay-affecting is sold"

Requirement 7.7 demands automated enforcement, because review alone will not survive twenty more
milestones. `tests/test_monetization_invariants.gd`:

| Assertion | Catches |
|---|---|
| Every `ProductData` maps only to entitlement ids that resolve to `CosmeticData` or the ad-free flag | Selling a stat |
| No `CosmeticData` in the catalogue has a non-schema property | The D3/D14 typo class, and a smuggled stat |
| `EntitlementManager` exposes no quantity, count, or balance field | A currency creeping in |
| With ads force-disabled, every baseline reward is byte-identical to with them enabled | The §6 reduced-baseline pattern |
| No scene under `scenes/ui/` whose name matches the retention surfaces contains a store node | `docs/19_RETENTION_AND_LIVEOPS.md` rule 8 |
| Every sold cosmetic that M16 recorded an earnable path for still has one | Requirement 7.6 |

## 10. What cannot be verified headlessly

Per `CLAUDE.md`, stated plainly rather than claimed:

**Testable in GUT:** the whole purchase state machine against the stub, grant/revoke/idempotence,
the ad permission state machine, the caps ledger, reward-shape invariants, store screen layout.

**Requires a device and a license-test account:** real Play Billing purchase, real refund
revocation, real ad fill and completion, the UMP consent dialog, the age gate on a real screen,
localized price fetching, and acknowledgement-window behaviour. None of these may be reported as
passing on the strength of a headless run.
