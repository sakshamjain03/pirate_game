extends GutTest

## Guards M25's central combat change: firing is an action the player takes.
##
## Before M25 `ShipCombat._physics_process` pulled the trigger automatically the
## moment `FiringSolver` reported arc-lock, so the player never pressed anything
## to shoot and none of the depth underneath (three damage pools, three ammo
## types, the chain/grape/round triangle) was ever a decision.
##
## Two things these tests pin that are easy to get wrong:
##
##   1. **Only the PLAYER went manual.** The `auto_fire_enabled` export default
##      stays TRUE. EnemyAI only calls fire_cannons() for its deliberate attack
##      run and relied on auto-fire for everything else, so flipping the export
##      would have quietly gutted every enemy's damage output — a sweeping combat
##      rebalance disguised as a UX change.
##   2. **Arc-lock still gates.** Manual fire is not free fire; aiming stays
##      positional, which is what keeps the game one-thumb.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D = null
var _saved_auto_fire: bool = false


func before_each() -> void:
	_saved_auto_fire = SettingsManager.auto_fire
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each() -> void:
	SettingsManager.auto_fire = _saved_auto_fire
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _make_hull(player: bool) -> ShipController:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	var ai := ship.get_node_or_null("EnemyAI")
	if ai:
		ship.remove_child(ai)
		ai.free()
	if player:
		ship.remove_from_group("enemy_ship")
		ship.add_to_group("player_ship")
	_scene.add_child(ship)
	return ship


func test_the_auto_fire_export_default_is_still_true_for_ai_hulls() -> void:
	# The regression guard for the rebalance-in-disguise. An AI hull that never
	# touches the setting must come up armed exactly as it did pre-M25.
	var enemy := _make_hull(false)
	var combat = enemy.get_node("ShipCombat")
	assert_true(
		combat.auto_fire_enabled,
		"An AI hull lost its auto-fire. EnemyAI only fires deliberately on its attack run "
		+ "(EnemyAI.gd:378) and relies on auto-fire otherwise, so this would silently cut "
		+ "enemy damage output across the whole game."
	)


func test_the_player_hull_is_manual_by_default() -> void:
	SettingsManager.auto_fire = false
	var player := _make_hull(true)
	await wait_process_frames(1)
	var combat = player.get_node("ShipCombat")
	assert_false(combat.auto_fire_enabled,
		"The player's guns must not fire themselves — firing is the player's action now")


func test_the_accessibility_setting_arms_the_player_hull() -> void:
	SettingsManager.auto_fire = true
	var player := _make_hull(true)
	await wait_process_frames(1)
	var combat = player.get_node("ShipCombat")
	assert_true(combat.auto_fire_enabled,
		"Turning the accessibility setting on must restore the pre-M25 behaviour")


func test_the_setting_applies_live_to_a_ship_already_at_sea() -> void:
	# A player toggling this mid-battle should see it immediately, not on the next
	# ship swap.
	SettingsManager.auto_fire = false
	var player := _make_hull(true)
	await wait_process_frames(1)
	var combat = player.get_node("ShipCombat")
	assert_false(combat.auto_fire_enabled)

	SettingsManager.auto_fire = true
	await wait_process_frames(1)
	assert_true(combat.auto_fire_enabled,
		"Toggling the setting must reach a hull that is already in the world")


func test_the_setting_round_trips_through_config() -> void:
	SettingsManager.auto_fire = true
	SettingsManager.save_settings()
	SettingsManager.auto_fire = false
	SettingsManager.load_settings()
	assert_true(SettingsManager.auto_fire, "auto_fire must persist across a save/load")


func test_manual_fire_still_exists_as_a_public_api() -> void:
	var player := _make_hull(true)
	var combat = player.get_node("ShipCombat")
	assert_true(combat.has_method("fire_broadside"),
		"fire_broadside() is what the FIRE button calls — it must stay public")
	assert_true(player.has_method("fire_cannons"),
		"WorldManager routes the fire_port/fire_starboard actions through this")


func test_the_fire_input_actions_exist() -> void:
	# The buttons are useless without the actions behind them.
	assert_true(InputMap.has_action("fire_port"), "fire_port action must exist")
	assert_true(InputMap.has_action("fire_starboard"), "fire_starboard action must exist")
