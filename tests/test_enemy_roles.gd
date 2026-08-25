extends GutTest

# test_enemy_roles.gd
# Slice 6 (docs/navalCombat.md "real roles, not just bigger numbers"). `role` is
# a tag on AIProfileData, not a second numeric system — most of these tests pin
# that the authored profiles actually diverge along the axes that already exist
# (aggression, flee threshold, preferred distance), plus the one thing `role`
# does drive in code: a Support ship repairs a wounded ally instead of attacking.

const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"

var _root: Node3D


func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
	_root = Node3D.new()
	_root.name = "RolesRoot"
	add_child_autoqfree(_root)


func _spawn(profile: AIProfileData, pos: Vector3) -> Node3D:
	var ship = load(ENEMY_SHIP).instantiate() as Node3D
	var ai = ship.get_node("EnemyAI")
	ai.ai_profile = profile
	_root.add_child(ship)
	ship.global_position = pos
	ship.freeze = true
	return ship


func test_every_authored_profile_has_a_valid_role():
	var paths := [
		"res://resources/combat/ai_profiles/StandardEnemy.tres",
		"res://resources/combat/ai_profiles/HarassingSloop.tres",
		"res://resources/combat/ai_profiles/AggressiveGalleon.tres",
		"res://resources/combat/ai_profiles/ArtilleryFrigate.tres",
		"res://resources/combat/ai_profiles/SupportGalleon.tres",
		"res://resources/combat/ai_profiles/BossProfile.tres",
	]
	var seen_roles := {}
	for p in paths:
		var prof: AIProfileData = load(p)
		assert_between(prof.role, AIProfileData.Role.BALANCED, AIProfileData.Role.BOSS,
			"%s must have a valid role" % p)
		seen_roles[prof.role] = true

	for role in [AIProfileData.Role.RAIDER, AIProfileData.Role.ARTILLERY,
			AIProfileData.Role.TANK, AIProfileData.Role.SUPPORT, AIProfileData.Role.BOSS]:
		assert_true(seen_roles.has(role),
			"role %s must be covered by at least one authored profile" % role)


func test_artillery_stands_off_further_than_raider():
	var artillery: AIProfileData = load("res://resources/combat/ai_profiles/ArtilleryFrigate.tres")
	var raider: AIProfileData = load("res://resources/combat/ai_profiles/HarassingSloop.tres")
	assert_gt(artillery.preferred_combat_distance, raider.preferred_combat_distance,
		"Artillery's whole identity is staying at range longer than a Raider closes to")


func test_tank_never_flees_but_a_raider_eventually_does():
	var tank: AIProfileData = load("res://resources/combat/ai_profiles/AggressiveGalleon.tres")
	var raider: AIProfileData = load("res://resources/combat/ai_profiles/HarassingSloop.tres")
	assert_eq(tank.flee_health_threshold, 0.0, "A Tank fights to the end")
	assert_gt(raider.flee_health_threshold, tank.flee_health_threshold,
		"...unlike a Raider, which breaks off once it's actually hurt")


func test_support_role_heals_a_nearby_wounded_ally_instead_of_attacking():
	var support_profile: AIProfileData = load("res://resources/combat/ai_profiles/SupportGalleon.tres")
	var healer = _spawn(support_profile, Vector3.ZERO)
	var wounded = _spawn(load("res://resources/combat/ai_profiles/StandardEnemy.tres"), Vector3(8, 0, 0))

	var wdmg = wounded.get_node("ShipDamage")
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	wdmg.apply_hit(wdmg.get_pool_maximum("hull") * 0.7, round_shot, Vector3.FORWARD)
	var hull_after_damage: float = wdmg.hull
	assert_lt(hull_after_damage / wdmg.get_pool_maximum("hull"),
		support_profile.support_heal_threshold, "Precondition: the ally is wounded enough to help")

	await wait_seconds(0.5)

	assert_gt(wdmg.hull, hull_after_damage,
		"A Support-role ship in range must repair a wounded ally's hull")


func test_a_friendly_grouped_ai_hunts_the_enemy_composition_not_the_player():
	## Slice 7 (AI support ships): a `friendly_ship`-grouped AI must draw its
	## target from the enemy composition, never from "player_ship" — it's on
	## the player's side of the fight, not chasing the player itself.
	##
	## Other test scripts in this same suite run legitimately spawn their own
	## "enemy_ship"-grouped hulls nearby, so this cannot assert the *exact*
	## node picked (that depends on run order) — only that whatever is picked
	## is a real enemy hull, never anything on the player's own side.
	var ally = _spawn(load("res://resources/combat/ai_profiles/StandardEnemy.tres"), Vector3.ZERO)
	ally.remove_from_group("enemy_ship")
	ally.add_to_group("friendly_ship")
	var hostile = _spawn(load("res://resources/combat/ai_profiles/StandardEnemy.tres"), Vector3(20, 0, 0))

	var ai = ally.get_node("EnemyAI")
	ai._find_player()

	assert_not_null(ai.player_ship, "A friendly-grouped AI with a hostile in range must find a target")
	assert_true(ai.player_ship.is_in_group("enemy_ship"),
		"...drawn from the enemy composition")
	assert_false(ai.player_ship.is_in_group("player_ship") or ai.player_ship.is_in_group("friendly_ship"),
		"...and never the player or another friendly-grouped ship")
	assert_ne(ai.player_ship, ally, "...and never itself")


func test_support_role_ignores_an_ally_that_is_not_wounded():
	## Other test scripts spawn their own "enemy_ship"-grouped hulls in this same
	## suite run, so this cannot assert _find_wounded_ally() returns null outright
	## — only that it never picks *this* full-health ally as its target.
	var support_profile: AIProfileData = load("res://resources/combat/ai_profiles/SupportGalleon.tres")
	var healer = _spawn(support_profile, Vector3.ZERO)
	var ai = healer.get_node("EnemyAI")
	var healthy = _spawn(load("res://resources/combat/ai_profiles/StandardEnemy.tres"), Vector3(8, 0, 0))

	assert_ne(ai._find_wounded_ally(), healthy,
		"A full-health ally is not a repair target, so Support has nothing to do but hold")
