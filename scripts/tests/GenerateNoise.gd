extends SceneTree

func _init():
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	
	# Wait for texture to generate
	await create_timer(1.0).timeout
	
	ResourceSaver.save(tex, "res://resources/shaders/wave_noise.tres")
	print("Generated wave_noise.tres")
	quit()
