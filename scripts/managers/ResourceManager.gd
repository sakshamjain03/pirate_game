extends Node

## Purpose: Global manager for player resources (Economy).
## Responsibilities: Tracks Gold, Wood, Iron, Rum, Research and Eights. Handles
##   adding/spending.
## Dependencies: ScheduleManager.pricing (M27 shortfall rates only)
##
## M25 — "eights" (Pieces of Eight) is the single premium currency. It lives here
## like any other resource so one wallet, one save path, one UI idiom -- but it is
## NOT an economy resource: `docs/00_VISION.md` §19.2 forbids it being granted by
## production or the economy tick. `PREMIUM_CURRENCY` + `is_premium_currency()`
## exist so that rule can be enforced in code (see `Island._produce_resource()`)
## rather than relying on nobody authoring a building that mints it.

signal resources_changed(resources: Dictionary)
signal global_economy_tick

var _economy_timer: float = 0.0
const ECONOMY_TICK_INTERVAL: float = 10.0

## The one premium currency. Never a second (AGENTS.md).
const PREMIUM_CURRENCY := "eights"

var current_resources: Dictionary = {
	"gold": 200,
	"wood": 50,
	"iron": 20,
	"rum": 10,
	"research": 0,
	"eights": 0
}

var max_storage: Dictionary = {
	"gold": 5000,
	"wood": 200,
	"iron": 100,
	"rum": 50,
	"research": 9999,
	# Purchased currency must never be silently destroyed by a storage cap, so
	# this is a practical ceiling rather than a balance lever. Warehouses do not
	# raise it.
	"eights": 999999
}

func _ready() -> void:
	# Emit initial state
	call_deferred("emit_signal", "resources_changed", current_resources)

func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.name == "World":
		_economy_timer += delta
		if _economy_timer >= ECONOMY_TICK_INTERVAL:
			_economy_timer -= ECONOMY_TICK_INTERVAL
			global_economy_tick.emit()

func add_resource(type: String, amount: int) -> void:
	if amount <= 0:
		return

	type = type.to_lower()
	if not max_storage.has(type):
		# Every resource type must be declared in max_storage/base_storage up
		# front (data-driven balance) -- an undeclared type showing up here is
		# a data bug, not a new resource to grant unlimited (999999) storage.
		push_error("ResourceManager: add_resource called with undeclared resource type '%s'." % type)
		return
	var cap = max_storage[type]
	if current_resources.has(type):
		current_resources[type] += amount
	else:
		current_resources[type] = amount

	if current_resources[type] > cap:
		current_resources[type] = cap

	resources_changed.emit(current_resources)

func spend_resource(type: String, amount: int) -> bool:
	if amount <= 0:
		return true
		
	type = type.to_lower()
	if current_resources.has(type) and current_resources[type] >= amount:
		current_resources[type] -= amount
		resources_changed.emit(current_resources)
		return true
		
	return false

func get_resource(type: String) -> int:
	type = type.to_lower()
	return current_resources.get(type, 0)

func can_afford(cost: Dictionary) -> bool:
	for type in cost.keys():
		if get_resource(type) < cost[type]:
			return false
	return true
	
func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
		
	for type in cost.keys():
		current_resources[type.to_lower()] -= cost[type]
		
	resources_changed.emit(current_resources)
	return true

## M27 — the one pay path for a purchase the player chose: spend the cost, or
## (allow_cover) top up whatever is missing with Eights first. Owners (Island,
## TechManager, FleetManager, IslandMenu) call this after their own guards pass.
func pay(cost: Dictionary, allow_cover: bool = false) -> bool:
	if allow_cover and not can_afford(cost):
		return cover_shortfall_and_spend(cost)
	return spend_resources(cost)


## M27 Requirement 5.1 — {resource: missing} for every non-Eights resource `cost`
## needs more of than the wallet holds. Empty when affordable.
func shortfall(cost: Dictionary) -> Dictionary:
	var gap := {}
	var wanted := _lowercase_keys(cost)
	for type in wanted:
		if is_premium_currency(type):
			continue
		var missing: int = int(wanted[type]) - get_resource(type)
		if missing > 0:
			gap[type] = missing
	return gap


## M27 Requirement 5.2 — Eights to cover `cost`'s shortfall at the authored
## per-resource rates, each rounded up; 0 when nothing is missing, otherwise at
## least 1. A missing resource with no authored rate can't be priced (0).
func shortfall_cost_eights(cost: Dictionary) -> int:
	var rates: Dictionary = _pricing().shortfall_rates
	var gap := shortfall(cost)
	var price := 0
	for type in gap:
		var rate := float(rates.get(type, 0))
		if rate <= 0.0:
			push_error("ResourceManager: no shortfall rate authored for '%s'." % type)
			return 0
		price += ceili(float(gap[type]) / rate)
	return price


## Whether `cost` can be covered right now: something is missing, the cost has no
## Eights in it (Requirement 5.5), every missing resource has a rate, the full
## amount fits under its storage cap (add_resource() clamps — Eights must never buy
## resources that vanish), and the Eights are there.
func can_cover_shortfall(cost: Dictionary) -> bool:
	var wanted := _lowercase_keys(cost)
	if wanted.has(PREMIUM_CURRENCY):
		return false
	var gap := shortfall(wanted)
	if gap.is_empty():
		return false
	for type in gap:
		if int(wanted[type]) > int(max_storage.get(type, 0)):
			return false
	var price := shortfall_cost_eights(wanted)
	return price > 0 and get_resource(PREMIUM_CURRENCY) >= price


## M27 Requirement 5.3 — atomically: spend the Eights, add exactly the shortfall,
## spend the full cost. Refuses (changing nothing) whenever can_cover_shortfall()
## is false.
func cover_shortfall_and_spend(cost: Dictionary) -> bool:
	if not can_cover_shortfall(cost):
		return false
	var gap := shortfall(cost)
	current_resources[PREMIUM_CURRENCY] -= shortfall_cost_eights(cost)
	for type in gap:
		current_resources[type] = get_resource(type) + gap[type]
	if not spend_resources(cost):
		push_error("ResourceManager: covered shortfall still unaffordable — %s." % str(cost))
		return false
	return true


## One authored pricing instance for the whole economy — ScheduleManager's.
func _pricing() -> Resource:
	return ScheduleManager.pricing


func _lowercase_keys(cost: Dictionary) -> Dictionary:
	var result := {}
	for type in cost.keys():
		result[String(type).to_lower()] = cost[type]
	return result


func get_save_data() -> Dictionary:
	return current_resources.duplicate()

func load_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	for key in data:
		var cap = max_storage.get(key, 999999)
		current_resources[key] = min(int(data[key]), cap)

	resources_changed.emit(current_resources)

func recalculate_storage_capacity() -> void:
	# Must list every key that `max_storage` is initialised with — this function
	# REBUILDS the dictionary rather than adjusting it, so any key omitted here
	# silently loses its cap and falls through to the 999999 default on the first
	# recalculation (i.e. as soon as one building is constructed).
	var base_storage: Dictionary = {
		"gold": 5000,
		"wood": 200,
		"iron": 100,
		"rum": 50,
		"research": 9999,
		"eights": 999999
	}

	max_storage = base_storage.duplicate()
	
	var islands = get_tree().get_nodes_in_group("islands")
	for island in islands:
		if island.get("built_buildings"):
			for building in island.built_buildings:
				if "storage_bonus" in building and building.storage_bonus:
					for res_type in building.storage_bonus.keys():
						var val = building.storage_bonus[res_type]
						if max_storage.has(res_type):
							max_storage[res_type] += val
						else:
							max_storage[res_type] = val
			
	var changed = false
	# Union of both key sets: a type that only exists in max_storage so far
	# (declared capacity, no balance yet) still needs a current_resources
	# entry so a later add_resource() sees its real cap instead of falling
	# through to the unknown-type rejection above.
	var all_types := {}
	for type in current_resources.keys():
		all_types[type] = true
	for type in max_storage.keys():
		all_types[type] = true

	for type in all_types.keys():
		var cap = max_storage.get(type, 0)
		if not current_resources.has(type):
			current_resources[type] = 0
			changed = true
		if current_resources[type] > cap:
			current_resources[type] = cap
			changed = true

	if changed:
		resources_changed.emit(current_resources)



## docs/00_VISION.md §19.2 — Eights are only ever granted by purchase, chapters,
## achievements, sieges and Maelstrom runs. Callers on an economy path check this
## and refuse, so a building authored to produce them fails loudly instead of
## quietly minting premium currency.
func is_premium_currency(type: String) -> bool:
	return type.to_lower() == PREMIUM_CURRENCY
