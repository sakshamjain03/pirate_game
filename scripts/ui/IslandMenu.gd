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
var available_modules: Array[ShipModuleData] = []

var colonize_btn: Button

func _ready() -> void:
	add_to_group("island_menu")
	close_button.pressed.connect(_on_close_pressed)
	tab_container.tab_changed.connect(func(_idx): if AudioManager: AudioManager.play_sound("ui_tab_switch"))
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
	colonize_btn.text = tr("Colonize (1000 Gold)")
	colonize_btn.custom_minimum_size = Vector2(150, 40)
	colonize_btn.pressed.connect(_on_colonize_pressed)
	island_name_label.get_parent().add_child(colonize_btn)
	
	# Apply theme
	theme = PirateThemeBuilder.build()

func _load_building_data() -> void:
	# In a real game, this would load from a directory or registry
	var mill = load("res://resources/buildings/LumberMill_L1.tres")
	if mill: available_buildings.append(mill)
	var mine = load("res://resources/buildings/Mine_L1.tres")
	if mine: available_buildings.append(mine)
	var farm = load("res://resources/buildings/Farm_L1.tres")
	if farm: available_buildings.append(farm)
	var market = load("res://resources/buildings/Market_L1.tres")
	if market: available_buildings.append(market)
	var shipyard = load("res://resources/buildings/Shipyard_L1.tres")
	if shipyard: available_buildings.append(shipyard)
	var tavern = load("res://resources/buildings/Tavern_L1.tres")
	if tavern: available_buildings.append(tavern)
	var watchtower = load("res://resources/buildings/Watchtower_L1.tres")
	if watchtower: available_buildings.append(watchtower)
	var fortress = load("res://resources/buildings/Fortress_L1.tres")
	if fortress: available_buildings.append(fortress)
	var warehouse = load("res://resources/buildings/Warehouse_L1.tres")
	if warehouse: available_buildings.append(warehouse)
	var academy = load("res://resources/buildings/Academy_L1.tres")
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

	# Load Modules (M8 §13: ship level + modules)
	var module_names = ["ReinforcedPlanking", "IronHull", "HeavyCannons", "SwiftLoaders",
		"FullCanvas", "ReinforcedRigging", "ExtraBerths", "LongGlass",
		"MasterGunners", "CopperBottom"]
	for m in module_names:
		var module = load("res://resources/modules/" + m + ".tres")
		if module: available_modules.append(module)

	# Load Techs — M11: scan resources/techs/ instead of a hardcoded filename list,
	# the same DirAccess scan pattern EventManager uses for resources/world/events/.
	var tech_dir = DirAccess.open("res://resources/techs/")
	if tech_dir:
		tech_dir.list_dir_begin()
		var file_name = tech_dir.get_next()
		while file_name != "":
			if not tech_dir.current_is_dir() and file_name.ends_with(".tres"):
				var tech = load("res://resources/techs/" + file_name) as TechData
				if tech: available_techs.append(tech)
			file_name = tech_dir.get_next()

func open(island: Node3D) -> void:
	current_island = island
	
	var name_text = tr("Unknown Island")
	var type = IslandData.IslandType.NEUTRAL
	if island.has_method("get_island_name"):
		name_text = island.get_island_name()
	if "island_data" in island and island.island_data:
		type = island.island_data.island_type
		if island.island_data.owner_faction:
			name_text += " (" + island.island_data.owner_faction.faction_name + ")"
		elif type == IslandData.IslandType.NEUTRAL:
			name_text = tr("%s (Neutral)") % name_text
		elif type == IslandData.IslandType.ENEMY:
			name_text = tr("%s (Enemy)") % name_text
			
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
			colonize_btn.tooltip_text = tr("This region has not yet drawn attention")
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
	if AudioManager: AudioManager.play_sound("ui_click")
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
		cost_text += str(cost_dict[k]) + " " + tr(k.capitalize()) + "  "
	cost_lbl.text = cost_text
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Button
	var btn = Button.new()
	btn.text = tr("Build")
	btn.custom_minimum_size = Vector2(80, 40)
	
	# Check if already built
	var is_built = false
	var existing_building: BuildingData = null
	if current_island.has_method("has_building"):
		for b in current_island.built_buildings:
			# Match by prefix so Level 2 counts as the same base building
			var b_base = b.building_id.split("_l")[0]
			var check_base = building.building_id.split("_l")[0]
			if b_base == check_base:
				is_built = true
				existing_building = b
				break
				
	var island_tier = 1
	if current_island.has_method("get_island_tier"):
		island_tier = current_island.get_island_tier()
				
	if is_built and existing_building:
		if "next_upgrade" in existing_building and existing_building.next_upgrade:
			btn.text = tr("Upgrade")
			var next_b = existing_building.next_upgrade
			
			if "required_island_tier" in next_b and next_b.required_island_tier > island_tier:
				btn.disabled = true
				cost_lbl.text = tr("Requires Island Tier %d") % next_b.required_island_tier
				cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				var up_cost = next_b.get_cost_dict()
				cost_text = ""
				for k in up_cost.keys():
					cost_text += str(up_cost[k]) + " " + tr(k.capitalize()) + "  "
				cost_lbl.text = cost_text
				
				if not ResourceManager.can_afford(up_cost):
					btn.disabled = true
					cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				else:
					cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
					btn.pressed.connect(func(): _on_upgrade_pressed(existing_building.building_id, next_b))
		else:
			btn.text = tr("Max Lvl")
			btn.disabled = true
			cost_lbl.text = ""
	else:
		if "required_island_tier" in building and building.required_island_tier > island_tier:
			btn.disabled = true
			cost_lbl.text = tr("Requires Island Tier %d") % building.required_island_tier
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
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
	name_lbl.text = ship.display_name if not ship.display_name.is_empty() else tr("Unknown Ship")
	name_lbl.add_theme_font_size_override("font_size", 18)

	var desc_lbl = Label.new()
	desc_lbl.text = tr("HP: %d | DMG: %d | SPD: %d | TRN: %.1f") % [ship.max_health, ship.cannon_damage, ship.max_speed, ship.turn_rate]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)

	var cost_dict = {"gold": ship.cost_gold, "wood": ship.cost_wood, "iron": ship.cost_iron}
	if ship.cost_rum > 0:
		cost_dict["rum"] = ship.cost_rum

	var cost_lbl = Label.new()
	cost_lbl.text = tr("%d Gold  %d Wood  %d Iron  ") % [ship.cost_gold, ship.cost_wood, ship.cost_iron]
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = tr("Buy")
	btn.custom_minimum_size = Vector2(80, 40)
	
	if FleetManager.owns_ship_stats(ship):
		btn.text = tr("Owned")
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
		if AudioManager: AudioManager.play_sound("ship_purchase")
		_refresh_ships()

# --- TAVERN ---

func _refresh_captains() -> void:
	for child in captains_container.get_children():
		child.queue_free()
		
	_create_crew_recruitment_entry()

	for cap in available_captains:
		# A captain whose chapter hasn't been reached is excluded entirely, not
		# shown disabled — a locked list of 20 is noise on a phone
		# (docs/12_CHARACTER_BIBLE.md §6).
		if not CampaignManager.is_chapter_completed(cap.unlock_chapter_id):
			continue
		_create_captain_entry(cap)

func _create_crew_recruitment_entry() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if not player: return
	var dmg = player.get_node_or_null("ShipDamage")
	if not dmg: return
	
	var current_crew = dmg.crew
	var max_crew = dmg.ship_stats.max_crew
	var missing = max_crew - current_crew
	
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = tr("Recruit Crew (Currently: %d/%d)") % [current_crew, max_crew]
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = tr("Cost: 10 Gold & 1 Rum per crew member")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	hbox.add_child(info_vbox)
	
	if missing > 0:
		var btn = Button.new()
		var recruit_amt = min(missing, 5)
		var cost = {"gold": 10 * recruit_amt, "rum": 1 * recruit_amt}

		btn.text = tr("Recruit %d") % recruit_amt
		btn.custom_minimum_size = Vector2(100, 40)
		
		var cost_lbl = Label.new()
		cost_lbl.text = tr("%d Gold  %d Rum  ") % [cost["gold"], cost["rum"]]
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		if not ResourceManager.can_afford(cost):
			btn.disabled = true
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
			btn.pressed.connect(func(): _on_recruit_crew_pressed(recruit_amt, cost, dmg))
			
		hbox.add_child(cost_lbl)
		hbox.add_child(btn)
	else:
		var full_lbl = Label.new()
		full_lbl.text = tr("Crew Full")
		full_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		hbox.add_child(full_lbl)
		
	captains_container.add_child(hbox)
	captains_container.add_child(HSeparator.new())

func _on_recruit_crew_pressed(amount: float, cost: Dictionary, dmg: Node) -> void:
	if ResourceManager.spend_resources(cost):
		dmg.crew = min(dmg.crew + amount, dmg.ship_stats.max_crew)
		if dmg.has_signal("pool_changed"):
			dmg.pool_changed.emit("crew", dmg.crew, dmg.ship_stats.max_crew)
		_refresh_captains()

func _create_captain_entry(cap: CaptainData) -> void:
	var hbox = HBoxContainer.new()

	# M11 Requirement 9 — real portrait art (or the sanctioned flat-color
	# icon-bust substitute) where it exists, falling back to the existing
	# monogram treatment otherwise, via PortraitFallback's shared contract.
	var portrait_slot = Control.new()
	portrait_slot.custom_minimum_size = Vector2(48, 48)
	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(48, 48)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var portrait_fallback = Label.new()
	portrait_fallback.custom_minimum_size = Vector2(48, 48)
	portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_slot.add_child(portrait_rect)
	portrait_slot.add_child(portrait_fallback)
	PortraitFallback.apply_to_texture_rect(portrait_rect, portrait_fallback, cap.portrait_path, cap.captain_name)
	hbox.add_child(portrait_slot)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = cap.captain_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = tr("%s (SPD x%.2f | TRN x%.2f | DMG x%.2f | HP x%.2f)") % [cap.background, cap.speed_modifier, cap.turn_rate_modifier, cap.damage_modifier, cap.health_modifier]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	# Cost - per-captain, ramps with roster depth
	var cost_dict = {"gold": cap.hire_cost_gold}

	var cost_lbl = Label.new()
	cost_lbl.text = tr("%d Gold  ") % cap.hire_cost_gold
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = tr("Hire")
	btn.custom_minimum_size = Vector2(80, 40)
	
	if cap in FleetManager.owned_captains:
		btn.text = tr("Hired")
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
		if AudioManager: AudioManager.play_sound("captain_recruit")
		_refresh_captains()

# --- FLEET ---

func _refresh_fleet() -> void:
	if not fleet_container:
		return
	for child in fleet_container.get_children():
		child.queue_free()

	for i in range(FleetManager.owned_ships.size()):
		var owned = FleetManager.owned_ships[i]
		_create_fleet_entry(owned, i)

func _create_fleet_entry(owned: OwnedShipData, index: int) -> void:
	var ship: ShipStats = owned.ship_stats
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	var ship_name = ship.display_name if ship and not ship.display_name.is_empty() else tr("Unknown Ship")
	name_lbl.text = tr("%s (Lvl %d)") % [ship_name, owned.level]
	name_lbl.add_theme_font_size_override("font_size", 18)

	var cap_index = index if index < FleetManager.owned_captains.size() else 0
	var assigned_cap = FleetManager.owned_captains[cap_index]
	
	var desc_lbl = Label.new()
	if index == FleetManager.active_ship_index:
		desc_lbl.text = tr("Active Player Ship | %s (Lvl %d)") % [assigned_cap.captain_name, assigned_cap.level]
		desc_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	elif FleetManager.is_on_mission(index):
		var mission_label = FleetManager.get_mission_display_text(index)
		desc_lbl.text = tr("On Mission: %s | %s (Lvl %d)") % [mission_label, assigned_cap.captain_name, assigned_cap.level]
		desc_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.8))
	else:
		desc_lbl.text = tr("Idle at Port | %s (Lvl %d)") % [assigned_cap.captain_name, assigned_cap.level]
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	desc_lbl.add_theme_font_size_override("font_size", 12)
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	hbox.add_child(info_vbox)
	
	if index != FleetManager.active_ship_index:
		if FleetManager.is_on_mission(index):
			var cancel_btn = Button.new()
			cancel_btn.text = tr("Recall")
			cancel_btn.custom_minimum_size = Vector2(80, 40)
			cancel_btn.pressed.connect(func(): _on_recall_pressed(index))
			hbox.add_child(cancel_btn)
		else:
			var trade_btn = Button.new()
			trade_btn.text = tr("Trade Route")
			trade_btn.custom_minimum_size = Vector2(90, 40)
			trade_btn.pressed.connect(func(): _on_trade_route_pressed(index, cap_index))
			hbox.add_child(trade_btn)
			
			var patrol_btn = Button.new()
			patrol_btn.text = tr("Patrol")
			patrol_btn.custom_minimum_size = Vector2(80, 40)
			patrol_btn.pressed.connect(func(): _on_mission_pressed(index, cap_index, "patrol"))
			hbox.add_child(patrol_btn)
			
			var defend_btn = Button.new()
			var is_defending = FleetManager.has_method("is_defending_home") and FleetManager.is_defending_home(index)
			defend_btn.text = tr("Defend: ON") if is_defending else tr("Defend: OFF")
			defend_btn.custom_minimum_size = Vector2(100, 40)
			if is_defending:
				defend_btn.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
			defend_btn.pressed.connect(func(): _on_defend_home_pressed(index, not is_defending))
			hbox.add_child(defend_btn)
			
		var make_active_btn = Button.new()
		make_active_btn.text = tr("Make Active")
		make_active_btn.custom_minimum_size = Vector2(100, 40)
		make_active_btn.pressed.connect(func(): _on_make_active_pressed(index))
		hbox.add_child(make_active_btn)

	fleet_container.add_child(hbox)
	_create_progression_rows(owned, index)
	fleet_container.add_child(HSeparator.new())

func _create_progression_rows(owned: OwnedShipData, index: int) -> void:
	## Ship level + modules (`docs/navalCombat.md` §13) — one row for leveling
	## the hull, one per module slot. List-based like the rest of this menu
	## rather than a dedicated equip screen.
	var level_row = HBoxContainer.new()
	var level_lbl = Label.new()
	if owned.level >= OwnedShipData.MAX_LEVEL:
		level_lbl.text = tr("Level: MAX")
	else:
		var cost = owned.get_level_up_cost()
		level_lbl.text = tr("Level Up: %d Gold  %d Wood") % [cost.get("gold", 0), cost.get("wood", 0)]
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	level_row.add_child(level_lbl)

	if owned.level < OwnedShipData.MAX_LEVEL:
		var level_btn = Button.new()
		level_btn.text = tr("Level Up")
		level_btn.custom_minimum_size = Vector2(90, 32)
		if not ResourceManager.can_afford(owned.get_level_up_cost()):
			level_btn.disabled = true
		else:
			level_btn.pressed.connect(func(): _on_level_up_pressed(index))
		level_row.add_child(level_btn)
	fleet_container.add_child(level_row)

	for slot in [ShipModuleData.Slot.HULL, ShipModuleData.Slot.CANNON,
			ShipModuleData.Slot.SAIL, ShipModuleData.Slot.UTILITY, ShipModuleData.Slot.SPECIAL]:
		_create_module_slot_row(owned, index, slot)

func _create_module_slot_row(owned: OwnedShipData, index: int, slot: int) -> void:
	var row = HBoxContainer.new()
	var equipped: ShipModuleData = owned.get_module_in_slot(slot)

	var slot_lbl = Label.new()
	slot_lbl.custom_minimum_size = Vector2(160, 0)
	slot_lbl.text = tr("%s: %s") % [
		tr(ShipModuleData.Slot.keys()[slot].capitalize()),
		equipped.display_name if equipped else tr("Empty")]
	slot_lbl.add_theme_font_size_override("font_size", 12)
	slot_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(slot_lbl)

	for module in available_modules:
		if module.slot != slot:
			continue
		var btn = Button.new()
		btn.text = module.display_name
		btn.custom_minimum_size = Vector2(120, 32)
		if module == equipped:
			btn.text = tr("%s [Equipped]") % module.display_name
			btn.disabled = true
		elif not ResourceManager.can_afford({"gold": module.cost_gold, "wood": module.cost_wood, "iron": module.cost_iron}):
			btn.disabled = true
		else:
			btn.pressed.connect(func(): _on_equip_module_pressed(index, module))
		row.add_child(btn)

	fleet_container.add_child(row)

func _on_level_up_pressed(index: int) -> void:
	if FleetManager.level_up_ship(index):
		_refresh_fleet()

func _on_equip_module_pressed(index: int, module: ShipModuleData) -> void:
	if FleetManager.equip_module(index, module):
		_refresh_fleet()

func _on_mission_pressed(ship_idx: int, cap_idx: int, type: String) -> void:
	FleetManager.assign_mission(ship_idx, cap_idx, type)
	_refresh_fleet()

func _on_trade_route_pressed(ship_idx: int, cap_idx: int) -> void:
	## M11 Requirement 6 — a trade route is tied to the port it's opened from
	## (region-derived tier and name), rather than the player picking an
	## abstract distance out of nowhere.
	var region_tier = 1
	var route_name = "Local Route"
	if current_island and current_island.has_method("get_island_id") and EmpireManager:
		var region = EmpireManager.get_region_for_island(current_island.get_island_id())
		if region:
			region_tier = region.tier
			route_name = region.display_name + " Route"
	FleetManager.assign_trade_route(ship_idx, cap_idx, route_name, region_tier)
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
			
		# A newly bought or swapped hull arrives fresh: restore every pool through
		# ShipDamage rather than only setting hull, so sails and crew match the
		# new ship's maxima instead of carrying over the old hull's damage.
		var combat = player.get_node_or_null("ShipCombat")
		var dmg = player.get_node_or_null("ShipDamage")
		if dmg:
			# ship_stats propagation is handled by ShipController._apply_ship_stats().
			dmg.restore_all()
			if combat and combat.has_signal("health_changed"):
				combat.health_changed.emit(dmg.hull, dmg.get_pool_maximum("hull"))
		elif combat:
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
		cost_text += str(cost_dict[k]) + " " + tr(k.capitalize()) + "  "
	cost_lbl.text = cost_text
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var btn = Button.new()
	btn.text = tr("Research")
	btn.custom_minimum_size = Vector2(100, 40)

	var island_tier = 1
	if current_island and current_island.has_method("get_island_tier"):
		island_tier = current_island.get_island_tier()

	if TechManager.is_unlocked(tech.tech_id):
		btn.text = tr("Researched")
		btn.disabled = true
	elif not TechManager.can_research(tech, island_tier):
		btn.disabled = true
		if tech.required_island_tier > island_tier:
			cost_lbl.text = tr("Requires Island Tier %d") % tech.required_island_tier
		else:
			cost_lbl.text = tr("Requires prior research")
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
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
		if AudioManager: AudioManager.play_sound("tech_unlock")
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

	var diplomacy_header = Label.new()
	diplomacy_header.text = tr("Diplomacy")
	diplomacy_header.add_theme_font_size_override("font_size", 20)
	trade_container.add_child(diplomacy_header)

	for faction_id in ["pirate_clans", "royal_navy", "merchant_guild"]:
		_create_tribute_entry(faction_id)

func _create_tribute_entry(faction_id: String) -> void:
	## M11 Requirement 6 — the inverse of the existing "attacking a faction's
	## ship reduces reputation" dynamic: spend resources for a reputation
	## bump, on a cooldown (FactionManager.pay_tribute()) so it can't be
	## spammed back to friendly.
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rep = FactionManager.get_reputation(faction_id)
	var name_lbl = Label.new()
	name_lbl.text = tr("Pay Tribute — %s") % tr(faction_id.capitalize().replace("_", " "))
	name_lbl.add_theme_font_size_override("font_size", 18)

	var desc_lbl = Label.new()
	var cooldown = FactionManager.get_tribute_cooldown_remaining(faction_id)
	if cooldown > 0.0:
		desc_lbl.text = tr("Reputation: %d | Cools down in %ds") % [rep, ceili(cooldown)]
	else:
		desc_lbl.text = tr("Reputation: %d | %d Gold for +%d reputation") % [
			rep, FactionManager.TRIBUTE_COST_GOLD, FactionManager.TRIBUTE_REPUTATION_GAIN]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)

	var btn = Button.new()
	btn.text = tr("Tribute")
	btn.custom_minimum_size = Vector2(100, 40)
	if not FactionManager.can_pay_tribute(faction_id) or not ResourceManager.can_afford({"gold": FactionManager.TRIBUTE_COST_GOLD}):
		btn.disabled = true
	else:
		btn.pressed.connect(func(): _on_pay_tribute_pressed(faction_id))

	hbox.add_child(info_vbox)
	hbox.add_child(btn)

	trade_container.add_child(hbox)
	trade_container.add_child(HSeparator.new())

func _on_pay_tribute_pressed(faction_id: String) -> void:
	if FactionManager.pay_tribute(faction_id):
		if AudioManager: AudioManager.play_sound("ui_confirm")
		_refresh_trade()
	elif AudioManager:
		AudioManager.play_sound("ui_error")

func _create_trade_entry(resource_name: String, amount: int, gold_value: int) -> void:
	var hbox = HBoxContainer.new()
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = tr("Sell %d %s") % [amount, resource_name]
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = tr("Receive %d Gold") % gold_value
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2)) # Gold color
	
	info_vbox.add_child(name_lbl)
	info_vbox.add_child(desc_lbl)
	
	var btn = Button.new()
	btn.text = tr("Sell")
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
