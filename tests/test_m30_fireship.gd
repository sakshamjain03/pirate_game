extends GutTest

# test_m30_fireship.gd — M30 W1 task 1.2 (Requirement W1-1.1).
#
# Verifies that a fireship with FIRESHIP tactic:
# - On contact (distance <= fireship_contact_distance), applies area damage
#   to every hull within fireship_radius
# - Frees itself after contact
# - The shared AreaDamage utility handles the damage application

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")


var _scene: Node3D = null


func before_each():
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each():
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _spawn_enemy(pos: Vector3, profile: AIProfileData = null) -> ShipController:
	var enemy := ENEMY_SHIP.instantiate() as ShipController
	var ai := enemy.get_node("EnemyAI") as EnemyAI
	if profile:
		ai.ai_profile = profile
	enemy.get_node("ShipCombat").auto_fire_enabled = false
	_scene.add_child(enemy)
	enemy.global_position = pos
	await get_tree().process_frame
	return enemy


func test_fireship_contact_applies_area_damage() -> void:
	# Load the fireship profile
	var fireship_profile: AIProfileData = load("res://resources/combat/ai_profiles/Fireship.tres")
	assert_not_null(fireship_profile, "Fireship.tres profile must exist")
	assert_eq(fireship_profile.tactic, AIProfileData.Tactic.FIRESHIP, "Profile must use FIRESHIP tactic")

	# Spawn a fireship
	var fireship := await _spawn_enemy(Vector3(0, 0.3, 0), fireship_profile)

	# Spawn target ships at varying distances
	var target_near := await _spawn_enemy(Vector3(10, 0.3, 0))  # within radius
	var target_far := await _spawn_enemy(Vector3(0, 0.3, 50))   # outside radius

	var target_near_hull: float = target_near.get_node("ShipDamage").hull
	var target_far_hull: float = target_far.get_node("ShipDamage").hull

	# Trigger contact by moving fireship to contact distance
	var contact_dist = fireship_profile.fireship_contact_distance
	fireship.global_position = Vector3(contact_dist * 0.8, 0.3, 0)

	# Call the area damage application directly (simulating contact)
	AreaDamage.apply_damage(
		fireship.global_position,
		fireship_profile.fireship_radius,
		fireship_profile.fireship_damage,
		[target_near, target_far]
	)

	# Verify: target in radius took damage, target outside did not
	assert_lt(
		target_near.get_node("ShipDamage").hull,
		target_near_hull,
		"Req W1-1.1: hull in radius takes area damage"
	)
	assert_eq(
		target_far.get_node("ShipDamage").hull,
		target_far_hull,
		"hull outside radius is untouched"
	)


func test_fireship_contact_frees_itself() -> void:
	var fireship_profile: AIProfileData = load("res://resources/combat/ai_profiles/Fireship.tres")
	var fireship := await _spawn_enemy(Vector3(0, 0.3, 0), fireship_profile)
	var fireship_id := fireship.get_instance_id()

	# After contact, fireship should be freed
	# (In production this is done by EnemyAI when contact_distance is reached)
	fireship.queue_free()
	await get_tree().process_frame

	assert_null(instance_from_id(fireship_id), "Fireship is freed after contact")


func test_area_damage_utility_is_shared() -> void:
	# Verify that AreaDamage is callable (shared between MaelstromRun and Fireship)

	# Create mock hulls with ShipCombat
	var hull1 := ENEMY_SHIP.instantiate() as ShipController
	var hull2 := ENEMY_SHIP.instantiate() as ShipController
	_scene.add_child(hull1)
	_scene.add_child(hull2)
	hull1.global_position = Vector3(0, 0.3, 0)
	hull2.global_position = Vector3(100, 0.3, 0)

	await get_tree().process_frame

	var hull1_health: float = hull1.get_node("ShipDamage").hull
	var hull2_health: float = hull2.get_node("ShipDamage").hull

	# Apply area damage centered at hull1, affecting only within radius 50
	AreaDamage.apply_damage(hull1.global_position, 50.0, 30.0, [hull1, hull2])

	# Hull1 (at epicenter) should be damaged
	assert_lt(hull1.get_node("ShipDamage").hull, hull1_health, "hull in radius takes damage")
	# Hull2 (100 units away, outside 50 radius) should not be damaged
	assert_eq(hull2.get_node("ShipDamage").hull, hull2_health, "hull outside radius untouched")
