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
@onready var sail_label      : Label        = %SailLabel
@onready var health_bar      : ProgressBar  = %HealthBar
@onready var health_container: Control      = %HealthBarContainer
@onready var health_left     : Label        = %HealthLeftLabel
@onready var health_right    : Label        = %HealthRightLabel
@onready var port_label      : Label        = %PortCooldown
@onready var stbd_label      : Label        = %StarboardCooldown
@onready var port_alignment_label: Label    = %PortAlignment
@onready var stbd_alignment_label: Label    = %StarboardAlignment
@onready var port_header_label    : Label   = %PortHeader
@onready var stbd_header_label    : Label   = %StbdHeader
@onready var mobile_controls: Node = get_node_or_null("MobileControls")
@onready var enemy_health_bars_layer: Control = %EnemyHealthBars
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
@onready var whats_new_screen: WhatsNewScreen = %WhatsNewScreen
@onready var wardrobe_screen: WardrobeScreen = %WardrobeScreen

## M17 Requirement 6.1 — one of the three permitted rewarded surfaces.
const RewardedBonusOfferScene := preload("res://scenes/ui/RewardedBonusOffer.tscn")
## preload rather than the bare global class name — headless GUT runs don't
## always have a freshly rebuilt global-script-class cache (same reasoning
## as SettingsMenu.gd's own ChoiceDialogScript constant).
const HudCustomizeOverlayScript := preload("res://scripts/ui/HudCustomizeOverlay.gd")
const EnemyHealthBarWidgetScene := preload("res://scenes/ui/EnemyHealthBarWidget.tscn")
## Presentation-only cutoff for the enemy health bar overlay — not a combat
## balance value, so a plain constant is fine (AGENTS.md's no-hardcoded-
## gameplay-values rule targets balance data, not UI legibility knobs).
const ENEMY_BAR_DISPLAY_RANGE := 150.0
@onready var top_right_panel : VBoxContainer = %TopRightPanel
@onready var resource_bar    : PanelContainer = %ResourceBar
@onready var cannons_container: HBoxContainer = %CannonsContainer
@onready var tutorial_dialogue: TutorialDialogue = %TutorialDialogue

## M13 Task 16.5 gave the utility buttons usable mobile targets, but five
## permanent targets still obscure the world and compete with sailing/combat.
## PC keeps direct mouse-accessible buttons. Phone builds expose one Menu
## button and reveal these infrequent destinations only on demand.
const HUD_BUTTON_SIZE_PC     := Vector2(70, 32)
const HUD_BUTTON_SIZE_MOBILE := Vector2(120, 52)
static func _hud_button_min_size() -> Vector2:
	return HUD_BUTTON_SIZE_PC if OS.has_feature("pc") else HUD_BUTTON_SIZE_MOBILE

## Test-only injection for the mobile branch: desktop CI cannot report a
## phone OS feature, so layout coverage needs a deterministic override.
@export var force_mobile_utility_menu: bool = false

var _ship_controller: ShipController
## Cached once the player ship is found — sibling of ShipCombat under the
## ship, same lookup ShipCombat._get_solver() uses internally.
var _firing_solver: FiringSolver
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
var _objective_card: PanelContainer
var _ability_label: Label
var _last_reported_health: float = -1.0

## Screen-space enemy health bars (item 2 of the 2026-09-21 combat-clarity
## fix) — pooled per ship instance ID so a widget persists across frames
## rather than being torn down and rebuilt each tick.
var _enemy_bar_pool: Dictionary = {}

func _ready() -> void:
	# Island.gd (capture announcements) and EncounterManager (encounter/boss
	# announcements) both look up the HUD via this group rather than a node
	# path/name, since the WorldHUD instance is actually named "WorldUI" in
	# World.tscn — a name-based lookup for "WorldHUD" always missed.
	add_to_group("hud")
	_apply_theme()
	_style_resource_chips()
	_find_ship()
	# SaveManager.load_game() runs deferred and finishes after this _ready(), so
	# _pending_offline_ticks isn't populated yet on a real Continue-from-save load.
	# Check now for the already-loaded/no-save case, and again once loading completes.
	_check_offline_return()
	if SaveManager.has_signal("game_loaded") and not SaveManager.game_loaded.is_connected(_check_offline_return):
		SaveManager.game_loaded.connect(_check_offline_return)
	if SaveManager.has_signal("load_failed") and not SaveManager.load_failed.is_connected(_on_save_load_failed):
		SaveManager.load_failed.connect(_on_save_load_failed)
	# M14 Requirement 5.2 — deliberately no immediate call here (unlike
	# _check_offline_return() above): a version-string comparison has no safe
	# default before World._seed_whats_new_version()/SaveManager.load_game()
	# have actually run, whereas _pending_offline_ticks defaults safely to 0.
	# game_loaded fires exactly once per boot regardless of new-game/continue/
	# failed-load (D15), so connecting to it alone is both correct and enough.
	if SaveManager.has_signal("game_loaded") and not SaveManager.game_loaded.is_connected(_check_whats_new):
		SaveManager.game_loaded.connect(_check_whats_new)
	_create_fps_label()
	if PirateThemeBuilder.is_mobile():
		MobileLayoutManager.layout_changed.connect(_apply_mobile_safe_area)
		get_viewport().size_changed.connect(_apply_mobile_safe_area)
		# Auto-fire makes side-fire buttons and their cooldown readout redundant
		# on a phone. The compact controls retain the special broadside instead.
		# CannonsContainer itself must stay hidden on mobile — a real Galaxy A35
		# device test previously found this exact bottom-center container
		# burying MobileControls' Actions cluster (test_mobile_controls_layout.gd);
		# its arc/range/alignment readout is instead mirrored onto MobileControls'
		# own (already safe-area-checked) Actions cluster below, via
		# _update_alignment_previews() -> MobileControls.update_alignment_caption().
		if cannons_container:
			cannons_container.hide()
		if dock_prompt:
			dock_prompt.hide()
		if board_prompt:
			board_prompt.hide()
		call_deferred("_apply_mobile_safe_area")
		# Settings > Customize HUD Layout is only meaningful with a live HUD,
		# but Settings is always its own scene (never an overlay on
		# World.tscn) — see SettingsManager.pending_hud_customize_request's
		# own comment. Queued after the deferred safe-area call above so
		# handles are built from each control's final, post-layout position.
		call_deferred("_open_hud_customize_overlay_if_requested")
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


func _apply_mobile_safe_area() -> void:
	## HUD edge widgets use Android's unobscured rectangle rather than assuming
	## the whole display is tappable. Centred modals stay centred and therefore
	## need no separate phone/tablet layout variant.
	var safe := MobileLayoutManager.safe_area(get_viewport())
	var top_bar: Control = %TopBar
	var hud_scale := 1.45
	# A player's saved drag/resize customization (Settings > Customize HUD
	# Layout) is applied as a bounded delta on top of each element's already-
	# computed default position/scale — never a replacement of it.
	if top_bar:
		var result := MobileLayoutManager.apply_control_override(
			"top_bar", safe.position + Vector2(12, 12), hud_scale, get_viewport(), top_bar.size)
		top_bar.position = result.position
		top_bar.scale = Vector2.ONE * float(result.scale)
	if top_right_panel:
		# The resource/notoriety cluster was authored at desktop reading size.
		# Scale it as one compact unit so the icon, amount, and panel spacing keep
		# their relationship instead of producing a row of tiny phone text.
		var base_position := Vector2(
			safe.end.x - top_right_panel.size.x * hud_scale - 12.0,
			safe.position.y + 12.0)
		var result := MobileLayoutManager.apply_control_override(
			"top_right_panel", base_position, hud_scale, get_viewport(), top_right_panel.size)
		top_right_panel.position = result.position
		top_right_panel.scale = Vector2.ONE * float(result.scale)
		# MobileControls.btn_pause placed itself using a starting guess (its
		# own MobileLayoutManager.mobile_scale(), floor 0.55) that has no
		# relationship to this panel's own fixed hud_scale = 1.45 above — on a
		# real device where the two diverge, the panel (taller than guessed)
		# covered all but btn_pause's bottom sliver, making it nearly
		# untappable. Nudged down here, right after this panel's real bottom
		# edge is known, rather than guessed a second time.
		var mobile_controls_for_pause := get_node_or_null("MobileControls")
		var pause_btn_to_nudge: Control = mobile_controls_for_pause.btn_pause \
			if mobile_controls_for_pause and "btn_pause" in mobile_controls_for_pause else null
		if pause_btn_to_nudge:
			var min_pause_y := top_right_panel.get_global_rect().end.y + 12.0
			pause_btn_to_nudge.position.y = maxf(pause_btn_to_nudge.position.y, min_pause_y)
	if _economy_label:
		# _economy_label ("Next Production: Xs") kept its desktop-authored
		# PRESET_CENTER_TOP + a fixed +20 offset on mobile too — on a phone-width
		# viewport, screen-center lands under/behind top_right_panel's now much
		# wider (scaled) footprint, hiding all but a sliver of the text behind
		# it (device-test feedback 2026-09-20). Anchor stays CENTER_TOP (keeps
		# it horizontally centred regardless of text length); only the Y offset
		# is pushed below whichever of TopBar/top_right_panel sits lower.
		var top_bar_bottom_for_econ := (top_bar.position.y + top_bar.size.y * hud_scale) if top_bar else safe.position.y + 62.0
		var panel_bottom_for_econ := top_right_panel.get_global_rect().end.y if top_right_panel else safe.position.y + 62.0
		_economy_label.position.y = maxf(top_bar_bottom_for_econ, panel_bottom_for_econ) + 10.0
	if health_container:
		# Hull health is always visible but no longer competes with steering in
		# the lower-left corner. A single centred readout avoids the duplicate
		# current/max labels the original desktop HUD carried.
		var health_scale := maxf(0.55, MobileLayoutManager.mobile_scale(get_viewport()))
		health_container.size = Vector2(320.0 * health_scale, 44.0 * health_scale)
		var top_bar_bottom := (top_bar.position.y + top_bar.size.y * hud_scale) if top_bar else safe.position.y + 62.0
		health_container.position = Vector2(safe.position.x + 12.0, top_bar_bottom + 10.0)
		if health_right:
			health_right.hide()
	if mobile_utility_menu_button:
		var button_size := mobile_utility_menu_button.size
		# Stacked directly below MobileControls' Pause button (measured, not a
		# second hardcoded offset — see CLAUDE.md's "two independently
		# hardcoded pixel offsets" failure mode, already hit once by this same
		# HUD's health bar). Previously floated at a fixed 48% of screen
		# height with no visual relationship to anything else, reading as
		# randomly placed (device-test feedback 2026-09-20); grouping it under
		# Pause forms one clear top-right utility corner instead.
		var mobile_controls := get_node_or_null("MobileControls")
		var pause_btn: Control = mobile_controls.btn_pause if mobile_controls and "btn_pause" in mobile_controls else null
		var top_y: float
		if pause_btn:
			top_y = pause_btn.position.y + pause_btn.size.y + 16.0
		else:
			top_y = safe.position.y + safe.size.y * 0.48 - button_size.y * 0.5
		mobile_utility_menu_button.position = Vector2(safe.end.x - button_size.x - 16.0, top_y)
	if mobile_utility_drawer:
		var drawer_width := minf(420.0, safe.size.x - 32.0)
		mobile_utility_drawer.size = Vector2(drawer_width, 276.0)
		mobile_utility_drawer.position = Vector2(safe.get_center().x - drawer_width * 0.5, safe.end.y - 366.0)
	if _objective_card:
		var action_scale := maxf(0.55, MobileLayoutManager.mobile_scale(get_viewport()))
		var card_width := 378.0 * action_scale
		var action_x := safe.position.x + 16.0 if MobileLayoutManager.is_left_handed() else safe.end.x - card_width - 16.0
		_objective_card.position = Vector2(action_x, safe.end.y - 510.0 * action_scale)
		_objective_card.size = Vector2(card_width, 72.0 * action_scale)

func _check_whats_new() -> void:
	## M14 Requirement 5.2 — one-time auto-show, same shape as
	## _check_offline_return() below but keyed off content version rather
	## than an ephemeral tick counter.
	if not whats_new_screen or not whats_new_screen.patch_notes:
		return
	var latest: String = whats_new_screen.patch_notes.latest_version()
	if latest.is_empty() or latest == SaveManager.last_seen_whats_new_version:
		return
	SaveManager.last_seen_whats_new_version = latest
	whats_new_screen.open()
	_update_mobile_menu_badge()


func _check_offline_return() -> void:
	## Show a one-time "while you were away" notice if SaveManager just replayed offline ticks
	if SaveManager._pending_offline_ticks > 0:
		var ticks = SaveManager._pending_offline_ticks
		SaveManager._pending_offline_ticks = 0
		announce_event(tr("While you were away: your empire kept running (%d ticks)") % ticks)
		_offer_offline_income_bonus()


func _open_hud_customize_overlay_if_requested() -> void:
	## Consumed the same way SaveManager._pending_offline_ticks is above —
	## SettingsMenu's "Customize HUD Layout" button sets this then calls
	## SceneManager.go_back(), which reloads World.tscn (Settings is always
	## its own scene, never an overlay), landing back here on the next
	## WorldHUD._ready().
	if not SettingsManager.pending_hud_customize_request:
		return
	SettingsManager.pending_hud_customize_request = false
	var overlay: Control = HudCustomizeOverlayScript.new()
	add_child(overlay)
	overlay.open(self)


## M17 Requirement 6.1/6.5 — the offline-return rewarded surface. The
## baseline income is already granted unconditionally by SaveManager's own
## catch-up loop above, before this is ever called; this only offers a
## bonus on top of it, and silently does nothing if there was no income or
## today's cap is already spent (RewardedBonusOffer.present() itself checks
## AdManager.can_offer()).
func _offer_offline_income_bonus() -> void:
	if SaveManager._pending_offline_income.is_empty():
		return
	var offer: RewardedBonusOffer = RewardedBonusOfferScene.instantiate()
	add_child(offer)
	offer.present(&"offline_double", tr("Watch an ad to double the income you just earned?"),
		SaveManager.grant_offline_income_bonus)

func _apply_theme() -> void:
	## Inject the runtime pirate theme into this HUD
	var theme := PirateThemeBuilder.build()
	for child in get_children():
		if child is Control:
			child.theme = theme

func _style_resource_chips() -> void:
	## M15.5 Requirement 3.1 — each resource chip's background is tinted to
	## match that resource's existing color identity (same colors
	## _on_resources_changed()/_tint_label() already use), rather than one
	## flat generic panel for all four.
	var chip_tints := {
		"GoldChip": Color(1, 0.84, 0, 1),
		"WoodChip": Color(0.6, 0.4, 0.2, 1),
		"IronChip": Color(0.7, 0.7, 0.75, 1),
		"RumChip":  Color(0.8, 0.4, 0.1, 1),
	}
	for chip_name in chip_tints:
		var chip: PanelContainer = get_node_or_null("%" + chip_name)
		if chip:
			chip.add_theme_stylebox_override("panel", PirateThemeBuilder.make_chip_stylebox(chip_tints[chip_name]))

func _find_ship() -> void:
	## Try to locate the PlayerShip in the scene tree
	await get_tree().process_frame
	var ship = get_tree().get_first_node_in_group("player_ship")
	if ship and ship is ShipController:
		_ship_controller = ship
		ship.ship_speed_changed.connect(_on_speed_changed)
		ship.ship_health_changed.connect(_on_health_changed)
		ship.ship_destroyed.connect(_on_ship_destroyed)
		ship.sail_level_changed.connect(_on_sail_level_changed)
		ship.anchor_dropped.connect(_on_anchor_dropped)
		ship.anchor_raised.connect(_on_anchor_raised)
		ship.ship_stats_changed.connect(_update_cannon_header_captions)
		_on_sail_level_changed(ship.sail_level, ship.ship_stats.sail_levels if ship.ship_stats else 3)
		if ship.combat and ship.combat.has_signal("fired"):
			ship.combat.fired.connect(_on_cannon_fired)
		if ship.combat and ship.combat.has_signal("arc_lock_changed"):
			ship.combat.arc_lock_changed.connect(_on_arc_lock_changed)
		_firing_solver = ship.get_node_or_null("FiringSolver") as FiringSolver
		_update_cannon_header_captions()
		var captain_ability: Node = ship.get_node_or_null("CaptainAbility")
		if captain_ability and captain_ability.has_signal("ability_ready"):
			captain_ability.ability_ready.connect(func(): HapticFeedbackManager.ready())

	# Connect to global systems
	if ResourceManager.has_signal("resources_changed"):
		ResourceManager.resources_changed.connect(_on_resources_changed)
		# Initialize display
		_on_resources_changed(ResourceManager.current_resources)

	if EventManager.has_signal("ocean_event_resolved"):
		EventManager.ocean_event_resolved.connect(_on_ocean_event_resolved)


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
	_create_utility_controls()
	if _uses_mobile_utility_menu():
		# The collapsed phone control needs room for the resource and notoriety
		# readouts plus one 52dp button. The drawer is deliberately allowed to
		# expand only after the player asks for it.
		top_right_panel.offset_bottom = 180.0
	CampaignManager.objective_completed.connect(_on_campaign_objective_completed)
	CampaignManager.chapter_completed.connect(_on_campaign_chapter_completed)
	CampaignManager.chapter_started.connect(_on_campaign_chapter_started)
	CampaignManager.objective_progressed.connect(_on_campaign_objective_progressed)

var _economy_label: Label
func _create_economy_label() -> void:
	_economy_label = Label.new()
	_economy_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(14))
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
	_fps_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(12))
	_fps_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.position = Vector2(8, -20)
	add_child(_fps_label)
	if not OS.has_feature("pc"):
		# Frame telemetry is useful in desktop development, not as persistent
		# player-facing phone HUD noise.
		_fps_label.hide()

var notoriety_label: Label
var captains_log_button: Button
var world_map_button: Button
var codex_button: Button
var whats_new_button: Button
var wardrobe_button: Button
var mobile_utility_menu_button: Button
var mobile_utility_drawer: PanelContainer
var mobile_utility_badge: Label

func _uses_mobile_utility_menu() -> bool:
	return force_mobile_utility_menu or not OS.has_feature("pc")


func _mobile_utility_button_size() -> Vector2:
	## HUD utility actions need the same device-pixel allowance as the rest of
	## the phone UI. This is intentionally separate from the PC 70x32 utility
	## buttons, which remain mouse-sized and are never used on a phone build.
	return HUD_BUTTON_SIZE_MOBILE * PirateThemeBuilder.control_scale()


func _create_utility_controls() -> void:
	if _uses_mobile_utility_menu():
		_create_mobile_utility_menu()
		return
	_create_captains_log_button()
	_create_world_map_button()
	_create_codex_button()
	_create_whats_new_button()
	_create_wardrobe_button()


func _rebuild_utility_controls() -> void:
	## Keeps the platform branch testable without changing the runtime's OS
	## feature detection. All utility controls are owned by TopRightPanel.
	for child in top_right_panel.get_children():
		if child.name.begins_with("Utility"):
			child.queue_free()
	for child in get_children():
		if child.name.begins_with("Utility"):
			child.queue_free()
	await get_tree().process_frame
	captains_log_button = null
	world_map_button = null
	codex_button = null
	whats_new_button = null
	wardrobe_button = null
	mobile_utility_menu_button = null
	mobile_utility_drawer = null
	_create_utility_controls()


func _create_mobile_utility_menu() -> void:
	mobile_utility_menu_button = Button.new()
	mobile_utility_menu_button.name = "UtilityMenuButton"
	mobile_utility_menu_button.text = tr("Captain")
	mobile_utility_menu_button.custom_minimum_size = _mobile_utility_button_size()
	mobile_utility_menu_button.size = _mobile_utility_button_size()
	mobile_utility_menu_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	mobile_utility_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_utility_menu_button.theme = PirateThemeBuilder.build()
	add_child(mobile_utility_menu_button)
	mobile_utility_menu_button.add_child(ButtonJuice.new())
	mobile_utility_badge = Label.new()
	mobile_utility_badge.name = "UtilityAttentionBadge"
	mobile_utility_badge.text = "!"
	mobile_utility_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mobile_utility_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mobile_utility_badge.position = Vector2(mobile_utility_menu_button.size.x - 30, 4)
	mobile_utility_badge.size = Vector2(24, 24)
	mobile_utility_badge.add_theme_font_size_override("font_size", 16)
	mobile_utility_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	mobile_utility_menu_button.add_child(mobile_utility_badge)

	mobile_utility_drawer = PanelContainer.new()
	mobile_utility_drawer.name = "UtilityMenuDrawer"
	mobile_utility_drawer.process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_utility_drawer.theme = PirateThemeBuilder.build()
	mobile_utility_drawer.visible = false
	add_child(mobile_utility_drawer)
	var items := GridContainer.new()
	items.name = "Items"
	items.columns = 2
	items.add_theme_constant_override("separation", 8)
	mobile_utility_drawer.add_child(items)
	_add_mobile_utility_item(items, "Log", "log")
	_add_mobile_utility_item(items, "Map", "map")
	_add_mobile_utility_item(items, "Codex", "codex")
	_add_mobile_utility_item(items, "New", "new")
	_add_mobile_utility_item(items, "Wardrobe", "wardrobe")
	mobile_utility_menu_button.pressed.connect(func():
		mobile_utility_drawer.visible = not mobile_utility_drawer.visible)
	_update_mobile_menu_badge()
	call_deferred("_apply_mobile_safe_area")


func _update_mobile_menu_badge() -> void:
	## The Captain badge is reserved for unread information; it is hidden in
	## ordinary play so it never becomes another permanent visual demand.
	if not mobile_utility_badge:
		return
	var needs_attention := false
	if whats_new_screen and whats_new_screen.patch_notes:
		var latest: String = whats_new_screen.patch_notes.latest_version()
		needs_attention = not latest.is_empty() and latest != SaveManager.last_seen_whats_new_version
	mobile_utility_badge.visible = needs_attention


func _add_mobile_utility_item(parent: Container, label: String, destination: String) -> void:
	var item := Button.new()
	item.name = "Utility%sButton" % destination.capitalize()
	item.text = tr(label)
	item.custom_minimum_size = _mobile_utility_button_size()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.process_mode = Node.PROCESS_MODE_ALWAYS
	item.pressed.connect(_open_mobile_utility.bind(destination))
	parent.add_child(item)
	item.add_child(ButtonJuice.new())


func _open_mobile_utility(destination: String) -> void:
	if mobile_utility_drawer:
		mobile_utility_drawer.hide()
	match destination:
		"log":
			if captains_log:
				captains_log.open()
		"map":
			if world_map_screen:
				world_map_screen.open()
		"codex":
			if codex_screen and not codex_screen.visible:
				codex_screen.toggle()
		"new":
			if whats_new_screen:
				whats_new_screen.open()
		"wardrobe":
			if tutorial_dialogue and tutorial_dialogue.visible:
				return
			if wardrobe_screen:
				wardrobe_screen.open()


func _create_notoriety_label() -> void:
	notoriety_label = Label.new()
	notoriety_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(14))
	notoriety_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	notoriety_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# M15.5 Requirement 3.4 — same rounded chip treatment as the resource
	# counters, instead of bare floating text.
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", PirateThemeBuilder.make_chip_stylebox(Color(1.0, 0.5, 0.2, 1)))
	# Shrink-to-content rather than the VBoxContainer default of filling
	# TopRightPanel's full width — a full-width tinted panel behind a short
	# "Notoriety: 0.0" readout rendered as a large mostly-empty bar.
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	chip.add_child(notoriety_label)

	# Added as a sibling of ResourceBar inside TopRightPanel (a VBoxContainer)
	# rather than given its own independently-anchored rect — the previous
	# approach hardcoded offset_top to match ResourceBar's own offset_bottom,
	# two constants kept in sync only by convention, which silently drifted
	# apart once real multi-digit resource values grew ResourceBar taller than
	# its authored rect (D36). A container lays out its children by their
	# actual measured size, so this pair structurally cannot overlap.
	top_right_panel.add_child(chip)

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
	captains_log_button.name = "UtilityLogButton"
	captains_log_button.text = tr("Log")
	captains_log_button.custom_minimum_size = _hud_button_min_size()
	captains_log_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# WorldHUD itself is not PROCESS_MODE_ALWAYS (its own _process() drives
	# cannon cooldowns/compass that must stay frozen while paused), so without
	# this the button stops receiving input the moment ANY pause-on-open
	# panel (this one included) sets get_tree().paused = true — a toggle
	# button that can open its panel but never close it back via a second
	# press, a real "looks stuck" bug found via self-play testing.
	captains_log_button.process_mode = Node.PROCESS_MODE_ALWAYS
	captains_log_button.pressed.connect(func():
		if captains_log:
			captains_log.toggle())
	top_right_panel.add_child(captains_log_button)
	captains_log_button.add_child(ButtonJuice.new())

func _create_world_map_button() -> void:
	## M10 Requirement 3 — same dynamic-positioning pattern as
	## _create_captains_log_button() just above: a fourth child of
	## top_right_panel, container-positioned rather than a fifth
	## independently-hardcoded offset.
	world_map_button = Button.new()
	world_map_button.name = "UtilityMapButton"
	world_map_button.text = tr("Map")
	world_map_button.custom_minimum_size = _hud_button_min_size()
	world_map_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# See _create_captains_log_button()'s comment — same pause-gate fix.
	world_map_button.process_mode = Node.PROCESS_MODE_ALWAYS
	world_map_button.pressed.connect(func():
		if world_map_screen:
			world_map_screen.toggle())
	top_right_panel.add_child(world_map_button)
	world_map_button.add_child(ButtonJuice.new())


func _create_codex_button() -> void:
	## Uses the same container-owned placement as Log/Map, avoiding a second
	## hard-coded HUD offset and its known overlap regression (D36).
	codex_button = Button.new()
	codex_button.name = "UtilityCodexButton"
	codex_button.text = tr("Codex")
	codex_button.custom_minimum_size = _hud_button_min_size()
	codex_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# See _create_captains_log_button()'s comment — same pause-gate fix.
	codex_button.process_mode = Node.PROCESS_MODE_ALWAYS
	codex_button.pressed.connect(func():
		if codex_screen and codex_screen.has_method("toggle"):
			codex_screen.toggle())
	top_right_panel.add_child(codex_button)
	codex_button.add_child(ButtonJuice.new())


func _create_whats_new_button() -> void:
	## M14 Requirement 5.1 — same container-owned placement as Log/Map/Codex.
	whats_new_button = Button.new()
	whats_new_button.name = "UtilityNewButton"
	whats_new_button.text = tr("New")
	whats_new_button.custom_minimum_size = _hud_button_min_size()
	whats_new_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# See _create_captains_log_button()'s comment — same pause-gate fix.
	whats_new_button.process_mode = Node.PROCESS_MODE_ALWAYS
	whats_new_button.pressed.connect(func():
		if whats_new_screen:
			whats_new_screen.toggle())
	top_right_panel.add_child(whats_new_button)
	whats_new_button.add_child(ButtonJuice.new())


func _create_wardrobe_button() -> void:
	## M16 Task 18 — same container-owned placement as Log/Map/Codex/New.
	wardrobe_button = Button.new()
	wardrobe_button.name = "UtilityWardrobeButton"
	wardrobe_button.text = tr("Wardrobe")
	wardrobe_button.custom_minimum_size = _hud_button_min_size()
	wardrobe_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# See _create_captains_log_button()'s comment — same pause-gate fix.
	wardrobe_button.process_mode = Node.PROCESS_MODE_ALWAYS
	wardrobe_button.pressed.connect(func():
		# Participate in M9's panel arbitration rather than stacking on top
		# (the V14 defect class) — a tutorial beat keeps focus if active.
		if tutorial_dialogue and tutorial_dialogue.visible:
			return
		if wardrobe_screen:
			wardrobe_screen.toggle())
	top_right_panel.add_child(wardrobe_button)
	wardrobe_button.add_child(ButtonJuice.new())


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
	if _uses_mobile_utility_menu():
		_set_mobile_context_state("dock", true)
	else:
		show_dock_prompt(true)
	HapticFeedbackManager.available()

func _on_dock_area_exited(_island_id: String) -> void:
	if _uses_mobile_utility_menu():
		_set_mobile_context_state("dock", false)
	else:
		show_dock_prompt(false)

func _on_dock_speed_exceeded() -> void:
	announce_event(tr("Too fast to dock — slow down!"), true)

func _on_boarding_prompt_available(_enemy_ship: Node) -> void:
	if _uses_mobile_utility_menu():
		_set_mobile_context_state("board", true)
	elif board_prompt:
		board_prompt.visible = true
	HapticFeedbackManager.available()

func _on_boarding_prompt_unavailable() -> void:
	if _uses_mobile_utility_menu():
		_set_mobile_context_state("board", false)
	elif board_prompt:
		board_prompt.visible = false

func _on_boarding_resolved(success: bool, loot: Dictionary, _target_faction_id: String = "", _target_ship_id: String = "") -> void:
	if success:
		HapticFeedbackManager.reward()
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
	## M15.5 — the icon now carries what an emoji prefix used to (each resource
	## chip's Icon TextureRect, tinted to match this same label's font color).
	var max_res = ResourceManager.max_storage
	if gold_label:
		gold_label.text = tr("%s / %s") % [str(res.get("gold", 0)), str(max_res.get("gold", 9999))]
		_tint_label(gold_label, res.get("gold", 0), max_res.get("gold", 9999))
	if wood_label:
		wood_label.text = tr("%s / %s") % [str(res.get("wood", 0)), str(max_res.get("wood", 9999))]
		_tint_label(wood_label, res.get("wood", 0), max_res.get("wood", 9999))
	if iron_label:
		iron_label.text = tr("%s / %s") % [str(res.get("iron", 0)), str(max_res.get("iron", 9999))]
		_tint_label(iron_label, res.get("iron", 0), max_res.get("iron", 9999))
	if rum_label:
		rum_label.text  = tr("%s / %s") % [str(res.get("rum", 0)), str(max_res.get("rum", 9999))]
		_tint_label(rum_label, res.get("rum", 0), max_res.get("rum", 9999))
	if _economy_label:
		# Just append it to the economy label for now to avoid creating a new UI element
		var res_str = " | 🧪 %s" % str(res.get("research", 0))
		if not _economy_label.has_meta("res_str"):
			_economy_label.set_meta("res_str", res_str)
		_economy_label.set_meta("res_str", res_str)

func _on_dock_completed(island_id: String) -> void:
	if _uses_mobile_utility_menu():
		_set_mobile_context_state("dock", false)
	else:
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

## docs/navalCombat.md §5.2 — the static half of the arc/range readout;
## rarely changes mid-fight (only via tech/upgrades), so it's refreshed on
## ship_stats_changed rather than every frame like _update_alignment_previews().
func _update_cannon_header_captions() -> void:
	if not _firing_solver:
		return
	var caption := " · %d° / %dm" % [int(_firing_solver.get_arc_degrees()), int(_firing_solver.get_range())]
	if port_header_label:
		port_header_label.text = tr("PORT CANNONS") + caption
	if stbd_header_label:
		stbd_header_label.text = tr("STARBOARD CANNONS") + caption

## docs/navalCombat.md §5.2 — alignment must be legible *before* the guns
## fire. set_cannon_cooldown()'s "ON TARGET" text already owns the locked
## state; this only fills the gap before a lock exists, so a side that's
## already locked hides its own label rather than showing stale info.
func _update_alignment_previews() -> void:
	var port_preview := _get_alignment_preview_safe(FiringSolver.SIDE_PORT)
	var stbd_preview := _get_alignment_preview_safe(FiringSolver.SIDE_STARBOARD)
	var port_locked: bool = _arc_locked.get("port", false)
	var stbd_locked: bool = _arc_locked.get("starboard", false)
	_apply_alignment_label(port_alignment_label, port_preview, port_locked)
	_apply_alignment_label(stbd_alignment_label, stbd_preview, stbd_locked)
	# CannonsContainer (this readout's desktop home) must stay hidden on
	# mobile — see the CannonsContainer.hide() comment above — so the same
	# preview data is mirrored onto MobileControls' own Actions cluster,
	# which already has safe-area-checked room for it.
	if mobile_controls and mobile_controls.has_method("update_alignment_caption"):
		mobile_controls.update_alignment_caption(port_preview, stbd_preview, port_locked, stbd_locked)

func _get_alignment_preview_safe(side: String) -> Dictionary:
	if not _firing_solver:
		return {"found": false, "angle_off_deg": 180.0, "in_range": false, "aligned": false}
	return _firing_solver.get_alignment_preview(side)

func _apply_alignment_label(label: Label, preview: Dictionary, locked: bool) -> void:
	if not label:
		return
	if locked:
		label.visible = false
		return
	label.visible = true
	if not preview.get("found", false):
		label.text = tr("NO TARGET")
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	elif not preview.get("in_range", false):
		label.text = tr("OUT OF RANGE")
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	else:
		var angle: float = preview.get("angle_off_deg", 180.0)
		label.text = tr("%d° TO ALIGN") % int(ceil(angle))
		var arc: float = maxf(_firing_solver.get_arc_degrees(), 0.01) if _firing_solver else 35.0
		var warmth: float = clampf(1.0 - angle / arc, 0.0, 1.0)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65).lerp(Color(1.0, 0.84, 0.2), warmth))

## Replaces the old per-ship Label3D (EnemyHealthBar.gd) that only appeared
## once an enemy had taken damage and had no occlusion handling — a
## CanvasLayer overlay draws over the 3D viewport unconditionally, and this
## is the only way to literally reuse the player's own ProgressBar/Theme
## styling rather than approximating it with 3D billboard text.
func _update_enemy_health_bars() -> void:
	if not enemy_health_bars_layer:
		return
	var camera := get_viewport().get_camera_3d()
	var alive_ids: Dictionary = {}
	for ship in get_tree().get_nodes_in_group("enemy_ship"):
		if not (ship is Node3D) or not is_instance_valid(ship):
			continue
		var id := ship.get_instance_id()
		alive_ids[id] = true
		var widget: Control = _enemy_bar_pool.get(id)
		if not widget:
			widget = EnemyHealthBarWidgetScene.instantiate()
			enemy_health_bars_layer.add_child(widget)
			widget.size = widget.custom_minimum_size
			widget.bind(ship)
			_enemy_bar_pool[id] = widget
		_position_enemy_health_bar(widget, ship, camera)

	for id in _enemy_bar_pool.keys():
		if not alive_ids.has(id):
			var stale: Control = _enemy_bar_pool[id]
			if is_instance_valid(stale):
				stale.queue_free()
			_enemy_bar_pool.erase(id)

func _position_enemy_health_bar(widget: Control, ship: Node3D, camera: Camera3D) -> void:
	# A sinking wreck keeps its ShipDamage/ShipCombat around during the sink
	# animation (ShipController._on_died() queue_free()s it a couple seconds
	# later) — the widget already hid itself on the `died` signal, so leave
	# it hidden rather than re-showing it every frame until it's actually gone.
	var dmg := ship.get_node_or_null("ShipDamage")
	if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
		return
	if not camera:
		widget.visible = false
		return
	var world_pos: Vector3 = ship.global_position + Vector3(0.0, 6.0, 0.0)
	if camera.is_position_behind(world_pos):
		widget.visible = false
		return
	if not _ship_controller or ship.global_position.distance_to(_ship_controller.global_position) > ENEMY_BAR_DISPLAY_RANGE:
		widget.visible = false
		return
	widget.visible = true
	var screen_pos: Vector2 = camera.unproject_position(world_pos)
	widget.position = screen_pos - widget.size * 0.5

func _on_ship_destroyed() -> void:
	if death_screen and _ship_controller:
		death_screen.open(_ship_controller)

func _on_health_changed(current: float, maximum: float) -> void:
	if _last_reported_health >= 0.0 and current < _last_reported_health:
		HapticFeedbackManager.damage()
	_last_reported_health = current
	set_health(current, maximum)

func _process(_delta: float) -> void:
	_update_cannon_cooldown_display("port", _port_cooldown_total, _port_cooldown_start_ms)
	_update_cannon_cooldown_display("starboard", _stbd_cooldown_total, _stbd_cooldown_start_ms)
	_update_alignment_previews()
	_update_enemy_health_bars()
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
		speed_label.text = tr("%.1f kn") % speed

var _is_anchored := false

func _on_sail_level_changed(level: int, max_level: int) -> void:
	if not sail_label or _is_anchored:
		return
	if level <= 0:
		sail_label.text = tr("⛵ Furled")
	else:
		sail_label.text = tr("⛵ %d/%d") % [level, max_level]

func _on_anchor_dropped() -> void:
	_is_anchored = true
	if sail_label:
		sail_label.text = tr("⚓ Anchored")

func _on_anchor_raised() -> void:
	_is_anchored = false
	if _ship_controller and _ship_controller.ship_stats:
		_on_sail_level_changed(_ship_controller.sail_level, _ship_controller.ship_stats.sail_levels)

var _health_pulse_active := false
var _health_pulse_tween: Tween

func set_health(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		var tween := create_tween()
		tween.tween_property(health_bar, "value", current, 0.25)
		_set_health_pulse(maximum > 0.0 and current / maximum < 0.25)
	if health_left:
		health_left.text = tr("HULL  %d / %d") % [int(current), int(maximum)]
	if health_right:
		health_right.text = "%d / %d" % [int(current), int(maximum)]

func _set_health_pulse(active: bool) -> void:
	## M15.5 Requirement 3.3 — a looping modulate pulse below 25% health,
	## stopped (and modulate restored) once health rises back above it.
	if active == _health_pulse_active:
		return
	_health_pulse_active = active
	if active:
		_health_pulse_tween = create_tween().set_loops()
		_health_pulse_tween.tween_property(health_bar, "modulate", Color(1.3, 0.5, 0.5), 0.4)
		_health_pulse_tween.tween_property(health_bar, "modulate", Color(1, 1, 1), 0.4)
	elif _health_pulse_tween:
		_health_pulse_tween.kill()
		health_bar.modulate = Color(1, 1, 1)

func _on_arc_lock_changed(side: String, locked: bool) -> void:
	_arc_locked[side] = locked

# --- Encounter readout ---

func _set_mobile_context_state(kind: String, available: bool) -> void:
	var mobile_controls := get_node_or_null("MobileControls")
	if not mobile_controls:
		return
	if kind == "dock" and mobile_controls.has_method("set_dock_available"):
		mobile_controls.set_dock_available(available)
	elif kind == "board" and mobile_controls.has_method("set_board_available"):
		mobile_controls.set_board_available(available)

func _create_objective_label() -> void:
	if _uses_mobile_utility_menu():
		_create_mobile_objective_card()
		return
	## Top-centre, under the economy label. Anchored in an explicit rect that grows
	## from the centre so long objective text cannot run off either edge — the D36
	## failure mode with PRESET_CENTER's zero-width rect.
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(18))
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE, true)
	_objective_label.offset_top = 44.0
	_objective_label.offset_bottom = 90.0
	_objective_label.visible = false
	add_child(_objective_label)


func _create_mobile_objective_card() -> void:
	## The objective remains visible while the player steers, but belongs just
	## above the primary action cluster instead of competing with top HUD data.
	_objective_card = PanelContainer.new()
	_objective_card.name = "ObjectiveCard"
	_objective_card.theme = PirateThemeBuilder.build()
	_objective_card.visible = false
	add_child(_objective_card)
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(18))
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_card.add_child(_objective_label)
	call_deferred("_apply_mobile_safe_area")

func _on_encounter_started(data) -> void:
	if not _objective_label:
		return
	_objective_label.visible = true
	if _objective_card:
		_objective_card.visible = true
	_objective_label.text = tr("%s — %s") % [data.get_kind_name(), data.display_name]

func _on_objective_progress(current: int, total: int) -> void:
	if not _objective_label or not _objective_label.visible:
		return
	if total > 0:
		_objective_label.text = "%s  [%d / %d]" % [
			_objective_label.text.split("  [")[0], current, total]

func _on_encounter_ended(victory: bool, rewards: Dictionary) -> void:
	if _objective_label:
		_objective_label.visible = false
	if _objective_card:
		_objective_card.visible = false
	# M17 Requirement 6.1/6.5/6.6 — the post-battle salvage surface. Offered
	# after the VICTORY result is already announced (EncounterManager._resolve()
	# calls _announce() before emitting this signal), never between the battle
	# ending and its result being shown. "Salvage" is the gold component of
	# the reward already granted unconditionally by EncounterManager's own
	# _grant_rewards() — this only offers to grant that same amount again.
	if victory and int(rewards.get("gold", 0)) > 0:
		HapticFeedbackManager.reward()
		_offer_salvage_bonus(int(rewards["gold"]))

func _offer_salvage_bonus(gold_already_earned: int) -> void:
	var offer: RewardedBonusOffer = RewardedBonusOfferScene.instantiate()
	add_child(offer)
	offer.present(&"salvage_double", tr("Watch an ad to double the salvage you just earned?"),
		func(): ResourceManager.add_resource("gold", gold_already_earned))

## M17 Requirement 6.1/6.5 — the event-reroll rewarded surface. The event
## named here has already applied unconditionally (EventManager emits this
## after applying, never before); this only announces it and offers a bonus
## SECOND roll, never a replacement of the first.
func _on_ocean_event_resolved(_event_id: String, display_text: String) -> void:
	if not display_text.is_empty():
		announce_event(display_text)
	var offer: RewardedBonusOffer = RewardedBonusOfferScene.instantiate()
	add_child(offer)
	offer.present(&"event_reroll", tr("Watch an ad for a bonus second event?"),
		EventManager.reroll_last_ocean_event)

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
	label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(32))
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
