extends GutTest
## M30 Wave 2 (2.5): WorldHUD wires the boarding overlay and the preview strip in game.
## test_m30_boarding_overlay.gd drives the overlay by hand; this catches the wiring lines
## being dropped (the same reason test_m30_side_ammo_hud.gd exists for the Spyglass).

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const WorldHUDScene := preload("res://scenes/ui/WorldHUD.tscn")

var _scene: Node3D = null
var _prev_scene: Node = null
var _prev_ad_state: int = 0
var _prev_offline_ticks: int = 0
var _system: BoardingSystem = null
var _player: ShipController = null
var _enemy: ShipController = null
var _viewport: SubViewport = null
var _hud: Node = null


func before_each() -> void:
	# Same isolation as test_m30_side_ammo_hud.gd: a real WorldHUD must never pause the run
	# (AdManager *_PENDING states, SaveManager's leftover offline ticks) or see leaked ships.
	_prev_ad_state = AdManager.state
	AdManager.state = AdManager.State.UNKNOWN
	_prev_offline_ticks = SaveManager._pending_offline_ticks
	SaveManager._pending_offline_ticks = 0
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "BoardingHudWorld"
	var systems := Node.new()
	systems.name = "Systems"
	_scene.add_child(systems)
	_system = BoardingSystem.new()
	_system.name = "BoardingSystem"
	systems.add_child(_system)
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene

	_player = _make_ship(true)
	_enemy = _make_ship(false)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2340, 1080)
	_viewport.disable_3d = true
	add_child(_viewport)
	_hud = WorldHUDScene.instantiate()
	_hud.get_node("MobileControls").force_mobile_layout_for_test = true
	_viewport.add_child(_hud)
	await wait_process_frames(4)  # WorldHUD._find_ship() awaits a frame before wiring


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
	_system = null
	_player = null
	_enemy = null
	_hud = null
	_viewport = null
	_prev_scene = null
	AdManager.state = _prev_ad_state as AdManager.State
	SaveManager._pending_offline_ticks = _prev_offline_ticks
	get_tree().paused = false


func _make_ship(is_player: bool) -> ShipController:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	var ai := ship.get_node_or_null("EnemyAI")
	if ai:
		ship.remove_child(ai)
		ai.free()
	ship.freeze = true
	if is_player:
		ship.remove_from_group("enemy_ship")
		ship.add_to_group("player_ship")
	_scene.add_child(ship)
	return ship


func test_world_hud_adds_a_boarding_overlay_bound_to_the_scene_boarding_system() -> void:
	var overlay := _hud.get_node_or_null("BoardingOverlay") as BoardingOverlay
	assert_not_null(overlay, "WorldHUD adds a BoardingOverlay once it finds the World")
	if overlay:
		assert_true(_system.boarding_started.is_connected(overlay._on_boarding_started),
			"it opens on the scene BoardingSystem's boarding_started")
		assert_false(overlay.visible, "closed until a boarding begins")


func test_the_hud_listens_for_the_preview_and_the_instant_route_toast() -> void:
	assert_true(_system.deck_preview_changed.is_connected(_hud._on_boarding_preview_changed))
	assert_true(_system.boarding_routed.is_connected(_hud._on_boarding_routed))


func test_a_deck_preview_reaches_the_targets_health_bar_and_clears_with_the_prompt() -> void:
	var widget: Control = _hud._enemy_bar_pool.get(_enemy.get_instance_id())
	assert_not_null(widget, "precondition: the HUD built a health bar for the enemy hull")
	if widget == null:
		return
	var label: Label = widget.get_boarding_preview_label()
	assert_not_null(label)
	assert_false(label.visible)
	_system.deck_preview_changed.emit(_enemy, {"defenders": 4, "officers": 1, "bells": 3,
			"entry": BoardingZone.Id.FORECASTLE, "threats": 0, "morale": 60})
	assert_true(label.visible, "the strip shows once a deck is known")
	assert_string_contains(label.text, "Forecastle")
	_system.boarding_prompt_unavailable.emit()
	assert_false(label.visible, "and goes away when the boarding prompt does")


func test_a_boarding_that_begins_opens_the_overlay_over_the_hud() -> void:
	var overlay := _hud.get_node("BoardingOverlay") as BoardingOverlay
	var dmg = _enemy.get_node("ShipDamage")
	var pdmg = _player.get_node("ShipDamage")
	pdmg.crew = pdmg.ship_stats.max_crew
	dmg.crew = dmg.ship_stats.max_crew * 0.9
	_system._eligible_enemy = _enemy
	assert_true(_system.begin_boarding(), "the Board verb begins a tactical boarding")
	assert_true(overlay.is_open)
	assert_true(get_tree().paused)
	overlay.cut_loose()
	overlay.finish()
	assert_false(get_tree().paused)
