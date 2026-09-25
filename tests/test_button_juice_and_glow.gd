extends GutTest

# test_button_juice_and_glow.gd
# M22 Phase 3.3 (design.md §7) — ButtonJuice's press feedback moved from a
# scale tween to a self_modulate darken (1 -> 0.88 -> 1), and
# PirateThemeBuilder.mark_primary() attaches an idempotent PrimaryGlow.
# Deliberately split out of test_theme_variations.gd: this file has no
# before_each rebuilding the whole Theme, since the press-timing assertion
# here is real-time-sensitive (see tests/test_theme_variations.gd's header).

func test_mark_primary_sets_variation_and_adds_exactly_one_glow():
	var btn := Button.new()
	add_child_autofree(btn)
	PirateThemeBuilder.mark_primary(btn)
	assert_eq(btn.theme_type_variation, &"PrimaryButton")
	assert_eq(_count_glow_children(btn), 1)

	PirateThemeBuilder.mark_primary(btn)
	assert_eq(_count_glow_children(btn), 1, "mark_primary() must be idempotent — no second glow")


func _count_glow_children(btn: Button) -> int:
	var count := 0
	for child in btn.get_children():
		if child is PrimaryGlow:
			count += 1
	return count


func test_button_juice_darkens_self_modulate_on_press_and_restores_on_release():
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 40)
	add_child_autofree(btn)
	btn.add_child(ButtonJuice.new())
	await wait_process_frames(1)

	btn.emit_signal("button_down")
	await wait_seconds(UITokens.PRESS_IN_SEC + 0.05)
	assert_almost_eq(btn.self_modulate.r, UITokens.PRESS_DARKEN_TO, 0.03)

	btn.emit_signal("button_up")
	await wait_seconds(UITokens.PRESS_OUT_SEC + 0.05)
	assert_almost_eq(btn.self_modulate.r, 1.0, 0.03)
