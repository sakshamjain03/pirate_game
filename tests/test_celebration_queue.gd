extends GutTest

# test_celebration_queue.gd
# M22 Phase 7.2 (design.md §10, Requirement 9.2) — tier rules: two Large
# moments never overlap (the second waits for the first's CTA), while Small
# and Medium moments show immediately even during a Large.

var _host: Control
var _queue: CelebrationQueue


func before_each():
	_host = Control.new()
	add_child_autofree(_host)
	_queue = CelebrationQueue.new()
	_queue.host = _host
	add_child_autofree(_queue)


func _moment_with_cta() -> Array:
	var moment := Control.new()
	var cta := Button.new()
	moment.add_child(cta)
	return [moment, cta]


func test_a_second_large_waits_for_the_first_ctas_press():
	var first := _moment_with_cta()
	var second := _moment_with_cta()
	_queue.play(CelebrationQueue.Tier.LARGE, first[0], first[1])
	_queue.play(CelebrationQueue.Tier.LARGE, second[0], second[1])
	assert_true(first[0].is_inside_tree(), "the first Large shows at once")
	assert_false(second[0].is_inside_tree(), "the second Large must not overlap it")
	assert_eq(_queue.pending_count(), 1)

	first[1].pressed.emit()
	await wait_frames(1)
	assert_true(second[0].is_inside_tree(), "the queued Large starts on the first CTA press")
	assert_eq(_queue.pending_count(), 0)
	assert_true(_queue.is_busy())
	second[1].pressed.emit()
	await wait_frames(1)
	assert_false(_queue.is_busy())


func test_small_and_medium_play_immediately_during_a_large():
	var large := _moment_with_cta()
	_queue.play(CelebrationQueue.Tier.LARGE, large[0], large[1])
	var small := Control.new()
	var medium := Control.new()
	_queue.play(CelebrationQueue.Tier.SMALL, small)
	_queue.play(CelebrationQueue.Tier.MEDIUM, medium)
	assert_true(small.is_inside_tree(), "Small never waits")
	assert_true(medium.is_inside_tree(), "Medium plays over the live scene")
	assert_true(_queue.is_busy(), "and the Large is still up")
	large[1].pressed.emit()
	small.queue_free()
	medium.queue_free()


func test_a_large_that_leaves_the_tree_without_its_cta_still_releases_the_queue():
	var first := _moment_with_cta()
	var second := _moment_with_cta()
	_queue.play(CelebrationQueue.Tier.LARGE, first[0], first[1])
	_queue.play(CelebrationQueue.Tier.LARGE, second[0], second[1])
	first[0].queue_free()  # e.g. the World was torn down mid-celebration
	await wait_frames(2)
	assert_true(second[0].is_inside_tree(), "a dismissed Large must not wedge the queue forever")
	second[1].pressed.emit()
