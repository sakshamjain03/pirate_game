# Requirements Document

## Introduction

Pieces of Eight exist (M25) but do almost nothing: the only thing to spend them on is dropping one
heat tier. And there is nothing to speed up — every build, research, ship purchase and repair
completes the instant it is paid for. The freemium economy the game is locked into
(`docs/00_VISION.md` §19.1, `docs/17_MONETIZATION.md` §1) needs three things that are missing:

1. **Timers on the empire layer** — building construction and upgrades, tech research, ship
   construction, and ship repair at port take real time.
2. **Eights sinks** — Eights *finish* a running timer and *cover a shortfall* on a purchase the
   player already chose.
3. **A way to buy Eights** — consumable Eights packs through the existing store.

Every rule here is already fixed by the constitution (`AGENTS.md` monetization section,
`docs/17` §3) and this milestone must stay inside it: exactly one premium currency; Eights never
from production; only the empire layer is time-gated (**sailing, combat, boarding stay
unlimited — no energy meter**); every timer is also shortened by play (building levels); skip
cost is priced off **remaining** time, never total; Chapters 1-5 completable at zero spend.

**Already met, no work needed:** `ResourceManager.PREMIUM_CURRENCY = "eights"`, its production
guard (`Island._produce_resource()` push_errors), `ChapterData.reward_eights`,
`EmpireManager.spend_to_reduce_heat()`. `StoreManager` + `IStoreBackend` + `StoreBackendStub`
already drive a purchase state machine; `ProductData` catalogue in `resources/store/`;
`StoreScreen` exists. `ResourceManager.can_afford()`/`spend_resources()` are the one spend path.

**Real Google Play Billing is out of scope** (the plugin isn't vendored; `StoreBackendPlay` is
TODOs). Everything here works end-to-end on the stub backend.

## Glossary

- **Job** — one running timer owned by `ScheduleManager`: `{id, kind, target, start_unix,
  duration}`. Kinds: `build`, `upgrade`, `research`, `ship`, `repair`.
- **Remaining** — `max(0, start_unix + duration - now)`, wall clock, so jobs finish while the
  game is closed.
- **Finish now** — spend Eights to complete a job immediately. Cost =
  `ceil(remaining / seconds_per_eight)`, minimum 1.
- **Shortfall** — the resources a chosen purchase is missing. **Cover** = pay that shortfall in
  Eights at authored per-resource rates, then complete the purchase normally.
- **Speed source** — the building level that shortens a job kind (play's answer to the timer).
- **Consumable** — a store product that grants Eights and can be bought repeatedly.

## Requirements

### Requirement 1: One clock

**User Story:** As a player, I want builds, research, new ships and repairs to take time and keep
running while I'm away, so that the empire has a rhythm to return to.

#### Acceptance Criteria

1. A `ScheduleManager` autoload SHALL own every job. No other system SHALL keep its own timer
   for these job kinds.
2. `ScheduleManager` SHALL emit `job_started(job)` and `job_completed(job)`, and expose
   `start_job()`, `get_job()`, `get_jobs_for(target)`, `remaining()`, `finish_now()`.
3. Jobs SHALL persist via `get_save_data()`/`load_save_data()` in a `schedule` save section,
   omitted when there are no jobs.
4. WHEN the game loads, every job whose remaining time is 0 SHALL complete once, in start order.
5. Completion SHALL be idempotent: a job completes exactly once across save/load.

### Requirement 2: Timed actions

**User Story:** As a player, I want to see what's under construction and how long is left.

#### Acceptance Criteria

1. Building construction and upgrade (`Island.build_structure()`/`upgrade_structure()`) SHALL
   spend the cost immediately and start a job; the building SHALL appear in `built_buildings`
   only on completion.
2. Tech research SHALL start a job; `TechManager.unlock_tech()` SHALL run on completion.
3. Ship construction SHALL start a job; `FleetManager.add_ship()` SHALL run on completion.
4. Ship repair at a shipyard SHALL start a job whose duration scales with missing hull+sails;
   repair SHALL apply on completion. Passive `DockingSystem` repair SHALL be unchanged.
5. Durations SHALL be authored data (new `build_seconds`/`research_seconds` exports on
   `BuildingData`/`TechData`/`ShipStats`, repair rate in `EconomyPricing.tres`). Any field left
   at 0 SHALL mean instant, so unauthored content behaves exactly as today.
6. THE IslandMenu SHALL show each running job's remaining time and a progress bar.
7. Only one `build`/`upgrade` job per island and one `research` job at a time SHALL run; the UI
   SHALL say why a second is refused.

### Requirement 3: Play shortens every timer

**User Story:** As a free player, I want my progress to make waiting shorter, so that I never
have to pay to keep moving.

#### Acceptance Criteria

1. Each job kind SHALL have an authored speed source: island tier (build/upgrade), Academy level
   (research), Shipyard level (ship, repair).
2. Effective duration SHALL be `base × speed_multiplier(level)` with the multipliers authored in
   `EconomyPricing.tres`, strictly decreasing with level.
3. A test SHALL assert every timed job kind has a speed source (constitution: "Every timer must
   also be reducible by playing").

### Requirement 4: Finish now

**User Story:** As a player, I want to finish a timer early with Eights when I choose to.

#### Acceptance Criteria

1. `ScheduleManager.finish_now(job_id)` SHALL cost `max(1, ceil(remaining / seconds_per_eight))`
   Eights, spend through `ResourceManager.spend_resources()`, and complete the job.
2. It SHALL refuse without spending when unaffordable or the job is already complete.
3. Every running job in the UI SHALL show a "Finish now — N ⚜" control and a confirm step.
4. Cost SHALL be computed from remaining time only; a test SHALL assert two jobs with different
   total durations but equal remaining time cost the same.

### Requirement 5: Cover a shortfall

**User Story:** As a player, I want to top up the few resources I'm missing with Eights instead
of grinding for them.

#### Acceptance Criteria

1. `ResourceManager.shortfall(cost) -> Dictionary` SHALL return the missing amount per resource.
2. `ResourceManager.shortfall_cost_eights(cost) -> int` SHALL price it from authored per-resource
   rates (`EconomyPricing.tres`), rounding up, minimum 1 when any shortfall exists.
3. `ResourceManager.cover_shortfall_and_spend(cost) -> bool` SHALL, atomically, spend the Eights,
   add exactly the shortfall, and spend the full cost — or change nothing.
4. Every purchase button that can fail on cost (build, upgrade, research, ship, captain) SHALL
   offer "Cover for N ⚜" with a confirm step when unaffordable.
5. Eights SHALL NOT be a valid shortfall resource; covering SHALL never apply to an Eights cost.

### Requirement 6: Buying Eights

**User Story:** As a player who wants to, I want to buy Eights packs in the store.

#### Acceptance Criteria

1. `ProductData` SHALL gain `grants_eights: int` (0 = not consumable, the default for every
   existing product).
2. `IStoreBackend` SHALL gain `consume(order_id)`; `StoreBackendStub` SHALL implement it;
   `StoreBackendPlay` SHALL keep it as a documented TODO.
3. On a successful purchase of a consumable, `StoreManager` SHALL add `grants_eights` to
   `ResourceManager` exactly once per `order_id`, then consume it. Granted order ids SHALL persist
   so a restore or a repeated callback never grants twice.
4. Four Eights packs SHALL be authored (`resources/store/EightsPack*.tres`).
5. `StoreScreen` SHALL show an Eights section with the current balance.
6. THE HUD SHALL show the Eights balance.

### Requirement 7: Zero-spend gate holds

**User Story:** As a free player, I want to finish all five chapters without paying.

#### Acceptance Criteria

1. A test SHALL assert every building, ship and tech a shipping chapter objective requires has
   no Eights in its cost.
2. A test SHALL assert no Ch1-2 required job has an effective duration over an authored cap
   (initial: 120 s) at the speed-source level those chapters reach.
3. `DevConsole` SHALL gain an economy tab: grant Eights, finish all jobs, set time offset.

## Out of Scope

- **Real Google Play / App Store billing** — separate step, needs the plugin and a store account.
- **Rewarded-ad speed-ups** — M33, with the rest of the ad work.
- **Construction queues longer than one job per island** — a later tuning decision.
- **Timers on sailing, combat, boarding, encounters or the Maelstrom** — forbidden, not deferred.
- **Premium captains** — the constitution allows them; they're content, not economy plumbing.
- **Full Ch1-5 balance pass** — M33. This milestone ships the gate tests, not the tuning.
