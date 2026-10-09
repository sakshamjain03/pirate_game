extends GutTest
## M30 Wave 0 (0.14): two friendly-AI side bugs.
## B4 — a friendly SUPPORT hull scanned "enemy_ship" for wounded allies, so
##      it repaired the very ships the player was sinking.
## B5 — a friendly hull attacked any "enemy_ship", including passive ambient
##      traffic at low heat, dragging the player into fights they never chose.
## Group membership mirrors EncounterManager's ally setup exactly: off
## "enemy_ship", onto "friendly_ship".

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const T0_UNKNOWN := "res://resources/balance/heat_tiers/T0_Unknown.tres"

var _saved_tier: HeatTierData
var _saved_notoriety: float
var _saved_last_gain_unix: int


## Pinning the tier alone is not enough: once EmpireManager's decay grace has
## passed, its _process re-derives the tier from `notoriety` every frame and
## overwrites the pin with whatever an earlier test leaked. Zero notoriety so
## the decay branch never runs, and restore all three afterwards.
func before_each() -> void:
	_saved_tier = EmpireManager._current_tier
	_saved_notoriety = EmpireManager.notoriety
	_saved_last_gain_unix = EmpireManager._last_gain_unix
	EmpireManager.notoriety = 0.0
	EmpireManager._last_gain_unix = int(Time.get_unix_time_from_system())


func after_each() -> void:
	EmpireManager.notoriety = _saved_notoriety
	EmpireManager._last_gain_unix = _saved_last_gain_unix
	EmpireManager._current_tier = _saved_tier


func _ship(at: Vector3, friendly: bool) -> ShipController:
	var s: ShipController = ENEMY_SHIP.instantiate()
	add_child_autofree(s)
	s.set_meta("test_pos", at)
	if friendly:
		s.remove_from_group("enemy_ship")
		s.add_to_group("friendly_ship")
	return s


## Ships settle and drift during their first frames (spawn placement,
## buoyancy); pin the layout after that so distances are what the test says.
func _settle() -> void:
	await wait_frames(2)
	for s in get_children():
		if s is ShipController and s.has_meta("test_pos"):
			s.global_position = s.get_meta("test_pos")


func _wound(ship: Node, fraction: float) -> void:
	var dmg: ShipDamage = ship.get_node("ShipDamage")
	dmg.hull = dmg.get_effective_max_health() * fraction


func test_friendly_support_never_heals_an_enemy() -> void:
	var healer := _ship(Vector3.ZERO, true)
	var enemy := _ship(Vector3(15, 0, 0), false)
	await _settle()
	_wound(enemy, 0.2)
	var ai = healer.get_node("EnemyAI")
	assert_null(ai._find_wounded_ally(), "a friendly healer patched up an enemy (B4)")


func test_friendly_support_heals_its_own_side() -> void:
	var healer := _ship(Vector3.ZERO, true)
	var enemy := _ship(Vector3(10, 0, 0), false)
	var ally := _ship(Vector3(25, 0, 0), true)
	await _settle()
	_wound(enemy, 0.2)
	_wound(ally, 0.2)
	assert_eq(healer.get_node("EnemyAI")._find_wounded_ally(), ally,
		"the nearer wounded enemy must be skipped for the friendly ally")


func test_enemy_support_still_heals_enemies() -> void:
	var healer := _ship(Vector3.ZERO, false)
	var mate := _ship(Vector3(15, 0, 0), false)
	await _settle()
	_wound(mate, 0.2)
	assert_eq(healer.get_node("EnemyAI")._find_wounded_ally(), mate)


func test_ally_ignores_passive_ambient_traffic() -> void:
	EmpireManager._current_tier = load(T0_UNKNOWN)  # low heat: ambient ships are passive
	var ally := _ship(Vector3.ZERO, true)
	var trader := _ship(Vector3(30, 0, 0), false)
	trader.add_to_group("ambient_enemy")
	await _settle()
	assert_false(trader.get_node("EnemyAI").is_provoked())
	assert_null(ally.get_node("EnemyAI")._find_nearest_hostile_enemy(),
		"an ally picked a fight with passive ambient traffic (B5)")


func test_ally_engages_a_provoked_hull() -> void:
	EmpireManager._current_tier = load(T0_UNKNOWN)
	var ally := _ship(Vector3.ZERO, true)
	var trader := _ship(Vector3(30, 0, 0), false)
	trader.add_to_group("ambient_enemy")
	await _settle()
	trader.get_node("EnemyAI").provoke()
	assert_eq(ally.get_node("EnemyAI")._find_nearest_hostile_enemy(), trader)
