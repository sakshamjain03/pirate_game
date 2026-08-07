class_name IslandMenu extends Control

## Purpose: UI menu shown when docked at an island.
## Responsibilities: Displays island info, available buildings, handles construction requests,
##   ship/captain purchase, fleet mission assignment (incl. a Defend Home toggle, M4), tech
##   research, and resource trading. Disables the Colonize button (with an explanatory tooltip)
##   when the island's region is not yet active (M4).
## Dependencies: Island, ResourceManager, PirateThemeBuilder, EmpireManager (region gating)

signal structure_changed(building_id: String, is_upgrade: bool)

@onready var tab_container: TabContainer = %TabContainer
@onready var buildings_container: VBoxContainer = %BuildingsContainer
@onready var ships_container: VBoxContainer = %ShipsContainer
@onready var captains_container: VBoxContainer = %CaptainsContainer
@onready var fleet_container: VBoxContainer = %FleetContainer
@onready var research_container: VBoxContainer = %ResearchContainer
@onready var trade_container: VBoxContainer = %TradeContainer
@onready var close_button: Button = %CloseButton
@onready var island_name_label: Label = %IslandNameLabel

var current_island: Node3D = null

# Data (loaded dynamically)
var available_buildings: Array[BuildingData] = []
var available_ships: Array[ShipStats] = []
var available_captains: Array[CaptainData] = []
var available_techs: Array[TechData] = []

var colonize_btn: Button

func _ready() -> void:
	add_to_group("island_menu")
	close_button.pressed.connect(_on_close_pressed)
	_load_building_data()
	hide()

	# Keep processing input while paused — open()/close() pause the game so
	# enemies don't keep sailing and shooting the player (and the economy
	# doesn't keep ticking) while this menu is up.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceManager.has_signal("resources_changed"):
		ResourceManager.resources_changed.connect(_on_resources_changed)


	# Create Colonize Button
	colonize_btn = Button.new()
	colonize_btn.text = "Colonize (1000 Gold)"
	colonize_btn.custom_minimum_size = Vector2(150, 40)
	colonize_btn.pressed.connect(_on_colonize_pressed)
	island_name_label.get_parent().add_child(colonize_btn)
	
	# Apply theme
	theme = PirateThemeBuilder.build()

func _load_building_data() -> void:
	# In a real game, this would load from a directory or registry
	var mill = load("res://resources/buildings/LumberMill.tres")
	if mill: available_buildings.append(mill)
	var mine = load("res://resources/buildings/Mine.tres")
	if mine: available_buildings.append(mine)
	var farm = load("res://resources/buildings/Farm.tres")
	if farm: available_buildings.append(farm)
	var market = load("res://resources/buildings/Market.tres")
	if market: available_buildings.append(market)
	var shipyard = load("res://resources/buildings/Shipyard.tres")
	if shipyard: available_buildings.append(shipyard)
	var tavern = load("res://resources/buildings/Tavern.tres")
	if tavern: available_buildings.append(tavern)
	var watchtower = load("res://resources/buildings/Watchtower.tres")
	if watchtower: available_buildings.append(watchtower)
	var fortress = load("res://resources/buildings/Fortress.tres")
	if fortress: available_buildings.append(fortress)
	var warehouse = load("res://resources/buildings/Warehouse.tres")
	if warehouse: available_buildings.append(warehouse)
	var academy = load("res://resources/buildings/Academy.tres")
	if academy: available_buildings.append(academy)
	
	# Load Ships
	var ship_names = ["Dinghy", "Sloop", "Schooner", "Brigantine", "Corvette", "Frigate", "Galleon", "ManOWar"]
	for s in ship_names:
		var ship = load("res://resources/ships/" + s + ".tres")
		if ship: available_ships.append(ship)
		
	# Load Captains
	var cap_names = ["Redbeard", "Anne", "Bartholomew", "Jack", "Mary",
		"Isabela", "Diego", "Grace", "OldTom", "Fiona",
		"Cutlass", "Whistler", "Marguerite", "Ezra", "Rook",
		"Selene", "Barnaby", "Constance", "Yusuf", "Ophelia"]
	for c in cap_names:
		var cap = load("res://resources/captains/" + c + ".tres")
		if cap: available_captains.append(cap)
		
	# Load Techs
	var t1 = load("res://resources/techs/ReinforcedHulls.tres")
	if t1: available_techs.append(t1)
	var t2 = load("res://resources/techs/AdvancedCannons.tres")
	if t2: available_techs.append(t2)

func open(island: Node3D) -> void:
	current_island = island
	
	var name_text = "Unknown Island"
	var type = IslandData.IslandType.NEUTRAL
	if island.has_method("get_island_name"):
		name_text = island.get_island_name()
	if "island_data" in island and island.island_data:
		type = island.island_data.island_type
		if island.island_data.owner_faction:
			name_text += " (" + island.island_data.owner_faction.faction_name + ")"
		elif type == IslandData.IslandType.NEUTRAL:
			name_text += " (Neutral)"
		elif type == IslandData.IslandType.ENEMY:
			name_text += " (Enemy)"
			
	island_name_label.text = name_text
		
	# Configure Tabs
	var has_shipyard = island.has_building("shipyard") if island.has_method("has_building") else false
	var has_tavern = island.has_building("tavern") if island.has_method("has_building") else false
	
	var can_build = type == IslandData.IslandType.FRIENDLY
	
	tab_container.set_tab_hidden(0, not can_build) # Index 0 is Buildings
	tab_container.set_tab_hidden(1, not has_shipyard or not can_build) # Index 1 is Shipyard
	tab_container.set_tab_hidden(2, not has_tavern or not can_build) # Index 2 is Tavern
	tab_container.set_tab_hidden(3, false) # Index 3 is Fleet (always visible)
	tab_container.set_tab_hidden(4, false) # Index 4 is Research (always visible)
	tab_container.set_tab_hidden(5, not can_build) # Index 5 is Trade

	# Tutorial gating: only ever further hides tabs, never overrides the rules above.
	if TutorialManager.tutorial_active:
		if not TutorialManager.is_ui_unlocked("tab_fleet"):
			tab_container.set_tab_hidden(3, true)
		if not TutorialManager.is_ui_unlocked("tab_research"):
			tab_container.set_tab_hidden(4, true)
		if not TutorialManager.is_ui_unlocked("tab_trade"):
			tab_container.set_tab_hidden(5, true)

	if colonize_btn:
		colonize_btn.visible = type == IslandData.IslandType.NEUTRAL
		
		# Task 10: disable if not active
		if current_island.has_method("_should_be_active") and not current_island._should_be_active():
			colonize_btn.disabled = true
			colonize_btn.tooltip_text = "This region has not yet drawn attention"
		else:
			colonize_btn.disabled = false
			colonize_btn.tooltip_text = ""
		
	_refresh_buildings()
	if has_shipyard and can_build: _refresh_ships()
	if has_tavern and can_build: _refresh_captains()
	_refresh_fleet()
	_refresh_research()
	if can_build: _refresh_trade()

	show()
	get_tree().paused = true

func close() -> void:
	current_island = null
	hide()
	get_tree().paused = false

func _on_resources_changed(_res: Dictionary) -> void:
	# Affordability (button disabled states, colors) was only ever computed
	# once at open() and never refreshed — spend gold on one tab and every
	# other tab kept showing stale can/can't-afford states until re-opened.
	if not visible or not current_island:
		return
	_refresh_buildings()
	if current_island.has_method("has_building"):
		if current_island.has_building("shipyard"):
			_refresh_ships()
		if current_island.has_building("tavern"):
			_refresh_captains()
	_refresh_research()
	_refresh_trade()

func _on_close_pressed() -> void:
	# Tell the docking system to undock
	var dock_sys = get_tree().current_scene.get_node_or_null("Systems/DockingSystem")
	if dock_sys and dock_sys.has_method("attempt_undock"):
		dock_sys.attempt_undock()
	close()

func _on_colonize_pressed() -> void:
	if not current_island or not current_island.has_method("capture_island"):
		return
		
	var cost = {"gold": 1000}
	if ResourceManager.spend_resources(cost):
		if FactionManager.has_method("get_player_faction"):
			current_island.capture_island(FactionManager.get_player_faction())
			# Re-open the menu to refresh tabs
			open(current_island)

func _refresh_buildings() -> void:
	# Clear existing entries
	for child in buildings_container.get_children():
		child.queue_free()
		
	if not current_island or not current_island.has_method("has_building"):
		return
		
	for building in available_buildings:
		_create_building_entry(building)

func _create_building_entry(building: BuildingData) -> void:
	var hbox = HBoxContainer.new()
	
	# Name & Desc
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = building.building_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = building.description + " (+" + str(building.production_amount) + " " + building.produces_resource + "/" + str(int(building.production_interval)) + "s)"
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	# Cost
	var cost_lbl = Label.new()
	var cost_text = ""
	var cost_dict = building.get_cost_dict()
	for k in cost_dict.keys():
		cost_text += str(cost_dict[k]) + " " + k.capitalize() + "  "
	cost_lbl.text = cost_text
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Button
	var btn = Button.new()
	btn.text = "Build"
	btn.custom_minimum_size = Vector2(80, 40)
	
	# Check if already built
	var is_built = false
	var existing_building: BuildingData = null
	if current_island.has_method("has_building"):
		for b in current_island.built_buildings:
			# Match by prefix so Level 2 counts as the same base building
			if b.building_id.begins_with(building.building_id) or building.building_id.begins_with(b.building_id):
				is_built = true
				existing_building = b
				break
				
	if is_built and existing_building:
		if "next_upgrade" in existing_building and existing_building.next_upgrade:
			btn.text = "Upgrade"
			var up_cost = existing_building.next_upgrade.get_cost_dict()
			cost_text = ""
			for k in up_cost.keys():
				cost_text += str(up_cost[k]) + " " + k.capitalize() + "  "
			cost_lbl.text = cost_text
			
			if not ResourceManager.can_afford(up_cost):
				btn.disabled = true
				cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
				btn.pressed.connect(func(): _on_upgrade_pressed(existing_building.building_id, existing_building.next_upgrade))
		else:
			btn.text = "Max Lvl"
			btn.disabled = true
			cost_lbl.text = ""
	else:
		# Check affordability
		if not ResourceManager.can_afford(cost_dict):
			btn.disabled = true
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
			
		btn.pressed.connect(func(): _on_build_pressed(building))
		
	hbox.add_child(info_vbox)
	hbox.add_child(cost_lbl)
	hbox.add_child(btn)
	
	buildings_container.add_child(hbox)
	
	# Add a separator
	var sep = HSeparator.new()
	buildings_container.add_child(sep)

func _on_build_pressed(building: BuildingData) -> void:
	if current_island and current_island.has_method("build_structure"):
		if current_island.build_structure(building):
			_refresh_buildings()
			# If we just built a shipyard or tavern, unhide the tabs
			if building.building_id.begins_with("shipyard"):
				tab_container.set_tab_hidden(1, false)
				_refresh_ships()
			elif building.building_id.begins_with("tavern"):
				tab_container.set_tab_hidden(2, false)
				_refresh_captains()
			structure_changed.emit(building.building_id, false)

func _on_upgrade_pressed(old_id: String, next_upgrade: BuildingData) -> void:
	if current_island and current_island.has_method("upgrade_structure"):
		if current_island.upgrade_structure(old_id, next_upgrade):
			_refresh_buildings()
			structure_changed.emit(next_upgrade.building_id, true)

# --- SHIPYARD ---

func _refresh_ships() -> void:
	for child in ships_container.get_children():
		child.queue_free()
	for ship in available_ships:
		_create_ship_entry(ship)

func _create_ship_entry(ship: ShipStats) -> void:
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	var path_parts = ship.resource_path.get_file().split(".")
	name_lbl.text = path_parts[0] if path_parts.size() > 0 else "Unknown Ship"
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "HP: %d | DMG: %d | SPD: %d | TRN: %.1f" % [ship.max_health, ship.cannon_damage, ship.max_speed, ship.turn_rate]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	# Cost - Dynamic based on mass
	var cost_gold = int(ship.mass / 100)
	var cost_wood = int(ship.mass / 200)
	var cost_iron = int(ship.mass / 400)
	var cost_dict = {"gold": cost_gold, "wood": cost_wood, "iron": cost_iron}
	
	var cost_lbl = Label.new()
	cost_lbl.text = "%d Gold  %d Wood  %d Iron  " % [cost_gold, cost_wood, cost_iron]
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(80, 40)
	
	if ship in FleetManager.owned_ships:
		btn.text = "Owned"
		btn.disabled = true
	elif not ResourceManager.can_afford(cost_dict):
		btn.disabled = true
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		btn.pressed.connect(func(): _on_buy_ship_pressed(ship, cost_dict))
		
	hbox.add_child(info_vbox)
	hbox.add_child(cost_lbl)
	hbox.add_child(btn)
	
	ships_container.add_child(hbox)
	ships_container.add_child(HSeparator.new())

func _on_buy_ship_pressed(ship: ShipStats, cost: Dictionary) -> void:
	if ResourceManager.spend_resources(cost):
		FleetManager.add_ship(ship)
		_refresh_ships()

# --- TAVERN ---

func _refresh_captains() -> void:
	for child in captains_container.get_children():
		child.queue_free()
	for cap in available_captains:
		_create_captain_entry(cap)

func _create_captain_entry(cap: CaptainData) -> void:
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = cap.captain_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "%s (SPD x%.2f | TRN x%.2f | DMG x%.2f | HP x%.2f)" % [cap.background, cap.speed_modifier, cap.turn_rate_modifier, cap.damage_modifier, cap.health_modifier]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	# Cost - per-captain, ramps with roster depth
	var cost_dict = {"gold": cap.hire_cost_gold}

	var cost_lbl = Label.new()
	cost_lbl.text = "%d Gold  " % cap.hire_cost_gold
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = "Hire"
	btn.custom_minimum_size = Vector2(80, 40)
	
	if cap in FleetManager.owned_captains:
		btn.text = "Hired"
		btn.disabled = true
	elif not ResourceManager.can_afford(cost_dict):
		btn.disabled = true
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		btn.pressed.connect(func(): _on_hire_captain_pressed(cap, cost_dict))
		
	hbox.add_child(info_vbox)
	hbox.add_child(cost_lbl)
	hbox.add_child(btn)
	
	captains_container.add_child(hbox)
	captains_container.add_child(HSeparator.new())

func _on_hire_captain_pressed(cap: CaptainData, cost: Dictionary) -> void:
	if ResourceManager.spend_resources(cost):
		FleetManager.add_captain(cap)
		_refresh_captains()

# --- FLEET ---

func _refresh_fleet() -> void:
	if not fleet_container:
		return
	for child in fleet_container.get_children():
		child.queue_free()
		
	for i in range(FleetManager.owned_ships.size()):
		var ship = FleetManager.owned_ships[i]
		_create_fleet_entry(ship, i)

func _create_fleet_entry(ship: ShipStats, index: int) -> void:
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	var path_parts = ship.resource_path.get_file().split(".")
	name_lbl.text = path_parts[0] if path_parts.size() > 0 else "Unknown Ship"
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var cap_index = index if index < FleetManager.owned_captains.size() else 0
	var assigned_cap = FleetManager.owned_captains[cap_index]
	
	var desc_lbl = Label.new()
	if index == FleetManager.active_ship_index:
		desc_lbl.text = "Active Player Ship | %s (Lvl %d)" % [assigned_cap.captain_name, assigned_cap.level]
		desc_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	elif FleetManager.is_on_mission(index):
		var mission = FleetManager.active_missions[index]["mission_type"]
		desc_lbl.text = "On Mission: %s | %s (Lvl %d)" % [mission.capitalize(), assigned_cap.captain_name, assigned_cap.level]
		desc_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.8))
	else:
		desc_lbl.text = "Idle at Port | %s (Lvl %d)" % [assigned_cap.captain_name, assigned_cap.level]
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	desc_lbl.add_theme_font_size_override("font_size", 12)
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	hbox.add_child(info_vbox)
	
	if index != FleetManager.active_ship_index:
		if FleetManager.is_on_mission(index):
			var cancel_btn = Button.new()
			cancel_btn.text = "Recall"
			cancel_btn.custom_minimum_size = Vector2(80, 40)
			cancel_btn.pressed.connect(func(): _on_recall_pressed(index))
			hbox.add_child(cancel_btn)
		else:
			var trade_btn = Button.new()
			trade_btn.text = "Trade"
			trade_btn.custom_minimum_size = Vector2(80, 40)
			trade_btn.pressed.connect(func(): _on_mission_pressed(index, cap_index, "trade"))
			hbox.add_child(trade_btn)
			
			var patrol_btn = Button.new()
			patrol_btn.text = "Patrol"
			patrol_btn.custom_minimum_size = Vector2(80, 40)
			patrol_btn.pressed.connect(func(): _on_mission_pressed(index, cap_index, "patrol"))
			hbox.add_child(patrol_btn)
			
			var defend_btn = Button.new()
			var is_defending = FleetManager.has_method("is_defending_home") and FleetManager.is_defending_home(index)
			defend_btn.text = "Defend: ON" if is_defending else "Defend: OFF"
			defend_btn.custom_minimum_size = Vector2(100, 40)
			if is_defending:
				defend_btn.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
			defend_btn.pressed.connect(func(): _on_defend_home_pressed(index, not is_defending))
			hbox.add_child(defend_btn)
			
		var make_active_btn = Button.new()
		make_active_btn.text = "Make Active"
		make_active_btn.custom_minimum_size = Vector2(100, 40)
		make_active_btn.pressed.connect(func(): _on_make_active_pressed(index))
		hbox.add_child(make_active_btn)
	
	fleet_container.add_child(hbox)
	fleet_container.add_child(HSeparator.new())

func _on_mission_pressed(ship_idx: int, cap_idx: int, type: String) -> void:
	FleetManager.assign_mission(ship_idx, cap_idx, type)
	_refresh_fleet()

func _on_recall_pressed(ship_idx: int) -> void:
	FleetManager.unassign_mission(ship_idx)
	_refresh_fleet()

func _on_defend_home_pressed(ship_idx: int, defend: bool) -> void:
	if FleetManager.has_method("set_defend_home"):
		FleetManager.set_defend_home(ship_idx, defend)
		_refresh_fleet()

func _on_make_active_pressed(index: int) -> void:
	FleetManager.active_ship_index = index
	# Keep the captain index in lockstep with the ship index, matching the pairing
	# _create_fleet_entry() displays for this row (cap_index falls back to 0 only
	# when index is out of range for owned_captains).
	FleetManager.active_captain_index = index if index < FleetManager.owned_captains.size() else 0
	var player = get_tree().get_first_node_in_group("player_ship")
	if player and "ship_stats" in player:
		var ship = FleetManager.get_active_ship()
		var cap = FleetManager.get_active_captain()
		player.ship_stats = ship
		if cap:
			player.active_captain = cap
			
		var combat = player.get_node_or_null("ShipCombat")
		if combat:
			var max_hp = ship.max_health
			if cap:
				max_hp *= cap.health_modifier
			max_hp *= TechManager.global_health_mod
			
			combat.current_health = max_hp
			if combat.has_signal("health_changed"):
				combat.health_changed.emit(combat.current_health, max_hp)
				
		_refresh_fleet()

# --- RESEARCH ---

func _refresh_research() -> void:
	if not research_container:
		return
	for child in research_container.get_children():
		child.queue_free()
		
	for tech in available_techs:
		_create_research_entry(tech)

func _create_research_entry(tech: TechData) -> void:
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = tech.tech_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = tech.description
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	var cost_dict = tech.get_cost_dict()
	var cost_lbl = Label.new()
	var cost_text = ""
	for k in cost_dict.keys():
		cost_text += str(cost_dict[k]) + " " + k.capitalize() + "  "
	cost_lbl.text = cost_text
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = "Research"
	btn.custom_minimum_size = Vector2(100, 40)
	
	if TechManager.is_unlocked(tech.tech_id):
		btn.text = "Researched"
		btn.disabled = true
	elif not ResourceManager.can_afford(cost_dict):
		btn.disabled = true
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		btn.pressed.connect(func(): _on_unlock_tech_pressed(tech, cost_dict))
		
	hbox.add_child(info_vbox)
	hbox.add_child(cost_lbl)
	hbox.add_child(btn)
	
	research_container.add_child(hbox)
	research_container.add_child(HSeparator.new())

func _on_unlock_tech_pressed(tech: TechData, cost: Dictionary) -> void:
	if ResourceManager.spend_resources(cost):
		TechManager.unlock_tech(tech)
		_refresh_research()

# --- TRADE ---

func _refresh_trade() -> void:
	if not trade_container:
		return
	for child in trade_container.get_children():
		child.queue_free()
		
	_create_trade_entry("Wood", 10, 50)  # Sell 10 Wood for 50 Gold
	_create_trade_entry("Iron", 5, 100)  # Sell 5 Iron for 100 Gold
	_create_trade_entry("Rum", 5, 150)   # Sell 5 Rum for 150 Gold

func _create_trade_entry(resource_name: String, amount: int, gold_value: int) -> void:
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = "Sell " + str(amount) + " " + resource_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "Receive " + str(gold_value) + " Gold"
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2)) # Gold color
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	var btn = Button.new()
	btn.text = "Sell"
	btn.custom_minimum_size = Vector2(100, 40)
	
	var res_key = resource_name.to_lower()
	if ResourceManager.get_resource(res_key) < amount:
		btn.disabled = true
	else:
		btn.pressed.connect(func(): _on_sell_pressed(res_key, amount, gold_value))
		
	hbox.add_child(info_vbox)
	hbox.add_child(btn)
	
	trade_container.add_child(hbox)
	trade_container.add_child(HSeparator.new())

func _on_sell_pressed(res_key: String, amount: int, gold_value: int) -> void:
	var cost = {}
	cost[res_key] = amount
	if ResourceManager.spend_resources(cost):
		ResourceManager.add_resource("gold", gold_value)
		_refresh_trade()
