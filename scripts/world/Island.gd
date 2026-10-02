extends Node3D

## Purpose: Manages the island's logic, buildings, and resource production.
## Responsibilities: Holds IslandData, tracks built structures, generates resources over time,
##   handles colonize/capture (gaining +15 notoriety and setting EmpireManager.home_island_id on
##   first capture). Defender spawning and capture are both gated on the island's region being
##   active (M4 — see _should_be_active()); a dormant region's islands have no defenders and
##   cannot be colonized yet.
## Dependencies: IslandData, ResourceManager, BuildingData resources, EmpireManager, RegionData

@export var island_data: IslandData

signal tier_changed(new_tier: int)
## M27 — a building finished construction or an upgrade finished (never on a save
## restore). IslandMenu re-emits it as structure_changed for the campaign, so a
## BUILD_STRUCTURE objective completes when the building exists, not when it's paid.
signal structure_completed(building: BuildingData, is_upgrade: bool)
var _current_tier: int = 1

var built_buildings: Array[BuildingData] = []
## Guards against stacking a second garrison when _spawn_defenses() re-runs on
## region activation. Never reset — a destroyed defender means the island was
## captured, not that it should grow a new garrison.
var _defenders_spawned: bool = false
var _production_timers: Dictionary = {}
var _spawned_models: Dictionary = {}

@onready var building_slots: Node3D = get_node_or_null("Buildings/BuildingSlots")
@onready var dock_area: Area3D = get_node_or_null("DockArea")

func _ready() -> void:
	# MVP scope gate (2026-09-28). World.tscn places all 11 authored islands;
	# the MVP ships 5. A disabled island removes itself here rather than being
	# deleted from the scene, so re-enabling one when its level ships is a
	# single bool in its .tres and no scene surgery. Done before add_to_group()
	# so nothing — docking, defenders, the economy tick, the world map — ever
	# sees it.
	if island_data and not ResourceLookup.is_content_enabled(island_data):
		queue_free()
		return

	var had_authored_data := island_data != null
	if not island_data:
		island_data = IslandData.new()
		island_data.island_name = name

	add_to_group("islands")

	# M10 Requirement 2 — IslandData.world_position is now the single source
	# of truth for where an authored island sits; World.tscn's own node
	# transform is kept in sync by hand for editor-preview accuracy, but this
	# is the actual authority at runtime so the two can never silently drift
	# apart again (docs/14_SYSTEM_INVENTORY.md's "layout only lives in the
	# scene file" gap). Skipped for the placeholder IslandData created above
	# (no @export assigned) — its default (0,0) isn't a real position, just
	# an empty resource with no scene transform to override. Y (height)
	# stays whatever the scene authored — world_position is XZ-only.
	if had_authored_data:
		global_position.x = island_data.world_position.x
		global_position.z = island_data.world_position.y

	if dock_area:
		dock_area.body_entered.connect(_on_dock_area_body_entered)
		dock_area.body_exited.connect(_on_dock_area_body_exited)

	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(on_economy_tick)

	ScheduleManager.job_completed.connect(_on_job_completed)

	# Defenders are gated on the island's region being active, and at world load
	# every region past Beginner is still dormant (notoriety 0). Without this
	# connection _spawn_defenses() only ever ran once, at _ready(), so an enemy
	# island stayed undefended for the whole session and only grew a garrison if
	# the player quit and reloaded after crossing the notoriety threshold.
	var empire := get_tree().root.get_node_or_null("EmpireManager")
	if empire and empire.has_signal("region_activated"):
		empire.region_activated.connect(_on_region_activated)

	_spawn_defenses()
	_apply_terrain_theme()


func _on_region_activated(region_id: String) -> void:
	var empire := get_tree().root.get_node_or_null("EmpireManager")
	if not empire:
		return
	var region = empire.get_region_for_island(get_island_id())
	if region and region.id == region_id:
		_spawn_defenses()

func _apply_terrain_theme() -> void:
	## All six islands instance the same Island.tscn layout — this re-tints
	## the shared sand/grass materials so an island whose name/lore promises
	## something different (a volcano, a frozen reef) doesn't render as an
	## identical copy of a tropical island. Terrain mesh/props stay shared;
	## only the color changes.
	if not island_data or island_data.terrain_theme == IslandData.TerrainTheme.TROPICAL:
		return

	var substitutions: Dictionary = {}
	match island_data.terrain_theme:
		IslandData.TerrainTheme.VOLCANIC:
			substitutions = {
				"res://resources/materials/sand.tres": "res://resources/materials/sand_volcanic.tres",
				"res://resources/materials/grass.tres": "res://resources/materials/grass_scorched.tres",
			}
		IslandData.TerrainTheme.FROZEN:
			substitutions = {
				"res://resources/materials/sand.tres": "res://resources/materials/sand_frozen.tres",
				"res://resources/materials/grass.tres": "res://resources/materials/grass_frozen.tres",
			}
		IslandData.TerrainTheme.DROWNED_RUIN:
			substitutions = {
				"res://resources/materials/sand.tres": "res://resources/materials/sand_drowned.tres",
				"res://resources/materials/grass.tres": "res://resources/materials/grass_drowned.tres",
			}
		IslandData.TerrainTheme.FORTIFIED:
			substitutions = {
				"res://resources/materials/sand.tres": "res://resources/materials/sand_fortified.tres",
				"res://resources/materials/grass.tres": "res://resources/materials/grass_fortified.tres",
			}
		IslandData.TerrainTheme.CALDERA:
			substitutions = {
				"res://resources/materials/sand.tres": "res://resources/materials/sand_caldera.tres",
				"res://resources/materials/grass.tres": "res://resources/materials/grass_caldera.tres",
			}

	var terrain := get_node_or_null("Terrain")
	if not terrain:
		return
	for tile in terrain.get_children():
		for child in tile.get_children():
			if child is KenneyMaterialApplier and substitutions.has(child.material_path):
				child.override_material_path(substitutions[child.material_path])

func _on_dock_area_body_entered(body: Node) -> void:
	if not body.is_in_group("player_ship"):
		return
	var ds = get_tree().current_scene.get_node_or_null("Systems/DockingSystem")
	if ds:
		ds.on_dock_area_entered(dock_area, get_island_id())

func _on_dock_area_body_exited(body: Node) -> void:
	if not body.is_in_group("player_ship"):
		return
	var ds = get_tree().current_scene.get_node_or_null("Systems/DockingSystem")
	if ds:
		ds.on_dock_area_exited(dock_area, get_island_id())

func _should_be_active() -> bool:
	var empire = get_tree().root.get_node_or_null("EmpireManager")
	if not empire:
		return true
	var region = empire.get_region_for_island(get_island_id())
	if not region:
		return true
	return empire.is_region_active(region.id)

func _spawn_defenses() -> void:
	if _defenders_spawned:
		return
	if not _should_be_active():
		return
	if island_data and island_data.island_type == IslandData.IslandType.ENEMY:
		_defenders_spawned = true
		var enemy_scene = load("res://scenes/world/EnemyShip.tscn")
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			var parent = get_tree().current_scene
			if not parent:
				parent = get_tree().root
			parent.call_deferred("add_child", enemy)
			# Offshore, clear of the terrain. The island collision cylinder is
			# radius 38 since the scale-up (docs/21 §2); the old (30,0,30) offset
			# is only 42.4u out, which put a ~9u hull's bow inside the beach.
			enemy.global_position = global_position + Vector3(42, 0, 42)

			# Monitor enemy death for capture logic
			var combat = enemy.get_node_or_null("ShipCombat")
			if combat:
				combat.died.connect(_on_defense_destroyed)

func _on_defense_destroyed() -> void:
	# Capture the island if the defending fleet is destroyed. The defender
	# ship itself is not freed here — ShipController._on_died() already
	# queues its own removal (after playing the sinking sequence), same as
	# any other destroyed enemy ship.
	if FactionManager.has_method("get_player_faction"):
		capture_island(FactionManager.get_player_faction())

func capture_island(new_faction: Resource) -> void:
	if not _should_be_active():
		return
	if island_data:
		# M29 B.3 — record previous owner before reassigning
		var previous_faction_id = ""
		if island_data.owner_faction:
			previous_faction_id = island_data.owner_faction.faction_id

		island_data.owner_faction = new_faction
		island_data.island_type = IslandData.IslandType.FRIENDLY

		if EmpireManager:
			if EmpireManager.home_island_id.is_empty():
				EmpireManager.home_island_id = get_island_id()
			EmpireManager.add_notoriety(15.0)
			EmpireManager.notify_island_captured(get_island_id(), previous_faction_id)
		
		# Show announcement
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("announce_event"):
			hud.announce_event("Captured " + get_island_name() + "!")

func on_economy_tick() -> void:
	# Only produce if owned by player (FRIENDLY or CAPITAL)
	if not island_data or not island_data.is_owned_by_player():
		return

	# Tick production for each building
	for building in built_buildings:
		if building.production_amount > 0 and building.produces_resource != "":
			_produce_resource(building.produces_resource, building.production_amount)

func _produce_resource(type: String, amount: int) -> void:
	# docs/00_VISION.md §19.2 — production may never mint the premium currency.
	# A building authored to produce Eights is a data bug that would quietly break
	# the entire monetization model, so it fails loudly and grants nothing rather
	# than being silently skipped (this repo has a standing rule against silent
	# skips on unresolvable ids, for the same reason).
	if ResourceManager.has_method("is_premium_currency") and ResourceManager.is_premium_currency(type):
		push_error(
			"Island '%s': building authored to produce premium currency '%s'. Eights are only granted by purchase, chapters, achievements, sieges and Maelstrom runs."
			% [get_island_id(), type]
		)
		return
	if ResourceManager.has_method("add_resource"):
		ResourceManager.add_resource(type, amount)

func get_island_id() -> String:
	if island_data:
		return island_data.island_id
	return name

func get_island_name() -> String:
	if island_data:
		return island_data.island_name
	return name

func get_island_tier() -> int:
	return _current_tier

func _recalculate_tier() -> void:
	var total_levels = 0
	for b in built_buildings:
		total_levels += b.level
		
	var new_tier = 1
	var min_b = 2
	if island_data and "min_buildings_for_tier" in island_data:
		min_b = island_data.min_buildings_for_tier
		
	if built_buildings.size() >= min_b and built_buildings.size() > 0:
		new_tier = floori(float(total_levels) / float(built_buildings.size()))
		
	new_tier = clampi(new_tier, 1, 5)
	
	if new_tier != _current_tier:
		_current_tier = new_tier
		tier_changed.emit(_current_tier)
		
		# Show announcement. Guarded on is_inside_tree() because tier is also
		# recalculated during restore_buildings() on load, which can run before
		# the island has entered the tree — get_tree() is null there and the
		# unguarded call aborted the whole restore.
		if is_inside_tree():
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("announce_event"):
				hud.announce_event(get_island_name() + " reached Tier " + str(_current_tier) + "!")
			
		if EmpireManager and EmpireManager.has_method("notify_island_tier_changed"):
			EmpireManager.notify_island_tier_changed(get_island_id(), _current_tier)

func has_building(building_id: String) -> bool:
	for b in built_buildings:
		if b.building_id == building_id:
			return true
	return false

## Is ANY level of this building type built? BuildingData.building_id is
## level-suffixed ("shipyard_l1".."shipyard_l5" — docs/05_CURRENT_SYSTEMS.md),
## so has_building("shipyard") — an exact match — could never be true for real
## data: the Shipyard/Tavern menu tabs never unlocked, shipyard docking never
## offered, raid defence never counted a fortress/watchtower. has_building()
## stays exact on purpose (build_structure()'s duplicate check needs that).
func has_building_type(base_id: String) -> bool:
	for b in built_buildings:
		if b.building_id == base_id or b.building_id.begins_with(base_id + "_l"):
			return true
	return false

func has_shipyard() -> bool:
	return has_building_type("shipyard")

## M27 — pays now; the building exists only once construction completes
## (instantly when its effective duration is 0, otherwise via a ScheduleManager
## job). Returns whether construction started. `allow_cover` tops up a shortfall
## with Eights (ResourceManager.pay()).
func build_structure(building: BuildingData, allow_cover: bool = false) -> bool:
	if not island_data or not island_data.is_owned_by_player():
		return false # Can only build on islands the player owns

	if has_building(building.building_id):
		return false # Already built

	if is_constructing():
		return false # One build/upgrade per island at a time (M27 Requirement 2.7)

	if not ResourceManager.pay(building.get_cost_dict(), allow_cover):
		return false

	var duration := get_construction_seconds(building, "build")
	if duration <= 0.0:
		_finish_build(building)
	else:
		ScheduleManager.start_job("build", get_island_id(), building.building_id, duration)
	return true

func upgrade_structure(old_id: String, new_building: BuildingData, allow_cover: bool = false) -> bool:
	if _index_of_building(old_id) == -1:
		return false

	if is_constructing():
		return false

	if not ResourceManager.pay(new_building.get_cost_dict(), allow_cover):
		return false

	var duration := get_construction_seconds(new_building, "upgrade")
	if duration <= 0.0:
		_finish_upgrade(old_id, new_building)
	else:
		ScheduleManager.start_job("upgrade", get_island_id(), new_building.building_id, duration)
	return true

## M27 — effective build/upgrade time at this island's current tier.
func get_construction_seconds(building: BuildingData, kind: String = "build") -> float:
	return ScheduleManager.pricing.effective_duration(kind, building.build_seconds, get_island_tier())

## M27 — the running build/upgrade job on this island, or {}.
func get_active_construction() -> Dictionary:
	for job in ScheduleManager.get_jobs_for(get_island_id()):
		if job["kind"] in ["build", "upgrade"]:
			return job
	return {}

func is_constructing() -> bool:
	return not get_active_construction().is_empty()

## M27 — is this exact building_id under construction (or being upgraded to)?
## has_building() stays "is built".
func is_building(building_id: String) -> bool:
	return get_active_construction().get("payload", "") == building_id

## M27 — the built level of a building type ("shipyard" -> 0..5), the speed source
## for research (Academy) and ships/repair (Shipyard).
func get_building_level(base_id: String) -> int:
	var level := 0
	for b in built_buildings:
		if b.building_id == base_id or b.building_id.begins_with(base_id + "_l"):
			level = maxi(level, b.level)
	return level

func _index_of_building(building_id: String) -> int:
	for i in range(built_buildings.size()):
		if built_buildings[i].building_id == building_id:
			return i
	return -1

func _on_job_completed(job: Dictionary) -> void:
	if job["target"] != get_island_id() or not job["kind"] in ["build", "upgrade"]:
		return
	var building := _resolve_building(job["payload"])   # push_errors on an unknown id
	if not building:
		return
	if job["kind"] == "build":
		_finish_build(building)
		return
	# The building being upgraded is the one whose next level is this one.
	for b in built_buildings:
		if b.next_upgrade and b.next_upgrade.building_id == building.building_id:
			_finish_upgrade(b.building_id, building)
			return
	push_error("Island %s: upgrade to %s completed but no built building upgrades into it." % [get_island_id(), building.building_id])

func _finish_build(building: BuildingData) -> void:
	if has_building(building.building_id):
		push_error("Island %s: %s completed but is already built." % [get_island_id(), building.building_id])
		return
	built_buildings.append(building)

	# Spawn visual model
	var slot_index = built_buildings.size() - 1
	_spawn_building_visual(building, slot_index, true)

	ResourceManager.recalculate_storage_capacity()
	_recalculate_tier()
	if AudioManager: AudioManager.play_sound("building_construct")
	structure_completed.emit(building, false)

func _finish_upgrade(old_id: String, new_building: BuildingData) -> void:
	var old_building_idx := _index_of_building(old_id)
	if old_building_idx == -1:
		push_error("Island %s: upgrade from %s completed but it is no longer built." % [get_island_id(), old_id])
		return
	built_buildings[old_building_idx] = new_building
	if AudioManager: AudioManager.play_sound("building_upgrade")

	# Update visuals if needed (just scale up for now)
	if _spawned_models.has(old_id):
		var model = _spawned_models[old_id]
		if is_instance_valid(model):
			var target_scale = Vector3.ONE * pow(1.2, new_building.level - 1)
			var tween = create_tween()
			tween.tween_property(model, "scale", target_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		# Re-map the dictionary key
		_spawned_models[new_building.building_id] = model
		_spawned_models.erase(old_id)

	ResourceManager.recalculate_storage_capacity()
	_recalculate_tier()
	structure_completed.emit(new_building, true)

func _spawn_building_visual(building: BuildingData, slot_index: int, animate: bool = false) -> void:
	if not building_slots or building_slots.get_child_count() == 0:
		return
		
	# Pick a slot (wrap around if more buildings than slots)
	var slots = building_slots.get_children()
	var slot = slots[slot_index % slots.size()] as Marker3D
	if not slot:
		return
		
	# Load model
	var model_scene = load(building.model_path)
	if not model_scene:
		return
		
	var instance = model_scene.instantiate()
	if instance is Node3D:
		slot.add_child(instance)
		
		# Add material applier to colorize it like the rest of the world
		var applier = load("res://scripts/components/KenneyMaterialApplier.gd").new()
		instance.add_child(applier)
		
		# Optional: Add a roof if it's the default structure
		if building.model_path.ends_with("structure.glb"):
			var roof_scene = load("res://assets/models/structure-roof.glb")
			if roof_scene:
				var roof = roof_scene.instantiate()
				roof.position = Vector3(0, 1, 0)
				instance.add_child(roof)
				var roof_applier = load("res://scripts/components/KenneyMaterialApplier.gd").new()
				roof.add_child(roof_applier)
		
		var target_scale = Vector3.ONE * pow(1.2, building.level - 1)
		
		if animate:
			instance.scale = Vector3.ZERO
			var tween = create_tween()
			tween.tween_property(instance, "scale", target_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		else:
			instance.scale = target_scale
			
		_spawned_models[building.building_id] = instance

func get_built_building_ids() -> Array:
	var ids = []
	for b in built_buildings:
		ids.append(b.building_id)
	return ids

func _resolve_building(building_id: String) -> BuildingData:
	var original_id = building_id
	if not "_l" in building_id:
		building_id += "_l1"
		
	var parts = building_id.split("_l")
	if parts.size() != 2:
		push_error("Island: Invalid building_id format for restore: " + original_id)
		return null
		
	var base_name = parts[0].capitalize().replace(" ", "")
	var level = parts[1]
	
	var path = "res://resources/buildings/" + base_name + "_L" + level + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as BuildingData
	else:
		push_error("Island: Unresolvable building_id: " + original_id + " (path not found: " + path + ")")
		return null

func restore_buildings(building_ids: Array) -> void:
	built_buildings.clear()
	
	# Clear spawned models
	for key in _spawned_models:
		if is_instance_valid(_spawned_models[key]):
			_spawned_models[key].queue_free()
	_spawned_models.clear()
	
	var slot_index = 0
	for b_id in building_ids:
		var b_res = _resolve_building(b_id)
		if b_res:
			built_buildings.append(b_res)
			_spawn_building_visual(b_res, slot_index, false)
			slot_index += 1
				
	if ResourceManager.has_method("recalculate_storage_capacity"):
		ResourceManager.recalculate_storage_capacity()
		
	_recalculate_tier()
