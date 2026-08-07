extends GutTest

# Property-based tests for Ocean and Environment.

const WaveGeneratorClass = preload("res://scripts/world/WaveGenerator.gd")
const ShipVisualsClass = preload("res://scripts/world/ShipVisuals.gd")
const ShipControllerClass = preload("res://scripts/world/ShipController.gd")
const EnvironmentControllerClass = preload("res://scripts/world/EnvironmentController.gd")
const OceanControllerClass = preload("res://scripts/world/OceanController.gd")

# Property 19: Wave Animation Continuity
func test_property_19_wave_animation_continuity():
	var passed = true
	var iterations = 25
	
	for i in range(iterations):
		var generator = WaveGeneratorClass.new()
		generator.ocean_settings = OceanSettings.new()
		generator.ocean_settings.wave_height = randf_range(0.5, 5.0)
		generator.ocean_settings.wave_length = randf_range(10.0, 50.0)
		generator.ocean_settings.wave_speed = randf_range(0.5, 3.0)
		
		var pos = Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
		var time = randf_range(0.0, 100.0)
		var dt = randf_range(0.001, 0.033) # Small time delta
		
		var h1 = generator.get_water_height_at(pos, time)
		var h2 = generator.get_water_height_at(pos, time + dt)
		var diff = abs(h2 - h1)
		
		generator.free()
		
		# For small dt, diff should be small
		if diff > 1.0:
			passed = false
			break
			
	assert_true(passed, "Wave heights must update continuously for any time delta")

# Property 20: Wake Trail Correlation
func test_property_20_wake_trail_correlation():
	var passed = true
	var iterations = 25
	
	for i in range(iterations):
		var visuals = ShipVisualsClass.new()
		var controller = ShipControllerClass.new()
		var stats = ShipStats.new()
		stats.max_speed = randf_range(10.0, 50.0)
		controller.ship_stats = stats
		visuals.controller = controller
		
		var wake = GPUParticles3D.new()
		visuals._wake = wake
		
		var speed = randf_range(0.0, stats.max_speed * 1.5)
		visuals._on_speed_changed(speed)
		
		var normalized = clamp(speed / max(stats.max_speed, 0.01), 0.0, 1.0)
		var expected_emitting = normalized > 0.08
		var expected_ratio = normalized
		
		if wake.emitting != expected_emitting or not is_equal_approx(wake.amount_ratio, expected_ratio):
			passed = false
			
		wake.free()
		controller.free()
		visuals.free()
		
		if not passed:
			break
			
	assert_true(passed, "Wake trail size and emission must correlate proportionally with ship speed")

# Property 21: LOD Distance Transitions
func test_property_21_lod_distance_transitions():
	var passed = true
	var iterations = 20
	
	for i in range(iterations):
		var dist = randf_range(10.0, 1000.0)
		
		var ocean = OceanControllerClass.new()
		# There is no explicit LOD distance check in OceanController yet, 
		# so if the method get_lod_level does not exist, the test should fail.
		if not ocean.has_method("get_lod_level"):
			passed = false
			
		ocean.free()
		
		if not passed:
			break
			
	assert_true(passed, "LOD transitions must occur based on defined distance thresholds")

# Property 22: Day/Night Cycle Consistency
func test_property_22_day_night_cycle_consistency():
	var passed = true
	var iterations = 30
	var dt = 0.005 # Small time jump
	
	for i in range(iterations):
		var env = EnvironmentControllerClass.new()
		env.settings = EnvironmentSettings.new()
		env.current_time = randf_range(0.0, 1.0)
		
		var light = DirectionalLight3D.new()
		env.add_child(light)
		env.directional_light = light
		
		env._update_lighting()
		var color1 = light.light_color
		var energy1 = light.light_energy
		var rot1 = light.rotation.x
		
		env.current_time = fmod(env.current_time + dt, 1.0)
		env._update_lighting()
		
		var color2 = light.light_color
		var energy2 = light.light_energy
		var rot2 = light.rotation.x
		
		# Check continuity: difference should be small
		var color_diff = abs(color1.r - color2.r) + abs(color1.g - color2.g) + abs(color1.b - color2.b)
		var energy_diff = abs(energy1 - energy2)
		# rotation.x is wrapped to [-PI, PI], so e.g. PI-0.01 and -PI+0.01 are
		# a small physical rotation apart despite a large raw numeric gap —
		# compare via the wrapped (circular) distance, not the raw difference.
		var rot_diff = abs(wrapf(rot1 - rot2, -PI, PI))
		
		light.free()
		env.free()
		
		if color_diff > 0.1 or energy_diff > 0.1 or rot_diff > 0.1:
			passed = false
			break
			
	assert_true(passed, "Day/night cycle lighting parameters must update continuously without jumps")
