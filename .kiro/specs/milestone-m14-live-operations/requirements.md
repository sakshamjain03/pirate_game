# Requirements Document

## Introduction

Milestone M14 is where Pirate Empire stops being "the v1 content set" and starts being a
live-service product that grows without rewrites — `docs/15_MASTER_PLAN.md`'s stated thesis for
this stage: "a content update ships without a code change." Everything narrative in scope here was
deliberately pre-planted: `docs/06_NARRATIVE_AND_WORLD.md` §8 names the Chapter 6+ hooks, and
`docs/13_CAMPAIGN_LEVELS_1-5.md` §9 already sketches all five (Chapters 6–10) as "one `ChapterData`
file plus content... if any of them needs a new script, the M7 implementation got the data model
wrong." `docs/11_WORLD_MAP.md` §5 already id-reserves Region 4 (The Ancient Ocean, tier 4,
notoriety threshold 300) and Region 5 (The Ghost Reaches, tier 5, threshold 500).

This spec brings M14 up to the same requirements/design depth as M11–M13 (this document was
previously a lighter outline with no `tasks.md` at all — that gap is closed here) and folds in two
additions identified when M15 (Backend & Cloud Services) was scoped: seasonal-event scheduling and
a live content kill-switch are both naturally backend-shaped needs that fit M15's Supabase project
better than anything invented locally, since client device clocks aren't trustworthy for "is it
currently spring" and disabling broken live content without an app-store resubmission needs some
remote toggle to exist. **This dependency is soft, not hard** — see Requirement 6.

Full context: `docs/15_MASTER_PLAN.md`'s M14 entry, `docs/06_NARRATIVE_AND_WORLD.md` §8,
`docs/13_CAMPAIGN_LEVELS_1-5.md` §9, `docs/11_WORLD_MAP.md` §5,
`.kiro/specs/milestone-m15-backend-cloud-services/`'s Requirement 11 (Remote config).

---

## Requirements

### Requirement 1 — Chapters 6–10

**User Story:** As a returning player who finished the v1 campaign, I want the story to keep
going, so reaching Chapter 5 isn't the end of the game's narrative reason to keep playing.

#### Acceptance Criteria

1. Five new `ChapterData` resources SHALL be authored per `docs/13_CAMPAIGN_LEVELS_1-5.md` §9's
   table: **Ch6 The Wandering Widow** (gate: notoriety ≥ 300 / Ancient Ocean active; pays off
   Vane's chart and Higgins' secret), **Ch7 Marguerite's Harbour** (gate: Ch6 complete; her port,
   never retaken since Ch3), **Ch8 The Spring Crossing** (seasonal, repeatable — see Requirement 3,
   this is NOT a normal one-time chapter and needs its own mechanism), **Ch9 An Unwelcome Ally**
   (gate: Ch8 available/complete per however Requirement 3 resolves that; Vance, who survived
   Ch4), **Ch10 The Cove Without a King** (gate: Ch7 complete; Morrow's unclaimed clan seat).
2. Each of Ch6, Ch7, Ch9, Ch10 SHALL be a real, permanent, one-time chapter using
   `CampaignManager`'s existing model exactly as Ch1–5 do — no script changes required to add
   them, proving `docs/06_NARRATIVE_AND_WORLD.md` §8's own claim rather than merely asserting it
   (verified the same way M7's exit criteria proved the 5-chapter model: author one for real,
   confirm `CampaignManager._load_chapters()` picks it up with zero script edits).
3. If authoring any of Ch6/7/9/10 genuinely surfaces a need `CampaignManager`'s current data model
   can't express (a dialogue feature, an `ObjectiveData.Condition` value none of Ch1–5 exercised),
   that SHALL be treated as a real, valuable finding to design around properly — not a sign to
   force-fit content into an ill-suited existing field.

### Requirement 2 — Region 4 (The Ancient Ocean) and Region 5 (The Ghost Reaches)

**User Story:** As a player deep into notoriety, I want the world to keep expanding past Imperial
Waters, so there's somewhere left to sail once the original three regions are fully explored.

#### Acceptance Criteria

1. `RegionData` resources for both reserved regions SHALL be authored: Region 4 (tier 4, notoriety
   threshold 300) and Region 5 (tier 5, threshold 500), using `EmpireManager`'s existing
   region-activation model exactly as Imperial Waters (M4) already established — no new activation
   mechanism.
2. Each region SHALL get at least one island with `world_position`/`region_id` (per M10's schema)
   and appropriate `IslandType`/faction ownership.
3. The Ghost Fleet faction (currently rumor-only per `docs/06_NARRATIVE_AND_WORLD.md`'s tone
   rule — "the supernatural is rumoured, never confirmed in Chapters 1–5") SHALL get real
   mechanical presence in Region 5 content — this milestone is where that tone rule's Chapters 1–5
   scope boundary is deliberately left behind; the design decision of *how much* to confirm SHALL
   be made explicitly in `design.md`, not defaulted into by whatever's easiest to author.

### Requirement 3 — Seasonal repeatable events

**User Story:** As a returning player, I want a live event I can play again next season, so
`docs/13_CAMPAIGN_LEVELS_1-5.md`'s own "there will be another in the spring" line pays off as a
real recurring beat, not a one-time chapter that happens to be titled seasonally.

#### Acceptance Criteria

1. A new, lightweight content concept — **not** `ChapterData`, whose `CampaignManager.
   is_chapter_completed()` model is a permanent one-way flag — SHALL represent repeatable content.
   Resolved here rather than left open: a small new `SeasonalEventData` resource + a thin
   `SeasonalEventManager` (or an extension of `EventManager`, if its existing ambient-event
   scheduling pattern fits better on inspection) that tracks "currently active" and "last
   completed" per event id, rather than a single permanent boolean. This is judged the smaller,
   safer change versus retrofitting `ChapterData`'s one-time-completion assumption to support
   resets — extending an existing system incorrectly is a worse violation of `AGENTS.md`'s
   "never duplicate systems" than adding a small, clearly-scoped new one for a genuinely different
   shape of content.
2. The Spring Crossing (Ch8, per Requirement 1) SHALL use this mechanism: available during an
   authored seasonal window, completable once per window, available again next window.
3. The seasonal window's dates SHALL be sourced from `.kiro/specs/milestone-m15-backend-cloud-services/`'s
   Requirement 11 remote config **if that milestone has landed and the key is present**, falling
   back to an authored, hardcoded date range in the event's own data otherwise (Requirement 6
   governs this fallback precisely) — client device clocks are not trustworthy for "is it spring,"
   but this system SHALL still function correctly without a network connection using its local
   fallback.
4. Reward re-granting on repeat completion SHALL be deliberate, not accidental — decide explicitly
   in `design.md` whether repeat rewards match first-completion rewards or are reduced/different,
   and author it that way rather than whatever the loot-table plumbing happens to do by default.

### Requirement 4 — Content-authoring guide

**User Story:** As a non-programmer content author, I want a documented process for adding a
chapter/region/event, so scaling content past this milestone doesn't require a programmer's
involvement every time — the exact gap `docs/14_SYSTEM_INVENTORY.md` §6 already flags as "needed
before chapters/techs scale."

#### Acceptance Criteria

1. A guide SHALL be written (e.g. `docs/CONTENT_AUTHORING_GUIDE.md`) covering: the `ChapterData`/
   `ObjectiveData`/`DialogueBeatData` schema with real field-by-field explanation, the
   `SeasonalEventData` schema from Requirement 3, the `RegionData`/`IslandData` schema from
   Requirement 2, and — critically — which `.gd` script's `@export`ed fields define each schema,
   per this project's own repeatedly-learned lesson that a `.tres` setting a property the script
   doesn't `@export` fails silently (`docs/05_CURRENT_SYSTEMS.md` D3/D14).
2. The guide SHALL be validated by actually using it — whoever authors Chapters 6–10
   (Requirement 1) SHALL use only the documented process, and any point where the guide was wrong,
   incomplete, or assumed undocumented tribal knowledge SHALL be fixed in the guide itself before
   this milestone's checkpoint, not silently worked around.

### Requirement 5 — "What's New" panel

**User Story:** As a returning player, I want to see what changed since I last played, so a live
content update feels like an event, not something I might not even notice happened.

#### Acceptance Criteria

1. A themed screen (reusing `CaptainsLog`'s existing pattern: `PirateThemeBuilder`, opened via a
   `WorldHUD`-owned dynamically-positioned button per the established `_create_captains_log_button()`
   convention) SHALL show patch notes for the current content version.
2. It SHALL show automatically, once, the first time a player launches the game after a content
   update that added something (a new chapter available, a region activated) — reusing
   `WorldHUD`'s existing one-time-notice pattern (the M5 "while you were away" precedent), not a
   new notification mechanism.
3. Patch notes content SHALL be simple authored text per release, not auto-generated from
   `git log` or similar — this project's content updates are infrequent and small enough that
   hand-written notes are both accurate and low-effort.

### Requirement 6 — Remote-config consumption (soft dependency on M15)

**User Story:** As a maintainer, I want live-ops safety nets (accurate seasonal scheduling, an
emergency kill-switch) where the backend to support them exists, without this milestone being
unable to start until that backend does.

#### Acceptance Criteria

1. Requirement 3.3's seasonal-window lookup and a kill-switch check before starting any newly-added
   chapter's ambient content or a seasonal event SHALL both go through a single small wrapper
   (e.g. `LiveOpsConfig.get_seasonal_window(event_id)` / `LiveOpsConfig.is_content_enabled(id)`)
   that internally calls `.kiro/specs/milestone-m15-backend-cloud-services/`'s
   `RemoteConfigManager.get_value()` if that autoload exists in the project, and returns a safe
   local default (the authored fallback window; "enabled" for the kill-switch, since the default
   assumption is content works until told otherwise) if it doesn't.
2. This milestone SHALL be fully startable and completable with M15 not yet landed — every
   acceptance criterion above this one in this document has no dependency on M15 at all, and
   Requirement 6 itself degrades to "content always uses its authored local defaults" rather than
   blocking.
3. If M15 has landed, this milestone's own checkpoint SHALL include actually configuring the
   Spring Crossing's real seasonal window in `remote_config` and confirming the fallback path
   (Requirement 6.1) still works correctly if that key is temporarily removed — proving the
   degradation is real, not just described.

### Requirement 7 — Documentation

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain an "M14 — Live Operations" section.
2. `docs/14_SYSTEM_INVENTORY.md`'s content-volume table SHALL be updated (chapters 5→10, regions
   3→5).
3. `docs/11_WORLD_MAP.md` SHALL have its Region 4/5 entries updated from "id-reserved" to
   describing what was actually built.
4. `docs/15_MASTER_PLAN.md`'s M14 exit-criteria results SHALL be filled in, including whether
   Requirement 6's remote-config integration shipped or is running on local fallback only.

---

## Non-Goals

- Multiplayer, PvP, guilds, or any player-to-player interaction in Regions 4/5 — still permanently
  out per `AGENTS.md`, regardless of how far the notoriety/region-tier system scales.
- A general-purpose live-ops dashboard, A/B testing, or per-user content targeting — Requirement 6
  is deliberately a thin wrapper over M15's already-minimal remote config; this milestone does not
  build tooling beyond what Requirements 3/6 actually need.
- Regions 6+ or chapters beyond 10 — this milestone proves the model is extensible (Requirement 1
  AC2/AC3); it doesn't need to exhaust every hook `docs/06_NARRATIVE_AND_WORLD.md` §8 ever planted.
- Confirming or denying the Ghost Fleet's supernatural nature beyond what Requirement 2.3's
  `design.md` decision settles — "how much mystery gets resolved" is a narrative design call to
  make deliberately in this milestone's design pass, not an open door to over-resolve everything
  the original five chapters kept ambiguous.
- Any of M9–M13's own scope, if not already complete by the time this milestone starts.
