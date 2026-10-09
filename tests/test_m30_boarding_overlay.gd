extends GutTest
## M30 Wave 2 (2.5): the BoardingOverlay — opens on boarding_started, pauses the tree and
## holds autosave while open, queues orders into the battle, rings the bell, shows the result
## and pays out through BoardingSystem.resolve_tactical() AFTER it has closed (so an upgrade
## offer opened by the payout is not unpaused underneath), plus the preview strip on the
## enemy health bar. Real WorldHUD wiring is in test_m30_boarding_hud_wiring.gd.
##
## Every awaited frame happens BEFORE the overlay opens: a paused tree hangs timed awaits.

class MockShipParent extends RigidBody3D:
	pass

const OverlayScene := preload("res://scenes/ui/BoardingOverlay.tscn")
const WidgetScene := preload("res://scenes/ui/EnemyHealthBarWidget.tscn")

var _system: BoardingSystem
var _overlay: BoardingOverlay
var _player: Node
var _enemy: Node
var _scene: Node3D
var _prev_scene: Node
var _prev_resources: Dictionary = {}
var _prev_quick: bool = false


func before_each() -> void:
	_prev_scene = get_tree().current_scene
	_scene = Node3D.new()
	_scene.name = "BoardingOverlayWorld"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_prev_resources = ResourceManager.current_resources.duplicate()
	_prev_quick = SettingsManager.quick_boarding
	SettingsManager.quick_boarding = false
	for stale in get_tree().get_nodes_in_group("player_ship"):
		stale.remove_from_group("player_ship")

	_system = BoardingSystem.new()
	_system.boarding_data = (load("res://resources/combat/Boarding.tres") as BoardingData).duplicate()
	_scene.add_child(_system)
	_player = _make_ship(true, 100.0)
	_enemy = _make_ship(false, 100.0)
	_set_crews(100.0, 100.0)  # 120 vs 100 - far from the overwhelm ratio, so it is tactical

	_overlay = OverlayScene.instantiate() as BoardingOverlay
	_scene.add_child(_overlay)
	_overlay.bind_boarding_system(_system)
	await wait_process_frames(2)


func after_each() -> void:
	get_tree().paused = false
	SaveManager.hold_autosave(BoardingOverlay.AUTOSAVE_HOLD, false)
	SettingsManager.quick_boarding = _prev_quick
	ResourceManager.current_resources = _prev_resources.duplicate()
	for p in get_tree().get_nodes_in_group("player_ship"):
		if is_instance_valid(p): p.free()
	for e in get_tree().get_nodes_in_group("enemy_ship"):
		if is_instance_valid(e): e.free()
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = _prev_scene if is_instance_valid(_prev_scene) else null
		get_tree().root.remove_child(_scene)
		_scene.free()
	_scene = null


func _make_ship(is_player: bool, max_crew: float) -> Node:
	var parent := MockShipParent.new()
	parent.add_to_group("player_ship" if is_player else "enemy_ship")
	var stats := ShipStats.new()
	stats.max_crew = max_crew
	stats.display_name = "Mock Hull"
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	_scene.add_child(parent)
	return parent


func _set_crews(player_crew: float, enemy_crew: float) -> void:
	_player.get_node("ShipDamage").crew = player_crew
	_enemy.get_node("ShipDamage").crew = enemy_crew


func _open() -> void:
	# BoardingSystem._process re-derives eligibility from range and hull each frame and so
	# drops a mock target; pin it again right before the verb.
	_system._eligible_enemy = _enemy
	assert_true(_system.begin_boarding(), "precondition: a tactical boarding begins")
	assert_true(_overlay.is_open, "precondition: the overlay opened on boarding_started")


func _defender_uid(zone: int = -1) -> int:
	for d in _overlay.battle.defenders:
		if zone < 0 or d.zone == zone:
			return d.uid
	return -1


# === Opening, pausing, closing ===

func test_opens_pauses_the_tree_and_holds_autosave() -> void:
	assert_false(_overlay.visible)
	assert_false(get_tree().paused)
	_open()
	assert_true(_overlay.visible)
	assert_true(get_tree().paused, "the deck is a modal")
	assert_true(SaveManager._autosave_holds.has(BoardingOverlay.AUTOSAVE_HOLD), "no autosave mid-battle")
	assert_eq(_overlay.process_mode, Node.PROCESS_MODE_ALWAYS, "it must keep running while paused")


func test_closing_unpauses_and_releases_autosave() -> void:
	_open()
	_overlay.cut_loose()
	_overlay.finish()
	assert_false(get_tree().paused)
	assert_false(SaveManager._autosave_holds.has(BoardingOverlay.AUTOSAVE_HOLD))
	assert_false(_overlay.visible)
	assert_false(_overlay.is_open)


func test_it_closes_before_it_resolves_so_a_payout_modal_is_not_unpaused() -> void:
	_open()
	var seen := {"paused": null, "open": null}
	_system.boarding_resolved.connect(func(_s, _l, _f, _i):
		seen["paused"] = get_tree().paused
		seen["open"] = _overlay.is_open)
	_overlay.cut_loose()
	_overlay.finish()
	assert_eq(seen["paused"], false, "unpaused by the time boarding_resolved reaches the HUD/Campaign")
	assert_eq(seen["open"], false)


func test_no_upgrade_offer_can_tick_while_the_overlay_is_open() -> void:
	var mgr := EncounterManager.new()
	mgr.ambient_enabled = false
	_scene.add_child(mgr)
	assert_true(mgr.can_process(), "precondition: a manager ticks while the tree runs")
	_open()
	assert_false(mgr.can_process(),
		"EncounterManager's upgrade_interval timer is frozen with the tree, so no offer opens over the deck")
	_overlay.cut_loose()
	_overlay.finish()
	assert_true(mgr.can_process())


func test_a_second_boarding_started_signal_is_ignored_while_open() -> void:
	_open()
	var first := _overlay.battle
	_overlay._on_boarding_started(_enemy)
	assert_same(_overlay.battle, first)


# === Reading the deck ===

func test_the_deck_shows_zones_defenders_and_their_telegraphed_intent() -> void:
	_open()
	for zone_name in BoardingZone.NAMES:
		assert_not_null(_overlay._zones_row.get_node_or_null("Zone_%s" % zone_name), zone_name)
	var uid := _defender_uid()
	var tile := _overlay._zones_row.find_child("Defender_%d" % uid, true, false)
	assert_not_null(tile, "every defender is a tile")
	var intent: Label = tile.find_child("Intent", true, false)
	assert_string_contains(intent.text, tr("Next:"), "the intent is telegraphed")
	assert_eq(_overlay._morale_bar.value, float(_overlay.battle.morale))
	assert_eq(_overlay._party_bar.max_value, float(_overlay.battle.player_hp_start))


func test_the_objective_zones_are_marked() -> void:
	_open()
	var quarter: Control = _overlay._zones_row.get_node("Zone_Quarterdeck")
	var texts := quarter.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_true(texts.any(func(t): return t.contains("★")), "the Colours are marked on the quarterdeck")


func test_the_party_is_marked_in_its_entry_zone() -> void:
	_open()
	var entry := _overlay.battle.zone
	var zone: Control = _overlay._zones_row.get_node("Zone_%s" % BoardingZone.NAMES[entry])
	var texts := zone.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_true(texts.any(func(t): return t.contains("◀")))


# === Orders ===

func test_tapping_a_defender_in_reach_queues_the_default_strike() -> void:
	_open()
	var b := _overlay.battle
	var uid := _defender_uid(b.zone)
	assert_ne(uid, -1, "precondition: someone defends the entry zone")
	_overlay.tap_defender(uid)
	assert_eq(b.queued_count(), 1)
	assert_lt(b.cp_left(), b.cp)
	assert_string_contains(_overlay._queue_label.text, tr("Queued"))


func test_select_a_verb_then_a_target() -> void:
	_open()
	var b := _overlay.battle
	var parry: BoardingActionData
	for a in _system.boarding_data.actions:
		if a.id == &"parry": parry = a
	_overlay.select_action(parry)
	assert_same(_overlay.selected_action, parry)
	_overlay.tap_defender(_defender_uid(b.zone))
	assert_eq(b.queued_count(), 1)
	assert_true((b.queued()[0]["action"] as BoardingActionData).cancels_intent)
	assert_null(_overlay.selected_action, "the verb is spent")


func test_selecting_the_same_verb_twice_deselects_it() -> void:
	_open()
	var cutlass: BoardingActionData = _system.boarding_data.actions[0]
	_overlay.select_action(cutlass)
	_overlay.select_action(cutlass)
	assert_null(_overlay.selected_action)


func test_a_targetless_verb_queues_at_once_and_undo_takes_it_back() -> void:
	_open()
	var brace: BoardingActionData
	for a in _system.boarding_data.actions:
		if a.id == &"brace": brace = a
	_overlay.select_action(brace)
	assert_eq(_overlay.battle.queued_count(), 1, "Brace has no target")
	_overlay.undo()
	assert_eq(_overlay.battle.queued_count(), 0)
	assert_eq(_overlay.battle.cp_left(), _overlay.battle.cp)


func test_cp_cannot_be_overspent() -> void:
	_open()
	var b := _overlay.battle
	var uid := _defender_uid(b.zone)
	for i in 6:
		_overlay.tap_defender(uid)
	assert_eq(b.cp_left(), 0)
	assert_eq(b.queued_count(), b.cp, "three one-CP orders and no more")


func test_advance_is_offered_toward_adjacent_zones_only() -> void:
	_open()
	var here := _overlay.battle.zone
	for z in BoardingZone.COUNT:
		var btn := _overlay._zones_row.find_child("Advance_%s" % BoardingZone.NAMES[z], true, false)
		if BoardingZone.are_adjacent(here, z):
			assert_not_null(btn, "advance into %s" % BoardingZone.NAMES[z])
		else:
			assert_null(btn)


func test_outside_threats_show_as_intents_and_point_blank_answers_them() -> void:
	_open()
	var b := _overlay.battle
	b.outside_threats.append({"id": &"escort", "name": "Escort Sloop", "hp": 3, "damage": 2})
	_overlay._refresh()
	var tile: Button = _overlay._threat_row.get_node_or_null("Threat_0")
	assert_not_null(tile)
	assert_true(_overlay._threat_row.visible)
	assert_string_contains(tile.text, "2", "its next broadside is telegraphed")
	_overlay.tap_threat(0)
	assert_eq(b.queued_count(), 1)
	assert_eq((b.queued()[0]["action"] as BoardingActionData).id, &"point_blank")
	assert_eq(b.cp_left(), b.cp - 2, "Point-Blank costs 2")


func test_no_threat_row_without_threats() -> void:
	_open()
	assert_false(_overlay._threat_row.visible)


# === The bell ===

func test_ringing_the_bell_resolves_the_orders_and_logs_what_happened() -> void:
	_open()
	var b := _overlay.battle
	_overlay.tap_defender(_defender_uid(b.zone))
	_overlay.ring()
	assert_eq(b.queued_count(), 0)
	if not b.is_over():
		assert_eq(b.bell, 2)
		assert_eq(b.cp_left(), b.cp, "fresh CP")
	assert_ne(_overlay._log_label.text, "", "the player is told what happened")


func test_the_bell_rings_itself_after_bell_seconds() -> void:
	_open()
	var b := _overlay.battle
	_overlay._process(_system.boarding_data.bell_seconds * 0.5)
	assert_eq(b.bell, 1)
	_overlay._process(_system.boarding_data.bell_seconds * 0.6)
	assert_true(b.bell == 2 or b.is_over(), "6s passed, the bell rang on its own")


func test_the_timer_does_not_run_once_the_battle_is_over() -> void:
	_open()
	_overlay.cut_loose()
	var bell := _overlay.battle.bell
	_overlay._process(100.0)
	assert_eq(_overlay.battle.bell, bell)


# === Results ===

func test_cutting_loose_shows_the_result_then_pays_out_a_failure_once() -> void:
	_open()
	watch_signals(_system)
	_overlay.cut_loose()
	assert_true(_overlay._result_box.visible, "the result screen")
	assert_signal_not_emitted(_system, "boarding_resolved", "nothing is paid until Continue")
	_overlay.finish()
	assert_signal_emit_count(_system, "boarding_resolved", 1)
	assert_signal_emitted_with_parameters(_system, "boarding_resolved", [false, {}, "", ""])
	assert_eq(get_signal_parameters(_system, "boarding_outcome")[0], "cut_loose")
	assert_false(_enemy.get_node("ShipDamage").is_destroyed())
	assert_lt(_player.get_node("ShipDamage").crew, 100.0, "cutting loose costs crew")


func test_taking_the_colours_pays_out_a_win_once_and_destroys_the_hull() -> void:
	_open()
	var b := _overlay.battle
	# Clear the deck so the party seizes its landing zone at the first bell: a stern boarding
	# lands on the quarterdeck, where the Colours are.
	b.defenders.clear()
	b.zone = BoardingZone.Id.QUARTERDECK
	watch_signals(_system)
	_overlay.ring()
	assert_true(b.is_over())
	assert_eq(b.outcome["id"], "colours")
	assert_true(_overlay._result_box.visible)
	_overlay.finish()
	assert_signal_emit_count(_system, "boarding_resolved", 1)
	assert_eq(get_signal_parameters(_system, "boarding_outcome")[0], "colours")
	assert_true(_enemy.get_node("ShipDamage").is_destroyed())
	assert_eq(_enemy.get_meta("boarding_outcome", ""), "colours")
	assert_false(get_tree().paused)


func test_finish_does_nothing_while_the_battle_is_still_running() -> void:
	_open()
	watch_signals(_system)
	_overlay.finish()
	assert_signal_not_emitted(_system, "boarding_resolved")
	assert_true(_overlay.is_open)


func test_every_outcome_has_result_text() -> void:
	for id in ["colours", "struck", "hold", "magazine", "brig", "cabin", "repulsed", "cut_loose"]:
		assert_ne(_overlay.result_text({"id": id}), _overlay.result_text({"id": "nonsense"}), id)


func test_freeing_the_overlay_while_open_releases_the_pause_and_the_hold() -> void:
	_open()
	_scene.remove_child(_overlay)
	_overlay.free()
	assert_false(get_tree().paused)
	assert_false(SaveManager._autosave_holds.has(BoardingOverlay.AUTOSAVE_HOLD))
	_overlay = null


# === Preview strip on the enemy health bar ===

func test_the_preview_strip_reads_the_deck_and_hides_when_cleared() -> void:
	var widget := WidgetScene.instantiate() as EnemyHealthBarWidget
	_scene.add_child(widget)
	await wait_process_frames(1)
	widget._build_pool_bars()
	var label := widget.get_boarding_preview_label()
	assert_not_null(label)
	assert_false(label.visible, "hidden until a deck is known")
	widget.set_boarding_preview({"defenders": 5, "officers": 1, "bells": 3,
			"entry": BoardingZone.Id.WAIST, "threats": 1, "morale": 60})
	assert_true(label.visible)
	assert_string_contains(label.text, "5")
	assert_string_contains(label.text, "Waist")
	assert_string_contains(label.text, "Officer")
	assert_string_contains(label.text, "Escorts")
	widget.set_boarding_preview({})
	assert_false(label.visible)


func test_the_deck_preview_updates_live_as_gunnery_lands() -> void:
	_system._eligible_enemy = _enemy
	_system._track_hits(_enemy)
	watch_signals(_system)
	_system._emit_preview(_enemy)
	assert_signal_emit_count(_system, "deck_preview_changed", 1)
	var before: Dictionary = get_signal_parameters(_system, "deck_preview_changed")[1]
	assert_gt(int(before["defenders"]), 0)

	var dmg = _enemy.get_node("ShipDamage")
	dmg.hit_resolved.emit(_player, &"beam", {}, &"grape", PackedStringArray(["ammo:grape", "facing:beam"]))
	assert_signal_emit_count(_system, "deck_preview_changed", 2, "a hit on the eligible target refreshes it")
	var after: Dictionary = get_signal_parameters(_system, "deck_preview_changed")[1]
	assert_lt(int(after["defenders"]), int(before["defenders"]), "grape took a deckhand off the deck")
	dmg.hit_resolved.emit(null, &"beam", {}, &"grape", PackedStringArray(["ammo:grape"]))
	assert_signal_emit_count(_system, "deck_preview_changed", 2, "a stranger's shot does not")
