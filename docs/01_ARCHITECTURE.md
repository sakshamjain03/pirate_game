# System Architecture

Version: 1.0

---

# Purpose

This document defines the high-level architecture of Pirate Empire.

It explains how the project is organized, how systems communicate, and the guiding principles behind the codebase.

This document intentionally avoids implementation details.

---

# Architectural Principles

Pirate Empire follows five core principles.

## 1. Modular

Every gameplay system is independent.

Examples

- Combat
- Buildings
- Economy
- Exploration
- Fleets
- Save System

Each module should be replaceable without affecting unrelated systems.

---

## 2. Data Driven

Game balance should be controlled through Resources (*.tres) and configuration files.

Examples

Ships

Captains

Buildings

Enemies

Bosses

Items

Avoid hardcoding gameplay values inside scripts.

---

## 3. Composition over Inheritance

Favor small reusable components instead of deep inheritance trees.

Example

Ship
 ├── HealthComponent
 ├── WeaponComponent
 ├── MovementComponent
 ├── CrewComponent
 └── CargoComponent

---

## 4. Event Driven

Systems communicate using Signals.

Never tightly couple unrelated systems.

Good

CombatFinished
↓

RewardSystem

↓

QuestSystem

↓

Analytics

Bad

Combat directly modifying every other system.

---

## 5. Expandable

Every system should assume additional content will be added.

New Regions

New Ships

New Buildings

New Bosses

New Resources

No system should assume fixed limits.

---

# High-Level Architecture

```

```
Player

↓

Empire

↓

Fleet

↓

Exploration

↓

Combat

↓

Rewards

↓

Progression

↓

Save

```
