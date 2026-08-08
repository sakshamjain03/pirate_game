class_name EnvironmentController extends Node3D

## Purpose: Controls the world environment (sky, lighting, day/night cycle).
## Responsibilities: Updates DirectionalLight3D rotation/color, the sky
##                   background colors, and ambient light energy based on
##                   time of day.
## Dependencies: DirectionalLight3D child, WorldEnvironment child, EnvironmentSettings resource

@export var day_length_seconds: float = 600.0 # 10 minutes per day
@export var current_time: float = 0.45 # Start near noon — bright and vibrant
@export var settings: EnvironmentSettings

# DirectionalLight3D and WorldEnvironment are siblings within the Environment node
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment

# Authored compass heading of the sun (captured from the scene once, in
# radians) so the day/night cycle only ever drives elevation. Writing
# rotation.x directly on the light every frame round-trips through Euler
# decomposition, which is gimbal-locked right at the noon/midnight poles
# (elevation == +-90 deg) — the authored yaw could drift or flip there.
# Composing an explicit basis from a fixed yaw + the live elevation avoids
# that entirely.
var _sun_yaw: float = 0.0

func _ready() -> void:
	if not settings:
		push_warning("EnvironmentController: No EnvironmentSettings resource — using defaults.")
		settings = EnvironmentSettings.new()
	if directional_light:
		_sun_yaw = directional_light.rotation.y
	_update_lighting()

func _process(delta: float) -> void:
	# Advance time
	current_time += delta / day_length_seconds
	if current_time >= 1.0:
		current_time -= 1.0

	_update_lighting()

func _update_lighting() -> void:
	if not directional_light or not settings:
		return

	# 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
	# Wrapped to [-PI, PI]: current_time wraps from ~1.0 back to ~0.0 every day
	# cycle, and an unwrapped angle would jump by a full 2*PI at that instant
	# even though the light's actual orientation is unchanged.
	#
	# `angle` is the sun's elevation, expressed as the light's pitch about
	# its local X axis: 0 = horizon, -PI/2 = straight overhead (noon),
	# +PI/2 = straight below the ground (midnight). At current_time = 0.5
	# this evaluates to -PI/2, so the sun is directly overhead at noon and
	# below the horizon at 0.0/1.0, as the segment comments below assume.
	var angle = wrapf(PI / 2.0 - current_time * PI * 2.0, -PI, PI)
	directional_light.transform.basis = Basis(Vector3.UP, _sun_yaw) * Basis(Vector3.RIGHT, angle)

	var seg: int
	var t: float
	if current_time < 0.25: # Midnight to morning
		seg = 0
		t = current_time / 0.25
	elif current_time < 0.5: # Morning to noon
		seg = 1
		t = (current_time - 0.25) / 0.25
	elif current_time < 0.75: # Noon to evening
		seg = 2
		t = (current_time - 0.5) / 0.25
	else: # Evening to midnight
		seg = 3
		t = (current_time - 0.75) / 0.25

	directional_light.light_color = _lerp_color(seg, t,
		settings.sun_color_night, settings.sun_color_morning,
		settings.sun_color_noon, settings.sun_color_evening)
	directional_light.light_energy = _lerp_float(seg, t, 0.3, 0.9, 1.3, 0.9)

	# The sky background and ambient light don't follow the sun on their own —
	# without driving them here the sky stays a static bright-day gradient
	# even at midnight.
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_energy = _lerp_float(seg, t,
			settings.ambient_energy_night, settings.ambient_energy_morning,
			settings.ambient_energy_noon, settings.ambient_energy_evening)

		var horizon := _lerp_color(seg, t,
			settings.sky_horizon_night, settings.sky_horizon_morning,
			settings.sky_horizon_noon, settings.sky_horizon_evening)

		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
			sky_mat.sky_top_color = _lerp_color(seg, t,
				settings.sky_top_night, settings.sky_top_morning,
				settings.sky_top_noon, settings.sky_top_evening)
			sky_mat.sky_horizon_color = horizon
			# The ground half of the procedural sky is what shows below the
			# horizon line; leaving it authored while the sky half animates
			# made the two disagree at every time except the one it was
			# authored for.
			sky_mat.ground_horizon_color = horizon

		# Fog was the actual cause of the "permanent sunset" — it was authored
		# warm orange and nothing ever updated it, so it tinted the whole
		# distance regardless of time of day, even after the sky colours were
		# corrected. Tying it to the horizon colour keeps the two consistent.
		env.fog_light_color = horizon

func _lerp_color(seg: int, t: float, night: Color, morning: Color, noon: Color, evening: Color) -> Color:
	match seg:
		0: return night.lerp(morning, t)
		1: return morning.lerp(noon, t)
		2: return noon.lerp(evening, t)
		_: return evening.lerp(night, t)

func _lerp_float(seg: int, t: float, night: float, morning: float, noon: float, evening: float) -> float:
	match seg:
		0: return lerp(night, morning, t)
		1: return lerp(morning, noon, t)
		2: return lerp(noon, evening, t)
		_: return lerp(evening, night, t)
