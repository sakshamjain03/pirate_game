class_name IncomingWindupTracker extends RefCounted

## Purpose: knows which hostile broadsides are winding up at ONE hull right now
## and how long each has left (M30 W1-1.3, task 1.6). Brace is only offered
## "during a wind-up that covers" the player, and a Perfect Brace is a press in
## the last BraceData.perfect_window of one, so both need this.
## Responsibilities: connect hostile hulls' ShipCombat.broadside_windup /
##   broadside_windup_cancelled signals, keep the wind-ups whose target is
##   `target`, count them down, answer has_threat()/soonest_remaining().
## Owner: WorldManager (one instance, ticked from its _physics_process).
## Limitations: read-only — never changes when or whether anyone fires.
## ThreatDecals keeps its own list because it draws every wind-up, not just the
## ones aimed at the player, and is presentation-only.

const HOSTILE_GROUPS: Array[String] = ["enemy_ship", "boss_ship"]

## The hull being threatened (the player's ship).
var target: Node = null

var _watched: Dictionary = {}   # ShipCombat instance id -> true
var _windups: Dictionary = {}   # "<combat id>:<side>" -> seconds left


## Connects one hull's wind-up signals. Returns false when it has no ShipCombat
## carrying them.
func watch(ship: Node) -> bool:
	if not is_instance_valid(ship):
		return false
	var combat := ship.get_node_or_null("ShipCombat")
	if not combat or not combat.has_signal("broadside_windup") \
			or not combat.has_signal("broadside_windup_cancelled"):
		return false
	var id := combat.get_instance_id()
	if _watched.has(id):
		return true
	_watched[id] = true
	combat.broadside_windup.connect(_on_windup.bind(id))
	combat.broadside_windup_cancelled.connect(_on_cancelled.bind(id))
	return true


## Picks up hostile hulls spawned since the last scan, and forgets freed ones.
func scan(tree: SceneTree) -> void:
	if not tree:
		return
	for id in _watched.keys():
		if not is_instance_id_valid(id):
			_watched.erase(id)
	for group in HOSTILE_GROUPS:
		for node in tree.get_nodes_in_group(group):
			watch(node)


func tick(delta: float) -> void:
	for key in _windups.keys():
		var id := int(str(key).get_slice(":", 0))
		_windups[key] -= delta
		if _windups[key] < 0.0 or not is_instance_id_valid(id):
			_windups.erase(key)


func has_threat() -> bool:
	return not _windups.is_empty()


## Seconds until the soonest wind-up aimed at `target` fires; INF when none.
func soonest_remaining() -> float:
	var best := INF
	for t in _windups.values():
		best = minf(best, float(t))
	return best


func clear() -> void:
	_windups.clear()


func _on_windup(side: String, duration: float, aimed_at: Node3D, combat_id: int) -> void:
	if target == null or aimed_at != target:
		return
	_windups["%d:%s" % [combat_id, side]] = duration


func _on_cancelled(side: String, combat_id: int) -> void:
	_windups.erase("%d:%s" % [combat_id, side])
