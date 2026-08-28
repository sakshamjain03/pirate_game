# Implementation Plan: Milestone M17 — Freemium Launch

## Overview

**Hard gate: M13 must have shipped, and M16's final checkpoint must have passed.** `AGENTS.md`
(amended 2026-08-27) forbids any paid feature before the M13 launch build. This is not
negotiable by convenience, and a checkpoint that finds M13 unshipped stops the milestone.

Read `docs/17_MONETIZATION.md` in full — it is the design of record and outranks this spec where
they differ — then `docs/05_CURRENT_SYSTEMS.md`, then this spec's `design.md`, before Task 1. Pay
particular attention to `design.md` §5 (the ad permission state machine, where a mistake is a
compliance failure) and §6 (the reward-shape rule, where a mistake makes the game predatory).

Confirm every external prerequisite in `requirements.md` is in place before Wave 1 — a
half-configured Play Console will waste more time than it saves.

## Tasks

### Wave 0 — The seam, with no store attached

- [ ] 1. Create `scripts/core/IStoreBackend.gd` with exactly the signals and methods in
        `design.md` §3.
  - **Verify:** it compiles as part of a GUT run and no game code references a platform SDK.
  - _Requirements: 1.1, 1.2_

- [ ] 2. Create `scripts/core/StoreBackendStub.gd` modelling async emission, cancellation,
        failure, already-owned, and revocation — not just the happy path.
  - **Verify:** a scratch test drives all five outcomes and each emits the right signal on a later
    frame, never synchronously.
  - _Requirements: 1.4_

- [ ] 3. Create `scripts/core/ProductData.gd` (`Resource`: `sku`, `entitlement_ids`, `is_ad_free`)
        and author one `.tres` per planned SKU under `resources/store/`.
  - **Verify:** every `entitlement_ids` entry resolves in `CosmeticCatalogue`, or is the ad-free id.
  - _Requirements: 7.1_

- [ ] 4. Create `scripts/managers/StoreManager.gd` — backend selection (Play on Android, stub
        elsewhere), product catalogue, `IDLE`/`PENDING` state machine. Register in `[autoload]`.
  - **Verify:** full GUT suite passes at baseline; on desktop, `is_available()` is false and no
    store affordance appears.
  - _Requirements: 1.1, 1.5_

- [ ] 5. Add `EntitlementManager.grant_batch(ids, source, order_id)` — stage all, write once — and
        `revoke(id)`. Still one write path.
  - **Verify:** simulate a crash between two grants of a bundle; confirm the account file contains
    either all or none, never a partial bundle.
  - _Requirements: 2.1, 2.2, 2.4, 8.1, 8.4_

- [ ] 6. Write `tests/test_purchase_flow.gd` against the stub — success, cancel, fail, replayed
        purchase, bundle atomicity, revocation, survives-kill reconciliation.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 2.3, 2.5, 2.6, 8.1_

- [ ] 7. **Checkpoint — billing seam**
  - Full GUT suite at or above baseline.
  - Grep-confirm that no file outside `StoreBackendPlay.gd` references a platform billing SDK.
  - Confirm `EntitlementManager` still has exactly one write path and no quantity field.
  - Confirm the game is fully playable on desktop with billing unavailable.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.

### Wave 1 — Real billing

- [ ] 8. Implement `scripts/core/StoreBackendPlay.gd` against Google Play Billing.
  - **Verify:** on a device with a license-test account, `query_products` returns real localized
    prices. Report this as a **device** observation; it cannot be checked headlessly.
  - _Requirements: 1.3, 4.2_

- [ ] 9. Implement launch-time reconciliation — `query_owned()` on every launch, grant anything
        missing silently, acknowledge anything unacknowledged.
  - **Verify:** buy on a test account, clear app data, relaunch, confirm the entitlement returns
    with no user action.
  - _Requirements: 1.6, 3.1_

- [ ] 10. Implement explicit "Restore purchases" in settings, and the purchase-support screen
         surfacing order id and contact route.
  - **Verify:** restore on a device with a prior purchase reports what was restored.
  - _Requirements: 3.2, 3.5_

- [ ] 11. Implement entitlement cloud sync as a **union** if M15 has shipped. If it has not,
         implement layers 1 and 3 only and write that decision into `docs/17_MONETIZATION.md`
         §4.3 and this milestone's checkpoint notes.
  - **Verify:** either two devices converge to the union, or the decision is recorded in writing.
    Do not leave this ambiguous.
  - _Requirements: 3.3, 3.4, 3.6_

- [ ] 12. Implement refund revocation — store revoke signal removes the entitlement, equipped
         cosmetic falls back to default, save untouched.
  - **Verify:** refund a test purchase in Play Console with that cosmetic equipped; confirm the
    ship falls back cleanly with no null-material error (the V5 defect class) and the save loads.
  - _Requirements: 8.1, 8.2, 8.3_

### Wave 2 — The store surface

- [ ] 13. Build `scenes/ui/StoreScreen.tscn` + script — real fetched prices, owned marked and not
         re-offered, plain-language "cosmetic only, affects no gameplay" statement, M9 theme,
         anchor-based sizing.
  - **Verify:** render at 3 aspect ratios; confirm no hardcoded price string exists anywhere
    (grep for currency symbols in scenes and scripts).
  - _Requirements: 4.2, 4.3, 4.4, 4.6_

- [ ] 14. Implement the price-unavailable state — an unavailable label, never a placeholder or
         stale price.
  - **Verify:** run with the network disabled; confirm no number is shown.
  - _Requirements: 4.7_

- [ ] 15. Add store entry points from the wardrobe and main menu only, never unprompted, and
         confirm no countdown, scarcity claim, or randomized reward exists in the screen.
  - **Verify:** grep the scene for timer/countdown/limited/random nodes; expect zero. Play a full
    first session and confirm the store is never presented on its own.
  - _Requirements: 4.1, 4.5_

- [ ] 16. **Checkpoint — purchases work end to end**
  - Full GUT suite at or above baseline.
  - On a device: buy, own, restore, refund, and revoke a real test purchase — all four.
  - Confirm the Supporter Pack grants ad-free plus every bundled cosmetic atomically.
  - Explicitly list which checks were device-verified and which remain unverified.
  - Use the `checkpoint-reviewer` agent.

### Wave 3 — Permissions before ads

- [ ] 17. Implement `AdManager`'s permission state machine exactly per `design.md` §5, persisted
         at account level, with the SDK **not initialized** outside `READY_*`.
  - **Verify:** `tests/test_ad_gating.gd` asserts no SDK call, ad request, or advertising-id read
    occurs in `UNKNOWN`, `AGE_GATE_PENDING`, `CONSENT_PENDING`, or `CHILD_DIRECTED`.
  - _Requirements: 5.5_

- [ ] 18. Build the age gate — neutral phrasing, no pre-selected answer, never shown in the
         tutorial or first session.
  - **Verify:** fresh install; confirm the first session completes without the gate appearing, and
    that no answer is pre-highlighted when it does.
  - _Requirements: 5.1, 5.2, 5.3, 6.6_

- [ ] 19. Integrate the UMP-equivalent consent flow with a genuine decline path falling back to
         non-personalized ads, plus a settings entry to change the choice later.
  - **Verify:** on a device in a GDPR territory (or with the SDK's geography override), decline
    and confirm play continues with non-personalized ads.
  - _Requirements: 5.4, 5.6_

- [ ] 20. Write `tests/test_ad_gating.gd` covering every §5 invariant and every state transition.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 5.5_

### Wave 4 — Rewarded surfaces

- [ ] 21. Implement the caps ledger (account-level, day-bucketed) and the three registered
         surfaces. No surface may count for itself.
  - **Verify:** exhaust each cap; confirm the offer stops appearing and rolls over at local
    midnight.
  - _Requirements: 6.1, 6.3_

- [ ] 22. Implement the offline-return, event-reroll, and post-battle surfaces using the
         **bonus-on-top** shape in `design.md` §6. The baseline grant must be identical with the
         ad path fully disabled.
  - **Verify:** `test_monetization_invariants.gd` asserts byte-identical baseline rewards with ads
    disabled versus enabled. This is the assertion that keeps the game non-predatory — do not
    weaken it.
  - _Requirements: 6.2, 6.5_

- [ ] 23. Implement decline behaviour (no re-prompt, no confirmation dialog), failure behaviour
         (no loss of baseline or offer), and the ad-free short-circuit granting directly.
  - **Verify:** decline an offer and confirm it is not re-presented; force an ad-load failure and
    confirm the player keeps the baseline and the offer.
  - _Requirements: 6.4, 6.7, 6.8_

- [ ] 24. Write `tests/test_monetization_invariants.gd` covering the whole `design.md` §9 table.
  - **Verify:** the single-file GUT run passes, and deliberately introducing a stat-granting
    product makes it fail.
  - _Requirements: 7.1, 7.3, 7.5, 7.6, 7.7_

- [ ] 25. **Checkpoint — ads work and are not predatory**
  - Full GUT suite at or above baseline.
  - Confirm on a device that no advertisement can appear without a labelled button press.
  - Confirm the tutorial and entire first session contain zero ad offers.
  - Confirm every baseline reward is unchanged with ads disabled — verified by test, not by eye.
  - Use the `checkpoint-reviewer` agent.

### Wave 5 — Compliance, measurement, documentation

- [ ] 26. Enumerate, in this spec, exactly what data the shipped build collects, then revise the
         privacy policy and terms to match, and update the Play Data Safety declaration.
  - **Verify:** each declared item traces to a real code path; each real collection point appears
    in the declaration. Derived from fact, not assumption.
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 27. Configure store price tiers per market in Play Console.
  - **Verify:** prices render correctly in at least two locales on a device.
  - _Requirements: 9.5_

- [ ] 28. Emit the Requirement 10.1 analytics events through M12's pipeline, with no personally
         identifying data.
  - **Verify:** trigger each event and confirm it appears with no PII in the payload.
  - _Requirements: 10.1, 10.2_

- [ ] 29. Update `docs/05_CURRENT_SYSTEMS.md` (M17 section), `docs/14_SYSTEM_INVENTORY.md`
         (billing/ads/consent/age-gate rows), `docs/17_MONETIZATION.md` (real shipped prices), and
         `docs/20_PLATFORM_MATRIX.md` §4.1.
  - **Verify:** run the `sync-systems-doc` skill; expect no undocumented M17 system.
  - _Requirements: 11.1, 11.2, 11.3, 11.4_

- [ ] 30. **Checkpoint — M17 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Walk `docs/17_MONETIZATION.md` §7's ten-question reviewer checklist against the whole
    milestone diff. Any "yes" blocks the milestone.
  - Confirm no currency, wallet, or spendable balance exists anywhere.
  - Confirm the M15-dependency decision from Task 11 is recorded in writing.
  - Record the pre-M17 D1/D7 retention baseline so Requirement 10.3 can actually be compared
    after release — this cannot be reconstructed later.
  - Explicitly list every check that was device-verified versus unverified, per `CLAUDE.md`.
  - Use the `checkpoint-reviewer` agent.

## Notes

- **The single most dangerous task in this milestone is 22.** The difference between "watch an ad
  to double your income" and "we halved your income, watch an ad to get it back" is invisible in
  a screenshot and total in what kind of game this is. `test_monetization_invariants.gd`'s
  identical-baseline assertion is the only thing standing between the two, and it must never be
  relaxed to make a task pass.
- **Task 17 is a compliance surface, not a feature.** Requesting an ad before consent resolves is
  a policy violation with real consequences, and it fails silently in development because test ad
  units serve regardless. The state machine and its test are the mitigation.
- Wave 0 has no external dependency at all and can be built before the Play Console work is ready.
  Waves 1 and 3 both need real accounts configured.
- Waves 3–4 (ads) and Waves 1–2 (billing) are independent after Wave 0 and can be reordered. If ad
  network approval is slow, do billing first — the Supporter Pack is the anchor revenue anyway.
- **After release, Requirement 10.4 is a standing obligation, not a task.** If D1/D7 retention
  drops, the monetization gets rolled back. Whoever is holding this project at that moment should
  know that was decided in advance, deliberately, and is not up for renegotiation against a
  revenue number.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4", "5", "6", "7"] },
    { "id": 1, "tasks": ["8", "9", "10", "11", "12"] },
    { "id": 2, "tasks": ["13", "14", "15", "16"] },
    { "id": 3, "tasks": ["17", "18", "19", "20"] },
    { "id": 4, "tasks": ["21", "22", "23", "24", "25"] },
    { "id": 5, "tasks": ["26", "27", "28", "29", "30"] }
  ]
}
```
