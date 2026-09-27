# 00_VISION.md

> Version: 1.0
> Status: Living Document
> Owner: Project Lead
>
> This document defines the vision of Pirate Empire.
>
> Every design decision, engineering decision, monetization decision,
> content update, and gameplay mechanic must align with this document.
>
> If a proposed feature contradicts this vision, the feature should be rejected
> unless this document is explicitly updated.

---

# 1. Vision Statement

Pirate Empire is a mobile-first empire-building strategy game where players grow a pirate nation across an ever-expanding ocean through exploration, conquest, economy, and skill-based naval combat.

Players are not role-playing a pirate.

Players are building history.

The ultimate fantasy is becoming the Pirate King by creating the greatest pirate empire ever known.

---

# 2. The Core Fantasy

Most pirate games ask:

"Can you become a legendary pirate?"

Pirate Empire asks:

"Can you build the greatest pirate civilization in history?"

The player owns:

- Islands
- Ports
- Fleets
- Trade Routes
- Captains
- Resources
- Economy
- Defenses
- Reputation

Ships are assets.

Captains are heroes.

The Empire is the player.

---

# 3. Product Vision

We are not building another RTS.

We are not building another Clash of Clans.

We are not building another Black Flag.

We are creating a new genre that combines:

Empire Building

+

Exploration

+

Action Naval Combat

+

Long-term Progression

The goal is to create a game that players return to every day for years.

---

# 4. Core Pillars

Every feature must strengthen one or more pillars.

## Build

Expand islands.

Construct cities.

Upgrade infrastructure.

Develop economy.

Unlock technology.

Create trade routes.

Strengthen defenses.

---

## Explore

Discover new islands.

Find hidden treasures.

Encounter mysterious events.

Navigate dangerous seas.

Uncover forgotten civilizations.

Expand the known world.

---

## Conquer

Fight naval battles.

Capture islands.

Defeat pirate factions.

Destroy legendary enemies.

Protect your empire.

Become Pirate King.

---

If a feature does not strengthen at least one pillar,
it should not be implemented.

---

# 5. The Emotional Experience

We are not creating a resource simulator.

We are creating emotions.

The player should regularly experience:

Curiosity

Achievement

Discovery

Ownership

Power

Growth

Risk

Reward

Victory

Surprise

The game should create stories players remember.

Example:

"I barely escaped the Kraken."

"My favorite captain died defending my island."

"I finally captured the Volcano Fortress."

Those stories create retention.

---

# 6. The Daily Experience

Every time a player opens the game,
something meaningful should have happened.

Examples

A fleet has returned.

An island has finished upgrading.

A storm has appeared.

A treasure map was discovered.

A merchant fleet is nearby.

A boss has awakened.

A captain has leveled up.

A new expedition is available.

The player should never open the game and have nothing interesting to do.

---

# 7. Player Fantasy

The player should gradually transform from:

Unknown Pirate

↓

Captain

↓

Fleet Commander

↓

Island Ruler

↓

Pirate Lord

↓

Empire Builder

↓

Legend

↓

Pirate King

Progression is identity.

Not just bigger numbers.

---

# 8. The Gameplay Philosophy

Empire management creates long-term retention.

Combat creates excitement.

Exploration creates curiosity.

Progression creates purpose.

Every gameplay system should support one of these motivations.

---

# 9. What Makes Pirate Empire Different

Most empire games have passive combat.

Most action games lack long-term progression.

Pirate Empire combines both.

The player spends time:

Building an empire

AND

Actively participating in exciting naval battles.

Neither system exists only to support the other.

Both are first-class gameplay.

---

# 10. Combat Philosophy

Combat should never become a passive animation.

Battles should require decisions.

Movement.

Dodging.

Positioning.

Ability selection.

Temporary upgrades.

Boss mechanics.

Winning should feel earned.

Not automatic.

---

# 11. Exploration Philosophy

The world should feel alive.

Players should never know everything.

Mystery is valuable.

Players should wonder:

"What is beyond that fog?"

"What happens if I explore farther?"

"What is hidden on this island?"

Discovery creates excitement.

---

# 12. Progression Philosophy

Every session should improve something.

Player.

Ship.

Captain.

Empire.

Island.

Technology.

Economy.

Progress should always feel visible.

---

# 13. Simplicity

The game should be easy to understand.

Simple systems.

Deep interactions.

Avoid unnecessary complexity.

Avoid excessive currencies.

Avoid dozens of overlapping mechanics.

Depth should emerge from systems working together.

Not from adding more systems.

---

# 14. Art Direction

The visual identity should be:

Stylized

Readable

Timeless

Colorful

Low-poly

Expressive

Gameplay readability always comes before realism.

The world should feel adventurous rather than historically accurate.

---

# 15. Target Audience

Primary

18–40

Strategy players

Empire builders

Exploration lovers

Midcore mobile players

Secondary

PC strategy players

Simulation fans

Pirate fantasy fans

Players who enjoy long-term progression.

---

# 16. Session Length

Quick Session

2–5 minutes

Collect rewards.

Upgrade.

Launch expedition.

Small battle.

Medium Session

10–20 minutes

Capture island.

Boss battle.

Explore.

Long Session

30–60 minutes

Major expansion.

Large fleet battle.

Complete objectives.

The game should support every session length.

---

# 17. Long-Term Content Philosophy

The game should be expandable forever.

Future content should include:

New Regions

New Ships

New Captains

New Islands

New Resources

New Events

New Enemies

New Bosses

New Stories

New Technologies

The architecture should never assume "finished."

---

# 18. Multiplayer Vision

Version 1 is completely single-player.

Future updates may introduce:

Leaderboards

Asynchronous PvP

Guilds

Alliance Wars

Trading

Seasonal Rankings

Real-time multiplayer is not part of the initial vision.

The game must succeed as a single-player experience first.

---

# 19. Monetization Philosophy

Players should pay because they enjoy the game.

Never because they are forced.

Acceptable monetization:

Cosmetics

Premium Account

Battle Pass

Decorations

Rewarded Ads

Premium currency (Pieces of Eight) and timer finishes, within the limits of §19.2

Expansion Packs

Never:

Pay-to-win in any competitive context

Forced advertisements

Deceptive or hidden pricing

Gating the campaign behind money

Gameplay should remain fair.

## 19.1 The committed model (decided 2026-09-28, supersedes 2026-08-27)

> **This section was rewritten on 2026-09-28.** The previous model committed to a cosmetics-only
> game with no premium currency and no sellable timers, and described its never-list as
> "unamendable". The project owner has since locked the game's identity as a **freemium mobile
> title**, and that model is no longer the one being built. The change is recorded here
> deliberately rather than being worked around in code. The limits in §19.2 are what survive.

Pirate Empire is a **free-to-play mobile game**. The entire five-chapter campaign is completable
without spending anything.

**One premium currency: "Pieces of Eight"** (UI short form *Eights*). It is deliberately silver, so
it never reads as the `gold` gameplay resource. It is the only thing purchasable with money, and it
is also **earnable in play** — chapter completion, achievements, first boss kills, repelled sieges,
Maelstrom runs — so free players hold it and understand its value.

Eights buy exactly four things:

1. **Finishing a timer** — construction, ship repair, or a fleet operation, priced off *remaining*
   time so it is a finisher rather than a bypass.
2. **Covering a resource shortfall** on an upgrade the player has already chosen.
3. **Cosmetics** — sail patterns, hull paint, flags, figureheads, island decorations.
4. **Premium captains** — see the PvE ceiling in §19.2.

Revenue also comes from **opt-in rewarded advertisements** (a Maelstrom revive, a doubled payout,
an offline-income bonus) and the **Pirate King Supporter Pack** (one-time: permanently ad-free, a
cosmetic bundle, extra save slots).

## 19.2 The limits that survive

These are testable rules, and the PR checklist in `AGENTS.md` enforces them.

- **No energy, stamina or fuel meter.** Sailing, combat, boarding and encounters are unlimited
  forever. Monetization pressure lives only in the empire layer — build, repair and operation
  queues. The core loop is never gated.
- **No paid-exclusive campaign content.** Every chapter, island, hull, tech and story captain is
  earnable. Nothing that advances the campaign is behind money or an advertisement.
- **PvE-only power ceiling.** Premium captains may be stronger than earnable ones, but
  **Chapters 1–5 must be completable using only earnable content**, verified by a balance pass
  before release. There is no PvP, so paid power never disadvantages another player.
- **No forced, interstitial or unskippable advertisement.** Every ad is opt-in, and every ad reward
  has an earnable equivalent.
- **No deceptive pricing.** Any randomized purchase discloses its odds, per Google Play and App
  Store policy.
- **Timers must also be shortenable by playing** — building levels reduce durations — so progress
  is never purely a function of waiting.
- **No cosmetic may be sold that was previously earnable**, without keeping the earnable path.
- **Eights are never granted by production or the economy tick** — only by purchase, chapters,
  achievements, sieges and Maelstrom runs.

The engineering constraints derived from this section live in `AGENTS.md`; the SKU list, price
points and entitlement model live in `docs/17_MONETIZATION.md`.

---

# 20. Live Service Philosophy

Launch is the beginning.

Not the finish line.

Every update should make the world feel larger.

Players should feel that the ocean is constantly expanding.

The game world should evolve over time just as real civilizations do.

---

# 21. The North Star

Whenever a feature is proposed, ask four questions:

1.

Does this make building the empire more satisfying?

2.

Does this make exploration more exciting?

3.

Does this make combat more engaging?

4.

Will players remember this experience?

If the answer is "No" to all four,
the feature should probably not exist.

---

# 22. Success Definition

Pirate Empire succeeds when players:

Return every day.

Feel proud of their empire.

Tell stories about their adventures.

Recommend the game to friends.

Look forward to every update.

Feel that their empire is uniquely theirs.

---

# 23. Where the Vision Becomes Specific

This document is deliberately abstract. Five companion documents turn it into content:

`docs/06_NARRATIVE_AND_WORLD.md`

The premise, the tone, and the five-chapter spine.

`docs/11_WORLD_MAP.md`

Where every island is, and why it is there.

`docs/06_NARRATIVE_AND_WORLD.md` §10 (character bible)

The cast, including all twenty existing captains.

`docs/13_CAMPAIGN_LEVELS_1-5.md`

What actually happens in the first five chapters.

`docs/05_CURRENT_SYSTEMS.md`

Ground truth: what runs today file-by-file, including system status, known defects, and content volume targets.

`docs/15_MASTER_PLAN.md`

The order in which the rest gets built.

The story is a frame around the loop.

It never gates the loop.

A player who ignores it entirely can still build, explore, and conquer.

---

# 24. Final Principle

We are not building levels.

We are building a world.

We are not building missions.

We are building stories.

We are not building a pirate game.

We are building a living pirate empire.