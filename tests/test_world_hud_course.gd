extends GutTest

# test_world_hud_course.gd
# M22 Phase 6d — the world map's "Set Course" hands WorldHUD a waypoint:
# a course chip + a compass-rim marker, UI only (no autopilot). Covers the
# set / clear contract; arrival (within _COURSE_ARRIVE_RADIUS of the ship)
# clears it and announces.

const WorldHUDScene = preload("res://scenes/ui/WorldHUD.tscn")

var _viewport: SubViewport
var _hud: Node


func before_each():
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.disable_3d = true
	add_child(_viewport)
	_hud = WorldHUDScene.instantiate()
	_viewport.add_child(_hud)
	await wait_frames(3)


func after_each():
	get_tree().paused = false
	if is_instance_valid(_viewport):
		_viewport.queue_free()


func _island(name: String, pos: Vector2) -> IslandData:
	var d := IslandData.new()
	d.island_id = name.to_snake_case()
	d.island_name = name
	d.world_position = pos
	return d


func test_set_course_shows_the_chip_and_marker_and_clear_hides_them():
	var target := _island("Skull Cove", Vector2(400, -300))
	_hud.set_course(target)
	await wait_frames(2)
	assert_eq(_hud.get_course_target(), target)
	assert_true(_hud._course_chip.visible, "course chip shows")
	assert_true(_hud._course_marker.visible, "compass marker shows")
	_hud.clear_course()
	assert_null(_hud.get_course_target())
	assert_false(_hud._course_chip.visible)
	assert_false(_hud._course_marker.visible)


func test_arriving_clears_the_course():
	var target := _island("Skull Cove", Vector2(400, -300))
	_hud.set_course(target)
	_hud._update_course(Vector2(420, -150))
	assert_eq(_hud.get_course_target(), target, "150u out: still on course")
	_hud._update_course(Vector2(400, -290))
	assert_null(_hud.get_course_target(), "within the arrive radius the course clears itself")
