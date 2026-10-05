class_name ThreatDecals extends Control

## Purpose: makes an enemy broadside readable BEFORE it lands (M30 W1-1.2,
## task 1.5). While a hostile hull winds up a broadside
## (`ShipCombat.broadside_windup`) a wedge is drawn on the water out of the side
## about to fire, tinted by that hull's loaded ammo; if the hull is off-screen a
## screen-rim arrow points at it instead of leaving the player to guess.
## Responsibilities: watch hostile hulls' wind-up signal, keep a short list of
##   live threats, show at most `config.max_visible` of them ranked soonest-to-fire
##   then nearest, and own the wedge/arrow nodes for them.
## Dependencies: ShipCombat.broadside_windup (connected defensively with
##   has_signal — the signal arrives with the gunnery lane), FiringSolver (wedge
##   arc/range, optional), WedgeMesh, ThreatDecalsData.
## Limitations: purely presentational; never changes when or whether anyone fires.

const CONFIG_PATH := "res://resources/ui/ThreatDecals.tres"
const HOSTILE_GROUPS: Array[String] = ["enemy_ship", "boss_ship"]

@export var config: ThreatDecalsData
## Off in tests, which call watch_ship()/refresh() themselves.
@export var auto_scan: bool = true

## The hull being threatened. Found from the "player_ship" group when unset.
var player: Node3D
## Camera used for the on/off-screen test; the viewport's camera when unset.
var camera: Camera3D

## instance_id -> {ship, side, remaining, target, wedge, arrow}
var _threats: Dictionary = {}
var _watched: Dictionary = {}   # instance_id -> true
var _visible: Array = []
var _scan_accum: float = INF


func _ready() -> void:
	if not config:
		config = load(CONFIG_PATH) as ThreatDecalsData
	if not config:
		push_error("ThreatDecals: missing %s" % CONFIG_PATH)
		config = ThreatDecalsData.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if auto_scan:
		_scan_accum += delta
		if _scan_accum >= config.scan_interval:
			_scan_accum = 0.0
			_scan_for_hulls()
	refresh(delta)


## Connects one hull's wind-up signal. Returns false when the hull has no
## ShipCombat or that ShipCombat has no `broadside_windup` (pre-gunnery-lane).
func watch_ship(ship: Node3D) -> bool:
	if not is_instance_valid(ship):
		return false
	var combat := ship.get_node_or_null("ShipCombat")
	if not combat or not combat.has_signal("broadside_windup"):
		return false
	var id := ship.get_instance_id()
	if _watched.has(id):
		return true
	_watched[id] = true
	combat.connect("broadside_windup", _on_windup.bind(ship))
	return true


## Bound handler that accepts both the (side, duration) and the requirement's
## (side, duration, target) signal shapes: with two emitted args the bound
## ship lands in `target_or_ship` and `bound_ship` stays null.
func _on_windup(side: String, duration: float, target_or_ship = null, bound_ship = null) -> void:
	var ship: Node3D = bound_ship if bound_ship != null else target_or_ship
	var target: Node = target_or_ship if bound_ship != null else null
	report_windup(ship, side, duration, target)


func report_windup(ship: Node3D, side: String, duration: float, target: Node = null) -> void:
	if not is_instance_valid(ship) or duration <= 0.0:
		return
	if target != null and is_instance_valid(target) and not _is_player_side(target):
		return   # aimed at someone else — not the player's read
	var id := ship.get_instance_id()
	var t: Dictionary = _threats.get(id, {})
	t["ship"] = ship
	t["side"] = side
	t["remaining"] = duration
	_threats[id] = t


func refresh(delta: float) -> void:
	var p := _get_player()
	var ranked: Array = []
	for id in _threats.keys():
		var t: Dictionary = _threats[id]
		var ship = t.get("ship")
		t["remaining"] = float(t["remaining"]) - delta
		if not is_instance_valid(ship) or float(t["remaining"]) <= 0.0 or _is_sinking(ship):
			_drop(id)
			continue
		t["dist_sq"] = (ship.global_position - p.global_position).length_squared() if p else 0.0
		ranked.append(t)
	ranked.sort_custom(_outranks)
	_visible = []
	for i in range(ranked.size()):
		var t: Dictionary = ranked[i]
		var show := i < config.max_visible
		if show:
			_visible.append(t["ship"])
		_draw_threat(t, show)


func get_visible_threats() -> Array:
	return _visible.duplicate()


func get_wedge(ship: Node3D) -> MeshInstance3D:
	if not is_instance_valid(ship):
		return null
	var t: Dictionary = _threats.get(ship.get_instance_id(), {})
	var w = t.get("wedge")
	return w if is_instance_valid(w) else null


func get_rim_arrow(ship: Node3D) -> Polygon2D:
	if not is_instance_valid(ship):
		return null
	var t: Dictionary = _threats.get(ship.get_instance_id(), {})
	var a = t.get("arrow")
	return a if is_instance_valid(a) else null


# ------------------------------------------------------------------ internals

## Soonest to fire first; on an equal fuse, the nearer hull.
static func _outranks(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["remaining"]), float(b["remaining"])):
		return float(a["remaining"]) < float(b["remaining"])
	return float(a["dist_sq"]) < float(b["dist_sq"])


func _draw_threat(t: Dictionary, show: bool) -> void:
	var ship: Node3D = t["ship"]
	var wedge: MeshInstance3D = t.get("wedge")
	var arrow: Polygon2D = t.get("arrow")
	if not show:
		if is_instance_valid(wedge):
			wedge.visible = false
		if is_instance_valid(arrow):
			arrow.visible = false
		return
	var tint := _tint_for(ship)
	if not is_instance_valid(wedge):
		var geo := _arc_and_range(ship)
		wedge = WedgeMesh.make_instance(geo.x, geo.y, tint)
		wedge.name = "ThreatWedge"
		ship.add_child(wedge)   # dies with the hull; top_level keeps it flat
		t["wedge"] = wedge
	var mat := wedge.material_override as StandardMaterial3D
	# Brighter as the volley gets closer — the read is "how soon", not just "where".
	var duration_left: float = clampf(float(t["remaining"]), 0.0, 3.0) / 3.0
	tint.a = lerpf(config.wedge_alpha_max, config.wedge_alpha_min, duration_left)
	mat.albedo_color = tint
	wedge.global_transform = WedgeMesh.flat_transform(ship, str(t["side"]), config.wedge_height)
	wedge.visible = true

	if not is_instance_valid(arrow):
		arrow = _make_arrow()
		add_child(arrow)
		t["arrow"] = arrow
	arrow.color = Color(tint.r, tint.g, tint.b, 1.0)
	_place_rim_arrow(arrow, ship)


func _place_rim_arrow(arrow: Polygon2D, ship: Node3D) -> void:
	var cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	if not cam:
		arrow.visible = false
		return
	var rect := get_viewport_rect()
	var size := rect.size
	var world := ship.global_position
	var on_screen := false
	if not cam.is_position_behind(world):
		var sp := cam.unproject_position(world)
		on_screen = Rect2(Vector2.ZERO, size).has_point(sp)
	if on_screen:
		arrow.visible = false
		return
	# Direction in camera space -> screen direction (screen y grows downward).
	var local := cam.global_transform.affine_inverse() * world
	var dir := Vector2(local.x, -local.y)
	if local.z > 0.0:
		# Behind the camera: flag it on the bottom edge, keeping its lateral side.
		dir = Vector2(local.x, maxf(absf(local.y), absf(local.z)))
	if dir.length_squared() < 0.0001:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var centre := size * 0.5
	var half := centre - Vector2.ONE * config.rim_margin_px
	half = Vector2(maxf(half.x, 1.0), maxf(half.y, 1.0))
	var k := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	arrow.position = centre + dir * k
	arrow.rotation = dir.angle()
	arrow.visible = true


func _make_arrow() -> Polygon2D:
	var s := config.rim_arrow_size_px
	var poly := Polygon2D.new()
	poly.name = "RimArrow"
	# Points along +X; rotated to the threat's screen direction.
	poly.polygon = PackedVector2Array([Vector2(s, 0), Vector2(-s * 0.6, -s * 0.7), Vector2(-s * 0.6, s * 0.7)])
	poly.visible = false
	return poly


func _arc_and_range(ship: Node3D) -> Vector2:
	var solver := ship.get_node_or_null("FiringSolver") as FiringSolver
	if solver and solver.get_range() > 0.0:
		return Vector2(solver.get_arc_degrees(), solver.get_range())
	return Vector2(config.fallback_arc_degrees, config.fallback_range)


func _tint_for(ship: Node3D) -> Color:
	var combat := ship.get_node_or_null("ShipCombat")
	var ammo = combat.get("current_ammo") if combat else null
	if ammo is AmmoData:
		return config.color_for_ammo(ammo.ammo_id)
	return config.default_color


func _drop(id: int) -> void:
	var t: Dictionary = _threats.get(id, {})
	var wedge = t.get("wedge")
	if is_instance_valid(wedge):
		wedge.queue_free()
	var arrow = t.get("arrow")
	if is_instance_valid(arrow):
		arrow.queue_free()
	_threats.erase(id)


func _scan_for_hulls() -> void:
	if not is_inside_tree():
		return
	for group in HOSTILE_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D and not _watched.has(node.get_instance_id()):
				watch_ship(node)


func _get_player() -> Node3D:
	if is_instance_valid(player):
		return player
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player_ship") as Node3D
	return player if is_instance_valid(player) else null


func _is_player_side(target: Node) -> bool:
	if target == _get_player():
		return true
	return target.is_in_group("player_ship") or target.is_in_group("friendly_ship")


static func _is_sinking(ship: Node3D) -> bool:
	var dmg := ship.get_node_or_null("ShipDamage")
	return dmg != null and dmg.has_method("is_destroyed") and dmg.is_destroyed()
