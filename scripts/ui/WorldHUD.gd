class_name WorldHUD extends CanvasLayer

## Purpose: The in-game heads-up display for the World scene.
## Responsibilities: Shows speed, health, cannon cooldowns, dock prompts, resource counters.
##                   Applies the Pirate Theme and manages UI state. Shows live notoriety and
##                   time-to-next-region-escalation (M4), and announces region activations via a
##                   transient popup. (RaidReportScreen itself is shown by WorldManager.gd, not here.)
##                   Shows a one-time "while you were away" notice after an offline catch-up (M5).
## Dependencies: PirateThemeBuilder, ShipController signals, EmpireManager (notoriety_changed,
##               region_activated), SaveManager (_pending_offline_ticks)

# Signals from ShipController to connect to
signal _dummy  # ensures signals section exists

@onready var speed_label     : Label        = %SpeedLabel
@onready var health_bar      : ProgressBar  = %HealthBar
@onready var health_left     : Label        = %HealthLeftLabel
@onready var health_right    : Label        = %HealthRightLabel
@onready var port_label      : Label        = %PortCooldown
@onready var stbd_label      : Label        = %StarboardCooldown
@onready var dock_prompt     : PanelContainer = %DockPrompt
@onready var board_prompt    : PanelContainer = %BoardPrompt
@onready var compass_needle  : Control      = %CompassNeedle
@onready var wind_arrow      : Control      = %WindArrow

@onready var gold_label      : Label        = %GoldLabel
@onready var wood_label      : Label        = %WoodLabel
@onready var iron_label      : Label        = %IronLabel
@onready var rum_label       : Label        = %RumLabel
@onready var island_menu     : IslandMenu   = %IslandMenu
@onready var death_screen    : DeathScreen  = %DeathScreen
@onready var upgrade_choice_screen: UpgradeChoiceScreen = %UpgradeChoiceScreen
@onready var captains_log: CaptainsLog = %CaptainsLog
@onready var world_map_screen: WorldMapScreen = %WorldMapScreen
@onready var codex_screen: CanvasLayer = %CodexScreen
@onready var top_right_panel : VBoxContainer = %TopRightPanel
@onready var resource_bar    : PanelContainer = %ResourceBar
@onready var cannons_container: HBoxContainer = %CannonsContainer
@onready var tutorial_dialogue: TutorialDialogue = %TutorialDialogue

var _ship_controller: ShipController
# M11 — lazily cached; looked up once found since EnvironmentController is a
# scene node that may not exist yet the first few frames HUD is active.
var _environment_controller: Node = null

# Cannon cooldown display state — ShipCombat's own cooldown timers don't
# report progress, only a final "ready again" flip, so this tracks each
# side's cooldown window from the moment it fires to compute a live percent.
var _port_cooldown_total: float = 0.0
var _port_cooldown_start_ms: int = 0
var _stbd_cooldown_total: float = 0.0
var _stbd_cooldown_start_ms: int = 0

# Broadside indicator state (docs/navalCombat.md §5.2). Alignment has to be
# legible *before* the guns fire, so each side's readout reports whether the
# FiringSolver currently holds a target in that arc, not just its reload.
var _arc_locked := {"port": false, "starboard": false}
var _special_label: Label
var _objective_label: Label
var _ability_label: Label

func _ready() -> void:
	# Island.gd (capture announcements) and EncounterManager (encounter/boss
	# announcements) both look up the HUD via this group rather than a node
	# path/name, since the WorldHUD instance is actually named "WorldUI" in
	# World.tscn — a name-based lookup for "WorldHUD" always missed.
	add_to_group("hud")
	_apply_theme()
	_find_ship()
	# SaveManager.load_game() runs deferred and finishes after this _ready(), so
	# _pending_offline_ticks isn't populated yet on a real Continue-from-save load.
	# Check now for the already-loaded/no-save case, and again once loading completes.
	_check_offline_return()
	if SaveManager.has_signal("game_loaded") and not SaveManager.game_loaded.is_connected(_check_offline_return):
		SaveManager.game_loaded.connect(_check_offline_return)
	if SaveManager.has_signal("load_failed") and not SaveManager.load_failed.is_connected(_on_save_load_failed):
		SaveManager.load_failed.connect(_on_save_load_failed)
	_create_fps_label()
	if tutorial_dialogue and not tutorial_dialogue.visibility_changed.is_connected(_on_tutorial_dialogue_visibility_changed):
		tutorial_dialogue.visibility_changed.connect(_on_tutorial_dialogue_visibility_changed)

func _on_save_load_failed(reason: String) -> void:
	## M2 Task 12.3 — graceful degradation: a corrupt/unreadable save must not
	## silently drop the player into a fresh game with no explanation.
	announce_event(tr("Save data could not be loaded (%s) — starting fresh.") % reason, true)

func _on_tutorial_dialogue_visibility_changed() -> void:
	## M9 Requirement 5 — a tutorial beat and the combat HUD previously
	## rendered stacked with no arbitration (D69). Dimming rather than hiding
	## keeps the cannon panel legible as context without it visually
	## competing with the dialogue that has focus.
	if cannons_container:
		cannons_container.modulate.a = 0.35 if tutorial_dialogue.visible else 1.0

func _check_offline_return() -> void:
	## Show a one-time "while you were away" notice if SaveManager just replayed offline ticks
	if SaveManager._pending_offline_ticks > 0:
		var ticks = SaveManager._pending_offline_ticks
		SaveManager._pending_offline_ticks = 0
		announce_event(tr("While you were away: your empire kept running (%d ticks)") % ticks)

func _apply_theme() -> void:
	## Inject the runtime pirate theme into this HUD
	var theme := PirateThemeBuilder.build()
	for child in get_children():
		if child is Control:
			child.theme = theme

func _find_ship() -> void:
	## Try to locate the PlayerShip in the scene tree
	await get_tree().process_frame
	var ship = get_tree().get_first_node_in_group("player_ship")
	if ship and ship is ShipController:
		_ship_controller = ship
		ship.ship_speed_changed.connect(_on_speed_changed)
		ship.ship_health_changed.connect(_on_health_changed)
		ship.ship_destroyed.connect(_on_ship_destroyed)
		if ship.combat and ship.combat.has_signal("fired"):
			ship.combat.fired.connect(_on_cannon_fired)
		if ship.combat and ship.combat.has_signal("arc_lock_changed"):
			ship.combat.arc_lock_changed.connect(_on_arc_lock_changed)

	# Connect to global systems
	if ResourceManager.has_signal("resources_changed"):
		ResourceManager.resources_changed.connect(_on_resources_changed)
		# Initialize display
		_on_resources_changed(ResourceManager.current_resources)
		
	var current_scene = get_tree().current_scene
	var dock_sys = current_scene.get_node_or_null("Systems/DockingSystem") if current_scene else null
	if dock_sys:
		dock_sys.dock_completed.connect(_on_dock_completed)
		dock_sys.undock_initiated.connect(_on_undock_initiated)
		dock_sys.dock_area_entered.connect(_on_dock_area_entered)
		dock_sys.dock_area_exited.connect(_on_dock_area_exited)
		dock_sys.dock_speed_exceeded.connect(_on_dock_speed_exceeded)
		
	var boarding_sys = current_scene.get_node_or_null("Systems/BoardingSystem") if current_scene else null
	if boarding_sys:
		boarding_sys.boarding_prompt_available.connect(_on_boarding_prompt_available)
		boarding_sys.boarding_prompt_unavailable.connect(_on_boarding_prompt_unavailable)
		boarding_sys.boarding_resolved.connect(_on_boarding_resolved)

	var enc_mgr = current_scene.get_node_or_null("Systems/EncounterManager") if current_scene else null
	if enc_mgr:
		enc_mgr.encounter_started.connect(_on_encounter_started)
		enc_mgr.encounter_ended.connect(_on_encounter_ended)
		enc_mgr.objective_progress.connect(_on_objective_progress)
		if upgrade_choice_screen:
			upgrade_choice_screen.bind_encounter_manager(enc_mgr)
		
	# Create Economy Tick Label
	_create_economy_label()
	
	# Create Notoriety Label
	_create_notoriety_label()

	# Create the special-broadside readout
	_create_special_broadside_label()

	# Create the captain-ability readout
	_create_captain_ability_label()

	# Create the encounter objective readout
	_create_objective_label()

	# Captain's Log (M7 §9.1) + campaign objective feedback (§9.2/9.4)
	_create_captains_log_button()
	_create_world_map_button()
	_create_codex_button()
	CampaignManager.objective_completed.connect(_on_campaign_objective_completed)
	CampaignManager.chapter_completed.connect(_on_campaign_chapter_completed)
	CampaignManager.chapter_started.connect(_on_campaign_chapter_started)
	CampaignManager.objective_progressed.connect(_on_campaign_objective_progressed)

var _economy_label: Label
func _create_economy_label() -> void:
	_economy_label = Label.new()
	_economy_label.add_theme_font_size_override("font_size", 14)
	_economy_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	# Position top center
	_economy_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_economy_label.position.y += 20
	add_child(_economy_label)

var _fps_label: Label
func _create_fps_label() -> void:
	## M2 Task 12.1 — frame time monitoring and display.
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.position = Vector2(8, -20)
	add_child(_fps_label)

var notoriety_label: Label
var captains_log_button: Button
func _create_notoriety_label() -> void:
	notoriety_label = Label.new()
	notoriety_label.add_theme_font_size_override("font_size", 14)
	notoriety_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	notoriety_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Added as a sibling of ResourceBar inside TopRightPanel (a VBoxContainer)
	# rather than given its own independently-anchored rect — the previous
	# approach hardcoded offset_top to match ResourceBar's own offset_bottom,
	# two constants kept in sync only by convention, which silently drifted
	# apart once real multi-digit resource values grew ResourceBar taller than
	# its authored rect (D36). A container lays out its children by their
	# actual measured size, so this pair structurally cannot overlap.
	top_right_panel.add_child(notoriety_label)

	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		emp.notoriety_changed.connect(_on_notoriety_changed)
		emp.region_activated.connect(_on_region_activated)
		_on_notoriety_changed(emp.notoriety)

func _create_captains_log_button() -> void:
	## M7 §9.1 — added as a third child of top_right_panel (below the
	## notoriety label) rather than a fourth independently-hardcoded offset:
	## a hardcoded `offset_top = 100.0` here was calibrated against the old
	## notoriety label's fixed end position and silently started overlapping
	## it once that label became container-positioned (and thus taller) —
	## the exact "two independently-hardcoded numbers drift apart" failure
	## mode D36 already burned this HUD on once.
	captains_log_button = Button.new()
	captains_log_button.text = tr("Log")
	captains_log_button.custom_minimum_size = Vector2(70, 32)
	captains_log_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	captains_log_button.pressed.connect(func():
		if captains_log:
			captains_log.toggle())
	top_right_panel.add_child(captains_log_button)

var world_map_button: Button
func _create_world_map_button() -> void:
	## M10 Requirement 3 — same dynamic-positioning pattern as
	## _create_captains_log_button() just above: a fourth child of
	## top_right_panel, container-positioned rather than a fifth
	## independently-hardcoded offset.
	world_map_button = Button.new()
	world_map_button.text = tr("Map")
	world_map_button.custom_minimum_size = Vector2(70, 32)
	world_map_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	world_map_button.pressed.connect(func():
		if world_map_screen:
			world_map_screen.toggle())
	top_right_panel.add_child(world_map_button)


func _create_codex_button() -> void:
	## Uses the same container-owned placement as Log/Map, avoiding a second
	## hard-coded HUD offset and its known overlap regression (D36).
	var codex_button := Button.new()
	codex_button.text = tr("Codex")
	codex_button.custom_minimum_size = Vector2(70, 32)
	codex_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	codex_button.pressed.connect(func():
		if codex_screen and codex_screen.has_method("toggle"):
			codex_screen.toggle())
	top_right_panel.add_child(codex_button)


# --- Campaign feedback (M7 §9.2/§9.4) ---

const _OBJECTIVE_STALL_DELAY := 90.0
var _objective_stall_timer: float = 0.0
var _hinted_objective_ids: Array[String] = []

func _on_campaign_objective_completed(objective_id: String) -> void:
	var chapter := CampaignManager._current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if objective.objective_id == objective_id:
			announce_event(tr("Objective complete: %s") % objective.description)
			return

func _on_campaign_chapter_started(chapter: ChapterData) -> void:
	announce_event(tr("Chapter %d: %s") % [chapter.chapter_number, chapter.title])
	_objective_stall_timer = 0.0
	_hinted_objective_ids.clear()

func _on_campaign_chapter_completed(chapter: ChapterData) -> void:
	announce_event(tr("Chapter Complete: %s") % chapter.title)

func _on_campaign_objective_progressed(objective_id: String, _current: int, _target: int) -> void:
	# Real progress resets the stall clock and lets that objective's hint
	# surface again later if it stalls a second time.
	_objective_stall_timer = 0.0
	_hinted_objective_ids.erase(objective_id)

func _check_objective_stall(delta: float) -> void:
	_objective_stall_timer += delta
	if _objective_stall_timer < _OBJECTIVE_STALL_DELAY:
		return
	_objective_stall_timer = 0.0
	var chapter := CampaignManager._current_chapter()
	if not chapter:
		return
	for objective in chapter.objectives:
		if objective.is_optional or objective.hint_text.is_empty():
			continue
		if CampaignManager._completed_objective_ids.has(objective.objective_id):
			continue
		if _hinted_objective_ids.has(objective.objective_id):
			continue
		announce_event(objective.hint_text)
		_hinted_objective_ids.append(objective.objective_id)
		return


func _on_notoriety_changed(new_val: float) -> void:
	if not notoriety_label:
		return
		
	var text = tr("Notoriety: %.1f") % new_val
	var next_threshold = -1.0
	
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		for region in emp._regions:
			if not emp.is_region_active(region.id):
				if next_threshold < 0 or region.activation_notoriety_threshold < next_threshold:
					next_threshold = region.activation_notoriety_threshold
					
	if next_threshold >= 0:
		var remaining = max(0.0, next_threshold - new_val)
		text += "\n" + (tr("Next escalation in: %.1f") % remaining)
		
	notoriety_label.text = text

func _on_region_activated(region_id: String) -> void:
	var region_name = region_id
	var faction_name = tr("an Empire")
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		for r in emp._regions:
			if r.id == region_id:
				region_name = r.display_name
				if emp.has_method("_get_faction_by_id"):
					var f = emp._get_faction_by_id(r.dominant_faction)
					if f:
						faction_name = f.get("faction_name")
				break
				
	announce_event((tr("%s is now active!") % region_name) + "\n" + (tr("%s is hunting you!") % faction_name))

func _on_dock_area_entered(_island_id: String) -> void:
	show_dock_prompt(true)

func _on_dock_area_exited(_island_id: String) -> void:
	show_dock_prompt(false)

func _on_dock_speed_exceeded() -> void:
	announce_event(tr("Too fast to dock — slow down!"), true)

func _on_boarding_prompt_available(_enemy_ship: Node) -> void:
	if board_prompt:
		board_prompt.visible = true

func _on_boarding_prompt_unavailable() -> void:
	if board_prompt:
		board_prompt.visible = false

func _on_boarding_resolved(success: bool, loot: Dictionary, _target_faction_id: String = "", _target_ship_id: String = "") -> void:
	if success:
		var text = tr("Boarding Successful!") + "\n"
		for k in loot.keys():
			text += tr("+%d %s ") % [loot[k], tr(k.capitalize())]
		announce_event(text)
	else:
		announce_event(tr("Boarding Failed! Crew lost."))

func _tint_label(lbl: Label, current: int, maximum: int) -> void:
	if not lbl: return
	if current >= maximum:
		lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		lbl.remove_theme_color_override("font_color")

func _on_resources_changed(res: Dictionary) -> void:
	var max_res = ResourceManager.max_storage
	if gold_label: 
		gold_label.text = tr("💰 %s / %s") % [str(res.get("gold", 0)), str(max_res.get("gold", 9999))]
		_tint_label(gold_label, res.get("gold", 0), max_res.get("gold", 9999))
	if wood_label: 
		wood_label.text = tr("🪵 %s / %s") % [str(res.get("wood", 0)), str(max_res.get("wood", 9999))]
		_tint_label(wood_label, res.get("wood", 0), max_res.get("wood", 9999))
	if iron_label: 
		iron_label.text = tr("⛏️ %s / %s") % [str(res.get("iron", 0)), str(max_res.get("iron", 9999))]
		_tint_label(iron_label, res.get("iron", 0), max_res.get("iron", 9999))
	if rum_label:  
		rum_label.text  = tr("🍷 %s / %s") % [str(res.get("rum", 0)), str(max_res.get("rum", 9999))]
		_tint_label(rum_label, res.get("rum", 0), max_res.get("rum", 9999))
	if _economy_label:
		# Just append it to the economy label for now to avoid creating a new UI element
		var res_str = " | 🧪 %s" % str(res.get("research", 0))
		if not _economy_label.has_meta("res_str"):
			_economy_label.set_meta("res_str", res_str)
		_economy_label.set_meta("res_str", res_str)

func _on_dock_completed(island_id: String) -> void:
	show_dock_prompt(false)
	if island_menu:
		# Find the island node
		var dock_sys = get_tree().current_scene.get_node_or_null("Systems/DockingSystem")
		var island_node = dock_sys.active_dock_area.get_parent() if dock_sys and dock_sys.active_dock_area else null
		island_menu.open(island_node)

func _on_undock_initiated() -> void:
	if island_menu:
		island_menu.close()

func _on_cannon_fired(side: String) -> void:
	if not _ship_controller or not _ship_controller.combat or not _ship_controller.combat.ship_stats:
		return
	var cooldown_time = 1.0 / max(_ship_controller.combat.ship_stats.fire_rate, 0.1)
	if side == "port":
		_port_cooldown_total = cooldown_time
		_port_cooldown_start_ms = Time.get_ticks_msec()
	else:
		_stbd_cooldown_total = cooldown_time
		_stbd_cooldown_start_ms = Time.get_ticks_msec()

func _update_cannon_cooldown_display(side: String, total: float, start_ms: int) -> void:
	if total <= 0.0:
		set_cannon_cooldown(side, true, 1.0)
		return
	var elapsed = (Time.get_ticks_msec() - start_ms) / 1000.0
	var pct = clamp(elapsed / total, 0.0, 1.0)
	set_cannon_cooldown(side, pct >= 1.0, pct)

func _on_ship_destroyed() -> void:
	if death_screen and _ship_controller:
		death_screen.open(_ship_controller)

func _on_health_changed(current: float, maximum: float) -> void:
	set_health(current, maximum)

func _process(_delta: float) -> void:
	_update_cannon_cooldown_display("port", _port_cooldown_total, _port_cooldown_start_ms)
	_update_cannon_cooldown_display("starboard", _stbd_cooldown_total, _stbd_cooldown_start_ms)
	_update_special_broadside_display()
	_update_captain_ability_display()
	_check_objective_stall(_delta)

	if _fps_label:
		var fps := Engine.get_frames_per_second()
		var frame_ms := (1000.0 / fps) if fps > 0 else 0.0
		_fps_label.text = tr("%d FPS (%.1f ms)") % [fps, frame_ms]

	## Update compass needle to match ship yaw
	if _ship_controller and compass_needle:
		var yaw = fmod(_ship_controller.global_rotation_degrees.y, 360.0)
		compass_needle.rotation_degrees = yaw

	## M11 Requirement 2.3 — wind indicator. WindArrow is nested inside
	## CompassNeedle so it inherits the same +yaw rotation the N/S/E/W labels
	## get "for free"; its own local rotation_degrees only needs to add the
	## region's wind bearing on top of that; combined they land at the same
	## screen-relative-bearing convention the compass already establishes.
	if wind_arrow:
		if not is_instance_valid(_environment_controller):
			_environment_controller = get_tree().get_first_node_in_group("environment_controller")
		var region: RegionData = null
		if is_instance_valid(_environment_controller) and _environment_controller.has_method("get_current_region"):
			region = _environment_controller.get_current_region()
		if region and region.wind_strength > 0.0:
			wind_arrow.visible = true
			wind_arrow.rotation_degrees = region.wind_direction_degrees
			wind_arrow.modulate.a = lerp(0.35, 1.0, region.wind_strength)
		else:
			wind_arrow.visible = false


	if _economy_label and ResourceManager:
		var time_left = ResourceManager.ECONOMY_TICK_INTERVAL - ResourceManager._economy_timer
		var base_text = tr("Next Production: %.1fs") % max(0.0, time_left)
		if _economy_label.has_meta("res_str"):
			_economy_label.text = base_text + _economy_label.get_meta("res_str")
		else:
			_economy_label.text = base_text

func _on_speed_changed(speed: float) -> void:
	if speed_label:
		speed_label.text = tr("⚓ %.1f kn") % speed

func set_health(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value     = current
	if health_left:
		health_left.text = tr("🤍 %d / %d HP") % [int(current), int(maximum)]
	if health_right:
		health_right.text = "%d / %d" % [int(current), int(maximum)]

func _on_arc_lock_changed(side: String, locked: bool) -> void:
	_arc_locked[side] = locked

# --- Encounter readout ---

func _create_objective_label() -> void:
	## Top-centre, under the economy label. Anchored in an explicit rect that grows
	## from the centre so long objective text cannot run off either edge — the D36
	## failure mode with PRESET_CENTER's zero-width rect.
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE, true)
	_objective_label.offset_top = 44.0
	_objective_label.offset_bottom = 90.0
	_objective_label.visible = false
	add_child(_objective_label)

func _on_encounter_started(data) -> void:
	if not _objective_label:
		return
	_objective_label.visible = true
	_objective_label.text = tr("%s — %s") % [data.get_kind_name(), data.display_name]

func _on_objective_progress(current: int, total: int) -> void:
	if not _objective_label or not _objective_label.visible:
		return
	if total > 0:
		_objective_label.text = "%s  [%d / %d]" % [
			_objective_label.text.split("  [")[0], current, total]

func _on_encounter_ended(_victory: bool, _rewards: Dictionary) -> void:
	if _objective_label:
		_objective_label.visible = false

func set_cannon_cooldown(side: String, ready: bool, pct: float = 1.0) -> void:
	var label: Label = port_label if side == "port" else stbd_label
	if not label:
		return
	var locked: bool = _arc_locked.get(side, false)
	if locked and ready:
		# The moment that matters: a hostile is in the arc and the guns are
		# loaded, so this side is about to fire on its own.
		label.text = tr("ON TARGET ✹")
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	elif locked:
		label.text = tr("TARGET · RELOADING %d%%") % int(pct * 100.0)
		label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
	elif ready:
		label.text = tr("READY ⚓")
		label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	else:
		label.text = tr("RELOADING %d%% ⌛") % int(pct * 100.0)
		label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))

func _update_special_broadside_display() -> void:
	if not _special_label or not _ship_controller or not _ship_controller.combat:
		return
	var combat = _ship_controller.combat
	if not combat.has_method("is_special_broadside_ready"):
		_special_label.visible = false
		return
	if combat.is_special_broadside_ready():
		_special_label.text = tr("[SPACE] FULL BROADSIDE")
		_special_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		var pct: float = combat.get_special_cooldown_fraction()
		_special_label.text = tr("FULL BROADSIDE %d%%") % int(pct * 100.0)
		_special_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))

func _update_captain_ability_display() -> void:
	if not _ability_label or not _ship_controller:
		return
	var node = _ship_controller.get_node_or_null("CaptainAbility")
	if not node or not node.has_method("has_ability") or not node.has_ability():
		_ability_label.visible = false
		return
	_ability_label.visible = true
	var ability = node.get_ability()
	if node.is_ready():
		_ability_label.text = tr("[R] %s %s") % [ability.icon, ability.display_name]
		_ability_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	else:
		_ability_label.text = "%s %s %d%%" % [
			ability.icon, ability.display_name, int(node.get_cooldown_fraction() * 100.0)]
		_ability_label.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))

func _create_captain_ability_label() -> void:
	if not port_label or not port_label.get_parent():
		return
	_ability_label = Label.new()
	_ability_label.name = "CaptainAbilityLabel"
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_label.get_parent().add_child(_ability_label)
	_update_captain_ability_display()

func _create_special_broadside_label() -> void:
	## Sits directly under the two per-side readouts, reusing the same parent so
	## it inherits the existing cannon-panel layout rather than introducing a
	## second anchored control that could drift off-screen (the D36 failure mode).
	if not port_label or not port_label.get_parent():
		return
	_special_label = Label.new()
	_special_label.name = "SpecialBroadsideLabel"
	_special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_label.get_parent().add_child(_special_label)
	_update_special_broadside_display()

func show_dock_prompt(show: bool) -> void:
	if dock_prompt:
		dock_prompt.visible = show

func announce_event(text_content: String, is_warning: bool = false) -> void:
	## M9 Requirement 6 (D68) — previously bare, unframed red Label text
	## directly over the 3D world, reading as a debug print for every message
	## regardless of tone. Framed like the rest of the HUD's panels; color
	## reads informational (gold) by default, alarm-red only for genuine
	## warnings (e.g. docking too fast, a corrupted save).
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = PirateThemeBuilder.COLOR_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text_content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color",
		PirateThemeBuilder.COLOR_RED_HEALTH if is_warning else PirateThemeBuilder.COLOR_GOLD_BRIGHT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

	# Span the full width and wrap, rather than PRESET_CENTER. That preset
	# anchors a zero-width rect at the centre, so a long announcement grew
	# rightwards off the edge of the screen instead of centring within it —
	# "While you were away: your empire kept running (N ticks)" ran clean off
	# the frame. A full-width rect with wrapping centres properly at any length.
	panel.set_anchors_preset(Control.PRESET_HCENTER_WIDE, true)
	panel.offset_left = 40.0
	panel.offset_right = -40.0
	panel.offset_top = -140.0
	panel.offset_bottom = -40.0

	add_child(panel)

	# Start transparent, otherwise the first tween fades from 1.0 to 1.0 and the
	# announcement simply pops in.
	panel.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)
