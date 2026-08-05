## AutoScreenshotter.gd
extends SceneTree

func _init() -> void:
	print("=== AutoScreenshotter: Starting Visual Capture ===")
	
	var scenes_to_capture = {
		"D:/Pirate-game/screenshot_world.png": "res://scenes/world/World.tscn",
		"D:/Pirate-game/screenshot_playership.png": "res://scenes/world/PlayerShip.tscn",
		"D:/Pirate-game/screenshot_cannonball.png": "res://scenes/combat/Cannonball.tscn",
		"D:/Pirate-game/screenshot_worldhud.png": "res://scenes/ui/WorldHUD.tscn"
	}
	
	for path in scenes_to_capture.keys():
		var scene_res = scenes_to_capture[path]
		var scene = load(scene_res)
		if scene:
			var instance = scene.instantiate()
			if instance is Node3D:
				var cameras = instance.find_children("*", "Camera3D", false, false)
				var has_camera = cameras.size() > 0
				if not has_camera:
					var cam = Camera3D.new()
					cam.position = Vector3(15, 12, 15)
					cam.look_at(Vector3(0, 2, 0))
					cam.current = true
					instance.add_child(cam)
					
					# Add lighting for isolated 3D models so they aren't black
					var light = DirectionalLight3D.new()
					light.rotation_degrees = Vector3(-45, 45, 0)
					instance.add_child(light)
					
					var env = WorldEnvironment.new()
					var res = Environment.new()
					res.background_mode = Environment.BG_COLOR
					res.background_color = Color(0.2, 0.6, 0.8)
					res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					res.ambient_light_color = Color(1.0, 1.0, 1.0)
					env.environment = res
					instance.add_child(env)
			
			root.add_child(instance)
			
			# Ensure engine has time to initialize and render the frame
			for i in range(5):
				await process_frame
			
			var img = root.get_viewport().get_texture().get_image()
			if img.is_empty():
				print("ERROR: Image is empty for ", path)
			else:
				var err = img.save_png(path)
				if err == OK:
					print("SUCCESS: Screenshot saved to ", path, " (Size: ", img.get_size(), ")")
				else:
					print("ERROR: Failed to save ", path, " code: ", err)
				
			instance.queue_free()
			for i in range(2):
				await process_frame
		else:
			print("ERROR: Failed to load ", scene_res)
			
	print("=== AutoScreenshotter: Complete ===")
	quit()
