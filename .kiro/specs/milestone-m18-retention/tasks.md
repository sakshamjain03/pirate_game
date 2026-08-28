# Implementation Plan: Milestone M18 — Retention & Re-engagement

## Overview

Depends on **M12** (analytics pipeline and local-notification capability) and **M16**
(`EntitlementManager`, for streak cosmetic grants). M17 is not a hard dependency — if it has not
shipped, build every surface without the offline ad affordance and add it later.

Read `docs/19_RETENTION_AND_LIVEOPS.md` in full before Task 1 — it is the design of record and
outranks this spec where they differ. Its §7 rules are not aspirational; §7 of this spec's
`design.md` turns five of them into tests.

Scaffolded 2026-08-27 as a forward-planning artifact alongside M16–M21. Rule 8 (milestones are
strictly sequential) still governs — do not start this ahead of its predecessors.

## Tasks

### Wave 0 — Streak

- [ ] 1. Create `scripts/managers/RetentionManager.gd` with account-scoped streak state per
        `design.md` §3, registered in `[autoload]`.
  - **Verify:** full GUT suite passes at baseline; streak state survives starting a new game.
  - _Requirements: 1.7_

- [ ] 2. Implement the streak advance/step-back rule — local date comparison, same-day no-op,
        `max(0, tier - 1)` on a gap, `highest_tier` tracked.
  - **Verify:** `test_retention_streak.gd` asserts a 30-day gap steps back exactly one tier;
    asserts two sessions on one local day award once; asserts a backwards clock is not a gap.
  - _Requirements: 1.1, 1.2, 1.8_

- [ ] 3. Hook session start — **not** `SaveManager.game_loaded`, which fires on every load and has
        existing subscribers with side effects (D15).
  - **Verify:** load a save three times in one session; confirm exactly one streak evaluation.
  - _Requirements: 1.1_

- [ ] 4. Implement tier rewards at 1, 2, 3, 5, 7 and every 7th, with day 7 granting a cosmetic
        through `EntitlementManager.grant()`.
  - **Verify:** reach tier 7 and confirm the cosmetic appears in the wardrobe as owned.
  - _Requirements: 1.4, 1.5_

- [ ] 5. Build `CaptainsLogPanel` — shows what is **next**, never a countdown or expiry warning,
        M9 theme, anchor-based sizing, no purchase affordance.
  - **Verify:** grep the scene for timer/countdown/expire/price/buy nodes; expect zero hits.
  - _Requirements: 1.3, 1.6_

- [ ] 6. Write `tests/test_retention_streak.gd` covering every §3 case including the timezone and
        clock-skew hazards.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 1.1, 1.2, 1.8_

### Wave 1 — Goals and comeback

- [ ] 7. Create `scripts/core/WeeklyGoalData.gd` per `design.md` §4 and author a pool of at least
        9 goals across all 5 metrics.
  - **Verify:** every authored `.tres` matches the schema and every `metric` maps to a real
    existing signal.
  - _Requirements: 3.2, 3.3_

- [ ] 8. Implement goal selection (3 per week), signal connection, and progress — connecting to
        existing signals, adding no parallel counters.
  - **Verify:** sink an enemy and confirm the matching goal advances by exactly one, with no
    double-count from a second subscriber.
  - _Requirements: 3.1, 3.2_

- [ ] 9. Implement silent weekly rotation — disconnect, discard, reselect. No penalty screen, no
        summary, no notification.
  - **Verify:** advance the clock past a week boundary with goals incomplete; confirm nothing is
    shown to the player about the failure.
  - _Requirements: 3.5_

- [ ] 10. Build `WeeklyGoalsPanel` — progress, rewards, no purchase affordance.
  - **Verify:** grep for store/price/purchase nodes; expect zero.
  - _Requirements: 3.6, 3.7_

- [ ] 11. Implement comeback — bounded catch-up after 7+ days, streak tier restored from
         `highest_tier`, one summary shown once, no apology or guilt framing.
  - **Verify:** simulate a 21-day absence; confirm the tier is restored, the summary appears once,
    and does not reappear on the next launch.
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 12. Write `tests/test_weekly_goals.gd`.
  - **Verify:** the single-file GUT run passes.
  - _Requirements: 3.1, 3.4, 3.5_

- [ ] 13. **Checkpoint — streak, goals, comeback**
  - Full GUT suite at or above baseline.
  - Confirm by test that a 30-day gap steps back one tier and never to zero — the single most
    important behaviour in this milestone.
  - Confirm no retention scene contains any store, price, or purchase node.
  - Use the `checkpoint-reviewer` agent, per Rules 3/4/8.

### Wave 2 — Offline return, notifications, feedback

- [ ] 14. Reframe and theme the offline-return panel to the M9 style with anchor-based sizing,
         closing visual bug **V13**.
  - **Verify:** headful render at 3 aspect ratios and at 200% text scale. Report this as a real
    visual observation, not a headless inference (`CLAUDE.md`).
  - _Requirements: 2.3, 2.5, 9.4_

- [ ] 15. Extend the panel's summary — buildings that ticked, fleets returned, raids resolved,
         one next action — drawn from existing post-catch-up state with no new tracking.
  - **Verify:** return after a simulated 3-hour absence and confirm each line matches what
    actually happened.
  - _Requirements: 2.1, 2.2_

- [ ] 16. Create `NotificationScheduler` owning the one-per-24h rule, quiet hours, the permitted
         kind list, and a `push_error` on any banned kind.
  - **Verify:** `test_notification_rules.gd` asserts a second same-day schedule is refused, a
    quiet-hours schedule is refused, and a sale-kind schedule raises an error.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 17. Implement lazy opt-in permission (never in the first session) and a settings toggle to
         disable notifications entirely.
  - **Verify:** complete a full first session on a fresh install with no permission prompt.
  - _Requirements: 5.6, 5.7_

- [ ] 18. Build `FeedbackScreen` — free text, chapter, region, build version, device model;
         explicit preview and decline for any log attachment; draft preserved on failure.
  - **Verify:** submit with the network disabled and confirm the draft survives a restart.
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 19. Write `tests/test_notification_rules.gd` and `tests/test_retention_invariants.gd`
         covering the whole `design.md` §7 table.
  - **Verify:** both single-file GUT runs pass; deliberately adding a decay-on-time code path
    makes the invariant test fail.
  - _Requirements: 5.1, 5.2, 8.1, 8.2_

### Wave 3 — Acting on the funnel (blocked on real telemetry)

- [ ] 20. From released M12 telemetry, identify the largest drop-off step in the tutorial and
         first session, and address it.
  - **Verify:** name the step, the measured drop-off, and the change made. **If no released
    telemetry exists, this task blocks** — do not substitute intuition (`design.md` §8).
  - _Requirements: 7.1_

- [ ] 21. Identify the chapter objective with the highest abandon rate and rebalance it.
  - **Verify:** same standard — a named objective, a measured rate, a specific change.
  - _Requirements: 7.2_

- [ ] 22. Record the pre-change baselines so Requirement 7.3's re-measurement is possible after
         the next release.
  - **Verify:** the baselines are written down somewhere durable, not left in a session.
  - _Requirements: 7.3, 7.4_

### Wave 4 — Documentation and final checkpoint

- [ ] 23. Update `docs/05_CURRENT_SYSTEMS.md` (M18 section), `docs/14_SYSTEM_INVENTORY.md`
         (retention/notification/feedback rows), `docs/19_RETENTION_AND_LIVEOPS.md`
         (reconcile with what shipped), and `docs/09_VISUAL_BUG_TRACKER.md` (close V13).
  - **Verify:** run the `sync-systems-doc` skill; expect no undocumented M18 system.
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 24. **Checkpoint — M18 complete**
  - Full GUT suite at or above baseline, zero new failures.
  - Walk `docs/19_RETENTION_AND_LIVEOPS.md` §7's ten rules against the whole diff.
  - Confirm by test that nothing decays as a function of time away.
  - Confirm a playthrough ignoring every retention feature still reaches the final chapter.
  - State explicitly whether Wave 3 ran on real telemetry or was blocked — do not let a blocked
    analysis wave be quietly reported as complete.
  - Use the `checkpoint-reviewer` agent.

## Notes

- **Task 2's `max(0, tier - 1)` is the milestone.** Everything else here is ordinary UI work. That
  one line is the difference between a game that welcomes you back and one that punishes you for
  having a life, and it is the kind of thing that gets "simplified" to `tier = 0` by someone who
  did not read why. `test_retention_streak.gd` exists to stop that.
- **Wave 3 is analysis, not implementation**, and depends on released telemetry that may simply
  not exist yet. Blocking is the correct outcome in that case. A rebalance justified by
  imagined data is worse than none, because it will be trusted.
- Wave 0, Wave 1, and Wave 2's notification/feedback work are largely independent and can be
  reordered. The offline panel (Tasks 14–15) touches the same scene M17's ad surface does — if
  both milestones are in flight, sequence them rather than interleaving.
- Rule 8 (no monetization inside a retention surface) is enforced by test in Task 19. The single
  permitted exception is the offline panel's ad surface, which belongs to M17. Do not let that
  exception widen.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2", "3", "4", "5", "6"] },
    { "id": 1, "tasks": ["7", "8", "9", "10", "11", "12", "13"] },
    { "id": 2, "tasks": ["14", "15", "16", "17", "18", "19"] },
    { "id": 3, "tasks": ["20", "21", "22"] },
    { "id": 4, "tasks": ["23", "24"] }
  ]
}
```
