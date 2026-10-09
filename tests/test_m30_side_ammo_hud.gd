extends GutTest
## M30 Wave 1 (1.9): the Spyglass Briefing's in-game wiring and what the
## player sees of its per-side opening loads.
##   - WorldHUD._find_ship() builds a SpyglassBriefing and binds it to the
##     scene's Systems/EncounterManager (test_m30_spyglass.gd binds one by hand,
##     so it cannot catch that line being dropped).
##   - ShipCombat.set_side_ammo()/clear_side_ammo() emit side_ammo_changed —
##     never ammo_changed, which CampaignManager counts as the player's own
##     SWAP_AMMO — and the HUD shows each battery's load while one is set: the
##     phone ammo button reads "Port/Starboard", the desktop cannon headers name
##     their side's shot.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const WorldHUDScene := preload("res://scenes/ui/WorldHUD.tscn")
const ROUND := "res://resources/combat/ammo/RoundShot.tres"
const CHAIN := "res://resources/combat/ammo/ChainShot.tres"
const GRAPE := "res://resources/combat/ammo/GrapeShot.tres"

var _scene: Node3D = null
var _prev_scene: Node = null
var _prev_ad_state: int = 0
var _prev_offline_ticks: int = 0
var _mgr: EncounterManager = null
var _ship: ShipController = null
var _combat: ShipCombat = null
var _viewport: SubViewport = null
var _hud: Node = null


func before_each() -> void:
	# WorldHUD instances AgeGate/ConsentPanel, which pause the whole tree while
	# the global AdManager is in a *_PENDING state — and earlier scripts leave it
	# there. Pin a neutral state so a HUD built here can never pause the run.
	_prev_ad_state = AdManager.state
	AdManager.state = AdManager.State.UNKNOWN
	# A real WorldHUD turns SaveManager's leftover offline ticks into a modal
	# "while you were away" offer that pauses the tree — and test_save_manager_
	# offline leaves them set. Neutralise it, and drop player_ship stragglers
	# earlier scripts leaked (a mock parent made MobileControls error here).
	_prev_offline_ticks = SaveManager._pending_offline_ticks
	SaveManager._pending_offline_ticks = 0
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "SideAmmoWorld"
	var systems := Node.new()
	systems.name = "Systems"
	_scene.add_child(systems)
	_mgr = EncounterManager.new()
	_mgr.name = "EncounterManager"
	_mgr.ambient_enabled = false
	systems.add_child(_mgr)
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene

	_ship = ENEMY_SHIP.instantiate() as ShipController
	var ai := _ship.get_node_or_null("EnemyAI")
	if ai:
		_ship.remove_child(ai)
		ai.free()
	_ship.remove_from_group("enemy_ship")
	_ship.add_to_group("player_ship")
	_ship.freeze = true
	_scene.add_child(_ship)
	_combat = _ship.get_node("ShipCombat") as ShipCombat
	_combat.set_ammo(load(ROUND))

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2340, 1080)
	_viewport.disable_3d = true
	add_child(_viewport)
	_hud = WorldHUDScene.instantiate()
	_hud.get_node("MobileControls").force_mobile_layout_for_test = true
	_viewport.add_child(_hud)
	await wait_process_frames(3)  # WorldHUD._find_ship() awaits process_frame before wiring


## Freed now, not queued: a ship left in group player_ship leaks into later
## scripts (MaelstromRun/SaveManager read get_first_node_in_group).
func after_each() -> void:
	if is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.free()
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = _prev_scene if is_instance_valid(_prev_scene) else null
		get_tree().root.remove_child(_scene)
		_scene.free()
	_scene = null
	_ship = null
	_combat = null
	_mgr = null
	_hud = null
	_viewport = null
	_prev_scene = null
	AdManager.state = _prev_ad_state as AdManager.State
	SaveManager._pending_offline_ticks = _prev_offline_ticks
	get_tree().paused = false


func _ammo_button() -> Button:
	return _hud.get_node("MobileControls")._btn_ammo


# === WorldHUD wires the briefing in game ===

func test_world_hud_builds_a_briefing_bound_to_the_scene_encounter_manager() -> void:
	var briefing := _hud.get_node_or_null("SpyglassBriefing") as SpyglassBriefing
	assert_not_null(briefing, "WorldHUD adds a SpyglassBriefing once it finds the World")
	if briefing:
		assert_true(_mgr.encounter_started.is_connected(briefing._on_encounter_started),
			"it opens on the scene EncounterManager's encounter_started")
		assert_true(_mgr.encounter_ended.is_connected(briefing._on_encounter_ended))


# === The signal ===

func test_side_loads_emit_their_own_signal_and_never_ammo_changed() -> void:
	watch_signals(_combat)
	_combat.set_side_ammo("port", load(CHAIN))
	assert_signal_emit_count(_combat, "side_ammo_changed", 1)
	_combat.set_side_ammo("port", load(CHAIN))
	assert_signal_emit_count(_combat, "side_ammo_changed", 1, "setting the same load is not a change")
	_combat.clear_side_ammo()
	assert_signal_emit_count(_combat, "side_ammo_changed", 2, "clearing is a change")
	_combat.clear_side_ammo()
	assert_signal_emit_count(_combat, "side_ammo_changed", 2, "clearing nothing is not")
	assert_signal_not_emitted(_combat, "ammo_changed",
		"the briefing's opening pick must not count as the player's SWAP_AMMO")


# === What the player sees ===

func test_phone_ammo_button_shows_each_sides_opening_load() -> void:
	var btn := _ammo_button()
	assert_not_null(btn, "forced phone layout builds the ammo button")
	assert_eq(btn.text, "Round", "precondition: one load in both batteries")

	_combat.set_side_ammo("port", load(CHAIN))
	_combat.set_side_ammo("starboard", load(GRAPE))
	assert_eq(btn.text, "Chain/Grape", "Port/Starboard opening loads are on the button")

	_combat.clear_side_ammo()  # EncounterManager's resolve
	assert_eq(btn.text, "Round", "back to the one load after the battle")

	_combat.set_side_ammo("starboard", load(GRAPE))
	assert_eq(btn.text, "Round/Grape", "an untouched side shows the current load")
	_combat.cycle_ammo()  # choosing a load mid-fight replaces the opening loads
	assert_eq(btn.text, "Chain")


func test_desktop_cannon_headers_name_each_sides_opening_load() -> void:
	var port_header: Label = _hud.port_header_label
	var stbd_header: Label = _hud.stbd_header_label
	var chain: AmmoData = load(CHAIN)
	var grape: AmmoData = load(GRAPE)
	assert_false(port_header.text.contains(chain.display_name), "precondition")

	_combat.set_side_ammo("port", chain)
	_combat.set_side_ammo("starboard", grape)
	assert_string_contains(port_header.text, chain.display_name)
	assert_string_contains(stbd_header.text, grape.display_name)

	_combat.clear_side_ammo()
	assert_false(port_header.text.contains(chain.display_name), "cleared after the battle")
	assert_false(stbd_header.text.contains(grape.display_name))
