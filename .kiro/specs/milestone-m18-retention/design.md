# Design Document: Milestone M18 — Retention & Re-engagement

## 1. Why this design shape

**Reward, never punish.** Every mechanism below is designed so that a player's absence is
neutral. This is not decoration on the design — it determines the data model. A system that
tracks "days since last play" in order to subtract something needs different state from one that
tracks it in order to welcome someone back. This milestone builds the second kind, and
`test_retention_invariants.gd` (§7) asserts the first kind cannot creep in.

**Extend, don't add.** The offline catch-up already exists and already accrues. Weekly goals
resolve from signals that already exist (`ShipCombat.died`, the economy tick,
`EmpireManager.notoriety_changed`, `CampaignManager` completions) rather than adding parallel
counters — per `AGENTS.md`, connect to an existing signal rather than adding a call path.
Streak cosmetic rewards go through M16's single `EntitlementManager.grant()`.

**Retention and monetization stay physically separate.** Rule 8 of
`docs/19_RETENTION_AND_LIVEOPS.md` is enforced structurally: no retention scene may contain a
store node, asserted by test, not by review.

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/managers/RetentionManager.gd` | **New.** Autoload. Streak, weekly goals, comeback state. Account-scoped. |
| `scripts/core/WeeklyGoalData.gd` | **New.** `Resource` schema for one goal. |
| `resources/goals/*.tres` | **New.** Authored goal pool. |
| `scripts/ui/CaptainsLogPanel.gd` + scene | **New.** Streak surface. |
| `scripts/ui/WeeklyGoalsPanel.gd` + scene | **New.** |
| `scripts/ui/OfflineReturnPanel.gd` + scene | **Changed.** Framed and themed (V13), richer summary. |
| `scripts/ui/FeedbackScreen.gd` + scene | **New.** |
| `scripts/managers/NotificationScheduler.gd` | **New.** Owns the one-per-day and quiet-hours rules. |
| `scripts/managers/SettingsMenu.gd` | **Changed.** Notification toggle, feedback entry. |
| `tests/test_retention_streak.gd`, `test_weekly_goals.gd`, `test_notification_rules.gd`, `test_retention_invariants.gd` | **New.** Flat under `tests/`. |

## 3. Streak state and the step-back rule

Account-scoped, alongside entitlements (M16 §3.1) — a new campaign must not reset a month of
history.

```gdscript
{ "streak": { "tier": 5, "last_played_local_date": "2026-08-27", "highest_tier": 9 } }
```

```gdscript
func _on_session_start() -> void:
    var today := _local_date_string()
    if streak.last_played_local_date == today:
        return                                    # Req 1.8 — one award per local day
    var gap := _days_between(streak.last_played_local_date, today)
    if gap == 1:
        streak.tier += 1
    elif gap >= 2:
        streak.tier = max(0, streak.tier - 1)      # Req 1.2 — ONE tier back, never zero
    streak.highest_tier = max(streak.highest_tier, streak.tier)
    _award_if_tier_is_a_reward_tier()
```

**`highest_tier` is what makes comeback restoration (Requirement 4.2) honest.** A player returning
after three weeks gets their tier back rather than starting over, and this is the field that
remembers it.

**Hazards:**

- **Local date, not UTC, and not `Time.get_unix_time_from_system()` arithmetic.** A player who
  travels across a timezone must not lose a tier. Compare local date strings; a same-day repeat
  is a no-op and a backwards clock is treated as the same day, never as a gap.
- **Do not hook `SaveManager.game_loaded`.** It fires on every load and already has subscribers
  with side effects (D15). Session start is a distinct event; hook that.
- **The step-back is `max(0, tier - 1)`, not `0`.** This one line is the whole difference between
  this design and a punishing one, and `test_retention_streak.gd` asserts it directly, including
  the 30-day-gap case.

## 4. Weekly goals

```gdscript
class_name WeeklyGoalData extends Resource
@export var id: StringName
@export var display_name: String
@export_enum("enemies_sunk", "resources_earned", "islands_captured", "buildings_built", "notoriety_gained") var metric: String
@export var target: int
@export var reward_resources: Dictionary
@export var reward_cosmetic_progress: int
```

Each `metric` maps to an **existing** signal. `RetentionManager` connects once per active goal
and increments; there is no polling and no second counter. Adding a goal is adding a `.tres`
(Requirement 3.3), and adding a *metric* is the only thing that needs a script change — which is
why the enum is deliberately small and covers the systems that already emit.

**Rotation (Requirement 3.5) is silent.** On week boundary: disconnect, discard progress, pick 3
new goals, connect. No summary of what was missed, no notification, no panel. A player who
ignored their goals should not be told they failed at something they did not opt into.

## 5. Notification rules

`NotificationScheduler` owns them so no caller can bypass them:

```gdscript
func try_schedule(kind: String, when: int) -> bool:
    if not _enabled: return false
    if kind in BANNED_KINDS: push_error(...); return false   # sale/offer/expiry/guilt
    if _is_quiet_hours(when): return false                    # Req 5.2
    if _scheduled_within_24h(when): return false              # Req 5.1
    ...
```

The banned-kind check is a `push_error`, not a silent false — a caller trying to schedule a sale
notification is a design violation that should be loud, and `test_notification_rules.gd` asserts
it fires.

**Permission is requested lazily**, on the first genuinely useful occasion (a long build started),
never in the first session (Requirement 5.6).

## 6. Offline return panel (V13)

The panel already exists and works; it is unframed and unstyled, which is the open visual bug
**V13**, and it reports only a total. Changes:

- M9 frame and theme, anchor-based sizing so it survives M19's 200% text scale.
- A short itemized summary drawn from existing state — buildings that ticked, fleets that
  returned, raids that resolved. No new tracking; this data already exists after catch-up.
- One next-action button.
- Where M17 shipped, the rewarded-ad surface sits **here** and only here (Requirement 2.6). Its
  reward is a bonus on income already granted — never a reduced baseline. `design.md` §6 of the
  M17 spec is the binding description of that shape.

## 7. Enforcing the anti-dark-pattern rules

`tests/test_retention_invariants.gd`, covering the mechanically-testable subset of
`docs/19_RETENTION_AND_LIVEOPS.md` §8:

| Assertion | Rule |
|---|---|
| A 30-day gap steps the tier back by exactly 1, never to 0 | 3 |
| No manager applies a negative delta to resources, buildings, or reputation as a function of elapsed offline time | 6 |
| No scene under the retention set contains a store, price, or purchase node | 8 |
| `NotificationScheduler` refuses a second notification within 24h and any in quiet hours | 9 |
| A simulated playthrough that never touches a retention feature reaches the final chapter | 10 |

Rules 1, 2, 4, 5 and 7 are copy and design judgement, enforced by review against that list.

## 8. Requirement 7 is analysis, not code

Tasks 20–22 are a measurement-and-response loop, not a feature build. They require real released
telemetry from M12 and cannot be executed before it exists. If M12's data is not yet available
when this milestone runs, those tasks **block** rather than being guessed at — a rebalance based
on intuition, dressed up as data-driven, is worse than no rebalance, because it is believed.

## 9. What cannot be verified headlessly

**Testable in GUT:** streak arithmetic including the step-back and timezone cases, goal
resolution from signals, notification rule enforcement, the §7 invariants, panel layout.

**Not testable here:** actual notification delivery and quiet-hours behaviour on a device, how the
offline panel reads on a real phone, and everything in Requirement 7, which needs released
telemetry. Per `CLAUDE.md`, these are reported as unverified rather than claimed.
