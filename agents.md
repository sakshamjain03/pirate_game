# AGENTS.md

> Repository Constitution
>
> This document defines the engineering principles, architecture philosophy,
> coding standards, development workflow, and AI operating rules for this
> repository.
>
> Every AI coding agent MUST read this file before making any modifications.
>
> If another document conflicts with this one, this document takes precedence
> unless a newer architectural decision exists inside `/docs/DECISIONS.md`.

---

# Project Overview

Project Name (Working Title)

Pirate Empire

Genre

Mobile First
Empire Builder
Strategy
Exploration
Action Combat
Live Service

Engine

Godot 4.x

Primary Language

GDScript

Backend (Future)

Supabase
FastAPI

Current Phase

Pre-production

---

# Project Vision

We are NOT building another pirate game.

We are building a long-term mobile empire simulator where players build, expand,
explore and defend a growing pirate civilization.

The fantasy is NOT

"I control a pirate ship."

The fantasy IS

"I built the greatest pirate empire in history."

Ships are tools.

Captains are heroes.

The empire is the player.

---

# Core Pillars

Every feature MUST support at least one pillar.

## Pillar 1

Build

Expand islands

Upgrade cities

Develop economy

Unlock technology

Grow the empire

---

## Pillar 2

Explore

Unknown seas

Hidden islands

Treasures

Events

Discovery

Mysteries

---

## Pillar 3

Conquer

Fleet battles

Boss fights

Island capture

Defense

Naval warfare

---

If a feature does not improve one of these pillars,
it should probably not exist.

---

# Product Philosophy

The player should always have something meaningful to do.

Every session should contain at least one of:

Collect

Build

Upgrade

Explore

Battle

Claim

Unlock

Discover

No idle waiting without purpose.

---

# Design Philosophy

Easy to learn

Hard to master

Deep progression

Short sessions

Infinite expansion

No unnecessary complexity

No pay-to-win

Meaningful decisions

Visible progression

Every click should feel rewarding.

---

# Development Philosophy

Ship early.

Ship polished.

Expand continuously.

Never attempt to build Version 5 before Version 1 exists.

Always optimize for shipping.

Perfect later.

Playable first.

---

# MVP Philosophy

Version 1.0 is intentionally small.

Launch Scope

Three Regions

Eight Buildings

Eight Ships

Twenty Captains

Four Resources

Offline Gameplay

Single Player

World Events

Boss Battles

No Multiplayer

No Guilds

No PvP

Everything else comes later.

---

# AI Development Principles

AI should optimize for

Maintainability

Readability

Extensibility

Performance

Reusability

NOT

Writing clever code.

---

# Architecture Principles

Composition over inheritance.

Data driven whenever possible.

No God Objects.

No singleton abuse.

Small reusable scenes.

One responsibility per script.

Systems should be modular.

Everything configurable.

---

# Folder Philosophy

Every folder has one purpose.

Example

Scenes/

UI/

Scripts/

Resources/

Data/

World/

Ships/

Captains/

Combat/

Economy/

Managers/

Assets/

Audio/

Shaders/

Documentation/

Testing/

Never mix unrelated systems.

---

# Scene Philosophy

Scenes should be modular.

Examples

Ship Scene

Captain Scene

Island Scene

Enemy Scene

Projectile Scene

Loot Scene

Weather Scene

Everything should be reusable.

Never create giant scenes.

---

# Script Philosophy

Each script should solve one problem.

Good

ShipMovement

ShipCombat

ShipHealth

ShipInventory

Bad

ShipManagerEverything.gd

Maximum readability.

---

# Data Driven Development

Hardcoded values are forbidden.

Example

BAD

Damage = 15

GOOD

Damage loaded from Resource

All balancing should happen through data.

Not code.

---

# Resource Philosophy

Game balance belongs inside Resources.

Examples

ShipData

CaptainData

WeaponData

EnemyData

BuildingData

RegionData

EventData

LootTableData

This allows balancing without touching code.

---

# Signals

Prefer Signals over direct references.

Loose coupling.

Reusable systems.

Easy testing.

Never create unnecessary dependencies.

---

# State Machines

Every complex object should use states.

Example

Ship

Idle

Moving

Attacking

Destroyed

Docked

Repairing

Never create giant if statements.

---

# Naming Convention

Classes

PascalCase

ShipController

EnemySpawner

Variables

snake_case

current_health

movement_speed

Functions

snake_case

move_ship()

spawn_enemy()

Signals

snake_case

ship_destroyed

enemy_spawned

Constants

UPPER_CASE

MAX_HEALTH

DEFAULT_SPEED

---

# Documentation Rules

Every public script must explain

Purpose

Responsibilities

Dependencies

Limitations

TODOs

Every complex function requires comments.

Explain WHY.

Not WHAT.

---

# Error Handling

Never silently ignore failures.

Use assertions.

Return meaningful errors.

Log useful information.

Never hide exceptions.

---

# Performance Rules

Optimize architecture first.

Micro-optimize later.

Avoid

Large _process loops

Repeated node lookups

Duplicate calculations

Repeated allocations

Profile before optimizing.

---

# UI Principles

UI should require minimal learning.

Maximum three taps to reach important actions.

Avoid clutter.

Avoid hidden menus.

Animations should support usability.

Not distract.

---

# Art Direction

Style

Stylized Low Poly

Readable

Colorful

Timeless

Never pursue realism.

Readable gameplay always wins.

---

# Camera

Third Person Isometric

Mobile Friendly

Always prioritize gameplay visibility.

---

# Audio

Every action should provide feedback.

Build

Upgrade

Battle

Victory

Loot

Discovery

Damage

No silent interactions.

---

# Economy Principles

Simple.

Understandable.

Expandable.

Launch Resources

Gold

Wood

Iron

Rum

Never introduce unnecessary currencies.

---

# Progression Principles

Players should always feel stronger.

Visible upgrades.

Meaningful unlocks.

No fake progression.

Every upgrade should matter.

---

# Combat Philosophy

Combat must be fun.

Empire management creates retention.

Combat creates excitement.

Battles should involve

Movement

Dodging

Abilities

Temporary upgrades

Boss mechanics

Player skill matters.

---

# Future Multiplayer Philosophy

Do NOT design Version 1 around multiplayer.

Multiplayer will be added later.

Current architecture should remain compatible.

Avoid decisions that prevent networking.

---

# Live Service Philosophy

Everything should be expandable.

New Regions

New Ships

New Captains

New Events

New Bosses

New Buildings

New Resources

Avoid systems that require rewrites.

---

# Save System

Everything important should serialize cleanly.

Player

Empire

Inventory

Captains

Ships

Progress

Events

Never serialize Nodes directly.

Save pure data.

---

# AI Coding Rules

Every AI Agent MUST

Read documentation before coding.

Never duplicate systems.

Reuse existing code.

Follow naming conventions.

Keep functions small.

Prefer composition.

Keep scripts focused.

Update documentation.

Never invent architecture.

Never change folder structure without approval.

Never remove public APIs without migration.

Never hardcode balance values.

No paid feature ships before the M13 launch build. After M13, monetization is permitted only
within the bounds of `docs/00_VISION.md` §19 and `docs/17_MONETIZATION.md`. The §19 never-list
— pay-to-win, energy systems, forced advertisements, artificial waiting — is absolute and
unamendable.

Never introduce multiplayer.

Never introduce a hard or premium currency. Cosmetic entitlements are one-time, non-tradeable,
non-consumable, and never purchasable with gameplay-affecting power.

Never gate campaign progression, islands, captains, ships, or any gameplay-affecting stat behind
money or an advertisement.

Never break save compatibility.

---

# Pull Request Checklist (For Humans & AI)

Before submitting code

✓ Builds successfully

✓ No duplicate systems

✓ Documentation updated

✓ Uses Resources

✓ Uses Signals appropriately

✓ Naming follows conventions

✓ No hardcoded balance

✓ Reusable implementation

✓ No dead code

✓ No unnecessary dependencies

✓ Clean architecture

✓ Monetization gate — does this change put anything gameplay-affecting behind a purchase or an
advertisement? If yes, reject it.

---

# Out of Scope (Version 1)

PvP

Guilds

Trading

Online Chat

Cloud Saves

Competitive Seasons

Real-time Multiplayer

Microtransactions (see the monetization rules above — cosmetic-only entitlements are permitted
from M16 onward, and never in a v1/M13 launch build)

Battle Pass

Procedural World Generation

Branching Narrative Campaign

These are future milestones.

Do not implement unless instructed.

---

## Narrative — the one carve-out

A **lightweight, data-driven chapter spine is in scope** for Version 1. It is the frame that gives
the loop a reason; it is not a second game.

In scope

Up to five chapters

Objectives resolved from signals that already exist

Chapters authored entirely as Resource files

Short dialogue beats through the existing dialogue panel

Out of scope

Branching narrative or player dialogue choices

Cutscenes or scripted camera sequences

Voice acting

Any objective that blocks the economy loop

Any chapter that requires a script change to add

See `docs/06_NARRATIVE_AND_WORLD.md` for the design and
`docs/13_CAMPAIGN_LEVELS_1-5.md` for the chapters.

---

# Repository Philosophy

This project should remain understandable five years from now.

Every new feature should answer

1.

Does it improve one of the three pillars?

(Build, Explore, Conquer)

2.

Can this system scale?

3.

Can another developer understand this in ten minutes?

4.

Can AI extend this safely?

If the answer is no,

the implementation should be reconsidered.

---

# Final Principle

The goal is NOT to build the biggest game.

The goal is to build the strongest foundation.

A great architecture can support years of content.

A bad architecture cannot be saved by more features.