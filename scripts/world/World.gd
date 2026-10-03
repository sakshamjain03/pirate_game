extends Node3D

var _quality_tier_table: QualityTierTable
var _environment: Environment
var _directional_light: DirectionalLight3D

func _ready() -> void:
	# M29 E.2 — graphics-quality tier levers (QualityTierData). Medium matches the
	# authored scene, so only Low/High change anything on screen.
	_quality_tier_table = load("res://resources/settings/QualityTiers.tres")
	if not _quality_tier_table:
		push_error("World: Could not load res://resources/settings/QualityTiers.tres")
	var world_env := get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if world_env:
		_environment = world_env.environment
	_directional_light = get_node_or_null("Environment/DirectionalLight3D") as DirectionalLight3D
	_apply_quality_tiers()
	SettingsManager.settings_changed.connect(_apply_quality_tiers)

	var ship = get_node_or_null("PlayerShip")

	var islands = []
	var islands_node = get_node_or_null("Islands")
	if islands_node:
		islands = islands_node.get_children()

	# The manager is local in this scene under Systems/WorldManager
	var world_manager = get_node_or_null("Systems/WorldManager")
	if world_manager and world_manager.has_method("initialize_world"):
		world_manager.initialize_world(ship, islands)

	# Give the DockingSystem a reference to the player ship. Without this the
	# state machine's attempt_dock()/attempt_undock() calls have nothing to
	# operate on (ship_controller stays null forever).
	var docking_system = get_node_or_null("Systems/DockingSystem")
	if docking_system and docking_system.has_method("initialize") and ship:
		docking_system.initialize(ship)

	# D58 cold start fix (superseded): Port Royal used to be force-owned on a
	# genuinely new game. It's now a NEUTRAL, undefended island like Tortuga —
	# "pirate-friendly" but not owned — that the player claims via the same
	# Colonize flow every other island uses, at a story-cheap authored cost
	# (IslandData.colonize_cost_gold on PortRoyal.tres) reachable from the
	# 200-gold starting purse. See Ch1_TheDrownedPort.tres's new claim objective.
	if not SaveManager.has_save_data():
		call_deferred("_seed_whats_new_version")

	# Load game state (if coming from Continue)
	if SaveManager.has_method("load_game"):
		# Use call_deferred to ensure physics and all nodes are fully ready
		SaveManager.call_deferred("load_game")

	# M15 Requirement 4.3 — once per app session (internally guarded); a no-op for a
	# signed-out player. Does not block or delay anything above.
	if SaveManager.has_method("check_cloud_save_on_launch"):
		SaveManager.call_deferred("check_cloud_save_on_launch")

	# M17 Requirement 3.3 — same once-per-session, internally-guarded convention as above.
	if EntitlementManager.has_method("check_cloud_sync_on_launch"):
		EntitlementManager.call_deferred("check_cloud_sync_on_launch")

	# Deferred (and queued after load_game above) so resumed campaign progress
	# from a loaded save is already in place before signals start firing.
	if world_manager and CampaignManager.has_method("on_world_ready"):
		CampaignManager.call_deferred("on_world_ready", world_manager)
	if world_manager and SeasonalEventManager.has_method("on_world_ready"):
		SeasonalEventManager.call_deferred("on_world_ready", world_manager)
	if AnalyticsManager.has_method("on_world_ready"):
		AnalyticsManager.call_deferred("on_world_ready", self)


## Applies the tier for the current SettingsManager.graphics_quality.
func _apply_quality_tiers() -> void:
	if not _quality_tier_table:
		return
	var tier := _quality_tier_table.get_tier(SettingsManager.graphics_quality)
	if not tier:
		push_error("World: no quality tier for graphics_quality %d" % SettingsManager.graphics_quality)
		return
	tier.apply_to(_environment, _directional_light, get_viewport())


## M14 Requirement 5.2 — a genuinely new player experiences Ch6-10, Regions
## 4/5, and the Spring Crossing firsthand through normal progression; they
## must never see a "what's new" popup for content they haven't reached yet.
## Guarded the same way as the block above (a new game only).
func _seed_whats_new_version() -> void:
	var patch_notes: PatchNotesData = load("res://resources/ui/PatchNotes.tres")
	if patch_notes:
		SaveManager.last_seen_whats_new_version = patch_notes.latest_version()
