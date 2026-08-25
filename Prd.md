# Pirate Empire
# Product Requirements Document (PRD)
**Version:** 1.0  
**Status:** Vision Document — pre-production, written before any implementation existed  
**Engine:** Godot 4.x  
**Platform:** Android (Primary), PC (Secondary)  
**Genre:** Single Player Pirate Strategy / Empire Builder / Exploration

> ⚠️ **For anyone writing code: this file is aspirational, not a spec.** Several sections below
> name specific resources, buildings, ship classes, factions, and captain traits that were never
> built and do not exist in the project — they were brainstormed before M1 and superseded by what
> M1–M6 actually implemented. Per `AGENTS.md`, `docs/05_CURRENT_SYSTEMS.md` is the ground truth
> for what exists; where this file's specifics conflict with it, **the current systems doc wins,
> always.** Sections that have since been superseded by a more detailed, accurate doc say so
> inline and link to it instead of repeating stale specifics. Read this file only for the
> original tone/pillars/vision — never to learn what to build.

---

# 1. Executive Summary

Pirate Empire is a single-player pirate strategy game where players begin as the captain of a single ship and gradually build a powerful maritime empire.

Players will explore an open sea, discover islands, establish colonies, manage production, build fleets, recruit legendary captains, fight naval battles, and eventually dominate the world's oceans.

The game combines three core gameplay pillars:

- Build
- Explore
- Conquer

Every mechanic exists to strengthen one or more of these pillars.

---

# 2. Vision

> Start with nothing.
>
> Build an empire.
>
> Rule the seas.

Pirate Empire is designed to deliver the fantasy of becoming the greatest pirate lord through strategic decision making rather than fast action gameplay.

---

# 3. Core Pillars

## Build

Players create a growing pirate empire.

Includes

- Colonies
- Buildings
- Production chains
- Resource management
- Fleet management
- Ship construction
- Technology progression
- Economic optimization

---

## Explore

The world rewards curiosity.

Players can

- Discover islands
- Reveal hidden regions
- Find treasure
- Encounter random events
- Meet factions
- Unlock ports
- Explore dangerous waters

---

## Conquer

Dominate the seas through strategy.

Players will

- Fight enemy fleets
- Raid merchant ships
- Capture ports
- Defeat pirate lords
- Destroy naval fleets
- Expand territory

---

# 4. Gameplay Loop

```
Explore

↓

Discover Island

↓

Dock

↓

Gather Resources

↓

Build Colony

↓

Produce Resources

↓

Upgrade Fleet

↓

Fight Enemies

↓

Expand Territory

↓

Unlock New Regions

↓

Repeat
```

---

# 5. Player Progression

Player begins with

- One ship
- One captain
- Small amount of gold

Eventually grows into

- Multiple fleets
- Multiple colonies
- Large economy
- Powerful captains
- Legendary ships
- World domination

---

# 6. World Structure

The world is a set of regions, each containing islands, resources, enemies, events, and hidden
treasures — that shape held. **The specific region names below were brainstormed pre-production
and were not all built as named.** The 3 regions that actually exist (Beginner/Contested/Imperial
Waters) and their 6 islands are in `docs/11_WORLD_MAP.md`, with 2 further region ids reserved for
post-launch content.

---

# 7. Island System

Every island belongs to one of several categories.

## Neutral

Can be colonized.

---

## Friendly

Trade and diplomacy.

---

## Enemy

Must be conquered.

---

## Capital

Major strategic objective.

---

## Legendary

Late game content.

Contains unique rewards.

---

# 8. Colony System

Players establish and grow a home island that produces resources automatically. Concrete
building list superseded — see `docs/10_ASSET_REQUESTS.md`'s footprint and
`docs/14_SYSTEM_INVENTORY.md` §1/§4 for what's actually implemented.

---

# 9. Resource System

The original brainstorm listed 12 resources including Stone, Food, Cannonballs, Gems, and Magic
Relics — none of those shipped. `AGENTS.md` deliberately locks the launch set to **4: Gold, Wood,
Iron, Rum** (plus Research, added during implementation) and forbids introducing new currencies.
Resources are required for building, ship construction, fleet upgrades, research, and trading.

---

# 10. Building System

10 building types shipped, each with a 5-level upgrade chain — not the Town
Hall/Barracks/Cannon Foundry/Dry Dock/Lighthouse list originally brainstormed here. The real list
is in `docs/05_CURRENT_SYSTEMS.md` §1 ("Economy & Buildings") and `docs/14_SYSTEM_INVENTORY.md`
§4.

---

# 11. Fleet System

Players own multiple fleets.

Each fleet contains

- Ships
- Captains
- Crew
- Cargo

Fleets may

- Explore
- Trade
- Patrol
- Attack
- Defend
- Escort

---

# 12. Ship Classes

8 ships shipped (Dinghy → Man O'War), not the Raft/Cutter/Ghost Ship/Kraken Hunter/Black
Flag/Royal Flagship roster originally brainstormed here. The real ladder, including the
in-progress price/class correction, is in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2.

---

# 13. Captain System

20 captains shipped, each with narrative flavor and stat modifiers rather than the discrete
named-trait system (Navigator/Lucky/Greedy/Coward/etc.) originally brainstormed here. The real
roster, with each captain's home port, allegiance, and unlock chapter, is in
`docs/12_CHARACTER_BIBLE.md` §4. Captains gain experience through battles, exploration, trading,
and events.

---

# 14. Combat

Real-time tactical naval combat: cannon fire, boarding, and positioning shipped; ramming, wind
direction, and special abilities did not. **`docs/navalCombat.md` is the current, locked design**
for combat's identity going forward (auto-fire on arc alignment, captain active abilities, ship
modules) and reconciles this section's original intent against what M6 actually built. Victory
grants loot, reputation, and experience.

---

# 15. Economy

Colonies produce resources every economy tick.

Players decide

- Production priorities
- Trade routes
- Storage
- Tax rates
- Fleet logistics

Economic optimization becomes increasingly important as the empire grows.

---

# 16. Diplomacy

5 factions shipped (Pirate Clans, Merchant Guild, Royal Navy, Spanish Empire, Ghost Fleet) —
Independent Cities and Ancient Order from the original brainstorm were never built; do not
re-propose them without checking `docs/14_SYSTEM_INVENTORY.md` first, since region 4/5 are
already reserved for different content. Actual diplomacy mechanics (reputation, hostility) are
in `docs/05_CURRENT_SYSTEMS.md` §1; treaties/tribute remain unbuilt (M10).

---

# 17. Exploration

Discover

- Treasure maps
- Shipwrecks
- Ancient ruins
- Hidden islands
- Merchant convoys
- Sea monsters
- Random encounters

---

# 18. Progression

Unlock

- Better ships
- Better buildings
- Better captains
- Better technologies
- New regions
- Legendary equipment

---

# 19. Victory Conditions

Primary

Become the ruler of all seas.

Achieved by

- Controlling strategic regions
- Owning a powerful fleet
- Maintaining a strong economy
- Defeating major pirate lords
- Destroying or surpassing the Royal Navy

Optional

- 100% exploration
- All legendary ships
- Maximum colony development
- Complete technology tree
- Maximum reputation

---

# 20. Core Design Principles

- Mobile-first UX
- Data-driven architecture
- Modular systems
- Composition over inheritance
- Resource-based balancing
- No hardcoded gameplay values
- Save pure data only
- Event-driven communication
- Expandable through future content

---

# 21. Milestone Roadmap

**This section is superseded.** It described the pre-production plan and no longer matches what
was actually built. Real milestone history lives in `.kiro/specs/milestone-mN-*/`; the forward
plan (M7 onward) is `docs/15_MASTER_PLAN.md`. Do not plan work against the list that used to be
here — the names and order it described (e.g. "M7 Diplomacy & World Events") do not correspond
to any milestone that was actually executed.

---

# 22. Definition of Done

Pirate Empire is complete when a player can:

- Start with one ship
- Explore the world
- Discover islands
- Build colonies
- Manage an economy
- Construct fleets
- Recruit captains
- Fight naval battles
- Expand territory
- Defeat rival factions
- Become the undisputed ruler of the seas

The game should provide at least **20–40 hours** of meaningful progression for a single playthrough, with replayability driven by different strategies, exploration paths, and empire-building decisions.

> This figure predates scoping. The actual v1 campaign (`docs/13_CAMPAIGN_LEVELS_1-5.md`) targets
> **5–8 hours** to complete Chapters 1–5 — `docs/15_MASTER_PLAN.md` §6 is the current, scoped
> definition of done for v1; this 20–40 hour figure describes a longer-term live-service target
> (`docs/00_VISION.md` §17/§20), not the v1 launch bar.