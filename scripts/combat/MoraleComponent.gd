class_name MoraleComponent extends Node

## Purpose: an enemy crew's nerve (M30 2.6). Gunnery that kills crew, rakes the hull or sinks
##   the squad leader wears it down; a crew that wavers either runs or strikes its colours.
## Responsibilities:
##   - drains morale from the ship's `ShipDamage.hit_resolved` (crew lost, rakes) and from
##     `notify_leader_sunk()`,
##   - telegraphs WAVERING (`wavering_started`) so the player can see the break coming, then
##     FLEES (ordering the EnemyAI to run) or STRIKES (a struck ship stops firing and can be
##     taken with the Take Prize verb),
##   - never breaks a boss: `can_break` is false for hulls in group `boss_ship`.
## Dependencies: ShipDamage (hit_resolved, sails pool), EnemyAI (order_flee), ShipCombat
##   (auto_fire_enabled), MoraleData.
## Composition: added to enemy hulls by `ShipController._ready()`, like ShipCollisionHandler.

signal morale_changed(value: float)
signal wavering_started(seconds: float)
signal fled
signal struck

enum State { STEADY, WAVERING, FLED, STRUCK }

@export var data: MoraleData

var value: float = 100.0
var state: State = State.STEADY
## False for bosses (and anything else that must fight to the end).
var can_break: bool = true

var _waver_left: float = 0.0
var _damage: Node = null
var _ship: Node = null


func _ready() -> void:
	add_to_group(&"morale_component")
	if data == null:
		data = MoraleData.get_default()
	value = data.start
	_ship = get_parent()
	can_break = not (_ship != null and _ship.is_in_group("boss_ship"))
	_damage = _ship.get_node_or_null("ShipDamage") if _ship else null
	if _damage and _damage.has_signal("hit_resolved"):
		_damage.hit_resolved.connect(_on_hit_resolved)


func _process(delta: float) -> void:
	if state != State.WAVERING:
		return
	_waver_left -= delta
	if _waver_left <= 0.0:
		_resolve_waver()


# === Draining ===

func _on_hit_resolved(source: Node, facing: StringName, pool_deltas: Dictionary,
		_ammo_id: StringName, _hit_tags: PackedStringArray) -> void:
	var crew_lost: float = float(pool_deltas.get("crew", 0.0))
	if crew_lost > 0.0 and _damage and _damage.ship_stats:
		drain(crew_lost / maxf(_damage.ship_stats.max_crew, 1.0) * data.crew_loss_drain)
	# Only the player's guns rake; a collision "impact" is not a broadside.
	if (facing == &"stern" or facing == &"bow") and source != null and source.is_in_group("player_ship"):
		drain(data.rake_drain)


## The squad leader of this hull's fight just sank.
func notify_leader_sunk(leader: Node = null) -> void:
	if leader != null and leader == _ship:
		return
	drain(data.leader_sunk_drain)


func drain(amount: float) -> void:
	if amount <= 0.0 or state == State.FLED or state == State.STRUCK:
		return
	value = clampf(value - amount, 0.0, 100.0)
	morale_changed.emit(value)
	if can_break and state == State.STEADY and value <= data.wavering_threshold:
		state = State.WAVERING
		_waver_left = data.waver_seconds
		wavering_started.emit(data.waver_seconds)


# === Breaking ===

## The wavering has run its course. A crew with its rigging intact and some nerve left runs; a
## crew below the strike line, or on a ship that cannot run, strikes.
func _resolve_waver() -> void:
	if value <= data.strike_threshold or _sails_fraction() < data.flee_min_sails:
		strike()
	else:
		flee()


func _sails_fraction() -> float:
	if _damage == null or not _damage.has_method("get_pool_maximum"):
		return 1.0
	return float(_damage.get("sails")) / maxf(_damage.get_pool_maximum("sails"), 1.0)


func flee() -> void:
	if state == State.FLED or state == State.STRUCK:
		return
	state = State.FLED
	var ai = _ship.get_node_or_null("EnemyAI") if _ship else null
	if ai and ai.has_method("order_flee"):
		ai.order_flee()
	fled.emit()


## Strike the colours: stop fighting, stop firing, and wait to be taken.
func strike() -> void:
	if state == State.STRUCK:
		return
	state = State.STRUCK
	if _ship:
		_ship.set_meta(&"struck", true)
		_ship.add_to_group(&"struck_ship")
		var combat = _ship.get_node_or_null("ShipCombat")
		if combat:
			combat.auto_fire_enabled = false
		var ai = _ship.get_node_or_null("EnemyAI")
		if ai:
			ai.set_physics_process(false)
			ai.set_process(false)
		if _ship.has_method("set_input"):
			_ship.set_input(0.0, 0.0)
	struck.emit()


func is_struck() -> bool:
	return state == State.STRUCK


## morale / start, 0..1: the deck builder scales the boarding deck's morale by this, so a
## battered crew boards weakly and a struck one's colours are nearly down already.
func morale_fraction() -> float:
	return clampf(value / maxf(data.start, 1.0), 0.0, 1.0)
