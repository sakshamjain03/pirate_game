extends GutTest

## Guards M26 Task 7: the upgrade pool grew to >= 22 authored BattleUpgradeData,
## the four new CombatModifiers keys each change the stat they name, and the
## int-serialized Effect enum was only appended to (Requirements 4.4, 5.3).

const UPGRADE_DIR := "res://resources/combat/upgrades/"
const PLAYER_SHIP := preload("res://scenes/world/PlayerShip.tscn")
const LOOT_DROP := preload("res://scenes/combat/LootDrop.tscn")

## The ten upgrades that predate M26, pinned to the Effect each resolved to
## before the enum grew. If one of these moves, an enum value was inserted
## rather than appended and every authored .tres silently changed meaning.
const PRE_M26_EFFECTS := {
	"burning_shot": BattleUpgradeData.Effect.DAMAGE,
	"heavy_volley": BattleUpgradeData.Effect.DAMAGE,
	"rapid_reload": BattleUpgradeData.Effect.RELOAD_SPEED,
	"full_sail": BattleUpgradeData.Effect.SHIP_SPEED,
	"long_nines": BattleUpgradeData.Effect.CANNON_RANGE,
	"steady_gunners": BattleUpgradeData.Effect.FIRING_ARC,
	"primed_charges": BattleUpgradeData.Effect.SPECIAL_COOLDOWN,
	"emergency_repairs": BattleUpgradeData.Effect.REPAIR_HULL,
	"patch_the_rigging": BattleUpgradeData.Effect.REPAIR_SAILS,
	"rally_the_crew": BattleUpgradeData.Effect.RALLY_CREW,
}

var _scene: Node3D = null


func before_each() -> void:
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each() -> void:
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.free()
	_scene = null


func _load_all() -> Array[BattleUpgradeData]:
	var out: Array[BattleUpgradeData] = []
	var dir := DirAccess.open(UPGRADE_DIR)
	assert_not_null(dir, "upgrade directory exists")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var res = load(UPGRADE_DIR + file)
		assert_true(res is BattleUpgradeData, "%s loads as BattleUpgradeData" % file)
		if res is BattleUpgradeData:
			out.append(res)
	return out


func _by_id(id: String) -> BattleUpgradeData:
	for u in _load_all():
		if u.upgrade_id == id:
			return u
	return null


func _upgrade(effect: int, magnitude: float) -> BattleUpgradeData:
	var u := BattleUpgradeData.new()
	u.upgrade_id = "t_%d" % effect
	u.effect = effect
	u.magnitude = magnitude
	u.max_stacks = 5
	return u


func test_pool_has_at_least_22_unique_upgrades() -> void:
	var all := _load_all()
	assert_true(all.size() >= 22, "Req 5.3: >= 22 upgrades (10 existing + 12 new), got %d" % all.size())
	var ids := {}
	for u in all:
		assert_ne(u.upgrade_id, "", "every upgrade has an id")
		assert_false(ids.has(u.upgrade_id), "duplicate upgrade_id '%s'" % u.upgrade_id)
		ids[u.upgrade_id] = true


func test_every_upgrade_applies_cleanly() -> void:
	# An effect CombatModifiers doesn't handle push_errors and returns false.
	for u in _load_all():
		var mods := CombatModifiers.new()
		add_child_autofree(mods)
		assert_true(mods.apply_upgrade(u), "'%s' applies" % u.upgrade_id)


func test_pre_m26_upgrades_keep_their_effects() -> void:
	for id in PRE_M26_EFFECTS:
		var u := _by_id(id)
		assert_not_null(u, "pre-M26 upgrade '%s' still exists" % id)
		if u:
			assert_eq(u.effect, PRE_M26_EFFECTS[id], "'%s' still resolves to the same Effect" % id)


func test_effect_enum_was_appended_not_inserted() -> void:
	assert_eq(BattleUpgradeData.Effect.RALLY_CREW, 8, "pre-M26 values unmoved")
	assert_eq(BattleUpgradeData.Effect.PICKUP_RADIUS, 9)
	assert_eq(BattleUpgradeData.Effect.RAM_DAMAGE, 12)


func test_pickup_radius_key() -> void:
	var mods := CombatModifiers.new()
	add_child_autofree(mods)
	assert_eq(mods.pickup_radius_mult, 1.0)
	mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.PICKUP_RADIUS, 1.5))
	assert_almost_eq(mods.pickup_radius_mult, 1.5, 0.001)


func test_ram_damage_key_feeds_collision_handler() -> void:
	var ship := PLAYER_SHIP.instantiate()
	_scene.add_child(ship)
	assert_eq(ShipCollisionHandler._ram_upgrade_mult(ship), 1.0, "neutral without upgrade")
	var mods: CombatModifiers = ship.get_node("CombatModifiers")
	mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.RAM_DAMAGE, 1.6))
	assert_almost_eq(mods.ram_damage_mult, 1.6, 0.001)
	assert_almost_eq(ShipCollisionHandler._ram_upgrade_mult(ship), 1.6, 0.001)


func test_regen_key_repairs_hull_but_never_a_sunk_one() -> void:
	var ship := PLAYER_SHIP.instantiate()
	_scene.add_child(ship)
	var dmg: ShipDamage = ship.get_node("ShipDamage")
	var mods: CombatModifiers = ship.get_node("CombatModifiers")
	var maximum := dmg.get_pool_maximum("hull")
	mods.apply_upgrade(_upgrade(BattleUpgradeData.Effect.HULL_REGEN, 1.0))   # 1%/s
	assert_almost_eq(mods.regen_per_second, 0.01, 0.0001)

	dmg.hull = maximum * 0.5
	mods._process(1.0)
	assert_almost_eq(dmg.hull, maximum * 0.51, 0.01, "1 s of 1%/s regen")

	dmg.hull = 0.0
	mods._process(1.0)
	assert_eq(dmg.hull, 0.0, "a sunk hull is never regenerated")


func _balls_in_scene() -> int:
	var n := 0
	for c in _scene.get_children():
		if c is Cannonball:
			n += 1
	return n


func test_extra_projectile_key_fires_extra_balls() -> void:
	var plain := PLAYER_SHIP.instantiate()
	_scene.add_child(plain)
	assert_true(plain.get_node("ShipCombat").fire_broadside("port"), "baseline fires")
	var baseline := _balls_in_scene()
	assert_gt(baseline, 0)

	var boosted := PLAYER_SHIP.instantiate()
	_scene.add_child(boosted)
	boosted.get_node("CombatModifiers").apply_upgrade(_upgrade(BattleUpgradeData.Effect.EXTRA_PROJECTILE, 1.0))
	assert_eq(boosted.get_node("CombatModifiers").extra_projectiles, 1)
	boosted.get_node("ShipCombat").fire_broadside("port")
	assert_eq(_balls_in_scene() - baseline, baseline * 2, "one extra ball per gun doubles a 1-ball shot")


func test_timed_effect_can_carry_new_keys() -> void:
	var mods := CombatModifiers.new()
	add_child_autofree(mods)
	mods.add_timed_effect({"pickup_radius": 2.0}, 5.0)
	assert_almost_eq(mods.pickup_radius_mult, 2.0, 0.001)
	mods._process(6.0)
	assert_almost_eq(mods.pickup_radius_mult, 1.0, 0.001, "expires back to neutral")


func test_loot_magnet_pulls_only_when_enabled() -> void:
	var ship := Node3D.new()
	ship.add_to_group("player_ship")
	_scene.add_child(ship)
	ship.global_position = Vector3(20, 0, 0)

	var off := LOOT_DROP.instantiate() as LootDrop
	_scene.add_child(off)
	off._process(0.5)
	assert_almost_eq(off.global_position.x, 0.0, 0.001, "magnet 0 (campaign default) never moves")

	var on := LOOT_DROP.instantiate() as LootDrop
	on.magnet_range = 30.0
	_scene.add_child(on)
	on._process(0.5)
	assert_gt(on.global_position.x, 0.0, "magnet pulls the drop toward the ship")
