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
## M22 Phase 5.1 — v0.3 pills show the amount big (HudNum) and the storage
## cap as a small dim suffix, instead of one "200 / 5000" string that made
## every pill twice as wide; research is the fifth pill (was a "🧪 N" suffix
## tacked onto the economy readout).
@onready var gold_cap_label  : Label        = %GoldCapLabel
@onready var wood_cap_label  : Label        = %WoodCapLabel
@onready var iron_cap_label  : Label        = %IronCapLabel
@onready var rum_cap_label   : Label        = %RumCapLabel
@onready var research_label  : Label        = %ResearchLabel
## M27 Requirement 6.6 — the premium currency's balance. No cap label: Eights
## have no storage cap to show (ResourceManager.max_storage["eights"] is a ceiling).
@onready var eights_label    : Label        = %EightsLabel
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
const BoardingOverlayScene := preload("res://scenes/ui/BoardingOverlay.tscn")
## Presentation-only cutoff for the enemy health bar overlay — not a combat
## balance value, so a plain constant is fine (AGENTS.md's no-hardcoded-
## gameplay-values rule targets balance data, not UI legibility knobs).
const ENEMY_BAR_DISPLAY_RANGE := 150.0
@onready var top_right_panel : VBoxContainer = %TopRightPanel
@onready var resource_bar    : PanelContainer = %ResourceBar
@onready var cannons_container: HBoxContainer = %CannonsContainer
@onready var tutorial_dialogue: TutorialDialogue = %TutorialDialogue
const LESSON_COACH_CARD_SCENE := preload("res://scenes/ui/LessonCoachCard.tscn")
const _LESSON_BAND_MAX_WIDTH := 560.0
var _lesson_band: VBoxContainer

## M29 D.1 — world events reach the player through announce_event(), one at a
## time: a FIFO in front of the existing announcer (never a second banner system).
var _announce_queue: Array[Dictionary] = []   # {text, warning}
var _announce_active: Control = null
var _event_announcement_data: EventAnnouncementData = null
## M29 J.1 — "<Island> · <Owner>" line above the desktop dock prompt.
var _dock_owner_label: Label = null

## M13 Task 16.5 gave the utility buttons usable mobile targets, but five
## permanent targets still obscure the world and compete with sailing/combat.
## PC keeps direct mouse-accessible buttons. Phone builds expose one Menu
## button and reveal these infrequent destinations only on demand.
const HUD_BUTTON_SIZE_PC     := Vector2(70, 32)
const _MOBILE_HUD_SCALE      := 1.0


## M22 Phase 5 — HUD state colours from the palette (they were raw Color()
## literals Phase 3.5's COLOR_* migration never reached). Semantic, not
## decorative: ready = hp_good, alarm/at-cap = hp_low, attention = gold.
static func _hud_muted() -> Color:
	var t := UITokens.palette().text_on_dark
	return Color(t.r, t.g, t.b, 0.55)
## Compass disc (canvas px) and the box each cardinal letter is seated in.
## Widest an event announcement toast gets (canvas px), centred.
const _ANNOUNCE_MAX_WIDTH := 900.0
const _COMPASS_SIZE := 88.0
const _COMPASS_LETTER := 26.0
const HUD_BUTTON_SIZE_MOBILE := Vector2(120, 52)
static func _hud_button_min_size() -> Vector2:
	return HUD_BUTTON_SIZE_PC if OS.has_feature("pc") else HUD_BUTTON_SIZE_MOBILE

## M22 Phase 5.5 — Log/Map/Codex/New/Wardrobe are a rail of round wood icon
## buttons with a caption under each (v0.3's round nav buttons), instead of
## five ragged-width brass text buttons stacked down the right edge. 96 wide
## = the 48dp touch floor (MOBILE_MIN_TOUCH_TARGET); height follows the art.
const _RAIL_BUTTON_WIDTH := 96.0
## The phone's collapsed "Captain" opener: the same 48dp round button. A
## 116-wide one (plus caption) reached down into the action cluster's
## context button on a 2340x1080 phone (Phase 5 sweep).
const _MOBILE_MENU_BUTTON_WIDTH := 96.0

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
## M30 W1 (1.12) — the Fury meter, stacked under the special readout.
var _fury_meter: ProgressBar
## M30 W1 (1.6) — desktop's Brace call-out (phones read the context button).
var _brace_label: Label
## Fury meter bar height (canvas px).
const _FURY_METER_HEIGHT := 12
var _objective_label: Label
var _objective_card: PanelContainer
var _ability_label: Label
var _last_reported_health: float = -1.0

## Screen-space enemy health bars (item 2 of the 2026-09-21 combat-clarity
## fix) — pooled per ship instance ID so a widget persists across frames
## rather than being torn down and rebuilt each tick.
var _enemy_bar_pool: Dictionary = {}
## M30 W2 (2.5): the last boarding-deck summary per enemy hull instance id, applied to a health
## bar built after the prompt that produced it.
var _boarding_previews: Dictionary = {}
var _notoriety_next_label: Label
## M25 heat tier name, shown beside the notoriety number.
var _heat_tier_label: Label
var _notoriety_bar: NotorietyBar
## v0.3 notoriety bar; the card hugs header + bar, well short of the pill
## row (test_notoriety_chip_shrinks_to_content_width).
const _NOTORIETY_BAR_WIDTH := 440.0

func _ready() -> void:
	# Island.gd (capture announcements) and EncounterManager (encounter/boss
	# announcements) both look up the HUD via this group rather than a node
	# path/name, since the WorldHUD instance is actually named "WorldUI" in
	# World.tscn — a name-based lookup for "WorldHUD" always missed.
	add_to_group("hud")
	_auto_hide = HudAutoHide.new()
	_auto_hide.name = "HudAutoHide"
	add_child(_auto_hide)
	if SettingsManager and SettingsManager.has_signal("settings_changed"):
		SettingsManager.settings_changed.connect(_apply_hud_settings)
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
	# M30 0.10 — say once when cloud sync starts failing or saving is paused;
	# the full line lives in Settings > Account.
	if SaveManager.has_signal("sync_status_changed") and not SaveManager.sync_status_changed.is_connected(_on_sync_status_changed):
		SaveManager.sync_status_changed.connect(_on_sync_status_changed)
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
	_create_lesson_coach_card()

	## M29 D.1 — Connect event banner signals
	_setup_event_banner()


## M28 — the lesson channel. Desktop: a child of TopRightPanel (a
## VBoxContainer), so it stacks under the resource bar by real measured size and
## structurally cannot overlap it (the D36 lesson). Phone: TopRightPanel grows
## down onto the right-thumb action cluster (Checkpoint B sweep — the card, and
## the notoriety card it pushed down, covered Ability/Broadside), so the card
## gets its own container in the free band between the thumb clusters instead,
## the same band TutorialDialogue uses — the two never show at once (the card
## queues behind any blocking dialogue).
func _create_lesson_coach_card() -> void:
	if find_child("LessonCoachCard", true, false):
		return
	var card: Control = LESSON_COACH_CARD_SCENE.instantiate()
	card.name = "LessonCoachCard"
	if PirateThemeBuilder.is_mobile():
		_lesson_band = VBoxContainer.new()
		_lesson_band.name = "LessonBand"
		_lesson_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_hud_widget(_lesson_band)
		card.size_flags_horizontal = Control.SIZE_FILL
		_lesson_band.add_child(card)
		# Centred until _apply_mobile_safe_area() measures the real thumb band.
		var w := get_viewport().get_visible_rect().size.x
		_place_lesson_band(w * 0.3, w * 0.7)
	elif top_right_panel:
		top_right_panel.add_child(card)


## Phone: the lesson band's rect inside the thumb-cluster band (see
## _fit_tutorial_between_thumb_clusters), below whichever sits lower of
## TutorialDialogue's own top offset and TopRightPanel's measured bottom edge —
## never a second hardcoded number that could drift from the panel's real size.
func _place_lesson_band(left: float, right: float) -> void:
	if not _lesson_band:
		return
	var width := minf(right - left, _LESSON_BAND_MAX_WIDTH)
	var top := TutorialDialogue._MOBILE_TOP
	if top_right_panel:
		top = maxf(top, top_right_panel.get_global_rect().end.y + 12.0)
	_lesson_band.position = Vector2((left + right) * 0.5 - width * 0.5, top)
	_lesson_band.size = Vector2(width, 0.0)

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
	# Was 1.45 — tuned for the pre-M22 1080-tall base, where desktop-authored
	# HUD sizes were too small on a phone. At the 1688x780 base the token
	# sizes are phone-sized already (design.md §3), and 1.45 pushed the
	# resource bar and utility controls off the right edge (Phase 3/4 sweeps).
	var hud_scale := _MOBILE_HUD_SCALE
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
		# Width is capped to a safe budget of the screen (independent of the
		# fixed 1.45 above) — Pause now lives on the opposite side of the top
		# edge (device-test feedback 2026-09-21), and on a narrow/tall aspect
		# the uncapped panel grows wide enough to reach clear across and
		# overlap it (test-caught 2026-09-21).
		# Measured from the panel's real content minimum, not .size — before the
		# first layout pass .size is still the scene's authored rect, so the
		# 62% width cap silently compared against the wrong width.
		var panel_size := top_right_panel.get_combined_minimum_size()
		top_right_panel.size = panel_size
		var panel_scale := minf(hud_scale, (safe.size.x * 0.62) / maxf(1.0, panel_size.x))
		var base_position := Vector2(
			safe.end.x - panel_size.x * panel_scale - 12.0,
			safe.position.y + 12.0)
		var result := MobileLayoutManager.apply_control_override(
			"top_right_panel", base_position, panel_scale, get_viewport(), panel_size)
		top_right_panel.position = result.position
		top_right_panel.scale = Vector2.ONE * float(result.scale)
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
		_economy_chip.size = _economy_chip.get_combined_minimum_size()
		_economy_chip.position = Vector2(
			get_viewport().get_visible_rect().size.x * 0.5 - _economy_chip.size.x * 0.5,
			maxf(top_bar_bottom_for_econ, panel_bottom_for_econ) + 10.0)
	if health_container:
		# Hull health is always visible but no longer competes with steering in
		# the lower-left corner. A single centred readout avoids the duplicate
		# current/max labels the original desktop HUD carried.
		var health_scale := maxf(0.55, MobileLayoutManager.mobile_scale(get_viewport()))
		# 60 = the hull pill art's own height (its 9-slice caps are 30+30).
		health_container.size = Vector2(360.0 * health_scale, maxf(60.0, 60.0 * health_scale))
		var top_bar_bottom := (top_bar.position.y + top_bar.size.y * hud_scale) if top_bar else safe.position.y + 62.0
		health_container.position = Vector2(safe.position.x + 12.0, top_bar_bottom + 10.0)
		# (HealthRightLabel is hidden on every platform now, in the scene —
		# HealthLeftLabel's "HULL x / y" already carries both numbers.)
		# Pause moved to the left side, under the health bar, per device-test
		# feedback 2026-09-21 — it previously sat on the right under
		# top_right_panel, close enough to the Captain button below it (also
		# right-anchored) to feel cramped/overlapping on some devices. Measured
		# off health_container's own real bottom edge, not a second guessed
		# offset (same reasoning as the old top_right_panel-relative nudge).
		var mobile_controls_for_pause := get_node_or_null("MobileControls")
		var pause_btn_to_nudge: Control = mobile_controls_for_pause.btn_pause \
			if mobile_controls_for_pause and "btn_pause" in mobile_controls_for_pause else null
		if pause_btn_to_nudge:
			var hull_rect: Rect2 = health_container.get_global_rect()
			pause_btn_to_nudge.position = Vector2(hull_rect.position.x, hull_rect.end.y + 12.0)
			# Left-handed puts the action cluster on this edge, directly under
			# Pause, and a 19.5:9 phone has no height to spare for both. Beside
			# the hull bar keeps Pause top-left without costing the cluster its
			# touch-target size.
			if MobileLayoutManager.is_left_handed():
				pause_btn_to_nudge.position = Vector2(hull_rect.end.x + 12.0,
					hull_rect.get_center().y - pause_btn_to_nudge.size.y * 0.5)
		# The fire buttons stack above the right-thumb action cluster; keep them
		# below TopRightPanel's real bottom edge (the notoriety card), which only
		# this function measures.
		if mobile_controls_for_pause and top_right_panel \
				and mobile_controls_for_pause.has_method("fit_combat_cluster_below"):
			# Whatever sits above the thumb cluster on its own side: the notoriety
			# card (right-handed) or the hull bar with Pause beside it
			# (left-handed, where the action cluster moves to the left edge).
			var limit_rect: Rect2 = top_right_panel.get_global_rect()
			if MobileLayoutManager.is_left_handed():
				limit_rect = health_container.get_global_rect()
				if pause_btn_to_nudge:
					limit_rect = limit_rect.merge(pause_btn_to_nudge.get_global_rect())
			mobile_controls_for_pause.fit_combat_cluster_below(limit_rect.end.y + 12.0)
	if mobile_utility_menu_button:
		var opener: Control = mobile_utility_menu_button.get_parent()
		var button_size := opener.get_combined_minimum_size()
		# Sits directly below top_right_panel by that panel's own measured
		# bottom edge (same technique as the old Pause-relative nudge this
		# replaces) now that Pause has moved to the opposite side — this reads
		# as slightly higher than before, since it no longer waits for Pause's
		# extra gap underneath it too.
		var top_y := (top_right_panel.get_global_rect().end.y + 12.0) if top_right_panel \
			else safe.position.y + safe.size.y * 0.48 - button_size.y * 0.5
		opener.position = Vector2(safe.end.x - button_size.x - 16.0, top_y)
		# M22 6c: the v0.3 notoriety card (with its bar) made the stack tall
		# enough that "below it" landed on the right thumb cluster. The card
		# hugs the right edge, so seat the opener in the free space beside it.
		var noto_chip: Control = top_right_panel.get_node_or_null("NotorietyChip") if top_right_panel else null
		if noto_chip:
			var chip_rect := noto_chip.get_global_rect()
			opener.position = Vector2(chip_rect.position.x - button_size.x - 16.0,
				chip_rect.position.y + (chip_rect.size.y - button_size.y) * 0.5)
	if mobile_utility_drawer:
		# Sized from its own content (one row of five round buttons + captions)
		# rather than a fixed 420x276 box sized for the old 2x3 text grid.
		var drawer_size := mobile_utility_drawer.get_combined_minimum_size()
		mobile_utility_drawer.size = drawer_size
		mobile_utility_drawer.position = Vector2(safe.get_center().x - drawer_size.x * 0.5,
				safe.end.y - drawer_size.y - 180.0)
	_place_compass()
	_fit_tutorial_between_thumb_clusters()
	if _objective_card:
		var action_scale := maxf(0.55, MobileLayoutManager.mobile_scale(get_viewport()))
		var card_width := 378.0 * action_scale
		var action_x := safe.position.x + 16.0 if MobileLayoutManager.is_left_handed() else safe.end.x - card_width - 16.0
		_objective_card.position = Vector2(action_x, safe.end.y - 510.0 * action_scale)
		_objective_card.size = Vector2(card_width, 72.0 * action_scale)

## Phone: hand TutorialDialogue the free band between the left-thumb and
## right-thumb clusters (whichever side each is on — left-handed mirrors
## them), from the real button rects, so the card can't cover a control.
func _fit_tutorial_between_thumb_clusters() -> void:
	var mc := get_node_or_null("MobileControls")
	if not tutorial_dialogue or not mc or not tutorial_dialogue.has_method("set_mobile_band"):
		return
	var mid := get_viewport().get_visible_rect().size.x * 0.5
	var left_edge := 0.0
	var right_edge := get_viewport().get_visible_rect().size.x
	for cluster_name in ["Movement", "Actions", "Combat"]:
		var cluster: Control = mc.get_node_or_null(cluster_name)
		if not cluster or not cluster.visible:
			continue
		for child in cluster.get_children():
			if not (child is Control) or not child.visible:
				continue
			var r: Rect2 = child.get_global_rect()
			if r.get_center().x < mid:
				left_edge = maxf(left_edge, r.end.x)
			else:
				right_edge = minf(right_edge, r.position.x)
	const GAP := 24.0
	if right_edge - left_edge > 400.0:
		tutorial_dialogue.set_mobile_band(left_edge + GAP, right_edge - GAP)
		_place_lesson_band(left_edge + GAP, right_edge - GAP)


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

## The one Theme this HUD builds (_apply_theme). Every Control this script
## adds DIRECTLY under the HUD's CanvasLayer at runtime must be given it: a
## CanvasLayer can't hold/propagate a theme, so without it type variations
## (WoodFramePanel, HudNumLabel…) silently resolve against the stock theme —
## how the announcement toast shipped as a grey band (M22 Phase 5 sweep).
## Reused rather than rebuilt per toast: build() loads every font and kit SVG.
var _hud_theme: Theme

## Adds a runtime HUD widget (chips, readouts, the phone utility opener and
## drawer) just after TopRightPanel in child order, not at the end: the modal
## screens (IslandMenu, CaptainsLog, …) are instanced children of this same
## CanvasLayer, so an appended widget drew ON TOP of an open modal (the
## "Next Production" chip over IslandMenu — M22 Phase 6 sweep). Event
## announcements deliberately still append (they're meant to be on top).
func _add_hud_widget(widget: Control) -> void:
	add_child(widget)
	if top_right_panel and top_right_panel.get_parent() == self:
		move_child(widget, top_right_panel.get_index() + 1)


func _hud_owned_theme() -> Theme:
	if not _hud_theme:
		_hud_theme = PirateThemeBuilder.build()
	return _hud_theme


func _apply_theme() -> void:
	## Inject the runtime pirate theme into this HUD
	var theme := PirateThemeBuilder.build()
	_hud_theme = theme
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
		ship.sail_level_changed.connect(_on_sail_level_changed)
		ship.anchor_dropped.connect(_on_anchor_dropped)
		ship.anchor_raised.connect(_on_anchor_raised)
		ship.ship_stats_changed.connect(_update_cannon_header_captions)
		_on_sail_level_changed(ship.sail_level, ship.ship_stats.sail_levels if ship.ship_stats else 3)
		if ship.combat and ship.combat.has_signal("fired"):
			ship.combat.fired.connect(_on_cannon_fired)
		if ship.combat and ship.combat.has_signal("arc_lock_changed"):
			ship.combat.arc_lock_changed.connect(_on_arc_lock_changed)
		# M30 1.9 — the Spyglass Briefing's per-side opening loads show under
		# each battery's header (desktop) and on the ammo button (phone).
		if ship.combat and ship.combat.has_signal("side_ammo_changed"):
			ship.combat.side_ammo_changed.connect(_update_cannon_header_captions)
		if mobile_controls and mobile_controls.has_method("refresh_ammo_from_ship"):
			mobile_controls.refresh_ammo_from_ship()
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
	if not boarding_sys:
		boarding_sys = get_tree().get_first_node_in_group("boarding_system")
	if boarding_sys:
		boarding_sys.boarding_prompt_available.connect(_on_boarding_prompt_available)
		boarding_sys.boarding_prompt_unavailable.connect(_on_boarding_prompt_unavailable)
		boarding_sys.boarding_resolved.connect(_on_boarding_resolved)
		# M30 W2 (2.5) — the Three Bells overlay, the live deck preview on the target's
		# health bar, and the toast when Quick boarding / a crushing crew skips the battle.
		var overlay := BoardingOverlayScene.instantiate() as BoardingOverlay
		overlay.name = "BoardingOverlay"
		add_child(overlay)
		overlay.bind_boarding_system(boarding_sys)
		boarding_sys.deck_preview_changed.connect(_on_boarding_preview_changed)
		boarding_sys.boarding_routed.connect(_on_boarding_routed)

	var enc_mgr = current_scene.get_node_or_null("Systems/EncounterManager") if current_scene else null
	if not enc_mgr:
		# A debug capture harness instances World under its own root, so the
		# path misses; the group finds it there too (M30 1.9 capture).
		enc_mgr = get_tree().get_first_node_in_group("encounter_manager")
	if enc_mgr:
		enc_mgr.encounter_started.connect(_on_encounter_started)
		enc_mgr.encounter_ended.connect(_on_encounter_ended)
		enc_mgr.objective_progress.connect(_on_objective_progress)
		if upgrade_choice_screen:
			upgrade_choice_screen.bind_encounter_manager(enc_mgr)
		# M30 1.9 — the Spyglass Briefing opens on every encounter start.
		var briefing := SpyglassBriefing.new()
		briefing.name = "SpyglassBriefing"
		add_child(briefing)
		briefing.bind_encounter_manager(enc_mgr)

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
## M22 Phase 5.1 — "Next Production" is a pill chip like the resources (was
## tiny pale-green floating text, top-centre, which the widened resource row
## ran into on desktop). The chip is what gets positioned; the label is what
## tests measure, and it can only ever sit inside the chip.
var _economy_chip: PanelContainer
func _create_economy_label() -> void:
	_economy_chip = PanelContainer.new()
	_economy_chip.name = "EconomyChip"
	_economy_chip.theme_type_variation = &"HudCard"
	_economy_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_economy_chip.theme = _hud_owned_theme()
	_economy_label = Label.new()
	_economy_label.theme_type_variation = &"ChipLabel"
	_economy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_economy_chip.add_child(_economy_label)
	_add_hud_widget(_economy_chip)
	# Desktop: directly under the speed/sail plaque, from its measured edge
	# (the mobile path re-places it in _apply_mobile_safe_area()).
	call_deferred("_place_economy_chip")


# ---------------------------------------------------------------------------
# M22 Phase 6d — "Set Course" from the world map: a HUD waypoint. UI only —
# no autopilot, no gameplay system; the player still sails. A gold marker
# rides the compass rim at the target's bearing and a chip shows the name
# and distance; arriving clears it with a short announcement.
# ---------------------------------------------------------------------------
const _COURSE_ARRIVE_RADIUS := 70.0
var _course_target: IslandData
var _course_chip: PanelContainer
var _course_label: Label
var _course_marker: Label


func set_course(island: IslandData) -> void:
	if island == null:
		clear_course()
		return
	_course_target = island
	if not _course_chip:
		_create_course_widgets()
	_course_chip.visible = true
	_course_marker.visible = true
	_update_course()
	_place_course_chip.call_deferred()
	UIMotion.pop_in(_course_chip)
	announce_event(tr("Course set for %s") % island.island_name)


func clear_course() -> void:
	_course_target = null
	if _course_chip:
		_course_chip.visible = false
	if _course_marker:
		_course_marker.visible = false


func get_course_target() -> IslandData:
	return _course_target


func _create_course_widgets() -> void:
	_course_chip = PanelContainer.new()
	_course_chip.name = "CourseChip"
	_course_chip.theme_type_variation = &"HudCard"
	_course_chip.theme = _hud_owned_theme()
	_course_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_course_label = Label.new()
	_course_label.theme_type_variation = &"ChipLabel"
	_course_label.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	_course_chip.add_child(_course_label)
	_add_hud_widget(_course_chip)
	_course_marker = Label.new()
	_course_marker.name = "CourseMarker"
	_course_marker.text = "◆"
	_course_marker.theme = _hud_owned_theme()
	_course_marker.theme_type_variation = &"ChipLabel"
	_course_marker.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	_course_marker.add_theme_color_override("font_outline_color", UITokens.palette().ink)
	_course_marker.add_theme_constant_override("outline_size", 6)
	_course_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if compass_needle:
		compass_needle.add_child(_course_marker)


func _place_course_chip() -> void:
	if not _course_chip:
		return
	var top_bar: Control = %TopBar
	var top_rect := top_bar.get_global_rect() if top_bar else Rect2(12, 12, 0, 40)
	var y := top_rect.end.y + 10.0
	if _economy_chip and _economy_chip.visible:
		y = _economy_chip.get_global_rect().end.y + 8.0
	_course_chip.position = Vector2(top_rect.position.x, y)


## `ship_xz` defaults to the live player ship; tests pass one explicitly.
func _update_course(ship_xz := Vector2.INF) -> void:
	if not _course_target:
		return
	if ship_xz == Vector2.INF:
		if not _ship_controller or not is_instance_valid(_ship_controller):
			return
		ship_xz = Vector2(_ship_controller.global_position.x, _ship_controller.global_position.z)
	var d := _course_target.world_position - ship_xz
	var dist := d.length()
	if dist <= _COURSE_ARRIVE_RADIUS:
		var name_now := _course_target.island_name
		clear_course()
		announce_event(tr("Arrived at %s") % name_now)
		return
	_course_label.text = "⚑ %s · %s u" % [_course_target.island_name, UIMotion.group_digits(roundi(dist))]
	if _course_marker and compass_needle:
		# Needle-local frame: it already turns with the ship's yaw, and its
		# top is world north (+X east, +Z south, docs/11_WORLD_MAP.md §2).
		var bearing := atan2(d.x, -d.y)
		var centre := compass_needle.pivot_offset
		var r := centre.x * 0.82
		_course_marker.reset_size()
		_course_marker.position = centre + Vector2(sin(bearing), -cos(bearing)) * r - _course_marker.size * 0.5
		_course_marker.rotation = -compass_needle.rotation  # keep the glyph upright


func _place_economy_chip() -> void:
	_place_compass()
	if not _economy_chip or PirateThemeBuilder.is_mobile() or _uses_mobile_utility_menu():
		return
	var top_bar: Control = %TopBar
	var top_rect := top_bar.get_global_rect() if top_bar else Rect2(12, 12, 0, 40)
	_economy_chip.position = Vector2(top_rect.position.x, top_rect.end.y + 10.0)


## M22 Phase 5 — the compass was anchored to the top-right corner, exactly
## where TopRightPanel's resource bar sits, so it rendered as a sliver behind
## the last resource chip for as long as that bar has existed. It is now the
## last child of the speed/sail plaque's HBox (scene), so it moves and scales
## with the plaque and can't overlap anything the plaque doesn't. This only
## seats the cardinal letters (their scene offsets were tuned for ~14px text
## and overprinted each other at chip size) and centres the rotation pivot
## (the needle turns with the ship's yaw every frame — around its top-left
## corner by default, which swung N/S/E/W off the disc).
func _place_compass() -> void:
	if not compass_needle:
		return
	var disc: Control = compass_needle.get_parent()
	var needle_size: Vector2 = disc.size - Vector2(16, 16) if disc else compass_needle.size
	compass_needle.pivot_offset = needle_size * 0.5
	if wind_arrow:
		wind_arrow.add_theme_color_override("font_color", UITokens.palette().shallows.lightened(0.35))
	# Only the north marker: four chip-size letters don't fit an 88px disc
	# without touching, and the needle rotating with the ship already reads
	# as a compass from N + the wind arrow alone.
	for other in ["SLabel", "ELabel", "WLabel"]:
		var hidden_letter := compass_needle.get_node_or_null(other)
		if hidden_letter:
			hidden_letter.visible = false
	var half := _COMPASS_LETTER * 0.5
	for letter_offsets in [["NLabel", Vector4(-half, 0, half, _COMPASS_LETTER)]]:
		var letter: Label = compass_needle.get_node_or_null(letter_offsets[0])
		if not letter:
			continue
		var o: Vector4 = letter_offsets[1]
		letter.theme_type_variation = &"ChipLabel"
		letter.add_theme_color_override("font_color", UITokens.palette().coral_bloom)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.offset_left = o.x
		letter.offset_top = o.y
		letter.offset_right = o.z
		letter.offset_bottom = o.w

var _fps_label: Label
func _create_fps_label() -> void:
	## M2 Task 12.1 — frame time monitoring and display.
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(12))
	_fps_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.position = Vector2(8, -20)
	_fps_label.theme = _hud_owned_theme()
	add_child(_fps_label)
	# M22 6f: player-facing via Settings > Display > "FPS counter" (off by
	# default on every platform — it was always-on desktop HUD noise).
	_fps_label.visible = bool(SettingsManager.show_fps) if SettingsManager and "show_fps" in SettingsManager else false

var notoriety_label: Label
var captains_log_button: Button
var world_map_button: Button
var codex_button: Button
var whats_new_button: Button
var wardrobe_button: Button
var mobile_utility_menu_button: Button
var mobile_utility_drawer: PanelContainer
var mobile_utility_badge: Label
var _utility_rail: HBoxContainer


## A round wood icon button + caption, the one recipe every utility
## destination uses (desktop rail and phone drawer). The Button is returned so
## callers keep their existing `*_button` references and pressed wiring.
func _make_round_utility_button(button_name: String, icon_key: String, caption: String,
		width: float, with_caption: bool = true) -> Dictionary:
	var item := VBoxContainer.new()
	item.name = button_name + "Item"
	item.add_theme_constant_override("separation", 2)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := Button.new()
	btn.name = button_name
	btn.theme_type_variation = &"WoodRoundButton"
	btn.icon = UIIcons.get_icon(icon_key)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.tooltip_text = caption
	btn.custom_minimum_size = PirateThemeBuilder.round_button_size(width)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# WorldHUD itself is not PROCESS_MODE_ALWAYS (its own _process() drives
	# cannon cooldowns/compass that must stay frozen while paused), so without
	# this the button stops receiving input the moment ANY pause-on-open
	# panel sets get_tree().paused = true — a toggle that can open its panel
	# but never close it back (a real "looks stuck" bug from self-play).
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	item.add_child(btn)
	btn.add_child(ButtonJuice.new())
	if with_caption:
		var label := Label.new()
		label.name = "Caption"
		label.text = caption
		label.theme_type_variation = &"ChipLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
	return {"item": item, "button": btn}

func _uses_mobile_utility_menu() -> bool:
	return force_mobile_utility_menu or not OS.has_feature("pc")


func _mobile_utility_button_size() -> Vector2:
	## HUD utility actions need the same device-pixel allowance as the rest of
	## the phone UI. This is intentionally separate from the PC 70x32 utility
	## buttons, which remain mouse-sized and are never used on a phone build.
	## M22 (2026-09-25): this dynamically-rebuilt control is never swept by
	## PirateThemeBuilder.apply_button_juice() (only _rebuild_utility_controls()
	## creates these buttons, and it doesn't call it), so it previously relied
	## solely on HUD_BUTTON_SIZE_MOBILE's flat scale multiplier happening to
	## clear the touch-target floor — true at the old 1.5x MOBILE_CONTROL_SCALE
	## (120,52)*1.5=(180,78), no longer true once that constant dropped to
	## identity (design.md §3). Floor explicitly here instead, the same way
	## apply_button_juice() does for every other button.
	var scaled := HUD_BUTTON_SIZE_MOBILE * PirateThemeBuilder.control_scale()
	var floor_size := PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET
	# M22 Phase 5.5: round now, so width alone decides it (height follows the
	# art's aspect, and is always taller than the width).
	return PirateThemeBuilder.round_button_size(maxf(scaled.x, floor_size.x))


func _create_utility_controls() -> void:
	if _uses_mobile_utility_menu():
		_create_mobile_utility_menu()
		return
	# One container-owned row, right-aligned under the status chips (named
	# "Utility…" so _rebuild_utility_controls() clears it with the rest).
	_utility_rail = HBoxContainer.new()
	_utility_rail.name = "UtilityRail"
	_utility_rail.size_flags_horizontal = Control.SIZE_SHRINK_END
	_utility_rail.add_theme_constant_override("separation", 12)
	top_right_panel.add_child(_utility_rail)
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
	# M22 Phase 5.5 — a round wood button (log glyph: the drawer is the
	# captain's papers) with a "Captain" caption, same family as the rail.
	# Icon-only (tooltip "Captain"): with a caption under it the opener
	# reached down into the action cluster's context button on a 2340x1080
	# phone — caught by test_mobile_controls_layout's opener check.
	var opener_parts := _make_round_utility_button("UtilityMenuButton", "log", tr("Captain"),
			_MOBILE_MENU_BUTTON_WIDTH, false)
	mobile_utility_menu_button = opener_parts.button
	var opener: VBoxContainer = opener_parts.item
	opener.name = "UtilityMenuOpener"
	opener.theme = _hud_owned_theme()
	_add_hud_widget(opener)
	mobile_utility_badge = Label.new()
	mobile_utility_badge.name = "UtilityAttentionBadge"
	mobile_utility_badge.text = "!"
	mobile_utility_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mobile_utility_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mobile_utility_badge.position = Vector2(mobile_utility_menu_button.custom_minimum_size.x - 30, 4)
	mobile_utility_badge.size = Vector2(24, 24)
	mobile_utility_badge.theme_type_variation = &"ChipLabel"
	mobile_utility_badge.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	mobile_utility_menu_button.add_child(mobile_utility_badge)

	mobile_utility_drawer = PanelContainer.new()
	mobile_utility_drawer.name = "UtilityMenuDrawer"
	mobile_utility_drawer.theme_type_variation = &"WoodFramePanel"
	mobile_utility_drawer.process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_utility_drawer.theme = _hud_owned_theme()
	mobile_utility_drawer.visible = false
	_add_hud_widget(mobile_utility_drawer)
	# One row of round icon buttons (was a 2-column grid of brass text
	# buttons) — the same five destinations, the same recipe as desktop.
	var items := HBoxContainer.new()
	items.name = "Items"
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 16)
	mobile_utility_drawer.add_child(items)
	_add_mobile_utility_item(items, "Log", "log", "log")
	_add_mobile_utility_item(items, "Map", "map", "map")
	_add_mobile_utility_item(items, "Codex", "codex", "codex")
	_add_mobile_utility_item(items, "New", "new", "new")
	_add_mobile_utility_item(items, "Wardrobe", "wardrobe", "wardrobe")
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


func _add_mobile_utility_item(parent: Container, label: String, destination: String, icon_key: String) -> void:
	var parts := _make_round_utility_button("Utility%sButton" % destination.capitalize(), icon_key,
			tr(label), _mobile_utility_button_size().x)
	parts.button.pressed.connect(_open_mobile_utility.bind(destination))
	parent.add_child(parts.item)


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
	# M22 Phase 6c — the v0.3 notoriety card (screen 04): a translucent HUD
	# card with a Germania "Notoriety" title, the value, the next escalation
	# in the coral accent, and the gradient NotorietyBar with its skull.
	var pal := UITokens.palette()
	notoriety_label = Label.new()
	notoriety_label.name = "NotorietyLabel"
	notoriety_label.theme_type_variation = &"HudNumLabel"
	notoriety_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notoriety_next_label = Label.new()
	_notoriety_next_label.name = "NotorietyNext"
	_notoriety_next_label.theme_type_variation = &"ChipLabel"
	_notoriety_next_label.add_theme_color_override("font_color", pal.notoriety_accent)
	_notoriety_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notoriety_next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = tr("Notoriety")
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	title.add_theme_color_override("font_color", pal.text_on_dark)

	var chip := PanelContainer.new()
	chip.name = "NotorietyChip"
	chip.theme_type_variation = &"HudCard"
	# Shrink-to-content rather than the VBoxContainer default of filling
	# TopRightPanel's full width (test_notoriety_chip_shrinks_to_content_width).
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	chip.add_child(col)
	# M25 — the heat tier name. Notoriety was a bare number; the tier is what makes
	# it read as a wanted level ("Unknown" vs "Nemesis") without the player having
	# to learn what 150 means. Added to the existing header HBox so it lays out
	# with its siblings rather than at a hand-placed offset.
	_heat_tier_label = Label.new()
	_heat_tier_label.name = "HeatTier"
	_heat_tier_label.theme_type_variation = &"ChipLabel"
	_heat_tier_label.add_theme_color_override("font_color", pal.notoriety_accent)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.add_child(title)
	header.add_child(notoriety_label)
	header.add_child(_heat_tier_label)
	header.add_child(_notoriety_next_label)
	col.add_child(header)
	_notoriety_bar = NotorietyBar.new()
	_notoriety_bar.name = "NotorietyBar"
	_notoriety_bar.custom_minimum_size.x = _NOTORIETY_BAR_WIDTH
	col.add_child(_notoriety_bar)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(_on_notoriety_card_input)
	chip.add_to_group(&"hud_notoriety")   # M28 lesson highlight
	_notoriety_bar.visible = HudAutoHide.always_show()

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
	var log_parts := _make_round_utility_button("UtilityLogButton", "log", tr("Log"), _RAIL_BUTTON_WIDTH)
	captains_log_button = log_parts.button
	captains_log_button.pressed.connect(func():
		if captains_log:
			captains_log.toggle())
	_utility_rail.add_child(log_parts.item)

func _create_world_map_button() -> void:
	## M10 Requirement 3 — same dynamic-positioning pattern as
	## _create_captains_log_button() just above: a fourth child of
	## top_right_panel, container-positioned rather than a fifth
	## independently-hardcoded offset.
	var map_parts := _make_round_utility_button("UtilityMapButton", "map", tr("Map"), _RAIL_BUTTON_WIDTH)
	world_map_button = map_parts.button
	world_map_button.add_to_group(&"hud_world_map_button")   # M28 lesson highlight
	world_map_button.pressed.connect(func():
		if world_map_screen:
			world_map_screen.toggle())
	_utility_rail.add_child(map_parts.item)


func _create_codex_button() -> void:
	## Uses the same container-owned placement as Log/Map, avoiding a second
	## hard-coded HUD offset and its known overlap regression (D36).
	var codex_parts := _make_round_utility_button("UtilityCodexButton", "codex", tr("Codex"), _RAIL_BUTTON_WIDTH)
	codex_button = codex_parts.button
	codex_button.pressed.connect(func():
		if codex_screen and codex_screen.has_method("toggle"):
			codex_screen.toggle())
	_utility_rail.add_child(codex_parts.item)


func _create_whats_new_button() -> void:
	## M14 Requirement 5.1 — same container-owned placement as Log/Map/Codex.
	var new_parts := _make_round_utility_button("UtilityNewButton", "new", tr("New"), _RAIL_BUTTON_WIDTH)
	whats_new_button = new_parts.button
	whats_new_button.pressed.connect(func():
		if whats_new_screen:
			whats_new_screen.toggle())
	_utility_rail.add_child(new_parts.item)


func _create_wardrobe_button() -> void:
	## M16 Task 18 — same container-owned placement as Log/Map/Codex/New.
	var wardrobe_parts := _make_round_utility_button("UtilityWardrobeButton", "wardrobe", tr("Wardrobe"), _RAIL_BUTTON_WIDTH)
	wardrobe_button = wardrobe_parts.button
	wardrobe_button.pressed.connect(func():
		# Participate in M9's panel arbitration rather than stacking on top
		# (the V14 defect class) — a tutorial beat keeps focus if active.
		if tutorial_dialogue and tutorial_dialogue.visible:
			return
		if wardrobe_screen:
			wardrobe_screen.toggle())
	_utility_rail.add_child(wardrobe_parts.item)


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
	notoriety_label.text = "%d" % roundi(new_val) if absf(new_val - roundf(new_val)) < 0.05 else "%.1f" % new_val
	var next_threshold := -1.0
	var thresholds: Array[float] = []
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		for region in emp._regions:
			if region.activation_notoriety_threshold > 0.0:
				thresholds.append(region.activation_notoriety_threshold)
			if not emp.is_region_active(region.id):
				if next_threshold < 0 or region.activation_notoriety_threshold < next_threshold:
					next_threshold = region.activation_notoriety_threshold
	if _notoriety_next_label:
		_notoriety_next_label.text = (tr("Next escalation: %d") % roundi(next_threshold)) if next_threshold >= 0 else tr("Hunted everywhere")
	if _heat_tier_label and emp and emp.has_method("get_heat_name"):
		var heat_name: String = emp.get_heat_name()
		_heat_tier_label.text = heat_name.to_upper() if not heat_name.is_empty() else ""
	if _notoriety_bar:
		_notoriety_bar.set_state(new_val, thresholds, next_threshold)
		if _auto_hide and _last_notoriety >= 0.0 and not is_equal_approx(new_val, _last_notoriety):
			_auto_hide.wake(_notoriety_bar, _NOTORIETY_PEEK_SEC)
	_last_notoriety = new_val

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

func _on_dock_area_entered(island_id: String) -> void:
	# M29 J.1 — say who holds the island you're approaching.
	var owner_line := island_owner_line(_find_island_data(island_id))
	if _uses_mobile_utility_menu():
		_set_mobile_context_state("dock", true)
		# Phone: the dock prompt is the context button, so the owner line is a
		# brief queued announcement instead of a label.
		if not String(owner_line["text"]).is_empty():
			queue_announcement(owner_line["text"])
	else:
		if _dock_owner_label:
			_dock_owner_label.text = owner_line["text"]
			_dock_owner_label.add_theme_color_override("font_color", owner_line["color"])
			_dock_owner_label.visible = not String(owner_line["text"]).is_empty()
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

func _on_boarding_preview_changed(enemy_ship: Node, summary: Dictionary) -> void:
	_boarding_previews[enemy_ship.get_instance_id()] = summary
	var widget: Control = _enemy_bar_pool.get(enemy_ship.get_instance_id())
	if widget and widget.has_method("set_boarding_preview"):
		widget.set_boarding_preview(summary)


func _on_boarding_routed(reason: String) -> void:
	announce_event(tr("Quick boarding.") if reason == "quick" else tr("Overwhelming numbers. They yield at once."))


func _clear_boarding_previews() -> void:
	_boarding_previews.clear()
	for widget in _enemy_bar_pool.values():
		if is_instance_valid(widget) and widget.has_method("set_boarding_preview"):
			widget.set_boarding_preview({})


func _on_boarding_prompt_unavailable() -> void:
	_clear_boarding_previews()
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
		lbl.add_theme_color_override("font_color", UITokens.palette().hp_low)
	else:
		lbl.remove_theme_color_override("font_color")

func _set_resource_pill(value_label: Label, cap_label: Label, current: int, maximum: int) -> void:
	if value_label:
		# M22 6c (v0.3 screen 04): numbers tick to their new value, and a gain
		# shines the pill once ("pill shine sweeps on +value").
		var prev: int = _pill_values.get(value_label, -1)
		_pill_values[value_label] = current
		if _pill_ticks.has(value_label) and _pill_ticks[value_label].is_valid():
			_pill_ticks[value_label].kill()
		if prev < 0 or prev == current or not value_label.is_inside_tree():
			value_label.text = UIMotion.group_digits(current)
		else:
			_pill_ticks[value_label] = UIMotion.tick_number(value_label, prev, current, "%d", UIMotion.group_digits)
			if current > prev:
				var pill := _resource_pill_of(value_label)
				if pill:
					UIMotion.shine(pill)
		_tint_label(value_label, current, maximum)
	if cap_label:
		cap_label.text = "/%s" % UIMotion.group_digits(maximum)


var _pill_values: Dictionary = {}
var _pill_ticks: Dictionary = {}


func _resource_pill_of(node: Node) -> Control:
	var n := node.get_parent()
	while n and n != self:
		if n is PanelContainer and (n as PanelContainer).theme_type_variation == &"ResourcePill":
			return n
		n = n.get_parent()
	return null


func _on_resources_changed(res: Dictionary) -> void:
	## M15.5 — the icon now carries what an emoji prefix used to (each resource
	## chip's Icon TextureRect, tinted to match this same label's font color).
	var max_res = ResourceManager.max_storage
	_set_resource_pill(gold_label, gold_cap_label, res.get("gold", 0), max_res.get("gold", 9999))
	_set_resource_pill(wood_label, wood_cap_label, res.get("wood", 0), max_res.get("wood", 9999))
	_set_resource_pill(iron_label, iron_cap_label, res.get("iron", 0), max_res.get("iron", 9999))
	_set_resource_pill(rum_label, rum_cap_label, res.get("rum", 0), max_res.get("rum", 9999))
	if research_label:
		research_label.text = str(res.get("research", 0))
	if eights_label:
		eights_label.text = str(res.get(ResourceManager.PREMIUM_CURRENCY, 0))

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
	# Own line under the side name: at chip size "PORT CANNONS · 40° / 85m"
	# no longer fits the panel on one line and wrapped mid-phrase.
	var caption := "\n%d° / %dm" % [int(_firing_solver.get_arc_degrees()), int(_firing_solver.get_range())]
	if port_header_label:
		port_header_label.text = tr("PORT CANNONS") + caption + _side_ammo_suffix("port")
	if stbd_header_label:
		stbd_header_label.text = tr("STARBOARD CANNONS") + caption + _side_ammo_suffix("starboard")


## M30 1.9 — " · Chain Shot" (the side's load) while a briefing opening load
## is in the guns; empty otherwise, so the header is unchanged outside a fight.
func _side_ammo_suffix(side: String) -> String:
	var combat: Node = _ship_controller.combat if _ship_controller and is_instance_valid(_ship_controller) else null
	if not combat or not combat.has_method("has_side_ammo") or not combat.has_side_ammo():
		return ""
	var ammo: AmmoData = combat.get_ammo_for_side(side)
	return " · %s" % tr(ammo.display_name) if ammo else ""

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
		label.add_theme_color_override("font_color", _hud_muted())
	elif not preview.get("in_range", false):
		label.text = tr("OUT OF RANGE")
		label.add_theme_color_override("font_color", _hud_muted())
	else:
		var angle: float = preview.get("angle_off_deg", 180.0)
		label.text = tr("%d° TO ALIGN") % int(ceil(angle))
		var arc: float = maxf(_firing_solver.get_arc_degrees(), 0.01) if _firing_solver else 35.0
		var warmth: float = clampf(1.0 - angle / arc, 0.0, 1.0)
		label.add_theme_color_override("font_color", _hud_muted().lerp(UITokens.palette().horizon_gold, warmth))

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
			if _boarding_previews.has(id) and widget.has_method("set_boarding_preview"):
				widget.set_boarding_preview(_boarding_previews[id])
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

# ---------------------------------------------------------------------------
# M22 Phase 6e — declutter. Only what the moment needs stays on screen:
# cannon readouts near an enemy or while reloading; the notoriety meter for
# a few seconds after it moves (tap the card to peek); the objective for a
# while after it changes; no production countdown (the resource pills tick
# and shine when production lands); captions under the rail only while
# learning (Always-show). Settings > Display > "HUD details" turns it off.
# ---------------------------------------------------------------------------
const _DECLUTTER_TICK_SEC := 0.2
const _NOTORIETY_PEEK_SEC := 6.0
const _OBJECTIVE_PEEK_SEC := 8.0
var _auto_hide: HudAutoHide
var _declutter_accum := 0.0
var _last_notoriety := -1.0
var _rail_captions: Array = []


func _apply_hud_settings() -> void:
	if _fps_label:
		_fps_label.visible = bool(SettingsManager.show_fps) if SettingsManager and "show_fps" in SettingsManager else false
	_declutter_tick(true)


func _in_combat_range() -> bool:
	if not _ship_controller or not is_instance_valid(_ship_controller):
		return false
	for ship in get_tree().get_nodes_in_group("enemy_ship"):
		if ship is Node3D and is_instance_valid(ship) \
				and ship.global_position.distance_to(_ship_controller.global_position) <= ENEMY_BAR_DISPLAY_RANGE:
			return true
	return false


func _reloading() -> bool:
	var now := Time.get_ticks_msec()
	return (_port_cooldown_total > 0.0 and now - _port_cooldown_start_ms < int(_port_cooldown_total * 1000.0)) \
		or (_stbd_cooldown_total > 0.0 and now - _stbd_cooldown_start_ms < int(_stbd_cooldown_total * 1000.0))


func _declutter_tick(force := false) -> void:
	if not _auto_hide:
		return
	var always := HudAutoHide.always_show()
	if cannons_container and not _uses_mobile_utility_menu():
		_auto_hide.set_wanted(cannons_container, _in_combat_range() or _reloading())
	if _economy_chip:
		_auto_hide.set_wanted(_economy_chip, false)
	if _objective_label and not _objective_card:
		_auto_hide.set_wanted(_objective_label, false)
	elif _objective_card:
		_auto_hide.set_wanted(_objective_card, false)
	if _notoriety_bar:
		var show_bar := always or _auto_hide.is_awake(_notoriety_bar)
		if _notoriety_bar.visible != show_bar or force:
			_notoriety_bar.visible = show_bar
			if show_bar and not force:
				UIMotion.pop_in(_notoriety_bar)
			if _uses_mobile_utility_menu():
				_apply_mobile_safe_area.call_deferred()
	# Desktop rail only — the phone drawer is opened on purpose and keeps its
	# captions. Cached: the rail is rebuilt only on layout changes.
	if not _uses_mobile_utility_menu():
		if force or _rail_captions.is_empty() or not is_instance_valid(_rail_captions[0]):
			_rail_captions = []
			for caption in find_children("Caption", "Label", true, false):
				if mobile_utility_drawer == null or not mobile_utility_drawer.is_ancestor_of(caption):
					_rail_captions.append(caption)
		for caption in _rail_captions:
			if is_instance_valid(caption):
				caption.visible = always


func _peek_objective() -> void:
	if not _auto_hide:
		return
	var target: Control = _objective_card if _objective_card else _objective_label
	if target:
		_auto_hide.wake(target, _OBJECTIVE_PEEK_SEC)


func _on_notoriety_card_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tapped and _auto_hide and _notoriety_bar:
		_auto_hide.wake(_notoriety_bar, _NOTORIETY_PEEK_SEC)
		_declutter_tick()


func _process(_delta: float) -> void:
	_declutter_accum += _delta
	if _declutter_accum >= _DECLUTTER_TICK_SEC:
		_declutter_accum = 0.0
		_declutter_tick()
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
	if _course_target:
		_update_course()

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
		_economy_label.text = tr("Next Production: %.1fs") % max(0.0, time_left)

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
	_objective_label.theme_type_variation = &"HudNumLabel"
	_objective_label.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE, true)
	_objective_label.offset_top = 44.0
	_objective_label.offset_bottom = 90.0
	_objective_label.visible = false
	_objective_label.theme = _hud_owned_theme()
	_add_hud_widget(_objective_label)


func _create_mobile_objective_card() -> void:
	## The objective remains visible while the player steers, but belongs just
	## above the primary action cluster instead of competing with top HUD data.
	_objective_card = PanelContainer.new()
	_objective_card.name = "ObjectiveCard"
	_objective_card.theme = _hud_owned_theme()
	# v0.3 "BOUNTY" card: a parchment slip in the HUD, ink text.
	_objective_card.theme_type_variation = &"BountyCard"
	_objective_card.visible = false
	_add_hud_widget(_objective_card)
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.theme_type_variation = &"HudNumLabel"
	_objective_label.add_theme_color_override("font_color", UITokens.palette().ink)
	_objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
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
	_peek_objective()

func _on_objective_progress(current: int, total: int) -> void:
	if not _objective_label or not _objective_label.visible:
		return
	if total > 0:
		_objective_label.text = "%s  [%d / %d]" % [
			_objective_label.text.split("  [")[0], current, total]
		_peek_objective()

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
		label.add_theme_color_override("font_color", UITokens.palette().hp_low)
	elif locked:
		label.text = tr("TARGET · RELOADING %d%%") % int(pct * 100.0)
		label.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	elif ready:
		label.text = tr("READY ⚓")
		label.add_theme_color_override("font_color", UITokens.palette().hp_good)
	else:
		label.text = tr("RELOADING %d%% ⌛") % int(pct * 100.0)
		label.add_theme_color_override("font_color", UITokens.palette().brass)

func _update_special_broadside_display() -> void:
	if not _special_label or not _ship_controller or not _ship_controller.combat:
		return
	var combat = _ship_controller.combat
	if not combat.has_method("is_special_broadside_ready"):
		_special_label.visible = false
		return
	# M30 W1 (1.12) — a full Fury readies the special early, so readiness is
	# is_special_ready() (timer OR Fury), not the timer alone.
	var ready: bool = combat.is_special_ready() if combat.has_method("is_special_ready") \
		else combat.is_special_broadside_ready()
	if mobile_controls and mobile_controls.has_method("set_cooldown_fraction"):
		mobile_controls.set_cooldown_fraction("broadside",
			1.0 if ready else combat.get_special_cooldown_fraction())
	if ready:
		_special_label.text = tr("[SPACE] FULL BROADSIDE")
		_special_label.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	else:
		var pct: float = combat.get_special_cooldown_fraction()
		_special_label.text = tr("FULL BROADSIDE %d%%") % int(pct * 100.0)
		_special_label.add_theme_color_override("font_color", _hud_muted())
	if _fury_meter:
		var has_fury: bool = combat.get("fury_data") != null
		_fury_meter.visible = has_fury
		if has_fury:
			_fury_meter.value = float(combat.get("fury"))
	_update_brace_label()


## M30 W1 (1.6) — names the key while Brace is the context verb. Phones show
## it on the context button itself (MobileControls), so this is desktop only.
func _update_brace_label() -> void:
	if not _brace_label:
		return
	var wm := get_tree().get_first_node_in_group("world_manager")
	var show_it: bool = not _uses_mobile_utility_menu() and wm != null \
		and wm.has_method("get_context_verb") and wm.get_context_verb() == &"brace"
	_brace_label.visible = show_it
	if show_it:
		_brace_label.text = tr("[%s] BRACE!") % _action_key_text("dock")


static func _action_key_text(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: int = e.keycode if e.keycode != KEY_NONE else e.physical_keycode
			return OS.get_keycode_string(code)
	return action.to_upper()

func _update_captain_ability_display() -> void:
	if not _ability_label or not _ship_controller:
		return
	var node = _ship_controller.get_node_or_null("CaptainAbility")
	if not node or not node.has_method("has_ability") or not node.has_ability():
		_ability_label.visible = false
		return
	_ability_label.visible = true
	if mobile_controls and mobile_controls.has_method("set_cooldown_fraction"):
		mobile_controls.set_cooldown_fraction("ability", node.get_cooldown_fraction())
	var ability = node.get_ability()
	if node.is_ready():
		_ability_label.text = tr("[R] %s %s") % [ability.icon, ability.display_name]
		_ability_label.add_theme_color_override("font_color", UITokens.palette().shallows.lightened(0.45))
	else:
		_ability_label.text = "%s %s %d%%" % [
			ability.icon, ability.display_name, int(node.get_cooldown_fraction() * 100.0)]
		_ability_label.add_theme_color_override("font_color", _hud_muted())

func _create_captain_ability_label() -> void:
	# Starboard panel (M22 Phase 5): the special broadside readout already
	# sits under Port, and stacking both there made Port twice Starboard's
	# height with an empty Starboard beside it.
	var host: Node = stbd_label.get_parent() if stbd_label else null
	if not host:
		return
	_ability_label = Label.new()
	_ability_label.name = "CaptainAbilityLabel"
	_ability_label.theme_type_variation = &"ChipLabel"
	_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(_ability_label)
	_update_captain_ability_display()

func _create_special_broadside_label() -> void:
	## Sits directly under the two per-side readouts, reusing the same parent so
	## it inherits the existing cannon-panel layout rather than introducing a
	## second anchored control that could drift off-screen (the D36 failure mode).
	if not port_label or not port_label.get_parent():
		return
	_special_label = Label.new()
	_special_label.name = "SpecialBroadsideLabel"
	_special_label.theme_type_variation = &"ChipLabel"
	_special_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_label.get_parent().add_child(_special_label)
	# M30 W1 (1.12/1.6) — same container, so they stack under the readout.
	_fury_meter = ProgressBar.new()
	_fury_meter.name = "FuryMeter"
	_fury_meter.min_value = 0.0
	_fury_meter.max_value = 1.0
	_fury_meter.step = 0.0
	_fury_meter.show_percentage = false
	_fury_meter.custom_minimum_size = Vector2(0, _FURY_METER_HEIGHT)
	_fury_meter.tooltip_text = tr("Fury: fills from your hits, rakes, kills and Perfect Braces. Full = Full Broadside ready.")
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITokens.palette().horizon_gold
	_fury_meter.add_theme_stylebox_override("fill", fill)
	port_label.get_parent().add_child(_fury_meter)
	_brace_label = Label.new()
	_brace_label.name = "BraceLabel"
	_brace_label.theme_type_variation = &"ChipLabel"
	_brace_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brace_label.add_theme_color_override("font_color", UITokens.palette().horizon_gold)
	_brace_label.visible = false
	port_label.get_parent().add_child(_brace_label)
	_update_special_broadside_display()

func show_dock_prompt(show: bool) -> void:
	if dock_prompt:
		dock_prompt.visible = show

func announce_event(text_content: String, is_warning: bool = false) -> Control:
	## M9 Requirement 6 (D68) — previously bare, unframed red Label text
	## directly over the 3D world, reading as a debug print for every message
	## regardless of tone. Framed like the rest of the HUD's panels; color
	## reads informational (gold) by default, alarm-red only for genuine
	## warnings (e.g. docking too fast, a corrupted save).
	# M22 Phase 5: the kit's wood frame + HudNum text (was a flat navy
	# StyleBoxFlat with a black-outlined label — the pre-M22 look).
	var panel := PanelContainer.new()
	panel.name = "Announcement"
	panel.theme_type_variation = &"WoodFramePanel"

	var label = Label.new()
	label.text = text_content
	label.theme_type_variation = &"HudNumLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",
		UITokens.palette().hp_low if is_warning else UITokens.palette().brass_light)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

	# Span the full width and wrap, rather than PRESET_CENTER. That preset
	# anchors a zero-width rect at the centre, so a long announcement grew
	# rightwards off the edge of the screen instead of centring within it —
	# "While you were away: your empire kept running (N ticks)" ran clean off
	# the frame. A full-width rect with wrapping centres properly at any length.
	# M22 Phase 5: centred and capped at _ANNOUNCE_MAX_WIDTH — a full-width
	# wood band read as a wall and, on phone, covered the side clusters
	# (Set Sail) for its whole 3.4s. Still a real-width rect (never the
	# zero-width PRESET_CENTER trap described above), so it wraps and centres.
	var announce_width := minf(_ANNOUNCE_MAX_WIDTH, get_viewport().get_visible_rect().size.x - 80.0)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -announce_width * 0.5
	panel.offset_right = announce_width * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = -140.0
	panel.offset_bottom = -40.0

	panel.theme = _hud_owned_theme()
	add_child(panel)

	# Start transparent, otherwise the first tween fades from 1.0 to 1.0 and the
	# announcement simply pops in.
	panel.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)
	return panel


## M29 D.1 — world-event announcements.
func _setup_event_banner() -> void:
	_event_announcement_data = load("res://resources/events/EventAnnouncements.tres") as EventAnnouncementData
	if not _event_announcement_data:
		push_error("WorldHUD: could not load res://resources/events/EventAnnouncements.tres")
	if not EventManager.world_event_triggered.is_connected(_on_world_event_triggered):
		EventManager.world_event_triggered.connect(_on_world_event_triggered)
	# M29 J.2 — the campaign's end is announced here; free-roam objective text
	# lives in the Captain's Log (CampaignManager.get_display_objective()).
	if not CampaignManager.campaign_completed_signal.is_connected(_on_campaign_completed):
		CampaignManager.campaign_completed_signal.connect(_on_campaign_completed)
	# EncounterManager is a World scene node, not an autoload; it joins this group.
	call_deferred("_connect_encounter_failed_signal")
	_build_dock_owner_line()


func _connect_encounter_failed_signal() -> void:
	if not is_inside_tree():
		return
	var encounters := get_tree().get_first_node_in_group("encounter_manager")
	if encounters and not encounters.encounter_failed.is_connected(_on_encounter_failed):
		encounters.encounter_failed.connect(_on_encounter_failed)


func _on_world_event_triggered(event_name: String, _data: Dictionary) -> void:
	if not _event_announcement_data:
		return
	var title = _event_announcement_data.get_title(event_name)
	if title == null:
		push_warning("WorldHUD: no EventAnnouncements entry for world event '%s'" % event_name)
		return
	if String(title).is_empty():
		return  # deliberately silent (e.g. ship_docked — the dock UI already says it)
	queue_announcement(tr(title))


func _on_sync_status_changed(state: StringName, _since: int) -> void:
	if state == SaveManager.SYNC_FAILING or state == SaveManager.SYNC_BLOCKED:
		queue_announcement(SaveManager.get_sync_status_text())


func _on_encounter_failed(_encounter_id: String, reason: String) -> void:
	# A refusal because a battle is already running is not news to the player.
	if reason == EncounterManager.REASON_BUSY:
		return
	# Quiet: the details are in the push_error log; the player only needs to know
	# nothing is coming.
	queue_announcement(tr("The encounter never formed — the sea is quiet again."))


func _on_campaign_completed() -> void:
	queue_announcement(tr("Campaign complete — the empire is yours. Sail on."))


## Queues a non-modal announcement; shows it now if none is on screen. World
## events use this so a burst (convoy + ghost ship + wreckage) reads one at a
## time instead of stacking on the same spot.
func queue_announcement(text_content: String, is_warning: bool = false) -> void:
	_announce_queue.append({"text": text_content, "warning": is_warning})
	_show_next_announcement()


func _show_next_announcement() -> void:
	if is_instance_valid(_announce_active) or _announce_queue.is_empty():
		return
	var next: Dictionary = _announce_queue.pop_front()
	_announce_active = announce_event(next["text"], next["warning"])
	_announce_active.tree_exited.connect(_on_announcement_finished, CONNECT_ONE_SHOT)


func _on_announcement_finished() -> void:
	_announce_active = null
	if is_inside_tree():
		_show_next_announcement()


# --- M29 J.1: island owner on approach ---

func _build_dock_owner_line() -> void:
	var dock_label := dock_prompt.get_node_or_null("DockLabel") if dock_prompt else null
	if not dock_label or _dock_owner_label:
		return
	# Container layout, not a second hardcoded offset (CLAUDE.md fragile area).
	var column := VBoxContainer.new()
	column.name = "DockColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_prompt.remove_child(dock_label)
	dock_prompt.add_child(column)
	_dock_owner_label = Label.new()
	_dock_owner_label.name = "DockOwnerLabel"
	_dock_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_owner_label.visible = false
	column.add_child(_dock_owner_label)
	column.add_child(dock_label)


func _find_island_data(island_id: String) -> IslandData:
	for node in get_tree().get_nodes_in_group("islands"):
		if node.has_method("get_island_id") and node.get_island_id() == island_id:
			return node.get("island_data") as IslandData
	return null


## "<Island> · <Owner>" plus the owner's colour; empty text when unknown.
func island_owner_line(island_data: IslandData) -> Dictionary:
	if not island_data:
		return {"text": "", "color": Color.WHITE}
	var display: Dictionary = FactionManager.get_island_owner_display(island_data)
	return {
		"text": "%s · %s" % [tr(island_data.island_name), tr(display.get("name", ""))],
		"color": display.get("color", Color.WHITE),
	}
