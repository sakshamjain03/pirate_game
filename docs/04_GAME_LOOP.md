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

# Design Rules

Every action should produce visible progress.

Every session should provide meaningful rewards.

Every battle should matter.

Every island should feel valuable.

Every new region should introduce fresh mechanics—not merely larger numbers.
