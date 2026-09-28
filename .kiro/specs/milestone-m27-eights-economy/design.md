# Design Document: Milestone M27 — Timers & the Eights Economy

## 1. Why this design shape

**One clock, owned by one autoload.** Four job kinds live in four places today (`Island`,
`TechManager`, `FleetManager`, `IslandMenu`'s repair). Giving each its own timer would be four
save paths, four offline-progress bugs and four skip implementations. `ScheduleManager` owns time;
the existing owners keep ownership of *what happens* when a job completes, by listening to
`job_completed` and filtering by `kind`. That is the project's signal-over-reference rule.

**Zero means instant.** Every new duration export defaults to 0 and 0 short-circuits to today's
immediate behaviour. That keeps every existing test's assumptions true and lets timers be tuned
into content gradually rather than all at once.

**Money only finishes what play can finish.** Pricing is off remaining time, every kind has a
speed source, and "cover shortfall" only applies to purchases the player already chose. These are
the constitution's testable lines, and each gets a test.

## 2. New/changed files

| File | Change |
|---|---|
| **new** `scripts/managers/ScheduleManager.gd` | the clock (autoload) |
| **new** `scripts/world/EconomyPricingData.gd` + `resources/balance/EconomyPricing.tres` | `seconds_per_eight`, shortfall rates, speed multipliers, repair rate, zero-spend cap |
| `project.godot` | additive: `ScheduleManager` autoload, after `ResourceManager` |
| `scripts/world/BuildingData.gd` | `@export var build_seconds: float = 0.0` |
| `scripts/world/TechData.gd` | `@export var research_seconds: float = 0.0` |
| `scripts/world/ShipStats.gd` | `@export var build_seconds: float = 0.0` |
| `scripts/world/Island.gd` | build/upgrade start jobs; `_on_job_completed` applies; `get_building_level(base_id)` |
| `scripts/managers/TechManager.gd` | `start_research(tech)`; unlock on completion; `is_researching()` |
| `scripts/managers/FleetManager.gd` | `start_ship_construction(ship)`; `add_ship` on completion |
| `scripts/managers/ResourceManager.gd` | `shortfall()`, `shortfall_cost_eights()`, `cover_shortfall_and_spend()` |
| `scripts/ui/IslandMenu.gd` | job rows (remaining + bar + Finish now), Cover buttons, repair job |
| **new** `scripts/ui/EightsConfirmDialog.gd` | one confirm dialog for both sinks |
| `scripts/managers/StoreManager.gd`, `scripts/core/IStoreBackend.gd`, `scripts/core/StoreBackendStub.gd`, `scripts/core/StoreBackendPlay.gd` | consumable branch, `consume()` |
| `scripts/core/ProductData.gd` | `grants_eights` |
| **new** `resources/store/EightsPack{Pouch,Chest,Hoard,KingsRansom}.tres` | packs |
| `scripts/ui/StoreScreen.gd` | Eights section |
| `scripts/ui/WorldHUD.gd` | additive: Eights chip in the resource bar |
| `scripts/managers/SaveManager.gd` | additive: `schedule` section |
| `scripts/debug/DevConsole.gd` | economy tab |
| authored `.tres` | durations on the Ch1-5 path buildings/ships/techs |
| **new** `tests/test_schedule_manager.gd`, `test_eights_sinks.gd`, `test_eights_store.gd`, `test_zero_spend_gate.gd` | |

## 3. `ScheduleManager`

```gdscript
signal job_started(job: Dictionary)
signal job_completed(job: Dictionary)

# job = {id: String, kind: String, target: String, payload: String,
#        start_unix: float, duration: float}
#   target  — who owns the result: island_id for build/upgrade/repair, "tech", "fleet"
#   payload — what it produces: building_id, tech_id, ship resource path
var _jobs: Dictionary = {}            # id -> job
var _completed_ids: Dictionary = {}   # id -> true, persisted, the idempotency record
var now_offset: float = 0.0           # DevConsole / tests only

func now() -> float: return Time.get_unix_time_from_system() + now_offset
func start_job(kind, target, payload, duration) -> String   # duration <= 0 → completes immediately
func remaining(id) -> float
func finish_now(id) -> bool
func finish_cost_eights(id) -> int
func _process(_d): for each job with remaining == 0 → _complete(job)   # start order
func _complete(job): if _completed_ids.has(job.id): return
	_jobs.erase(job.id); _completed_ids[job.id] = true; job_completed.emit(job)
```

`_completed_ids` is pruned to the last 200 ids on save. Ids are `"%s:%s:%d" % [kind, payload,
start_unix_msec]`.

**Hazard — completion while the owner isn't loaded.** A `build` job may complete while the player
is on the main menu or in the Maelstrom, when no `Island` node exists. Rule: `ScheduleManager`
only completes jobs **while the World scene is loaded** (same guard as `SaveManager._process`:
`current_scene.name == "World"`) and once from `SaveManager.game_loaded`. Owners are always
present then. `TechManager`/`FleetManager` are autoloads and could complete any time, but the
same rule keeps one order of events.

**Hazard — load order.** Buildings restore via `Island.restore_buildings()` from the `islands`
section. Completing a `build` job on load must run **after** islands restore, so the building is
appended once, not overwritten. Connect completion-on-load to `SaveManager.game_loaded`, which
fires after all sections load.

## 4. Durations and speed sources

```gdscript
# EconomyPricingData.gd
@export var seconds_per_eight: float = 60.0
@export var shortfall_rates: Dictionary = {"gold": 50, "wood": 10, "iron": 5, "rum": 5, "research": 5}  # units per Eight
@export var build_speed_by_island_tier: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4]
@export var research_speed_by_academy_level: Array[float] = [1.0, 0.8, 0.65, 0.5, 0.4, 0.3]  # index 0 = no academy
@export var ship_speed_by_shipyard_level: Array[float] = [1.0, 0.8, 0.65, 0.5, 0.4, 0.3]
@export var repair_seconds_per_point: float = 0.5
@export var zero_spend_early_cap_seconds: float = 120.0
func effective_duration(kind: String, base: float, level: int) -> float
```

Shipyard-level ship construction happens at a specific island; the speed source is that island's
`get_building_level("shipyard")`. Research is empire-wide: the **highest** Academy level on any
owned island.

Starting durations (tune in play): L1 buildings 20-45 s, L2 90 s, L3 5 min, L4 20 min, L5 1 h;
techs 30 s → 30 min along the tree; ships 45 s (sloop) → 20 min. Ch1-2 content stays under
120 s after speed sources.

## 5. Integration points

**Build** (`Island.build_structure`): keep every existing guard; after
`ResourceManager.spend_resources(cost)` succeeds, if `effective_duration > 0`:
`ScheduleManager.start_job("build", get_island_id(), building.building_id, dur)` and return
`true` **without** appending. `_on_job_completed(job)` with `kind == "build" and target ==
get_island_id()` resolves the building via `_resolve_building()` (push_errors on an unknown id)
and runs the existing append + visual + storage + tier code, now factored into
`_finish_build(building)`. Same pattern for upgrade → `_finish_upgrade(old_id, new_building)`.
`has_building()` stays "is built"; a new `is_building(building_id)` covers "under construction"
so IslandMenu can show a job row instead of a Build button.

**Campaign objectives** fire from `IslandMenu.structure_changed` today. That signal must now
fire on **completion**, not on payment, or BUILD_STRUCTURE objectives would complete before the
building exists. Island emits a new `structure_completed(building)`; IslandMenu re-emits
`structure_changed` from it. Check `CampaignManager._on_structure_changed` still receives it.

**Research / ship**: IslandMenu's `_on_unlock_tech_pressed` and ship purchase call
`TechManager.start_research(tech, cost)` / `FleetManager.start_ship_construction(ship, cost)`,
which spend, start the job, and on completion call the existing `unlock_tech()` / `add_ship()`.

**Repair**: `_on_repair_ship_pressed` starts a `repair` job whose duration is
`missing(hull+sails) × repair_seconds_per_point × ship_speed(shipyard_level)`; completion
repairs the player's active ship's `ShipDamage` exactly as today.

## 6. Cover shortfall

```gdscript
func shortfall(cost: Dictionary) -> Dictionary            # {res: missing} for res != eights
func shortfall_cost_eights(cost: Dictionary) -> int       # sum ceil(missing / rate), 0 if none
func cover_shortfall_and_spend(cost: Dictionary) -> bool:
	var gap := shortfall(cost); var price := shortfall_cost_eights(cost)
	if cost.has(PREMIUM_CURRENCY) or get_resource(PREMIUM_CURRENCY) < price: return false
	# storage caps: adding the gap must not clamp — refuse if res + gap > max_storage
	spend_resource(PREMIUM_CURRENCY, price)
	for r in gap: current_resources[r] += gap[r]
	return spend_resources(cost)    # must succeed now; assert
```

**Hazard — storage caps.** `add_resource()` clamps at `max_storage`. A cost larger than the cap
can never be covered; refuse it rather than charging Eights for resources that clamp away.

## 7. Store consumables

`StoreManager._on_purchase_completed(sku, order_id)` today calls `_grant_product()` →
`EntitlementManager.grant_batch()`. New branch first:

```gdscript
var product := get_product(sku)
if product and product.grants_eights > 0:
	if _granted_orders.has(order_id): _backend.consume(order_id); return
	ResourceManager.add_resource(ResourceManager.PREMIUM_CURRENCY, product.grants_eights)
	_granted_orders[order_id] = true; _save_granted_orders(); _backend.consume(order_id)
	purchase_succeeded.emit(sku); return
```

`_granted_orders` persists in `user://store_orders.json` (the same eager-write pattern
`EntitlementManager` uses, per its header), not in the main save, so a cloud-save conflict can't
roll it back. **Hazard:** Eights have a `max_storage` of 999999 — fine — but check
`recalculate_storage_capacity()` doesn't clamp Eights on load (M25 test pins the cap; keep it).

Packs: Pouch 80, Chest 450 (+12%), Hoard 1000 (+25%), King's Ransom 2800 (+40%). Prices are set in
the store console, not here; `docs/17` §2 gets the table.
