extends Node

## DEBUG HARNESS — not part of the game.
##
## Stages an M30 W2 boarding (task 2.5) with zero player input so BoardingCaptureHarness.tscn
## can screenshot it headful: GUT's dummy renderer cannot show that the overlay and the
## preview strip actually draw. It writes its own PNGs (the standard ScreenshotCapture counts
## `_process` frames, which stop when the overlay pauses the tree) and quits when done.
##
##   --capture-dir=<abs path>   where the PNGs go (required)
##   --mobile                   force the phone layout, as BraceCaptureStage does
##
## Frames written:
##   1_preview_strip   a crippled enemy within boarding range: the "Board" prompt is up and
##                     its health bar carries the deck preview line
##   2_overlay_open    the Three Bells overlay at bell 1, nothing queued
##   3_overlay_orders  two orders queued (a strike and a parry), damage shown on the tiles
##   4_overlay_bell    after the bell rang: the log lists what happened
##   5_overlay_result  the Colours taken: the result screen
##   6_prize_ledger    Continue pressed: the Prize Ledger (Keep / Ransom / Break)
## Nothing here sets HUD state directly; the stage only does what the Board verb does
## (BoardingSystem.begin_boarding) and presses the overlay's own public buttons.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
## Ahead of the camera and a little to its right, inside boarding range (12) of the player.
const ENEMY_AHEAD := 8.5
const ENEMY_RIGHT := 3.5
const SETTLE_FRAMES := 90

var _player: Node3D
var _enemy: Node3D
var _boarding: BoardingSystem
var _overlay: BoardingOverlay
var _dir := ""
var _mobile := false
## Staging is finished: stop closing "startup modals" (the Prize Ledger is a real one).
var _staged := false


func _enter_tree() -> void:
	_mobile = "--mobile" in OS.get_cmdline_args() or "--mobile" in OS.get_cmdline_user_args()
	if _mobile:
		PirateThemeBuilder.force_mobile_scaling_for_test = true
		var hud = get_tree().root.find_child("WorldHUD", true, false)
		if hud and "force_mobile_utility_menu" in hud:
			hud.force_mobile_utility_menu = true


func _ready() -> void:
	# Runs through the paused tree: the overlay pauses it, and so does a startup modal.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_args():
		if a.begins_with("--capture-dir="):
			_dir = a.trim_prefix("--capture-dir=")
	if _dir.is_empty():
		push_warning("BoardingCaptureStage: no --capture-dir, nothing to do")
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	await _run()
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
		_dismiss_startup_modal()


func _run() -> void:
	await _frames(3)
	_player = get_tree().get_first_node_in_group("player_ship") as Node3D
	_boarding = get_tree().root.find_child("BoardingSystem", true, false) as BoardingSystem
	if not _player or not _boarding:
		push_warning("BoardingCaptureStage: no player_ship or BoardingSystem")
		return
	_clear_other_hulls()
	_stage_enemy()
	# The player keeps sailing; hold the enemy at the same offset from it so the frame is the
	# same on every run.
	for _i in SETTLE_FRAMES:
		_pin_enemy()
		await _frames(1)
	_hide_dialogue()
	# The strip is drawn on a real EnemyHealthBarWidget bound to the staged hull and fed the real
	# deck summary, on a layer of its own at a fixed spot. (Riding the HUD's world-projected bar
	# made the frame depend on where the camera happened to be; the HUD's own routing of
	# deck_preview_changed to the bar is pinned in test_m30_boarding_hud_wiring.gd.)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var widget := preload("res://scenes/ui/EnemyHealthBarWidget.tscn").instantiate() as EnemyHealthBarWidget
	layer.add_child(widget)
	widget.size = widget.custom_minimum_size
	widget.position = Vector2(700.0, 230.0)
	widget.bind(_enemy)
	widget.set_boarding_preview(_boarding.preview_for(_enemy))
	await _frames(3)
	await _capture("1_preview_strip")
	layer.queue_free()  # the standalone strip has done its job; keep it out of the overlay frames

	# The Board verb. The overwhelm ratio is raised in memory so the stage cannot be routed
	# down the instant path by whatever crew the saved game happens to have.
	SettingsManager.quick_boarding = false
	_boarding.boarding_data.overwhelm_ratio = 1000.0
	_boarding._eligible_enemy = _enemy
	var began := _boarding.begin_boarding()
	print("[boarding-capture] begin_boarding -> %s" % began)
	_overlay = get_tree().root.find_child("BoardingOverlay", true, false) as BoardingOverlay
	if not began or _overlay == null or not _overlay.is_open:
		push_warning("BoardingCaptureStage: the overlay did not open")
		return
	await _frames(3)
	await _capture("2_overlay_open")

	var b := _overlay.battle
	var here := b.defenders_in(b.zone)
	if not here.is_empty():
		_overlay.tap_defender(here[0].uid)
		var parry: BoardingActionData
		for a in _boarding.boarding_data.actions:
			if a.id == &"parry":
				parry = a
		if here.size() > 1 and parry:
			_overlay.select_action(parry)
			_overlay.tap_defender(here[1].uid)
	await _frames(3)
	await _capture("3_overlay_orders")

	_overlay.ring()
	await _frames(3)
	await _capture("4_overlay_bell")
	print("[boarding-capture] bell=%d morale=%d party=%d/%d over=%s" % [
		b.bell, b.morale, b.player_hp, b.player_hp_start, b.is_over()])

	# Take the Colours (clear the deck and stand the party on the quarterdeck), then show the
	# result screen and the Prize Ledger that follows it.
	_staged = true
	b.defenders.clear()
	b.outside_threats.clear()
	b.zone = BoardingZone.Id.QUARTERDECK
	_overlay.ring()
	await _frames(3)
	await _capture("5_overlay_result")
	_overlay.finish()
	await _frames(3)
	await _capture("6_prize_ledger")


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := _dir.path_join("%s.png" % label)
		print("[boarding-capture] %s -> %s" % [label, "ok" if img.save_png(path) == OK else "SAVE FAILED"])


## Ambient hulls would pick their own fights and steal the Board prompt. Remove them and stop
## new ones, so the frame shows the staged boarding and nothing else.
func _clear_other_hulls() -> void:
	var mgr = get_tree().get_first_node_in_group("encounter_manager")
	if mgr and "ambient_enabled" in mgr:
		mgr.ambient_enabled = false
	for h in get_tree().get_nodes_in_group("enemy_ship"):
		h.queue_free()


func _pin_enemy() -> void:
	if not is_instance_valid(_enemy) or not is_instance_valid(_player):
		return
	# Placed by the CAMERA's heading, not the hull's: the rig does not necessarily look along
	# the ship's forward axis, and an enemy behind it has no health bar to show.
	var cam := get_viewport().get_camera_3d()
	var look := -cam.global_transform.basis.z if cam else Vector3.FORWARD
	look = Vector3(look.x, 0.0, look.z).normalized()
	var right := Vector3.UP.cross(-look).normalized()
	_enemy.global_position = _player.global_position + look * ENEMY_AHEAD + right * ENEMY_RIGHT
	_enemy.global_rotation.y = _player.global_rotation.y + 0.6
	_enemy.linear_velocity = Vector3.ZERO
	_enemy.angular_velocity = Vector3.ZERO


func _stage_enemy() -> void:
	_enemy = ENEMY_SHIP.instantiate()
	_player.get_parent().add_child(_enemy)
	_enemy.freeze = true
	_pin_enemy()
	var ai = _enemy.get_node_or_null("EnemyAI")
	if ai:
		ai.set_physics_process(false)
		ai.set_process(false)
	var combat = _enemy.get_node_or_null("ShipCombat")
	if combat:
		combat.auto_fire_enabled = false
	var player_combat = _player.get_node_or_null("ShipCombat")
	if player_combat:
		player_combat.auto_fire_enabled = false
	# Crippled and part-manned, so it is boardable and the deck is a real mix.
	var dmg = _enemy.get_node_or_null("ShipDamage")
	if dmg and dmg.ship_stats:
		dmg.hull = dmg.get_effective_max_health() * 0.2 if dmg.has_method("get_effective_max_health") \
				else dmg.ship_stats.max_health * 0.2
		dmg.crew = dmg.ship_stats.max_crew * 0.8
	var pdmg = _player.get_node_or_null("ShipDamage")
	if pdmg and pdmg.ship_stats:
		pdmg.crew = pdmg.ship_stats.max_crew
	# Hits the way the player's gunnery would have logged them: a grape volley and a stern rake.
	var log: Array = [PackedStringArray(["ammo:grape", "facing:beam"]), PackedStringArray(["ammo:round", "facing:stern"])]
	_enemy.set_meta(BoardingSystem.HIT_LOG_META, log)


func _hide_dialogue() -> void:
	# The opening-chapter dialogue would cover the frame; it is not under test.
	var dlg = get_tree().root.find_child("TutorialDialogue", true, false)
	if dlg and dlg is CanvasItem:
		dlg.visible = false


func _dismiss_startup_modal() -> void:
	if _staged or not get_tree().paused or (_overlay != null and _overlay.is_open):
		return
	for n in get_tree().root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.process_mode == Node.PROCESS_MODE_ALWAYS \
				and c.get_parent() is CanvasLayer and not c is BaseButton:
			print("[boarding-capture] closing startup modal %s" % c.get_path())
			c.visible = false
	get_tree().paused = false
