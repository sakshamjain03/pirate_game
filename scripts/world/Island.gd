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
var _current_tier: int = 1

var built_buildings: Array[BuildingData] = []
var _production_timers: Dictionary = {}
var _spawned_models: Dictionary = {}

@onready var building_slots: Node3D = get_node_or_null("Buildings/BuildingSlots")
@onready var dock_area: Area3D = get_node_or_null("DockArea")

func _ready() -> void:
	if not island_data:
		island_data = IslandData.new()
		island_data.island_name = name

	add_to_group("islands")

	if dock_area:
		dock_area.body_entered.connect(_on_dock_area_body_entered)
		dock_area.body_exited.connect(_on_dock_area_body_exited)
		
	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(_on_economy_tick)

	_spawn_defenses()
	_apply_terrain_theme()

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
	if not _should_be_active():
		return
	if island_data and island_data.island_type == IslandData.IslandType.ENEMY:
		var enemy_scene = load("res://scenes/world/EnemyShip.tscn")
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			var parent = get_tree().current_scene
			if not parent:
				parent = get_tree().root
			parent.call_deferred("add_child", enemy)
			enemy.global_position = global_position + Vector3(30, 0, 30)
			
			# Monitor enemy death for capture logic
			var combat = enemy.get_node_or_null("ShipCombat")
			if combat:
				combat.died.connect(_on_defense_destroyed)

func _on_defense_destroyed() -> void:
	# Capture the island if the defending fleet is destroyed
	if FactionManager.has_method("get_player_faction"):
		capture_island(FactionManager.get_player_faction())

func capture_island(new_faction: Resource) -> void:
	if not _should_be_active():
		return
	if island_data:
		island_data.owner_faction = new_faction
		island_data.island_type = IslandData.IslandType.FRIENDLY

		if EmpireManager:
			if EmpireManager.home_island_id.is_empty():
				EmpireManager.home_island_id = get_island_id()
			EmpireManager.add_notoriety(15.0)
			EmpireManager.notify_island_captured(get_island_id())
		
		# Show announcement
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("announce_event"):
			hud.announce_event("Captured " + get_island_name() + "!")

func _on_economy_tick() -> void:
	# Only produce if owned by player or friendly
	if island_data and island_data.island_type == IslandData.IslandType.ENEMY:
		return
		
	# Tick production for each building
	for building in built_buildings:
		if building.production_amount > 0 and building.produces_resource != "":
			_produce_resource(building.produces_resource, building.production_amount)

func _produce_resource(type: String, amount: int) -> void:
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

func has_shipyard() -> bool:
	return has_building("shipyard")

func build_structure(building: BuildingData) -> bool:
	if has_building(building.building_id):
		return false # Already built
		
	# Pay cost
	var cost = building.get_cost_dict()
	if ResourceManager.has_method("spend_resources") and ResourceManager.spend_resources(cost):
		built_buildings.append(building)
		
		# Spawn visual model
		var slot_index = built_buildings.size() - 1
		_spawn_building_visual(building, slot_index, true)
		
		if ResourceManager.has_method("recalculate_storage_capacity"):
			ResourceManager.recalculate_storage_capacity()
			
		_recalculate_tier()

		return true
		
	return false

func upgrade_structure(old_id: String, new_building: BuildingData) -> bool:
	var old_building_idx = -1
	var old_slot_index = -1
	for i in range(built_buildings.size()):
		if built_buildings[i].building_id == old_id:
			old_building_idx = i
			old_slot_index = i
			break
			
	if old_building_idx == -1:
		return false
		
	var cost = new_building.get_cost_dict()
	if ResourceManager.has_method("spend_resources") and ResourceManager.spend_resources(cost):
		built_buildings[old_building_idx] = new_building

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
			
		if ResourceManager.has_method("recalculate_storage_capacity"):
			ResourceManager.recalculate_storage_capacity()
			
		_recalculate_tier()
			
		return true
		
	return false

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
