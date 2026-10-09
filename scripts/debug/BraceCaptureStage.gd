extends Node

## DEBUG HARNESS — not part of the game.
##
## Stages an M30 W1 Brace prompt (task 1.6) with zero player input so
## BraceCaptureHarness.tscn can screenshot it headful. GUT's dummy renderer
## cannot show that the call-out actually draws.
##   - An enemy hull sits on the player's starboard bow. Its REAL ShipCombat
##     re-emits `broadside_windup(side, WINDUP_SECONDS, player)` every
##     REEMIT_SECONDS. That is the same signal the auto-fire wind-up gate emits.
##     WorldManager's IncomingWindupTracker therefore reports a threat, the
##     context arbiter picks `brace`, and ThreatDecals draws the wedge. Nothing
##     here sets the verb or the HUD directly.
##   - Desktop (default): WorldHUD's "[key] BRACE!" label.
##   - `--mobile`: forces the phone layout (PirateThemeBuilder's shared test
##     static, as UIScreenSweep's phone profile does), so MobileControls'
##     context button shows "Brace".
## The enemy never fires: auto-fire is off and its AI is paused.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
## Player-local: forward-starboard, so the camera (astern of the player) frames
## it, and outside the stern cone so Keg is not a competing verb.
const ENEMY_OFFSET := Vector3(26.0, 0.0, -28.0)
## Longer than BraceData.perfect_window, so the staged prompt is a plain one.
const WINDUP_SECONDS := 2.0
const REEMIT_SECONDS := 0.5

var _player: Node3D
var _enemy: Node3D
var _reemit_t: float = 0.0
var _mobile := false
var _last_verb: StringName = &"?"


func _enter_tree() -> void:
	# Runs after World's subtree has entered the tree and before any of its
	# _ready calls, so MobileControls/WorldHUD build their phone layout.
	_mobile = "--mobile" in OS.get_cmdline_args() or "--mobile" in OS.get_cmdline_user_args()
	if _mobile:
		PirateThemeBuilder.force_mobile_scaling_for_test = true
		var hud = get_tree().root.find_child("WorldHUD", true, false)
		if hud and "force_mobile_utility_menu" in hud:
			hud.force_mobile_utility_menu = true


func _ready() -> void:
	# A startup modal (offline-earnings offer, raid report...) pauses the tree
	# when the user:// save is old; it is not under test and would freeze the
	# stage and the screenshot clock, so this node keeps running to close it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player_ship") as Node3D
	if not _player:
		push_warning("BraceCaptureStage: no player_ship")
		set_process(false)
		return
	_stage_enemy()
	print("[brace-capture] staged (mobile=%s)" % _mobile)


func _process(delta: float) -> void:
	_dismiss_startup_modal()
	if not is_instance_valid(_enemy) or not is_instance_valid(_player):
		return
	# The opening-chapter dialogue would cover the frame; it is not under test.
	var dlg = get_tree().root.find_child("TutorialDialogue", true, false)
	if dlg and dlg is CanvasItem:
		dlg.visible = false
	_reemit_t -= delta
	if _reemit_t > 0.0:
		return
	_reemit_t = REEMIT_SECONDS
	var combat = _enemy.get_node_or_null("ShipCombat")
	if not combat:
		return
	var to_player: Vector3 = _player.global_position - _enemy.global_position
	var side := "starboard" if to_player.dot(_enemy.global_transform.basis.x) >= 0.0 else "port"
	combat.broadside_windup.emit(side, WINDUP_SECONDS, _player)
	var wm = get_tree().get_first_node_in_group("world_manager")
	if wm and wm.has_method("get_context_verb") and wm.get_context_verb() != _last_verb:
		_last_verb = wm.get_context_verb()
		print("[brace-capture] context verb = %s" % _last_verb)


func _dismiss_startup_modal() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "Control", true, false):
		var c := n as Control
		# Buttons (e.g. MobileControls' BtnPause) also run while paused; leave them.
		if c.is_visible_in_tree() and c.process_mode == Node.PROCESS_MODE_ALWAYS \
				and c.get_parent() is CanvasLayer and not c is BaseButton:
			print("[brace-capture] closing startup modal %s (%s)" % [c.name, c.get_path()])
			c.visible = false
	get_tree().paused = false


func _stage_enemy() -> void:
	_enemy = ENEMY_SHIP.instantiate()
	_player.get_parent().add_child(_enemy)
	_enemy.global_position = _player.global_position + _player.global_transform.basis * ENEMY_OFFSET
	_enemy.global_rotation.y = _player.global_rotation.y
	var ai = _enemy.get_node_or_null("EnemyAI")
	if ai:
		ai.set_physics_process(false)
		ai.set_process(false)
	var combat = _enemy.get_node_or_null("ShipCombat")
	if combat:
		combat.auto_fire_enabled = false   # the staged wind-up never fires
	var player_combat = _player.get_node_or_null("ShipCombat")
	if player_combat:
		player_combat.auto_fire_enabled = false   # keep the frame readable
