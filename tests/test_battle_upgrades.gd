extends GutTest

# test_battle_upgrades.gd
# Slice 3 — the roguelite layer (docs/navalCombat.md §11/§12).
# The load-bearing invariants here are (a) upgrades must NEVER write to a shared
# ShipStats resource, and (b) they must be gone when the battle ends.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false
	func fire_cannons(side: String) -> void:
		var c = get_node_or_null("ShipCombat")
		if c: c.fire_broadside(side)

var _ship: MockShip
var _mods: CombatModifiers
var _combat: ShipCombat
var _dmg: Node
var _stats: ShipStats


func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene

	# A fresh, unshared ShipStats so a leak into it cannot corrupt other tests.
	_stats = ShipStats.new()
	_stats.max_health = 200.0
	_stats.max_sails = 100.0
	_stats.max_crew = 20.0
	_stats.cannon_damage = 20.0
	_stats.fire_rate = 2.0
	_stats.cannon_range = 100.0
	_stats.firing_arc_degrees = 30.0
	_stats.special_broadside_cooldown = 10.0

	_ship = MockShip.new()
	_ship.add_to_group("player_ship")
	_ship.freeze = true

	_dmg = load("res://scripts/world/ShipDamage.gd").new()
	_dmg.name = "ShipDamage"
	_dmg.ship_stats = _stats
	_ship.add_child(_dmg)

	_mods = CombatModifiers.new()
	_mods.name = "CombatModifiers"
	_ship.add_child(_mods)

	var solver = FiringSolver.new()
	solver.name = "FiringSolver"
	solver.ship_stats = _stats
	_ship.add_child(solver)

	_combat = ShipCombat.new()
	_combat.name = "ShipCombat"
	_combat.ship_stats = _stats
	_combat.auto_fire_enabled = false
	_ship.add_child(_combat)

	add_child_autoqfree(_ship)


func _upgrade(effect: int, magnitude: float, stacks: int = 1, id: String = "test_up") -> BattleUpgradeData:
	var u = BattleUpgradeData.new()
	u.upgrade_id = id
	u.display_name = "Test Upgrade"
	u.effect = effect
	u.magnitude = magnitude
	u.max_stacks = stacks
	return u


# === the invariant that matters most ===

func test_an_upgrade_never_mutates_the_ship_stats_resource():
	## A ShipStats .tres is shared by every hull of its class. Writing "Rapid
	## Reload: -40% reload" into ship_stats.fire_rate would permanently buff every
	## Sloop in the game, enemy hulls included, and persist once saved.
	var damage_before: float = _stats.cannon_damage
	var rate_before: float = _stats.fire_rate
	var range_before: float = _stats.cannon_range
	var arc_before: float = _stats.firing_arc_degrees
	var special_before: float = _stats.special_broadside_cooldown

	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.DAMAGE, 2.0, 1, "a"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.RELOAD_SPEED, 2.0, 1, "b"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.CANNON_RANGE, 2.0, 1, "c"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.FIRING_ARC, 15.0, 1, "d"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.SPECIAL_COOLDOWN, 0.5, 1, "e"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.SHIP_SPEED, 2.0, 1, "f"))

	assert_eq(_stats.cannon_damage, damage_before, "cannon_damage must be untouched")
	assert_eq(_stats.fire_rate, rate_before, "fire_rate must be untouched")
	assert_eq(_stats.cannon_range, range_before, "cannon_range must be untouched")
	assert_eq(_stats.firing_arc_degrees, arc_before, "firing_arc_degrees must be untouched")
	assert_eq(_stats.special_broadside_cooldown, special_before,
		"special_broadside_cooldown must be untouched")

	# ...but the modifiers themselves definitely changed.
	assert_eq(_mods.damage_mult, 2.0, "The modifier layer is where the effect lives")
	assert_eq(_mods.fire_rate_mult, 2.0, "")
	assert_eq(_mods.arc_bonus_degrees, 15.0, "")


func test_reset_clears_every_modifier():
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.DAMAGE, 1.5, 1, "a"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.FIRING_ARC, 12.0, 1, "b"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.SHIP_SPEED, 1.3, 1, "c"))
	_mods.reset()

	assert_eq(_mods.damage_mult, 1.0, "damage back to neutral")
	assert_eq(_mods.fire_rate_mult, 1.0, "reload back to neutral")
	assert_eq(_mods.speed_mult, 1.0, "speed back to neutral")
	assert_eq(_mods.range_mult, 1.0, "range back to neutral")
	assert_eq(_mods.arc_bonus_degrees, 0.0, "arc back to neutral")
	assert_eq(_mods.special_cooldown_mult, 1.0, "special cooldown back to neutral")
	assert_eq(_mods.get_applied_upgrades().size(), 0, "and the build is forgotten")


# === effects actually reach the systems ===

func test_a_damage_upgrade_reaches_the_cannonball():
	var marker = Node3D.new()
	marker.name = "StarboardMarker1"
	_ship.add_child(marker)
	_combat.starboard_markers.append(marker)
	await wait_process_frames(1)

	_combat.fire_broadside("starboard")
	var baseline := _latest_cannonball_damage()
	assert_gt(baseline, 0.0, "Precondition: a cannonball carries damage")

	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.DAMAGE, 2.0))
	_combat.can_fire_starboard = true
	_combat.fire_broadside("starboard")
	var boosted := _latest_cannonball_damage()

	assert_almost_eq(boosted, baseline * 2.0, 0.01,
		"A damage upgrade must double what the guns actually deliver")

func _latest_cannonball_damage() -> float:
	var best: float = 0.0
	for n in get_tree().current_scene.get_children():
		if n is Cannonball:
			best = maxf(best, n.damage)
	return best


func test_a_reload_upgrade_shortens_the_actual_cooldown():
	var marker = Node3D.new()
	marker.name = "PortMarker1"
	_ship.add_child(marker)
	_combat.port_markers.append(marker)
	await wait_process_frames(1)

	# fire_rate 2.0 -> 0.5 s. With a x4 reload upgrade that becomes 0.125 s.
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.RELOAD_SPEED, 4.0))
	_combat.fire_broadside("port")
	assert_false(_combat.can_fire_port, "Precondition: the side is reloading")

	await wait_seconds(0.3)
	assert_true(_combat.can_fire_port,
		"A reload upgrade must genuinely shorten the wait, not just the display")


func test_an_arc_upgrade_widens_what_the_solver_accepts():
	var solver: FiringSolver = _ship.get_node("FiringSolver")
	var before: float = solver.get_arc_degrees()
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.FIRING_ARC, 20.0))
	assert_almost_eq(solver.get_arc_degrees(), before + 20.0, 0.01,
		"The solver must read the widened cone")

func test_the_firing_arc_can_never_widen_past_the_beam():
	## A cone wider than 90 degrees off the beam covers bow and stern too, which
	## would delete the positioning mechanic entirely.
	var solver: FiringSolver = _ship.get_node("FiringSolver")
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.FIRING_ARC, 500.0))
	assert_lt(solver.get_arc_degrees(), 90.0,
		"Arc must stay clamped below 90 degrees no matter how it is stacked")

func test_a_range_upgrade_extends_what_the_solver_accepts():
	var solver: FiringSolver = _ship.get_node("FiringSolver")
	var before: float = solver.get_range()
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.CANNON_RANGE, 1.5))
	assert_almost_eq(solver.get_range(), before * 1.5, 0.01, "Range must actually extend")

func test_a_special_cooldown_upgrade_brings_the_volley_back_sooner():
	var marker = Node3D.new()
	marker.name = "PortMarker1"
	_ship.add_child(marker)
	_combat.port_markers.append(marker)
	await wait_process_frames(1)

	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.SPECIAL_COOLDOWN, 0.5))
	assert_true(_combat.fire_special_broadside(), "Precondition: the volley fires")
	# 10 s base x 0.5 -> 5 s, so the reported progress must already be past where a
	# full-length cooldown would sit.
	assert_gt(_combat.get_special_cooldown_fraction(), -0.01, "")
	assert_almost_eq(_combat._special_cooldown_remaining, 5.0, 0.2,
		"The cooldown must be halved, not the display")


func test_instant_repairs_go_through_the_ship_damage_write_path():
	_dmg.hull = 20.0
	_dmg.sails = 10.0
	_dmg.crew = 2.0

	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.REPAIR_HULL, 0.25, 1, "h"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.REPAIR_SAILS, 0.5, 1, "s"))
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.RALLY_CREW, 0.5, 1, "c"))

	assert_almost_eq(_dmg.hull, 20.0 + 200.0 * 0.25, 0.01, "Hull restored as a fraction of max")
	assert_almost_eq(_dmg.sails, 10.0 + 100.0 * 0.5, 0.01, "Sails restored as a fraction of max")
	assert_almost_eq(_dmg.crew, 2.0 + 20.0 * 0.5, 0.01, "Crew restored as a fraction of max")

func test_a_repair_upgrade_cannot_overheal():
	_dmg.hull = _dmg.get_pool_maximum("hull")
	_mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.REPAIR_HULL, 1.0))
	assert_eq(_dmg.hull, _dmg.get_pool_maximum("hull"), "Repair must clamp at the maximum")


# === stacking rules ===

func test_stacking_is_capped_per_upgrade():
	var u = _upgrade(BattleUpgradeData.Effect.DAMAGE, 1.5, 2, "stacky")
	assert_true(_mods.apply_upgrade(u), "First take allowed")
	assert_true(_mods.apply_upgrade(u), "Second take allowed at max_stacks 2")
	assert_false(_mods.apply_upgrade(u), "Third take refused")
	assert_eq(_mods.stacks_of("stacky"), 2, "Only two stacks recorded")
	assert_almost_eq(_mods.damage_mult, 1.5 * 1.5, 0.001, "Two stacks compound")

func test_can_apply_reports_whether_an_upgrade_is_still_offerable():
	var u = _upgrade(BattleUpgradeData.Effect.DAMAGE, 1.2, 1, "once")
	assert_true(_mods.can_apply(u), "Offerable before it is taken")
	_mods.apply_upgrade(u)
	assert_false(_mods.can_apply(u), "Not offerable once maxed")
	assert_false(_mods.can_apply(null), "A null upgrade is never applicable")


# === authored content ===

func test_every_authored_upgrade_is_loadable_and_coherent():
	var dir := DirAccess.open("res://resources/combat/upgrades")
	assert_not_null(dir, "The upgrade pool directory must exist")
	var seen_ids: Array[String] = []
	var count := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		count += 1
		var u: BattleUpgradeData = load("res://resources/combat/upgrades/" + f)
		assert_not_null(u, "%s must load as BattleUpgradeData" % f)
		assert_ne(u.upgrade_id, "", "%s needs an id" % f)
		assert_false(seen_ids.has(u.upgrade_id),
			"%s duplicates the id '%s' — stack counting is keyed on it" % [f, u.upgrade_id])
		seen_ids.append(u.upgrade_id)
		assert_ne(u.display_name, "", "%s needs a name for its card" % f)
		assert_ne(u.describe(), "", "%s must describe what it does" % f)
		# A "buff" that makes things worse, or a no-op, is a broken card.
		match u.effect:
			BattleUpgradeData.Effect.SPECIAL_COOLDOWN:
				assert_lt(u.magnitude, 1.0, "%s: a cooldown upgrade must reduce it" % f)
			BattleUpgradeData.Effect.REPAIR_HULL, BattleUpgradeData.Effect.REPAIR_SAILS, \
			BattleUpgradeData.Effect.RALLY_CREW, BattleUpgradeData.Effect.FIRING_ARC:
				assert_gt(u.magnitude, 0.0, "%s: must restore/widen something" % f)
			_:
				assert_gt(u.magnitude, 1.0, "%s: a multiplier upgrade must be > 1.0" % f)
	assert_gt(count, 5, "The pool needs enough breadth for varied offers")

func test_the_four_upgrades_named_in_the_locked_design_all_exist():
	## docs/navalCombat.md §11 names Burning Shot, Heavy Volley, Rapid Reload and
	## Emergency Repairs by example. They should be real.
	var want := {
		"burning_shot": "res://resources/combat/upgrades/BurningShot.tres",
		"heavy_volley": "res://resources/combat/upgrades/HeavyVolley.tres",
		"rapid_reload": "res://resources/combat/upgrades/RapidReload.tres",
		"emergency_repairs": "res://resources/combat/upgrades/EmergencyRepairs.tres",
	}
	for id in want.keys():
		var u: BattleUpgradeData = load(want[id])
		assert_not_null(u, "%s must exist" % id)
		assert_eq(u.upgrade_id, id, "%s must carry the expected id" % id)
	var repairs: BattleUpgradeData = load(want["emergency_repairs"])
	assert_eq(repairs.effect, BattleUpgradeData.Effect.REPAIR_HULL,
		"Emergency Repairs restores hull, per the locked design")
