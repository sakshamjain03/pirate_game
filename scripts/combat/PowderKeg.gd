class_name PowderKeg extends StaticBody3D

## Purpose: a droppable powder keg (M30 W1-2.2, task 1.10). It sits on the
## water astern of the player with a visible fuse and blows up when a hostile
## hull comes within `config.proximity_radius` (contact or proximity — one
## distance check covers both), or when the fuse burns out.
## Responsibilities: the fuse, the trigger check and the detonation (through the
##   shared AreaDamage static, the same path MaelstromRun's kegs and the
##   Fireship use). Stock and the drop itself belong to WorldManager's "keg"
##   context verb.
## Collision: a StaticBody3D on layer 6 (bit 32), which no hull, cannonball or
##   camera mask includes, so nothing physically bumps into it. Its only job is
##   to be seen by EnemyAI's obstacle probe on hulls whose AIProfileData adds
##   bit 32 to their avoid mask (the Raker), so they path around kegs.
## Floating: every tick it rides the swell, reading the same WaveGenerator
##   (group "wave_generator") that BuoyancySimulator samples; flat water at
##   y=0 when there is none.
## Dependencies: KegConfigData, AreaDamage, FiringSolver.are_hostile, WaveGenerator.

signal detonated()

const HOSTILE_GROUPS: Array[String] = ["enemy_ship", "boss_ship"]

@export var config: KegConfigData = preload("res://resources/combat/KegConfig.tres")

## The hull that dropped it; hostility is judged against it. When unset (e.g.
## an editor-placed keg) every enemy_ship/boss_ship hull counts as hostile.
var dropped_by: Node3D = null

## The ocean the keg floats on; found by group on _ready when unset.
var wave_generator: WaveGenerator = null

var _fuse_remaining: float = 0.0
var _has_detonated: bool = false


func _ready() -> void:
	add_to_group("powder_kegs")
	if not config:
		push_error("PowderKeg: no KegConfigData")
		config = KegConfigData.new()
	_fuse_remaining = config.fuse_seconds
	if not wave_generator:
		var gens := get_tree().get_nodes_in_group("wave_generator")
		if gens.size() > 0:
			wave_generator = gens[0] as WaveGenerator


func _physics_process(delta: float) -> void:
	tick(delta)


## One fuse/trigger step; public so tests can drive it deterministically.
func tick(delta: float) -> void:
	if _has_detonated:
		return
	float_on_water()
	_fuse_remaining -= delta
	if _fuse_remaining <= 0.0 or _hostile_within(config.proximity_radius).size() > 0:
		detonate()


## Sets the keg's height to the water surface under it (W1-2.2 "a keg SHALL
## float"). Uses the same clock as BuoyancySimulator so it bobs with the hulls.
func float_on_water() -> void:
	if not is_inside_tree():
		return
	var h := 0.0
	if is_instance_valid(wave_generator):
		h = wave_generator.get_water_height_at(global_position, Time.get_ticks_msec() / 1000.0)
	global_position.y = h


func get_fuse_remaining() -> float:
	return _fuse_remaining


func detonate() -> void:
	if _has_detonated:
		return
	_has_detonated = true
	detonated.emit()
	AreaDamage.apply_damage(global_position, config.detonation_radius,
		config.detonation_damage, _hostile_within(config.detonation_radius))
	queue_free()


## Live hostile hulls (enemy_ship + boss_ship, not already sinking) within
## `radius` of the keg, flat distance.
func _hostile_within(radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	var r_sq := radius * radius
	for group in HOSTILE_GROUPS:
		for hull in get_tree().get_nodes_in_group(group):
			if not (hull is Node3D) or out.has(hull):
				continue
			if is_instance_valid(dropped_by) and not FiringSolver.are_hostile(dropped_by, hull):
				continue
			var dmg = hull.get_node_or_null("ShipDamage")
			if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
				continue
			var d: Vector3 = hull.global_position - global_position
			if Vector2(d.x, d.z).length_squared() <= r_sq:
				out.append(hull)
	return out
