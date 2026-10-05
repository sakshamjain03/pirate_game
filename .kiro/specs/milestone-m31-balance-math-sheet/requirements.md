# Requirements Document (STUB: expanded when M30 closes)

## Introduction

This milestone is M31, the Balance Math Sheet. The owner asked for "a math sheet to calculate
levels and difficulty levels so the hero/ship/economy strengths all add up evenly". They also asked
for the inter-player (PvP) math: "how much they can loot and how strong ships will be".

It runs **after** M30, because M30 creates the mechanics to be tuned. Every value M30 authors is
marked `# placeholder: tune in M31`.

**Inputs:**
- `notes-pvp-math-drafts.md` in this folder.
- `.kiro/specs/track-multiplayer/03-pvp-math.md`.
- `.kiro/specs/track-multiplayer/00-synthesis.md` §5.
- `docs/BALANCE_MODEL.md`, deleted in a2a3b71. Restore it with
  `git show a2a3b71^:docs/BALANCE_MODEL.md`.

## Requirements (to be written in full at scaffold time)

1. **The power model.**
   - Ship power is effective HP × sustained DPS (Lanchester).
   - Captain, tech, module, component, charter, crew station and upgrade contributions are each
     budgeted as a % of power.
2. **Threat rating** in the same units for encounters, squads, assaults, raids, legendaries and
   bosses. The HUD shows "Threat: Even / Dangerous / Deadly".
3. **Curves:**
   - ship cost vs power (today it goes from 3 to 46.7 gold per HP)
   - building payback by level
   - income per chapter vs that chapter's costs
   - time-to-kill bands: Normal 2–5 min, Elite 5–8 min, Boss 5–12 min
   - heat loot multiplier vs risk
   - Hold sizes
   - age-up and wonder costs
   - Three Bells boarding odds
   - morale drains
   - prize economy: refit costs and court multipliers
4. **The PvP section:**
   - Loot = defender storage × (1 − protected fraction by Warehouse) × star factor ×
     level-difference factor, with per-raid and per-day caps.
   - Never loot Eights or relics.
   - A cap on defender losses, plus a shield whose length depends on destruction %.
   - Attacker costs.
   - A fleet power budget per base level.
   - A normalised brawl stat mode.
   - Matchmaking bands and Elo-style trophies with loss floors.
   - Target: a fair match earns 2 stars about 50–60% of the time.
5. **Deliverables:**
   - `BalanceModelData.tres`.
   - An `.xlsx` sheet generated from the live `.tres` files.
   - A **balance-lint GUT test** asserting the invariants:
     - cost/power is monotonic within a band
     - time-to-kill stays in its band
     - a payback cap
     - no hull strictly dominates another
     - PvP loot caps
