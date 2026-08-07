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
@onready var compass_needle  : Control      = %CompassNeedle

@onready var gold_label      : Label        = %GoldLabel
@onready var wood_label      : Label        = %WoodLabel
@onready var iron_label      : Label        = %IronLabel
@onready var rum_label       : Label        = %RumLabel
@onready var island_menu     : IslandMenu   = %IslandMenu
@onready var death_screen    : DeathScreen  = %DeathScreen

var _ship_controller: ShipController

func _ready() -> void:
	_apply_theme()
	_find_ship()
	# SaveManager.load_game() runs deferred and finishes after this _ready(), so
	# _pending_offline_ticks isn't populated yet on a real Continue-from-save load.
	# Check now for the already-loaded/no-save case, and again once loading completes.
	_check_offline_return()
	if SaveManager.has_signal("game_loaded") and not SaveManager.game_loaded.is_connected(_check_offline_return):
		SaveManager.game_loaded.connect(_check_offline_return)

func _check_offline_return() -> void:
	## Show a one-time "while you were away" notice if SaveManager just replayed offline ticks
	if SaveManager._pending_offline_ticks > 0:
		var ticks = SaveManager._pending_offline_ticks
		SaveManager._pending_offline_ticks = 0
		announce_event("While you were away: your empire kept running (%d ticks)" % ticks)

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
		
		
	# Create Economy Tick Label
	_create_economy_label()
	
	# Create Notoriety Label
	_create_notoriety_label()

var _economy_label: Label
func _create_economy_label() -> void:
	_economy_label = Label.new()
	_economy_label.add_theme_font_size_override("font_size", 14)
	_economy_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	# Position top center
	_economy_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_economy_label.position.y += 20
	add_child(_economy_label)

var _notoriety_label: Label
func _create_notoriety_label() -> void:
	_notoriety_label = Label.new()
	_notoriety_label.add_theme_font_size_override("font_size", 14)
	_notoriety_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	# Position top right
	_notoriety_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notoriety_label.position.y += 20
	_notoriety_label.position.x -= 300
	add_child(_notoriety_label)
	
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		emp.notoriety_changed.connect(_on_notoriety_changed)
		emp.region_activated.connect(_on_region_activated)
		_on_notoriety_changed(emp.notoriety)

func _on_notoriety_changed(new_val: float) -> void:
	if not _notoriety_label:
		return
		
	var text = "Notoriety: %.1f" % new_val
	var next_threshold = -1.0
	
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		for region in emp._regions:
			if not emp.is_region_active(region.id):
				if next_threshold < 0 or region.activation_notoriety_threshold < next_threshold:
					next_threshold = region.activation_notoriety_threshold
					
	if next_threshold >= 0:
		var remaining = max(0.0, next_threshold - new_val)
		text += "\nNext escalation in: %.1f" % remaining
		
	_notoriety_label.text = text

func _on_region_activated(region_id: String) -> void:
	var region_name = region_id
	var faction_name = "an Empire"
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
				
	announce_event(region_name + " is now active!\n" + faction_name + " is hunting you!")

func _on_dock_area_entered(_island_id: String) -> void:
	show_dock_prompt(true)

func _on_dock_area_exited(_island_id: String) -> void:
	show_dock_prompt(false)

func _on_resources_changed(res: Dictionary) -> void:
	var max_res = ResourceManager.max_storage
	if gold_label: gold_label.text = "💰 %s / %s" % [str(res.get("gold", 0)), str(max_res.get("gold", 9999))]
	if wood_label: wood_label.text = "🪵 %s / %s" % [str(res.get("wood", 0)), str(max_res.get("wood", 9999))]
	if iron_label: iron_label.text = "⛏️ %s / %s" % [str(res.get("iron", 0)), str(max_res.get("iron", 9999))]
	if rum_label:  rum_label.text  = "🍷 %s / %s" % [str(res.get("rum", 0)), str(max_res.get("rum", 9999))]
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

func _on_ship_destroyed() -> void:
	if death_screen and _ship_controller:
		death_screen.open(_ship_controller)

func _on_health_changed(current: float, maximum: float) -> void:
	set_health(current, maximum)

func _process(_delta: float) -> void:
	## Update compass needle to match ship yaw
	if _ship_controller and compass_needle:
		var yaw = fmod(_ship_controller.global_rotation_degrees.y, 360.0)
		compass_needle.rotation_degrees = yaw
		
	if _economy_label and ResourceManager:
		var time_left = ResourceManager.ECONOMY_TICK_INTERVAL - ResourceManager._economy_timer
		var base_text = "Next Production: %.1fs" % max(0.0, time_left)
		if _economy_label.has_meta("res_str"):
			_economy_label.text = base_text + _economy_label.get_meta("res_str")
		else:
			_economy_label.text = base_text

func _on_speed_changed(speed: float) -> void:
	if speed_label:
		speed_label.text = "⚓ %.1f kn" % speed

func set_health(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value     = current
	if health_left:
		health_left.text = "🤍 %d / %d HP" % [int(current), int(maximum)]
	if health_right:
		health_right.text = "%d / %d" % [int(current), int(maximum)]

func set_cannon_cooldown(side: String, ready: bool, pct: float = 1.0) -> void:
	var label: Label = port_label if side == "port" else stbd_label
	if label:
		if ready:
			label.text = "READY ⚓"
			label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
		else:
			label.text = "RELOADING ⌛"
			label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))

func show_dock_prompt(show: bool) -> void:
	if dock_prompt:
		dock_prompt.visible = show

func announce_event(text_content: String) -> void:
	var label = Label.new()
	label.text = text_content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.y -= 100 # Slightly above center
	
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 2.0) # Hold for 2 seconds
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(2.0)
	tween.chain().tween_callback(label.queue_free)
