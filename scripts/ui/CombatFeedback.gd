class_name CombatFeedback extends Node

## Purpose: the M30 W1-2.3 feedback pack's wiring (task 1.11) — turns the
## player's combat events into the reads that make good play feel good:
##   - a rake cone on the current target (WedgeMesh off its stern),
##   - ribbons (RibbonStack, capped) for a rake, a kill and a Perfect Brace,
##   - a camera offset punch (CameraRig.punch — h/v_offset, never time_scale)
##     when the player is hit, rakes or sinks a hull,
##   - haptics through HapticFeedbackManager.
## Colour-coded damage numbers are FloatingDamage's own job (ShipCombat passes
## ammo and facing through); nothing here duplicates them.
## Reduced motion: CameraRig.punch() refuses, RibbonStack pops in without
## animation (UIMotion), FloatingDamage fades in place. Haptics follow their own
## Settings toggle (SettingsManager.haptics_enabled), not reduced motion.
## Responsibilities: find and wire the player hull (again if it is ever
##   replaced by a new node), and own the one rake-cone MeshInstance3D.
## Dependencies: ShipCombat (hit_landed, kill_landed, brace_started),
##   ShipDamage.hit_resolved, FiringSolver.get_current_target(), RibbonStack,
##   CameraRig (group "camera_rig"), HapticFeedbackManager, CombatFeedbackData.
## Limitations: presentational only; never changes combat outcomes.

const CONFIG_PATH := "res://resources/ui/CombatFeedback.tres"

@export var config: CombatFeedbackData
## Off in tests, which call wire_player()/refresh() themselves.
@export var auto_scan: bool = true
## The ribbon stack to feed; WorldHUD.tscn points this at its RibbonStack.
@export var ribbons: RibbonStack

var player: Node3D
## The camera rig to punch; found by group "camera_rig" when unset.
var camera_rig: CameraRig

var _rake_cone: MeshInstance3D
var _cone_target: Node3D
var _cone_half_angle: float = -1.0
var _scan_accum: float = INF


func _ready() -> void:
	if not config:
		config = load(CONFIG_PATH) as CombatFeedbackData
	if not config:
		push_error("CombatFeedback: missing %s" % CONFIG_PATH)
		config = CombatFeedbackData.new()
	if not ribbons and get_parent():
		ribbons = get_parent().get_node_or_null("RibbonStack") as RibbonStack


func _process(delta: float) -> void:
	if auto_scan:
		_scan_accum += delta
		if _scan_accum >= config.scan_interval:
			_scan_accum = 0.0
			if not is_instance_valid(player) and is_inside_tree():
				var p := get_tree().get_first_node_in_group("player_ship") as Node3D
				if p:
					wire_player(p)
	refresh()


## Connects the feedback pack to `ship` (the player hull). Idempotent.
func wire_player(ship: Node3D) -> void:
	if not is_instance_valid(ship):
		return
	player = ship
	var combat := ship.get_node_or_null("ShipCombat")
	if combat:
		_connect(combat, "hit_landed", _on_hit_landed)
		_connect(combat, "kill_landed", _on_kill_landed)
		_connect(combat, "brace_started", _on_brace_started)
	var dmg := ship.get_node_or_null("ShipDamage")
	if dmg:
		_connect(dmg, "hit_resolved", _on_player_hit)


func _connect(node: Object, sig: String, handler: Callable) -> void:
	if node.has_signal(sig) and not node.is_connected(sig, handler):
		node.connect(sig, handler)


## Re-places the rake cone on the current target (or hides it).
func refresh() -> void:
	var target := _current_target()
	if not is_instance_valid(target):
		if is_instance_valid(_rake_cone):
			_rake_cone.visible = false
		_cone_target = null
		return
	var half := _rake_half_angle(target)
	if not is_instance_valid(_rake_cone):
		_rake_cone = WedgeMesh.make_instance(half, config.rake_cone_length, config.rake_cone_color)
		_rake_cone.name = "RakeCone"
		add_child(_rake_cone)   # top_level: placed in world space below
		_cone_half_angle = half
	elif not is_equal_approx(half, _cone_half_angle):
		_rake_cone.mesh = WedgeMesh.build(half, config.rake_cone_length)
		_cone_half_angle = half
	_cone_target = target
	_rake_cone.global_transform = WedgeMesh.flat_transform(target, "stern", config.rake_cone_height)
	_rake_cone.visible = true


func get_rake_cone() -> MeshInstance3D:
	return _rake_cone if is_instance_valid(_rake_cone) and _rake_cone.visible else null


func get_rake_cone_target() -> Node3D:
	return _cone_target if is_instance_valid(_cone_target) else null


# ------------------------------------------------------------------ events

func _on_hit_landed(_target: Node, facing: StringName, _deltas: Dictionary, _ammo_id: StringName) -> void:
	if facing != &"stern" and facing != &"bow":
		return
	if ribbons:
		ribbons.add_ribbon("rake", tr("Rake!"))
	HapticFeedbackManager.reward()
	_punch(config.punch_rake)


func _on_kill_landed(_target: Node) -> void:
	if ribbons:
		ribbons.add_ribbon("kill", tr("Sunk!"))
	HapticFeedbackManager.reward()
	_punch(config.punch_kill)


func _on_brace_started(perfect: bool) -> void:
	if perfect:
		if ribbons:
			ribbons.add_ribbon("perfect_brace", tr("Perfect Brace!"))
		HapticFeedbackManager.ready()
	else:
		HapticFeedbackManager.tap()


func _on_player_hit(_source: Node, _facing: StringName, pool_deltas: Dictionary,
		_ammo_id: StringName, _hit_tags: PackedStringArray) -> void:
	var total := 0.0
	for pool in pool_deltas:
		total += float(pool_deltas[pool])
	if total <= 0.0:
		return
	HapticFeedbackManager.damage()
	_punch(config.punch_hit_taken)


func _punch(strength: float) -> bool:
	var rig := _get_camera_rig()
	if not rig:
		return false
	return rig.punch(strength, config.punch_duration, config.punch_max)


# ------------------------------------------------------------------ internals

func _current_target() -> Node3D:
	if not is_instance_valid(player):
		return null
	var solver := player.get_node_or_null("FiringSolver") as FiringSolver
	return solver.get_current_target() if solver else null


func _rake_half_angle(target: Node3D) -> float:
	var stats = target.get("ship_stats")
	if stats is ShipStats and stats.stern_arc_degrees > 0.0:
		return stats.stern_arc_degrees * 0.5
	return config.rake_cone_fallback_half_angle


func _get_camera_rig() -> CameraRig:
	if is_instance_valid(camera_rig):
		return camera_rig
	if is_inside_tree():
		camera_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig
	return camera_rig if is_instance_valid(camera_rig) else null
