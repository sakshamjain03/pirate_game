extends Node

## Temporary diagnostic autoload: boots straight into World.tscn (run via
## `godot --path . scenes/world/World.tscn`, NOT --headless since headless
## uses the dummy renderer and produces empty viewport textures) and
## captures a sequence of screenshots at meaningful gameplay checkpoints,
## driving the ship through the real Input singleton so the actual
## InputManager -> WorldManager -> ShipController path is exercised.

const OUT_DIR_ABS := "D:/Pirate-game/screenshots/verify"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR_ABS)

	var tries = 0
	while not get_tree().current_scene and tries < 120:
		await get_tree().process_frame
		tries += 1

	var world = get_tree().current_scene
	if not world:
		print("HARNESS ERROR: no current_scene after wait")
		get_tree().quit()
		return

	var ship = get_tree().get_first_node_in_group("player_ship")
	var world_manager = world.get_node_or_null("Systems/WorldManager")
	var env_controller = world.get_node_or_null("Environment")

	var waited = 0.0
	while world_manager and not world_manager.is_world_loaded and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	print("HARNESS: world_loaded=%s waited=%.2fs" % [str(world_manager.is_world_loaded if world_manager else "no_wm"), waited])

	await _capture("00_spawn")

	await _settle(3.0)
	if ship:
		print("HARNESS: at_rest pos=%s vel=%s sleeping=%s" % [ship.global_position, ship.linear_velocity, ship.sleeping])
	await _capture("01_at_rest")

	Input.action_press("ship_forward")
	await _settle(4.0)
	if ship:
		print("HARNESS: forward pos=%s vel=%s speed=%.2f" % [ship.global_position, ship.linear_velocity, ship.linear_velocity.length()])
	await _capture("02_moving_forward")

	Input.action_press("ship_right")
	await _settle(2.0)
	Input.action_release("ship_right")
	if ship:
		print("HARNESS: turning pos=%s rot=%s" % [ship.global_position, ship.global_rotation])
	await _capture("03_turning")

	Input.action_release("ship_forward")
	await _settle(0.5)

	Input.action_press("fire_port")
	await get_tree().process_frame
	Input.action_release("fire_port")
	await _settle(0.3)
	await _capture("04_cannons_port")

	if env_controller:
		env_controller.current_time = 0.0
		if env_controller.has_method("_update_lighting"):
			env_controller._update_lighting()
	await _settle(0.2)
	await _capture("05_midnight")

	if env_controller:
		env_controller.current_time = 0.75
		if env_controller.has_method("_update_lighting"):
			env_controller._update_lighting()
	await _settle(0.2)
	await _capture("06_sunset")

	print("HARNESS: DONE")
	get_tree().quit()

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		var path = "%s/%s.png" % [OUT_DIR_ABS, label]
		var err = img.save_png(path)
		print("HARNESS: saved %s -> err=%s" % [label, err])
	else:
		print("HARNESS: EMPTY IMAGE for ", label)
