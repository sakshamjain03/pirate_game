# Core Gameplay Loop

Version: 1.0

---

# Primary Loop

Collect Resources

↓

Upgrade Empire

↓

Build Ships

↓

Explore Ocean

↓

Fight Battles

↓

Capture Islands

↓

Unlock Region

↓

Repeat

Every feature should strengthen this loop.

---

# Secondary Loop

Enter Battle

↓

Control Ship

↓

Destroy Enemies

↓

Choose Temporary Upgrade

↓

Defeat Boss

↓

Collect Rewards

↓

Return Home

Combat should feel exciting even without rewards.

---

# Daily Loop

Open Game

↓

Collect Production

↓

Upgrade Building

↓

Send Expedition

↓

Fight Battle

↓

Claim Rewards

↓

Log Off

Players should always accomplish something meaningful within five minutes.

---

# Weekly Loop

Expand Territory.

Unlock New Captain.

Upgrade Fleet.

Capture New Island.

Discover New Region.

Fight New Boss.

---

# Chapter Loop

Read the chapter's opening beat

↓

Pursue three to five objectives through normal play

↓

Cross a notoriety threshold

↓

A new region activates

↓

Read the closing beat

↓

Claim the chapter's captains, buildings, and ships

↓

Next chapter

The chapter loop is a frame around the other loops—never a gate.

Every objective is satisfied by an action the player would take anyway.

A player who ignores the campaign entirely loses nothing but the frame.

Chapters are data. See `docs/13_CAMPAIGN_LEVELS_1-5.md`.

---

# Long-Term Loop

Small Empire

↓

Growing Fleet

↓

Regional Power

↓

Ocean Ruler

↓

Pirate King

Identity is the progression—not just statistics.

---

# Side Mode: The Maelstrom (M26)

Sail In (main menu, any time, no save needed)

↓

Survive (enemies never stop; every band is stronger)

↓

Sweep the Wreckage (plunder, repairs, power-ups, powder kegs)

↓

Level Up (choose 1 of 3 temporary upgrades)

↓

Sink (time survived is the score)

↓

Results (best time, Pieces of Eight) → Sail Again

A pure-combat session for when there is no time for the campaign. It is **isolated by
construction**: a run never changes gold, wood, iron, rum, notoriety, heat, fleet, captains or
chapter progress. Its one link to the empire is a capped Pieces of Eight grant from survival
milestones — one of the sources `AGENTS.md` allows. Upgrades last one run only; there is no
meta-progression between runs.

Implementation: `docs/05_CURRENT_SYSTEMS.md` → "M26 - The Maelstrom".

---

# Empire Timers (M27)

Choose a Build, Upgrade, Research, Ship or Repair (pay its cost)

↓

Work Starts (one construction per island, one research at a time)

↓

Sail, Fight, Explore (the clock keeps running — even with the game closed)

↓

Return to Port (the work is done; the building, tech or hull appears)

↓

Choose the Next One

This is the rhythm the Daily Loop returns to. **Only the empire layer is timed** — sailing,
combat, boarding, encounters and the Maelstrom are never gated by a timer or a meter.

Play shortens every timer: a higher island tier builds faster, the best Academy researches
faster, a bigger Shipyard builds and repairs ships faster. Early chapters stay short (Ch1-2 jobs
under two minutes), so a free player is never made to wait to move the story on.

Pieces of Eight are an optional shortcut, always behind a confirm step: **Finish now**, priced
off the time remaining (never the total), or **Cover** the few resources a chosen purchase is
missing. Neither can buy anything play can't.

Implementation: `docs/05_CURRENT_SYSTEMS.md` → "M27 - Timers & the Eights Economy".

---

# Design Rules

Every action should produce visible progress.

Every session should provide meaningful rewards.

Every battle should matter.

Every island should feel valuable.

Every new region should introduce fresh mechanics—not merely larger numbers.
