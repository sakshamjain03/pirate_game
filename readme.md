# Pirate Empire

> Build the greatest pirate civilization ever known.

---

## Overview

Pirate Empire is a mobile-first empire-building strategy game that combines exploration, naval combat, and long-term progression.

Unlike traditional pirate games, players do not control a single pirate.

They build and lead an entire pirate empire.

---

## Vision

Build.

Explore.

Conquer.

Every decision should make the player's empire larger, stronger, and more legendary.

---

## Current Status

🚧 Pre-production

The project is currently focused on establishing a solid architectural foundation before gameplay implementation begins.

---

## Technology

- Godot 4
- GDScript
- Blender
- GitHub
- VS Code
- Git LFS

---

## Project Structure

```
assets/
    art/
    audio/
    fonts/
    icons/
    shaders/
docs/
resources/
    buildings/
    captains/
    enemies/
    ships/
scenes/
    combat/
    core/
    ships/
    ui/
    world/
scripts/
    combat/
    components/
    core/
    managers/
    ui/
    world/
```

---

## Documentation

| Document | Purpose |
|----------|---------|
| AGENTS.md | Rules for AI coding agents |
| 00_VISION.md | Long-term product vision |
| 01_ARCHITECTURE.md | System architecture |
| 02_TECH_STACK.md | Technology decisions |
| 03_ART_DIRECTION.md | Visual identity |
| 04_GAME_LOOP.md | Core gameplay loops |
| 05_CURRENT_SYSTEMS.md | **Ground truth** — what actually runs today, and every known defect |
| navalCombat.md | Locked design for real-time combat — auto-fire, roles, captain abilities, battle upgrades |
| 06_NARRATIVE_AND_WORLD.md | Premise, tone, and the five-chapter story spine |
| 07_AI_AGENT_WORKFLOW.md | Which agent does which work |
| 08_PROMPT_LIBRARY.md | Task-prompt templates for the implementation agent |
| 09_VISUAL_BUG_TRACKER.md | Screenshot-driven rendering defect ledger |
| 10_ASSET_REQUESTS.md | Outstanding art and audio needs |
| 11_WORLD_MAP.md | Geography — where every island is, and why |
| 12_CHARACTER_BIBLE.md | The cast, including all twenty captains |
| 13_CAMPAIGN_LEVELS_1-5.md | What happens in the first five chapters |
| 14_SYSTEM_INVENTORY.md | **Every component and process the game needs, with status** |
| 15_MASTER_PLAN.md | The order the rest gets built in (M7 → M12) |

---

## Development Philosophy

- Build vertical slices.
- Keep systems modular.
- Prefer composition over inheritance.
- Use data-driven design.
- Write documentation before major systems.
- Optimize only when necessary.
- Test early and often.

---

## Roadmap

- ✅ Project Foundation
- ⏳ First Playable Prototype
- ⏳ Vertical Slice
- ⏳ Alpha
- ⏳ Beta
- ⏳ Android Launch
- ⏳ Live Operations

---

## Guiding Principle

> We are not building levels.

> We are building a living pirate empire.