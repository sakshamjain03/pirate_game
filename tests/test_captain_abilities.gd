extends GutTest

# test_captain_abilities.gd
# Slice 4 — captain active abilities (docs/navalCombat.md §10).
# "Captains are actual gameplay-changing heroes. Not just +5% damage." Before this,
# CaptainData carried five passive multipliers and nothing the player could press.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false

var _ship: MockShip
var _mods: CombatModifiers
var _ability_node: CaptainAbility
var _dmg: Node
var _stats: ShipStats
var _created_test_scene: Node3D = null


func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

	_stats = ShipStats.new()
	_stats.max_health = 200.0
	_stats.max_sails = 100.0
	_stats.max_crew = 20.0

	_ship = MockShip.new()
	_ship.freeze = true
	_ship.add_to_group("player_ship")

	_dmg = load("res://scripts/world/ShipDamage.gd").new()
	_dmg.name = "ShipDamage"
	_dmg.ship_stats = _stats
	_ship.add_child(_dmg)

	_mods = CombatModifiers.new()
	_mods.name = "CombatModifiers"
	_ship.add_child(_mods)

	_ability_node = CaptainAbility.new()
	_ability_node.name = "CaptainAbility"
	_ship.add_child(_ability_node)

	add_child_autoqfree(_ship)


func after_each():
	# This file's own current_scene, if it created one, must not outlive it —
	# a leaked one previously corrupted test_navigation_integration.gd's real
	# get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _ability(dur: float = 5.0, cd: float = 20.0) -> CaptainAbilityData:
	var a = CaptainAbilityData.new()
	a.ability_id = "test_ability"
	a.display_name = "Test Ability"
	a.duration = dur
	a.cooldown = cd
	return a

func _captain_with(a: CaptainAbilityData) -> CaptainData:
	var c = CaptainData.new()
	c.captain_id = "test_cap"
	c.active_ability = a
	return c


# === basic contract ===

func test_a_ship_with_no_captain_has_no_ability():
	assert_false(_ability_node.has_ability(), "No captain, no verb")
	assert_false(_ability_node.is_ready(), "...and nothing to trigger")
	assert_false(_ability_node.activate(), "Activation must fail cleanly, not error")

func test_a_captain_with_no_authored_ability_has_none():
	_ship.active_captain = CaptainData.new()
	await wait_process_frames(1)
	assert_false(_ability_node.has_ability(),
		"An unauthored active_ability must not fake a usable button")

func test_activating_applies_the_timed_multipliers():
	var a = _ability(5.0, 20.0)
	a.damage_mult = 2.0
	a.speed_mult = 1.5
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)

	assert_true(_ability_node.is_ready(), "A fresh captain's ability starts ready")
	assert_true(_ability_node.activate(), "It should fire")

	assert_eq(_mods.damage_mult, 2.0, "Damage buff must be live")
	assert_eq(_mods.speed_mult, 1.5, "Speed buff must be live")
	assert_true(_mods.has_timed_effect(), "...as a timed effect")

func test_the_buff_expires_and_restores_the_exact_prior_value():
	## Multiplying in and dividing back out would drift; the modifier layer
	## recomputes from base instead.
	var a = _ability(0.1, 20.0)
	a.damage_mult = 1.75
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)

	_ability_node.activate()
	assert_almost_eq(_mods.damage_mult, 1.75, 0.001, "Precondition: buff active")

	await wait_seconds(0.4)
	assert_eq(_mods.damage_mult, 1.0, "Expiry must restore exactly 1.0, not 0.9999")
	assert_false(_mods.has_timed_effect(), "...and drop the timed entry")

func test_a_buff_stacks_on_top_of_a_battle_upgrade_without_erasing_it():
	var upgrade = BattleUpgradeData.new()
	upgrade.upgrade_id = "u"
	upgrade.effect = BattleUpgradeData.Effect.DAMAGE
	upgrade.magnitude = 2.0
	upgrade.max_stacks = 1
	_mods.apply_upgrade(upgrade)
	assert_eq(_mods.damage_mult, 2.0, "Precondition: the battle upgrade is live")

	var a = _ability(0.1, 20.0)
	a.damage_mult = 3.0
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)
	_ability_node.activate()
	assert_almost_eq(_mods.damage_mult, 6.0, 0.001, "Ability multiplies on top of the upgrade")

	await wait_seconds(0.4)
	assert_almost_eq(_mods.damage_mult, 2.0, 0.001,
		"When the burst ends the battle-long upgrade must remain")


# === cooldown ===

func test_the_ability_goes_on_cooldown_and_refuses_a_second_use():
	var a = _ability(1.0, 30.0)
	a.damage_mult = 1.5
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)

	assert_true(_ability_node.activate(), "First use allowed")
	assert_false(_ability_node.is_ready(), "Now cooling down")
	assert_false(_ability_node.activate(), "Second use refused")
	assert_lt(_ability_node.get_cooldown_fraction(), 1.0, "...and the HUD can see that")

func test_the_cooldown_elapses():
	var a = _ability(0.05, 0.15)
	a.damage_mult = 1.5
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)

	_ability_node.activate()
	assert_false(_ability_node.is_ready(), "Precondition: cooling down")
	await wait_seconds(0.4)
	assert_true(_ability_node.is_ready(), "The ability must come back")
	assert_eq(_ability_node.get_cooldown_fraction(), 1.0, "...and read as ready")

func test_swapping_captains_swaps_the_verb_and_clears_the_cooldown():
	## The ability follows the captain, not the ship — that is what makes the
	## roster a collectible set of heroes rather than a stat sheet.
	var a1 = _ability(1.0, 60.0)
	a1.damage_mult = 1.5
	a1.ability_id = "first"
	_ship.active_captain = _captain_with(a1)
	await wait_process_frames(1)
	_ability_node.activate()
	assert_false(_ability_node.is_ready(), "Precondition: first captain's ability spent")

	var a2 = _ability(1.0, 60.0)
	a2.speed_mult = 2.0
	a2.ability_id = "second"
	_ship.active_captain = _captain_with(a2)
	await wait_process_frames(2)

	assert_eq(_ability_node.get_ability().ability_id, "second",
		"The new captain brings their own verb")
	assert_true(_ability_node.is_ready(),
		"...usable immediately, not inheriting a spent cooldown")


# === gating ===

func test_a_docked_ship_cannot_use_an_ability():
	var a = _ability(1.0, 20.0)
	a.damage_mult = 1.5
	_ship.active_captain = _captain_with(a)
	_ship.is_docked = true
	await wait_process_frames(1)
	assert_false(_ability_node.activate(), "No abilities while tied up at a dock")

func test_a_sunk_ship_cannot_use_an_ability():
	var a = _ability(1.0, 20.0)
	a.damage_mult = 1.5
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)
	_dmg.mark_destroyed()
	assert_false(_ability_node.activate(), "A wreck has no captain's orders left to give")

func test_an_ability_never_burns_its_cooldown_without_a_modifier_layer():
	var bare = MockShip.new()
	bare.freeze = true
	var node = CaptainAbility.new()
	node.name = "CaptainAbility"
	bare.add_child(node)
	add_child_autoqfree(bare)
	var a = _ability(1.0, 20.0)
	a.damage_mult = 1.5
	bare.active_captain = _captain_with(a)
	await wait_process_frames(1)

	assert_false(node.activate(), "Refuse rather than silently spend the cooldown")
	assert_true(node.is_ready(), "...so the ability is still available")


# === instant effects ===

func test_an_instant_ability_repairs_through_the_ship_damage_write_path():
	var a = _ability(0.0, 20.0)
	a.instant_hull_fraction = 0.25
	a.instant_sails_fraction = 0.5
	a.instant_crew_fraction = 0.5
	_ship.active_captain = _captain_with(a)
	await wait_process_frames(1)

	_dmg.hull = 20.0
	_dmg.sails = 10.0
	_dmg.crew = 2.0
	assert_true(_ability_node.activate(), "A repair-only ability still fires")

	assert_almost_eq(_dmg.hull, 20.0 + 200.0 * 0.25, 0.01, "Hull restored")
	assert_almost_eq(_dmg.sails, 10.0 + 100.0 * 0.5, 0.01, "Sails restored")
	assert_almost_eq(_dmg.crew, 2.0 + 20.0 * 0.5, 0.01, "Crew rallied")
	assert_false(_mods.has_timed_effect(),
		"A purely instant ability must not register an empty timed effect")


# === authored content: all 20 captains ===

func test_every_captain_has_a_distinct_authored_active_ability():
	## The point of §10: 20 captains, 20 different things to press.
	var dir := DirAccess.open("res://resources/captains")
	assert_not_null(dir, "The captain directory must exist")

	var seen_ability_ids: Array[String] = []
	var captain_count := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		captain_count += 1
		var cap: CaptainData = load("res://resources/captains/" + f)
		assert_not_null(cap, "%s must load as CaptainData" % f)
		assert_not_null(cap.active_ability,
			"%s has no active_ability — that captain has no in-battle verb" % f)
		var a: CaptainAbilityData = cap.active_ability
		assert_ne(a.ability_id, "", "%s ability needs an id" % f)
		assert_false(seen_ability_ids.has(a.ability_id),
			"%s reuses ability id '%s' — every captain must be distinct" % [f, a.ability_id])
		seen_ability_ids.append(a.ability_id)
		assert_ne(a.display_name, "", "%s ability needs a name for the HUD" % f)
		assert_ne(a.describe(), "No effect.", "%s ability must actually do something" % f)
		assert_gt(a.cooldown, 0.0, "%s ability needs a cooldown or it is spammable" % f)
		# A timed ability with no multipliers and no instant effect is a dead button.
		if a.duration > 0.0:
			assert_true(not a.get_timed_effects().is_empty() or a.has_instant_effect(),
				"%s ability has a duration but no effect" % f)

	assert_eq(captain_count, 20, "All 20 authored captains should be covered")

func test_every_captain_has_an_authored_boarding_modifier():
	## D55: the schema and BoardingSystem's read have existed since M6, but no
	## captain set the value, so captain choice had no effect on boarding at all.
	var dir := DirAccess.open("res://resources/captains")
	var non_default := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var cap: CaptainData = load("res://resources/captains/" + f)
		assert_gt(cap.base_boarding_modifier, 0.0, "%s must author a boarding modifier" % f)
		if not is_equal_approx(cap.base_boarding_modifier, 1.0):
			non_default += 1
	assert_gt(non_default, 10,
		"Most captains should differ from 1.0, or boarding is still not a choice")

func test_the_boarding_specialist_is_mechanically_the_best_boarder():
	## docs/12_CHARACTER_BIBLE.md rule 2: flavour must match mechanics. Cutlass
	## Kane's entire authored personality is "prefers boarding to broadsides".
	var cutlass: CaptainData = load("res://resources/captains/Cutlass.tres")
	var swift: CaptainData = load("res://resources/captains/Anne.tres")
	assert_gt(cutlass.base_boarding_modifier, swift.base_boarding_modifier,
		"The boarder must out-board the scout")
	assert_gt(cutlass.base_boarding_modifier, 1.0, "...and beat the default")
