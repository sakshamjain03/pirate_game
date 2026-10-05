extends GutTest
## M30 Wave 0 (0.18): ShipDamage.hit_resolved — one event per resolved hit,
## the bus every later feedback system (floating damage, Fury, ribbons,
## morale, the boarding deck) reads. Pins: facing comes from the arc test
## itself (not by comparing armour floats, which collide when two facings
## share a multiplier); deltas are what was actually applied; the killing
## blow is a hit BEFORE it is a death; and B12 — a cannonball, which calls
## apply_hit() directly, now produces floating damage through ShipCombat.

var _hull: Node3D
var _dmg: ShipDamage
var _stats: ShipStats
var _events: Array = []
var _order: Array = []


func before_each() -> void:
	_stats = ShipStats.new()
	_stats.max_health = 100.0
	_stats.max_sails = 50.0
	_stats.max_crew = 20.0
	_stats.broadside_armor_multiplier = 1.0
	_stats.stern_arc_degrees = 60.0
	# Same value as the broadside on purpose: the old float-equality facing
	# check reported every beam hit as a stern rake whenever these matched.
	_stats.stern_crit_multiplier = 1.0
	_stats.bow_arc_degrees = 60.0
	_stats.bow_armor_multiplier = 0.5
	_hull = Node3D.new()
	add_child_autofree(_hull)
	_dmg = ShipDamage.new()
	_dmg.name = "ShipDamage"  # ShipCombat finds its sibling by name
	_dmg.ship_stats = _stats
	_hull.add_child(_dmg)
	_dmg.hull = 100.0
	_dmg.sails = 50.0
	_dmg.crew = 20.0
	_events.clear()
	_order.clear()
	_dmg.hit_resolved.connect(func(src, facing, deltas, ammo_id, tags):
		_events.append({"src": src, "facing": facing, "deltas": deltas, "ammo": ammo_id, "tags": tags})
		_order.append("hit"))
	_dmg.destroyed.connect(func(): _order.append("destroyed"))


func _round() -> AmmoData:
	return load("res://resources/combat/ammo/RoundShot.tres")


func test_beam_hit_reports_beam_even_when_multipliers_collide() -> void:
	_dmg.apply_hit(10.0, _round(), _hull.global_transform.basis.x)
	assert_eq(_events.size(), 1)
	assert_eq(_events[0]["facing"], &"beam")


func test_stern_and_bow_facings() -> void:
	_dmg.apply_hit(10.0, _round(), _hull.global_transform.basis.z)
	_dmg.apply_hit(10.0, _round(), -_hull.global_transform.basis.z)
	assert_eq(_events[0]["facing"], &"stern")
	assert_eq(_events[1]["facing"], &"bow")
	assert_eq(_events[1]["deltas"].get("hull"), 5.0, "bow armour halves the hit")


func test_source_ammo_and_tags() -> void:
	var shooter := Node3D.new()
	add_child_autofree(shooter)
	_dmg.apply_hit(10.0, _round(), _hull.global_transform.basis.x, shooter)
	var e: Dictionary = _events[0]
	assert_eq(e["src"], shooter)
	assert_eq(e["ammo"], &"round")
	assert_has(e["tags"], "ammo:round")
	assert_has(e["tags"], "facing:beam")


func test_deltas_are_clamped_to_what_was_applied() -> void:
	_dmg.hull = 4.0
	_dmg.apply_hit(10.0, _round(), _hull.global_transform.basis.x)
	assert_eq(_events[0]["deltas"].get("hull"), 4.0, "only 4 hull was left to take")
	assert_false(_events[0]["deltas"].has("crew"), "pools that took nothing are omitted")


func test_killing_blow_is_a_hit_before_a_death() -> void:
	_dmg.hull = 5.0
	_dmg.apply_hit(10.0, _round(), _hull.global_transform.basis.x)
	assert_eq(_order, ["hit", "destroyed"])


func test_impact_emits_an_impact_hit() -> void:
	_dmg.apply_impact(12.0, 0.5)
	assert_eq(_events.size(), 1)
	assert_eq(_events[0]["facing"], &"impact")
	assert_eq(_events[0]["deltas"].get("hull"), 12.0)
	assert_eq(_events[0]["deltas"].get("crew"), 6.0)


func test_ship_combat_listens_for_floating_damage() -> void:
	var combat: Node = load("res://scripts/world/ShipCombat.gd").new()
	combat.ship_stats = _stats
	_hull.add_child(combat)
	assert_true(_dmg.hit_resolved.is_connected(combat._on_hit_resolved),
		"B12: cannon hits bypass take_damage(), so floating damage must hang off hit_resolved")
