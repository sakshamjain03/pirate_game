# 19_RETENTION_AND_LIVEOPS.md

> Version: 1.0
> Status: Living Document — the retention loop design and its anti-dark-pattern rules
> Owner: Project Lead
> Created: 2026-08-27
>
> Reads on top of: `docs/04_GAME_LOOP.md` (the core loop) → `docs/00_VISION.md` §20 (live service
> philosophy) → `docs/17_MONETIZATION.md` (what is sold) → this document (why a player comes back
> tomorrow).
>
> **Why this document exists.** A gap audit on 2026-08-27 found that the roadmap had no
> re-engagement layer at all. M12 *collects* analytics; nothing in M12–M15 *acts* on them. That
> is the gap that decides whether a freemium game earns anything: a player who does not return on
> day two never converts, no matter how good the store page is. Milestone **M18** implements this
> document.

---

# 1. The principle

**A player should return because there is something they want to see, not because leaving costs
them something.**

Every mechanic in this document is judged against that sentence. Reward, never punish. The
difference is not cosmetic — it is the whole design:

| Punishment framing (banned) | Reward framing (used here) |
|---|---|
| "Your streak will be lost" | "Day 4 unlocks the Storm-Torn sail" |
| "Your crew starves in 6 hours" | "Your crew has been busy — here is what they gathered" |
| "Limited time, 2h left!" | "This season's regatta runs through Sunday" |
| Buildings decay while away | Buildings produce while away |

The game already gets this right in one important place: **offline income accrues rather than
decaying**. Everything below extends that instinct.

---

# 2. The daily layer

## 2.1 Login streak — "The Captain's Log"

A running count of days played, framed as the captain writing up the voyage.

- Rewards on days 1, 2, 3, 5, 7, then every 7th day: resources, a captain recruitment token, and
  a **cosmetic at day 7** (this is the hook — it teaches that cosmetics exist before anything is
  ever sold).
- **A broken streak does not reset to zero.** It steps back one tier. Missing a day because of a
  hospital visit or a work week should not erase a month.
- **No timer is ever shown counting down to a loss.** The log shows what is *next*, not what is
  *expiring*.
- Rewards are never large enough that skipping days makes the game meaningfully harder. This is
  a reason to open the app, not a balance lever.

## 2.2 The offline return, improved

The existing offline-catch-up already works (`SaveManager.game_loaded`, the "while you were
away" panel — currently unframed, tracked as visual bug **V13** in M9). M18 upgrades it from a
number into a story beat:

- What the empire *did*: which buildings produced, which fleets returned, which raids were
  repelled.
- What changed *without* the player: faction movements, region activity.
- One clear next action, so the session has somewhere to go.
- The rewarded-ad "double your offline income" surface lives here (`docs/17_MONETIZATION.md`
  §2.3) — offered once, on an amount already granted.

---

# 3. The weekly layer

## 3.1 Weekly goals

Three rotating objectives drawn from the systems that already exist and already emit signals
(`ShipCombat.died`, the economy tick, `EmpireManager.notoriety_changed`, island capture) — so
goals are authored as Resources and require no script change to add, exactly as chapters are.

- Achievable in roughly two normal sessions, not a grind.
- Reward: resources plus progress toward a cosmetic.
- **Expire quietly.** A missed week rotates out with no penalty screen and no guilt.

## 3.2 Comeback bonus

For a player returning after 7+ days away:

- A generous but bounded resource catch-up, so they are not hopelessly behind.
- A short "what changed while you were gone" summary.
- Their streak tier restored to where it was, not to zero.
- **No apology-shaped nagging.** One warm panel, then let them play.

---

# 4. Notifications

Local notifications only (M12 already scopes the capability). The policy is deliberately
conservative:

**Permitted**

- Something the player set up has finished (a long build, a fleet returned).
- A raid on the home island is imminent or has resolved.
- A weekly goal set has rotated in.
- At most **one per day**, and never between 21:00 and 09:00 local time.

**Banned**

- "We miss you!" / "Your empire is crumbling!" — guilt and loss framing.
- Any notification about a sale, a discount, or an expiring offer.
- Any notification whose only purpose is to reopen the app with no in-game event behind it.
- More than one per day, under any circumstance.

Notifications are **opt-in** at first prompt, and the prompt is not shown in the first session.

---

# 5. The feedback channel

An in-game **"Report a problem / Send feedback"** entry in the settings menu, capturing:

- A free-text message, the current save's chapter and region, the build version, and the device
  model.
- Optionally the last N log lines, with the player shown exactly what will be sent and given a
  decline option.
- No personally identifying data, ever, without an explicit checkbox.

This closes the loop the audit found missing: right now a player who hits a bug has nowhere to
put it, and the project learns nothing.

---

# 6. Acting on the M12 funnel

M12 instruments the first-time-user experience. M18 is the milestone that **does something with
that data**, and it is listed here so it does not evaporate into "we have dashboards now":

- Identify the largest drop-off step in the tutorial and first session, and fix it.
- Identify the first chapter objective with an outsized failure or abandon rate, and rebalance it.
- Identify the median session length and whether the loop has a natural stopping point (it should
  — a game with no exit point is a game people quit angrily).
- Re-measure after each change. A change that does not move the number gets reverted, not kept
  out of sunk cost.

**Dependency:** M18 without M12 is guesswork. If M12 slips, M18 slips.

---

# 7. The anti-dark-pattern rules

These are the rules; §8 is how they get enforced.

1. **No loss framing.** Nothing is ever described as being taken away, expiring, or decaying.
2. **No countdown timers on rewards.** The player is never shown a clock ticking toward a loss.
3. **No streak-break punishment.** A broken streak steps back one tier; it never zeroes.
4. **No FOMO.** No "limited time only", no artificial scarcity, no fake urgency.
5. **No guilt notifications.** Ever.
6. **No decay.** Buildings, resources, reputation, and fleets never degrade while the player is
   away. Absence is neutral, never negative.
7. **No session-length manipulation.** No mechanic exists whose purpose is to extend a session
   past where the player wanted to stop.
8. **No retention mechanic may be a monetization surface.** Streaks, goals and comeback bonuses
   never contain a purchase prompt. The overlap between "come back tomorrow" and "buy this" is
   where free-to-play games go bad, and this project keeps them separate on purpose.
9. **Notification budget of one per day**, hard.
10. **Everything here is optional.** A player who ignores every retention feature must be able to
    play and finish the entire game with no disadvantage.

---

# 8. Enforcement

Rules 3, 6, 8, 9 and 10 are **mechanically testable** and become GUT tests in M18:

- Breaking a streak steps back exactly one tier and never below zero.
- No manager applies a negative delta to resources, buildings or reputation as a function of
  elapsed offline time.
- No retention panel scene contains a purchase or store node.
- The notification scheduler refuses to queue a second notification within 24 hours, and refuses
  any within the quiet-hours window.
- A save that never engages a retention feature can still reach the final chapter.

Rules 1, 2, 4, 5 and 7 are matters of copy and design judgement. They are enforced by review
against this list, and by the reviewer's checklist in `docs/17_MONETIZATION.md` §7 — which any
pull request touching these systems must also pass.
