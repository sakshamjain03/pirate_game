class_name EnvironmentController extends Node3D

## Purpose: Controls the world environment (sky, lighting, day/night cycle, per-region weather).
## Responsibilities: Updates DirectionalLight3D rotation/color, the sky
##                   background colors, and ambient light energy based on
##                   time of day. Monitors player position and applies per-region
##                   weather modifiers to OceanController (M10 Requirement 5).
## Dependencies: DirectionalLight3D child, WorldEnvironment child, EnvironmentSettings resource,
##               OceanController (optional — weather modifiers only apply if present)

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

## M10 Requirement 5 — per-region weather tracking.
var _ocean_controller: OceanController = null
var _current_region: RegionData = null
var _region_check_timer: float = 0.0
var _region_check_interval: float = 1.0  ## Check player region every second, not every frame.
var _player_ship: Node3D = null
## Cached as plain floats, NOT a reference to ocean_settings itself — that
## Resource is shared (the same object OceanController/WaveGenerator both
## read), so aliasing it here would mean the first region's multiplier
## permanently overwrites what "base" means, and the second region change
## would compound on top of the first instead of applying fresh each time.
var _base_wave_height: float = 0.0
var _base_wave_speed: float = 0.0

func _ready() -> void:
	if not settings:
		push_warning("EnvironmentController: No EnvironmentSettings resource — using defaults.")
		settings = EnvironmentSettings.new()
	if directional_light:
		_sun_yaw = directional_light.rotation.y

	## M11 — discoverable so ShipMovement (every ship, not just the player) can
	## read the current region's wind without each ship repeating its own
	## nearest-island lookup every physics frame.
	add_to_group("environment_controller")

	## Find OceanController in the scene (typically a sibling of World).
	_ocean_controller = get_tree().get_first_node_in_group("ocean_controller")
	if not _ocean_controller:
		_ocean_controller = get_tree().current_scene.find_child("OceanController", true, false)

	if _ocean_controller and _ocean_controller.ocean_settings:
		_base_wave_height = _ocean_controller.ocean_settings.wave_height
		_base_wave_speed = _ocean_controller.ocean_settings.wave_speed

	_update_lighting()

func _process(delta: float) -> void:
	# Advance time
	current_time += delta / day_length_seconds
	if current_time >= 1.0:
		current_time -= 1.0

	_update_lighting()

	## M10 Requirement 5 — check for region changes and apply weather modifiers.
	if _ocean_controller and _ocean_controller.ocean_settings:
		_region_check_timer += delta
		if _region_check_timer >= _region_check_interval:
			_region_check_timer = 0.0
			_update_region_weather()

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
	directional_light.light_energy = _lerp_float(seg, t,
		settings.sun_energy_night, settings.sun_energy_morning,
		settings.sun_energy_noon, settings.sun_energy_evening)

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

func _update_region_weather() -> void:
	## Check the player's current region and apply weather modifiers to
	## OceanController. Reuses the nearest-island pattern EnemySpawner
	## already established rather than a second lookup mechanism.
	if not _player_ship:
		_player_ship = get_tree().get_first_node_in_group("player_ship")
	if not _player_ship:
		return

	var region = _get_player_region()
	if not region or region == _current_region:
		return  ## No change in region.

	_current_region = region
	_apply_region_weather_modifiers()

## M11 — read-only access to the player's current region for systems (wind)
## that don't otherwise need the full weather-update machinery above.
func get_current_region() -> RegionData:
	return _current_region

func _get_player_region() -> RegionData:
	## Find the region of the closest island to the player. Mirrors
	## EnemySpawner._get_region_for_position()'s pattern.
	if not _player_ship:
		return null

	var islands = get_tree().get_nodes_in_group("islands")
	if islands.is_empty():
		return null

	var closest_island = null
	var min_dist = INF
	for island in islands:
		var d = island.global_position.distance_to(_player_ship.global_position)
		if d < min_dist:
			min_dist = d
			closest_island = island

	if closest_island and EmpireManager:
		return EmpireManager.get_region_for_island(closest_island.get_island_id())

	return null

func _apply_region_weather_modifiers() -> void:
	## Apply the current region's weather modifiers to OceanController
	## settings, always computed fresh from the cached pristine base values
	## (never from whatever the shared OceanSettings resource currently
	## holds) so successive region changes don't compound.
	if not _ocean_controller or not _current_region:
		return
	if not _ocean_controller.ocean_settings:
		return

	var ocean_settings := _ocean_controller.ocean_settings
	ocean_settings.wave_height = _base_wave_height * _current_region.wave_intensity_multiplier
	ocean_settings.wave_speed = _base_wave_speed * _current_region.wave_intensity_multiplier

	# fog_density_multiplier has no direct OceanSettings/shader parameter to
	# drive yet (the water shader's fog is horizon-color tinting, not a
	# density value) — authored and available on RegionData for whichever
	# future fog work reads it, not applied here.

	_ocean_controller._apply_settings()
