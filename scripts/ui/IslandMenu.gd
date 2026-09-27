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
@onready var panel: PanelContainer = $Panel

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
	PirateThemeBuilder.apply_button_juice(self)

	# Keep processing input while paused — open()/close() pause the game so
	# enemies don't keep sailing and shooting the player (and the economy
	# doesn't keep ticking) while this menu is up.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceManager.has_signal("resources_changed"):
		ResourceManager.resources_changed.connect(_on_resources_changed)


	# Create Colonize Button — label text is set per-island in open(), since cost is
	# now authored per-IslandData (IslandData.colonize_cost_gold) rather than fixed.
	colonize_btn = Button.new()
	colonize_btn.text = tr("Colonize")
	colonize_btn.custom_minimum_size = Vector2(150, 48)
	colonize_btn.pressed.connect(_on_colonize_pressed)
	island_name_label.get_parent().add_child(colonize_btn)
	
	# Apply theme
	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.dress_modal_dim($ColorRect)  # M22 6c: v0.3 teal-black backdrop
	UIMotion.fade_tabs(tab_container)  # M22 6c: pages fade in on tab change
	# M22 Phase 6.1 — tab pages are parchment with ink text (v0.3 screen 02's
	# parchment detail sheet), the same colour-only sub-theme Settings uses,
	# so every runtime-built row gets ink without a per-label override.
	tab_container.theme = PirateThemeBuilder.build_parchment_page_theme()
	# Colonize is this screen's one hero action when it's shown (design §7).
	PirateThemeBuilder.mark_primary(colonize_btn)
	_build_board_layouts()
	_build_tier_pips()

	if PirateThemeBuilder.is_mobile():
		panel.custom_minimum_size = PirateThemeBuilder.scaled_size(panel.custom_minimum_size)
		close_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(close_button.custom_minimum_size)
		colonize_btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(colonize_btn.custom_minimum_size)

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
	_refresh_tier_pips()
		
	# Configure Tabs
	# has_building_type(): building ids are level-suffixed ("shipyard_l1"), so
	# the exact has_building("shipyard") this used never matched real data.
	var has_shipyard = island.has_building_type("shipyard") if island.has_method("has_building_type") else false
	var has_tavern = island.has_building_type("tavern") if island.has_method("has_building_type") else false
	
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
	_select_first_visible_tab()

	if colonize_btn:
		colonize_btn.visible = type == IslandData.IslandType.NEUTRAL
		if colonize_btn.visible and island.island_data:
			colonize_btn.text = tr("Colonize (%d Gold)") % island.island_data.colonize_cost_gold

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
	PirateThemeBuilder.apply_button_juice(self)

	show()
	UIMotion.modal_enter(panel, $ColorRect)
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
	if current_island.has_method("has_building_type"):
		if current_island.has_building_type("shipyard"):
			_refresh_ships()
		if current_island.has_building_type("tavern"):
			_refresh_captains()
	_refresh_research()
	_refresh_trade()
	PirateThemeBuilder.apply_button_juice(self)

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
	if not current_island.island_data:
		return

	var cost = {"gold": current_island.island_data.colonize_cost_gold}
	if ResourceManager.spend_resources(cost):
		if FactionManager.has_method("get_player_faction"):
			current_island.capture_island(FactionManager.get_player_faction())
			# Re-open the menu to refresh tabs
			open(current_island)

func _refresh_buildings() -> void:
	_restyle_page.call_deferred(buildings_container)
	# Clear existing entries
	for child in buildings_container.get_children():
		child.queue_free()
		
	if not current_island or not current_island.has_method("has_building"):
		return
		
	for building in available_buildings:
		_create_building_entry(building)
	PirateThemeBuilder.apply_mobile_control_scaling(buildings_container)

func _create_building_entry(building: BuildingData) -> void:
	var hbox = HBoxContainer.new()
	hbox.set_meta("tile_icon", building.produces_resource)
	
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

# --- M22 Phase 6.1 restyle pass ---------------------------------------------
# Every tab builds its rows the same way (a name label at 18px, a grey 12px
# description, a "50 Gold  20 Wood" cost label coloured by affordability, an
# HSeparator), across six refresh functions. Rather than re-author each, one
# pass restyles whatever a refresh just built: rows become ink inset cards on
# the parchment page, label roles map to kit variations, state colours map to
# palette tokens readable on parchment, and plain cost text becomes icon cost
# chips. Display-only: every button, signal and handler is left untouched.
const _PORTRAIT_SIZE := 96.0
## What an empty tab page says instead of rendering blank parchment.
const _EMPTY_PAGE_TEXT := {
	"FleetContainer": "No ships in your fleet yet. Buy one at a Shipyard.",
	"ResearchContainer": "Nothing left to research here.",
	"CaptainsContainer": "No captains are drinking here tonight.",
	"ShipsContainer": "The shipyard has nothing for sale.",
	"BuildingsContainer": "Nothing to build here.",
	"TradeContainer": "No one here is buying.",
}
const _COST_RESOURCES := {"gold": "gold", "wood": "wood", "iron": "iron", "rum": "rum", "research": "research"}

## TabContainer keeps a hidden tab current: a neutral island (Construction
## hidden) opened on a blank Construction page with no tab highlighted
## (M22 6b sweep). Land on the first tab the player can actually see.
func _select_first_visible_tab() -> void:
	if not tab_container.is_tab_hidden(tab_container.current_tab):
		return
	for i in tab_container.get_tab_count():
		if not tab_container.is_tab_hidden(i):
			tab_container.current_tab = i
			return


func _restyle_page(container: Container) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is HSeparator:
			child.visible = false  # cards separate rows now
		elif child is BoxContainer and not child.get_parent() is PanelContainer:
			var card := PanelContainer.new()
			card.theme_type_variation = &"InkInsetPanel"
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(card)
			container.move_child(card, child.get_index())
			child.reparent(card)
			_restyle_subtree(child)
		elif child is Label:
			_restyle_label(child)
	if _boards.has(container):
		_layout_board(container)
	var has_content := false
	for child in container.get_children():
		if not child.is_queued_for_deletion() and child is Control and child.visible and child.name != "EmptyPage":
			has_content = true
			break
	var empty := container.get_node_or_null("EmptyPage")
	if has_content and empty:
		empty.queue_free()
	elif not has_content and not empty and _EMPTY_PAGE_TEXT.has(String(container.name)):
		var note := Label.new()
		note.name = "EmptyPage"
		note.text = tr(_EMPTY_PAGE_TEXT[String(container.name)])
		note.theme_type_variation = &"InkBodyLabel"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.modulate = Color(1, 1, 1, 0.7)
		container.add_child(note)


func _restyle_subtree(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			# Row children fill the card's height by default — a Hire/Build
			# button beside a tall captain card stretched to 160px.
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif child is Label:
			_restyle_label(child)
		elif child is Container:
			_restyle_subtree(child)


func _restyle_label(label: Label) -> void:
	var size := label.get_theme_font_size("font_size") if label.has_theme_font_size_override("font_size") else 0
	if size >= 18:
		label.remove_theme_font_size_override("font_size")
		label.theme_type_variation = &"InkTitleLabel"
		label.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	elif size > 0:
		label.remove_theme_font_size_override("font_size")
		label.theme_type_variation = &"ChipLabel"
		# Wrap rather than set the page's min width: an unwrapped long
		# description made the whole modal change width tab to tab.
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pal := UITokens.palette()
	var unaffordable := false
	if label.has_theme_color_override("font_color"):
		var c := label.get_theme_color("font_color")
		# The pre-M22 state colours were chosen for a dark navy page; on
		# parchment grey and yellow vanish, so re-map by what they MEANT.
		if c.r > 0.8 and c.g < 0.45:
			unaffordable = true
			label.add_theme_color_override("font_color", pal.brick)
		elif c.g > 0.7 and c.r < 0.35:
			label.add_theme_color_override("font_color", pal.hp_good.darkened(0.35))
		elif c.b > 0.7 and c.r < 0.35:
			label.add_theme_color_override("font_color", pal.sunset_teal)
		else:
			label.remove_theme_color_override("font_color")  # grey/yellow -> page ink
	var chips := _cost_chips_for(label.text, unaffordable)
	if chips:
		var parent := label.get_parent()
		parent.add_child(chips)
		parent.move_child(chips, label.get_index())
		label.visible = false


## "50 Gold  20 Wood  " -> a row of icon cost chips; null for anything else
## ("Requires Island Tier 2", names, descriptions).
func _cost_chips_for(text: String, unaffordable: bool) -> Control:
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty() or parts.size() % 2 != 0:
		return null
	var pairs: Array = []
	for i in range(0, parts.size(), 2):
		var key := String(parts[i + 1]).to_lower()
		if not parts[i].is_valid_int() or not _COST_RESOURCES.has(key):
			return null
		pairs.append([parts[i], key])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for pair in pairs:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"CostChip"
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = UIIcons.get_icon(_COST_RESOURCES[pair[1]])
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inner.add_child(icon)
		var amount := Label.new()
		amount.text = pair[0]
		amount.theme_type_variation = &"ChipLabel"
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if unaffordable:
			amount.add_theme_color_override("font_color", UITokens.palette().brick)
		inner.add_child(amount)
		chip.add_child(inner)
		row.add_child(chip)
	return row


# --- M22 Phase 6.1: v0.3 screen 02 tile board + right-docked detail ----------
# Construction/Shipyard/Tavern/Research are a board of selectable tiles with
# the selected entry's full card docked on the right, its one enabled action
# the Primary. Fleet and Trade stay card lists: a fleet ship's level,
# component, module and mission rows belong together (a tile per row would
# scatter them), and Trade is a handful of one-tap Sell actions.
#
# The existing row builders and every handler are untouched: _layout_board()
# re-parents the SAME row nodes (their buttons, closures and signals intact)
# from the page's list into the detail panel. Refreshes run on every economy
# tick (_on_resources_changed), so the selection is restored by key rather
# than reset.
const _TILE_SIZE := Vector2(196, 200)
const _DETAIL_WIDTH := 460.0
const _BOARD_MIN_HEIGHT := 380.0
const _TIER_PIP_COUNT := 5
## v0.3 tier nodes: 28 design px, the current one 36.
const _TIER_NODE := 44.0
const _TIER_NODE_CURRENT := 56.0
## container (the VBox rows are built into) -> {detail, body, selected, group}
var _boards: Dictionary = {}
var _tier_label: Label
var _tier_pips: HBoxContainer


func _build_board_layouts() -> void:
	for container in [buildings_container, ships_container, captains_container, research_container]:
		var scroll: Control = container.get_parent()
		var tab_name := String(scroll.name)
		var idx := scroll.get_index()
		var page := HBoxContainer.new()
		# Same name + index as the ScrollContainer it replaces as the tab
		# page, so tab titles and set_tab_hidden(index) are unchanged.
		scroll.name = tab_name + "Board"
		page.add_theme_constant_override("separation", 20)
		tab_container.add_child(page)
		tab_container.move_child(page, idx)
		page.name = tab_name
		scroll.reparent(page)
		# It was a tab page: TabContainer hid it whenever it wasn't the current
		# tab, and that `visible = false` survives the reparent — the board
		# vanished and the detail slid to the left edge (found in the sweep's
		# geometry dump; a headless probe happened to catch it visible).
		scroll.visible = true
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size.y = _BOARD_MIN_HEIGHT
		var detail := PanelContainer.new()
		detail.name = "Detail"
		detail.theme_type_variation = &"InkInsetPanel"
		detail.custom_minimum_size = Vector2(_DETAIL_WIDTH, _BOARD_MIN_HEIGHT)
		var body := VBoxContainer.new()
		body.name = "DetailBody"
		body.add_theme_constant_override("separation", 12)
		detail.add_child(body)
		page.add_child(detail)
		_boards[container] = {"detail": detail, "body": body, "selected": "", "group": null}


func _layout_board(container: Container) -> void:
	var board: Dictionary = _boards[container]
	var body: VBoxContainer = board.body
	# The previous refresh's docked card is not a child of `container`, so
	# the refresh's own clear-down never reached it.
	for child in body.get_children():
		child.queue_free()
	var cards: Array[PanelContainer] = []
	for child in container.get_children():
		if child is PanelContainer and not child.is_queued_for_deletion() and child.visible:
			cards.append(child)
	if cards.is_empty():
		board.detail.visible = false
		return
	board.detail.visible = true
	# The previous refresh's flow is only queued for deletion here; while it
	# still holds the name, the new one would silently be auto-renamed.
	var stale := container.get_node_or_null("Tiles")
	if stale:
		stale.name = "TilesStale"
	var flow := HFlowContainer.new()
	flow.name = "Tiles"
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	container.add_child(flow)
	container.move_child(flow, 0)
	var group := ButtonGroup.new()
	board.group = group
	var first_key := ""
	var tile_for_selected: Button = null
	for i in cards.size():
		var card := cards[i]
		_stack_card_for_detail(card)
		card.visible = false
		var key := "%d:%s" % [i, _card_title(card)]
		if first_key.is_empty():
			first_key = key
		var tile := _make_tile(card, key, group)
		tile.pressed.connect(_select_card.bind(container, card, key))
		flow.add_child(tile)
		if key == board.selected:
			tile_for_selected = tile
	if not tile_for_selected:
		tile_for_selected = flow.get_child(0) as Button
		board.selected = first_key
	tile_for_selected.set_pressed_no_signal(true)
	tile_for_selected.emit_signal("pressed")


func _select_card(container: Container, card: PanelContainer, key: String) -> void:
	var board: Dictionary = _boards[container]
	board.selected = key
	var body: VBoxContainer = board.body
	for child in body.get_children():
		# Send the previously docked card back to the (hidden) list rather
		# than freeing it — its tile can be selected again.
		child.visible = false
		child.reparent(container)
	card.reparent(body)
	card.visible = true
	# One Primary per screen: the docked entry's first enabled action — unless
	# Colonize is showing, which is then the screen's hero action.
	var marked := false
	for btn in card.find_children("*", "Button", true, false):
		if btn.visible and not btn.disabled and not marked and not colonize_btn.visible:
			PirateThemeBuilder.mark_primary(btn)
			marked = true
		else:
			PirateThemeBuilder.unmark_primary(btn)


## Re-flows a list row (portrait? | info | cost | buttons, side by side) into
## the detail panel's stacked form: header (portrait + info), cost chips,
## then the actions row right-aligned. Same nodes, new parents.
func _stack_card_for_detail(card: PanelContainer) -> void:
	if card.has_meta("stacked"):
		return
	card.set_meta("stacked", true)
	var row := card.get_child(0) as BoxContainer
	if not row:
		return
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var costs := HFlowContainer.new()
	costs.add_theme_constant_override("h_separation", 8)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	for child in row.get_children():
		if child is Button:
			child.reparent(actions)
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif child is HBoxContainer and child.get_child_count() > 0 and child.get_child(0) is PanelContainer:
			child.reparent(costs)  # a cost-chip row
		elif child is Label and not child.visible:
			child.reparent(costs)  # the hidden original cost label (kept for its text)
		elif child is Label:
			child.reparent(costs)  # "Requires Island Tier 3", "Crew Full", …
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			child.reparent(header)
	stack.add_child(header)
	stack.add_child(costs)
	stack.add_child(actions)
	card.remove_child(row)
	row.queue_free()
	card.add_child(stack)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.set_meta("tile_icon", row.get_meta("tile_icon", ""))
	if row.has_meta("tile_title"):
		card.set_meta("tile_title", row.get_meta("tile_title"))


func _card_title(card: Node) -> String:
	if card.has_meta("tile_title"):
		return String(card.get_meta("tile_title"))
	for lbl in card.find_children("*", "Label", true, false):
		if lbl.theme_type_variation == &"InkTitleLabel" and not lbl.text.is_empty():
			return lbl.text
	for lbl in card.find_children("*", "Label", true, false):
		if lbl.visible and not lbl.text.is_empty():
			return lbl.text
	return "?"


## Tile caption: the entry's name without its " Level N" suffix — that reads
## on the tile's status line instead ("Lv 1 · Build"). Long names wrapped to
## 3+ lines inside the tile otherwise (a Label's autowrap minimum height
## ignores max_lines_visible), overflowing it.
func _tile_title(card: Node) -> String:
	var t := _card_title(card)
	var at := t.rfind(" Level ")
	if at > 0:
		t = t.substr(0, at)
	# "Recruit Crew (Currently: 15/15)": the parenthetical is detail-panel
	# information; on a tile it only truncated mid-phrase.
	var paren := t.find(" (")
	return t.substr(0, paren) if paren > 0 else t


func _tile_level(card: Node) -> String:
	var t := _card_title(card)
	var at := t.rfind(" Level ")
	return (tr("Lv %s") % t.substr(at + 7)) if at > 0 else ""


func _make_tile(card: PanelContainer, key: String, group: ButtonGroup) -> Button:
	var status := _tile_status(card)
	var level := _tile_level(card)
	var tile := PirateThemeBuilder.make_board_tile(_TILE_SIZE, _tile_icon(card), _tile_title(card),
		status.text if level.is_empty() else "%s · %s" % [level, status.text], status.color)
	tile.name = "Tile_" + key.validate_node_name()
	tile.button_group = group
	tile.tooltip_text = _card_title(card)
	if status.dim:
		tile.modulate = Color(1, 1, 1, 0.72)
	return tile


func _tile_icon(card: Node) -> Texture2D:
	var key := String(card.get_meta("tile_icon", ""))
	if not key.is_empty() and _COST_RESOURCES.has(key.to_lower()):
		return UIIcons.get_icon(_COST_RESOURCES[key.to_lower()])
	if key == "cannonball" or key == "research":
		return UIIcons.get_icon(key)
	for rect in card.find_children("*", "TextureRect", true, false):
		if rect.visible and rect.texture:
			return rect.texture  # captain portrait / first cost icon
	return null


## What the tile says under its name: the entry's own action state, never a
## second, separately-derived rule (so tile and detail can't disagree).
func _tile_status(card: Node) -> Dictionary:
	var pal := UITokens.palette()
	for lbl in card.find_children("*", "Label", true, false):
		if lbl.visible and lbl.text.begins_with(tr("Requires")):
			return {"text": tr("Locked"), "color": pal.brick, "dim": true}
	for btn in card.find_children("*", "Button", true, false):
		if not btn.visible:
			continue
		if btn.disabled:
			return {"text": btn.text, "color": pal.ink, "dim": true}
		return {"text": btn.text, "color": pal.hp_good.darkened(0.35), "dim": false}
	# No action button (e.g. "Crew Full"): the entry's own state label — the
	# one the restyle pass coloured by meaning.
	for lbl in card.find_children("*", "Label", true, false):
		if lbl.visible and lbl.has_theme_color_override("font_color") and lbl.text.length() <= 24:
			return {"text": lbl.text, "color": lbl.get_theme_color("font_color"), "dim": true}
	return {"text": "", "color": pal.ink, "dim": false}


func _build_tier_pips() -> void:
	var header := island_name_label.get_parent()
	var box := HBoxContainer.new()
	box.name = "TierBox"
	box.add_theme_constant_override("separation", 8)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tier_label = Label.new()
	_tier_label.theme_type_variation = &"ChipLabel"
	box.add_child(_tier_label)
	_tier_pips = HBoxContainer.new()
	_tier_pips.add_theme_constant_override("separation", 6)
	_tier_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_tier_pips)
	header.add_child(box)
	header.move_child(box, island_name_label.get_index() + 1)


## v0.3 screen 02's island-tier track: "Tier N" + five pips, filled to N.
func _refresh_tier_pips() -> void:
	if not _tier_pips:
		return
	var tier := 0
	if current_island and current_island.has_method("get_island_tier"):
		tier = int(current_island.get_island_tier())
	_tier_pips.get_parent().visible = tier > 0
	# v0.3 caption ("ISLAND TIER") — the numbered nodes carry the number.
	_tier_label.text = tr("ISLAND TIER")
	_tier_label.add_theme_color_override("font_color", UITokens.palette().text_muted_dark)
	for child in _tier_pips.get_children():
		child.queue_free()
	# v0.3 screen 02 tier track: numbered nodes. Done = brass
	# (radial #f7de98 -> #c29444), current = bigger, gold
	# (#fffbe0 -> #ffd97a -> #c29444) with a breathing glow, locked = dark
	# wood #2a1d12 with a #5a4632 rim and muted number.
	for i in _TIER_PIP_COUNT:
		var n := i + 1
		var state := "done" if n < tier else ("cur" if n == tier else "lock")
		var d := _TIER_NODE_CURRENT if state == "cur" else _TIER_NODE
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(d, d)
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(int(d))
		st.set_border_width_all(3)
		st.anti_aliasing = true
		match state:
			"done":
				st.bg_color = Color("#DDB870")
				st.border_color = Color("#4A300F")
			"cur":
				st.bg_color = Color("#FFD97A")
				st.border_color = Color("#4A300F")
				st.shadow_color = Color(1.0, 217.0 / 255.0, 122.0 / 255.0, 0.7)
				st.shadow_size = 14
			_:
				st.bg_color = Color("#2A1D12")
				st.border_color = Color("#5A4632")
		node.add_theme_stylebox_override("panel", st)
		var num := Label.new()
		num.text = str(n)
		num.theme_type_variation = &"PillNumLabel"
		num.add_theme_font_size_override("font_size", UITokens.FONT_CHIP if state != "cur" else UITokens.FONT_BODY)
		num.add_theme_color_override("font_color", Color("#7A6650") if state == "lock" else Color("#3A2410"))
		num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		node.add_child(num)
		_tier_pips.add_child(node)
		if state == "cur":
			UIMotion.idle_glow(node)


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
			if AudioManager: AudioManager.play_sound("build_success")
			structure_changed.emit(building.building_id, false)
			HapticFeedbackManager.reward()

func _on_upgrade_pressed(old_id: String, next_upgrade: BuildingData) -> void:
	if current_island and current_island.has_method("upgrade_structure"):
		if current_island.upgrade_structure(old_id, next_upgrade):
			_refresh_buildings()
			if AudioManager: AudioManager.play_sound("upgrade_success")
			structure_changed.emit(next_upgrade.building_id, true)
			HapticFeedbackManager.reward()

# --- SHIPYARD ---

func _refresh_ships() -> void:
	_restyle_page.call_deferred(ships_container)
	for child in ships_container.get_children():
		child.queue_free()
	_create_repair_ship_entry()
	for ship in available_ships:
		_create_ship_entry(ship)
	PirateThemeBuilder.apply_mobile_control_scaling(ships_container)


func _create_repair_ship_entry() -> void:
	## DockingSystem still provides passive repairs, but a player should not have
	## to wait or infer that a shipyard is doing work. This explicit action is
	## available only through the friendly-island Shipyard tab that calls it.
	var player := get_tree().get_first_node_in_group("player_ship")
	var damage = player.get_node_or_null("ShipDamage") if player else null
	if not damage:
		return
	var hull: float = damage.get("hull")
	var hull_max: float = damage.get_pool_maximum("hull")
	var sails: float = damage.get("sails")
	var sails_max: float = damage.get_pool_maximum("sails")
	var row := HBoxContainer.new()
	row.set_meta("tile_icon", "cannonball")
	row.set_meta("tile_title", tr("Repairs"))
	var details := Label.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.text = tr("Hull %d / %d  •  Rigging %d / %d") % [roundi(hull), roundi(hull_max), roundi(sails), roundi(sails_max)]
	details.add_theme_font_size_override("font_size", 14)
	row.add_child(details)
	var repair_button := Button.new()
	repair_button.text = tr("Repair Ship")
	repair_button.custom_minimum_size = Vector2(120, 44)
	repair_button.disabled = is_equal_approx(hull, hull_max) and is_equal_approx(sails, sails_max)
	if not repair_button.disabled:
		repair_button.pressed.connect(_on_repair_ship_pressed.bind(damage))
	row.add_child(repair_button)
	ships_container.add_child(row)
	ships_container.add_child(HSeparator.new())


func _on_repair_ship_pressed(damage: Node) -> void:
	if not is_instance_valid(damage):
		return
	## A Shipyard restores hull and rigging. Crew remain a Tavern concern, so
	## this does not erase the recruit/boarding economy.
	var restored: float = damage.repair("hull", damage.get_pool_maximum("hull"))
	restored += damage.repair("sails", damage.get_pool_maximum("sails"))
	if restored <= 0.0:
		return
	HapticFeedbackManager.reward()
	_refresh_ships()

func _create_ship_entry(ship: ShipStats) -> void:
	var hbox = HBoxContainer.new()
	hbox.set_meta("tile_icon", "cannonball")
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
	_restyle_page.call_deferred(captains_container)
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
	PirateThemeBuilder.apply_mobile_control_scaling(captains_container)

func _create_crew_recruitment_entry() -> void:
	var player = get_tree().get_first_node_in_group("player_ship")
	if not player: return
	var dmg = player.get_node_or_null("ShipDamage")
	if not dmg: return
	
	var current_crew = dmg.crew
	var max_crew = dmg.ship_stats.max_crew
	var missing = max_crew - current_crew
	
	var hbox = HBoxContainer.new()
	hbox.set_meta("tile_icon", "rum")
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
	# M22 Phase 6.2 — v0.3 screen 03's roster card: a framed 96px portrait
	# (was a bare 48px square). No rarity gem — CaptainData has no rarity
	# field, and the spec forbids inventing one (plain frame instead).
	var portrait_frame = PanelContainer.new()
	portrait_frame.theme_type_variation = &"PortraitFrame"
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait_slot = Control.new()
	portrait_slot.custom_minimum_size = Vector2(_PORTRAIT_SIZE, _PORTRAIT_SIZE)
	portrait_frame.add_child(portrait_slot)
	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(_PORTRAIT_SIZE, _PORTRAIT_SIZE)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var portrait_fallback = Label.new()
	portrait_fallback.custom_minimum_size = Vector2(_PORTRAIT_SIZE, _PORTRAIT_SIZE)
	portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_slot.add_child(portrait_rect)
	portrait_slot.add_child(portrait_fallback)
	PortraitFallback.apply_to_texture_rect(portrait_rect, portrait_fallback, cap.portrait_path, cap.captain_name)
	hbox.add_theme_constant_override("separation", 16)
	hbox.add_child(portrait_frame)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = cap.captain_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	
	var desc_lbl = Label.new()
	desc_lbl.text = cap.background
	desc_lbl.add_theme_font_size_override("font_size", 12)

	info_vbox.add_child(name_lbl)
	if cap.active_ability:
		var ability_lbl := Label.new()
		ability_lbl.text = tr("Ability: %s") % cap.active_ability.display_name
		ability_lbl.theme_type_variation = &"ChipLabel"
		ability_lbl.add_theme_color_override("font_color", UITokens.palette().sunset_teal)
		info_vbox.add_child(ability_lbl)
	info_vbox.add_child(desc_lbl)
	# Stat chips (v0.3 "DMG 412 · HP 3.1k · SPD 88"), the same numbers the
	# single "(SPD x1.00 | TRN x…)" line carried, one chip each.
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 8)
	for stat in [[tr("SPD x%.2f"), cap.speed_modifier], [tr("TRN x%.2f"), cap.turn_rate_modifier],
			[tr("DMG x%.2f"), cap.damage_modifier], [tr("HP x%.2f"), cap.health_modifier]]:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"CostChip"
		var stat_lbl := Label.new()
		stat_lbl.text = String(stat[0]) % float(stat[1])
		stat_lbl.theme_type_variation = &"ChipLabel"
		chip.add_child(stat_lbl)
		stats.add_child(chip)
	info_vbox.add_child(stats)
	
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
	_restyle_page.call_deferred(fleet_container)
	if not fleet_container:
		return
	for child in fleet_container.get_children():
		child.queue_free()

	for i in range(FleetManager.owned_ships.size()):
		var owned = FleetManager.owned_ships[i]
		_create_fleet_entry(owned, i)
	PirateThemeBuilder.apply_mobile_control_scaling(fleet_container)

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
	##
	## M23 — the ship level is a Clash-of-Clans-style Town Hall: it caps every
	## component's level, and only rises once all components have caught up.
	## Every disabled button says *why* it's disabled.
	var level_row = HBoxContainer.new()
	var level_lbl = Label.new()
	var behind := owned.get_components_below_level()
	if owned.level >= OwnedShipData.MAX_LEVEL:
		level_lbl.text = tr("Ship Level %d: MAX") % owned.level
	elif not behind.is_empty():
		level_lbl.text = tr("Ship Level %d — upgrade all parts to Lv %d first (%d to go)") % [
			owned.level, owned.level, behind.size()]
	else:
		level_lbl.text = tr("Ship Level %d → %d: %s") % [
			owned.level, owned.level + 1, _format_cost(owned.get_level_up_cost())]
	level_lbl.add_theme_font_size_override("font_size", 12)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	level_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(level_lbl)

	if owned.level < OwnedShipData.MAX_LEVEL:
		var level_btn = Button.new()
		level_btn.text = tr("Upgrade Ship")
		level_btn.custom_minimum_size = Vector2(110, 32)
		if not owned.can_level_up_ship() or not ResourceManager.can_afford(owned.get_level_up_cost()):
			level_btn.disabled = true
		else:
			level_btn.pressed.connect(func(): _on_level_up_pressed(index))
		level_row.add_child(level_btn)
	fleet_container.add_child(level_row)

	var catalog := OwnedShipData.get_component_catalog()
	if catalog:
		for comp in catalog.components:
			if comp:
				_create_component_row(owned, index, comp)

	for slot in [ShipModuleData.Slot.HULL, ShipModuleData.Slot.CANNON,
			ShipModuleData.Slot.SAIL, ShipModuleData.Slot.UTILITY, ShipModuleData.Slot.SPECIAL]:
		_create_module_slot_row(owned, index, slot)

func _create_component_row(owned: OwnedShipData, index: int, comp: ShipComponentData) -> void:
	var row = HBoxContainer.new()
	var lvl := owned.get_component_level(comp.component_id)
	var lbl = Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = tr("%s  Lv %d/%d  (%s)") % [tr(comp.display_name), lvl, owned.level, comp.describe_level(lvl)]
	lbl.tooltip_text = tr(comp.description)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(lbl)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 32)
	if lvl >= OwnedShipData.MAX_LEVEL:
		btn.text = tr("MAX")
		btn.disabled = true
	elif not owned.can_upgrade_component(comp.component_id):
		btn.text = tr("Needs Ship Lv %d") % (lvl + 1)
		btn.disabled = true
	else:
		var cost := owned.get_component_upgrade_cost(comp.component_id)
		btn.text = tr("Upgrade: %s") % _format_cost(cost)
		if not ResourceManager.can_afford(cost):
			btn.disabled = true
		else:
			btn.pressed.connect(func(): _on_upgrade_component_pressed(index, comp.component_id))
	row.add_child(btn)
	fleet_container.add_child(row)


func _format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in ["gold", "wood", "iron", "rum"]:
		if int(cost.get(key, 0)) > 0:
			parts.append("%d %s" % [int(cost[key]), tr(key.capitalize())])
	return "  ".join(parts) if not parts.is_empty() else tr("Free")


func _on_upgrade_component_pressed(index: int, component_id: String) -> void:
	if FleetManager.upgrade_component(index, component_id):
		_refresh_fleet()


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
	_restyle_page.call_deferred(research_container)
	if not research_container:
		return
	for child in research_container.get_children():
		child.queue_free()
		
	for tech in available_techs:
		_create_research_entry(tech)
	PirateThemeBuilder.apply_mobile_control_scaling(research_container)

func _create_research_entry(tech: TechData) -> void:
	var hbox = HBoxContainer.new()
	hbox.set_meta("tile_icon", "research")
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
	_restyle_page.call_deferred(trade_container)
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
	PirateThemeBuilder.apply_mobile_control_scaling(trade_container)

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
