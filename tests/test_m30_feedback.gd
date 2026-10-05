extends GutTest
## M30 W1 task 1.11 — feedback pack for combat clarity.
## Rake cone, ribbons (at most 3), colour damage numbers, camera punch,
## haptics, and reduced motion support.

var _ribbons: RibbonStack


func before_each() -> void:
	_ribbons = RibbonStack.new()
	_ribbons.max_ribbons = 3
	add_child_autofree(_ribbons)


func test_ribbon_stack_respects_capacity() -> void:
	_ribbons.add_ribbon("ribbon_1")
	_ribbons.add_ribbon("ribbon_2")
	_ribbons.add_ribbon("ribbon_3")
	assert_eq(_ribbons.get_ribbon_count(), 3, "at capacity with 3 ribbons")

	_ribbons.add_ribbon("ribbon_4")
	assert_eq(_ribbons.get_ribbon_count(), 3, "cap holds at 3")


func test_ribbon_stack_can_clear() -> void:
	_ribbons.add_ribbon("ribbon_1")
	_ribbons.add_ribbon("ribbon_2")
	assert_eq(_ribbons.get_ribbon_count(), 2)

	_ribbons.clear()
	assert_eq(_ribbons.get_ribbon_count(), 0, "clear removes all ribbons")
