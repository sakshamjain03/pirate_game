extends GutTest
## M30 Wave 2 (2.3): BoardingDeckBuilder — gunnery shapes the deck, the bearing picks the
## entry zone, faction x class picks the roster — plus BoardingSystem's hit_tags log.
## Resources are built by hand; the authored content is checked in test_m30_boarding_content.gd.

class MockShipParent extends RigidBody3D:
	pass

var _grape := PackedStringArray(["ammo:grape", "facing:beam"])
var _chain := PackedStringArray(["ammo:chain", "facing:beam"])
var _round := PackedStringArray(["ammo:round", "facing:beam"])
var _rake := PackedStringArray(["ammo:round", "facing:stern"])

var _rules: BoardingData
var _deckhand: DefenderData
var _rigger: DefenderData
var _officer: DefenderData
var _profile: BoardingDeckProfile


func before_each() -> void:
	_rules = BoardingData.new()
	_deckhand = _def(&"deckhand", [&"ammo:grape"], [])
	_rigger = _def(&"rigger", [&"ammo:chain"], [])
	_officer = _def(&"officer", [], [&"facing:stern"], true, 8)
	_profile = BoardingDeckProfile.new()
	_profile.defenders = [_deckhand, _deckhand, _deckhand, _rigger, _rigger, _officer]
	_profile.defender_zones = PackedInt32Array([1, 1, 1, 0, 0, 2])
	_profile.min_defenders = 2


func _def(id: StringName, removed: Array, wounded: Array, officer: bool = false, hp: int = 3) -> DefenderData:
	var d := DefenderData.new()
	d.id = id
	d.hp = hp
	d.is_officer = officer
	for t in removed:
		d.removed_by_tags.append(t)
	for t in wounded:
		d.wounded_by_tags.append(t)
	return d


func _ids(deck: BoardingDeck) -> Array:
	return deck.defenders.map(func(e): return e["data"].id)


func _build(ctx: Dictionary = {}) -> BoardingDeck:
	var full := {"hit_tags": [], "facing": &"beam", "hull_fraction": 0.2, "crew_fraction": 1.0, "player_crew": 40.0}
	full.merge(ctx, true)
	return BoardingDeckBuilder.build(_profile, _rules, full)


# === Gunnery shapes the deck ===

func test_an_untouched_ship_carries_its_full_crew() -> void:
	var deck := _build()
	assert_eq(deck.defenders.size(), 6)
	assert_eq(_ids(deck).count(&"deckhand"), 3)


func test_grape_hits_remove_deckhands() -> void:
	var deck := _build({"hit_tags": [_grape, _grape]})
	assert_eq(_ids(deck).count(&"deckhand"), 1, "two grape hits, two deckhands gone")
	assert_eq(_ids(deck).count(&"rigger"), 2, "riggers untouched")


func test_chain_hits_remove_riggers() -> void:
	var deck := _build({"hit_tags": [_chain]})
	assert_eq(_ids(deck).count(&"rigger"), 1)
	assert_eq(_ids(deck).count(&"deckhand"), 3)


func test_plain_round_shot_removes_nobody() -> void:
	assert_eq(_build({"hit_tags": [_round, _round]}).defenders.size(), 6)


func test_a_stern_rake_wounds_the_officer_and_rattles_the_crew() -> void:
	var deck := _build({"hit_tags": [_rake]})
	var officer = deck.defenders.filter(func(e): return e["data"].is_officer)[0]
	assert_eq(officer["hp"], 8 - _profile.wound_per_hit)
	assert_eq(deck.morale, _profile.morale - _profile.rake_morale)


func test_wounds_never_kill_and_rakes_never_strike_before_the_first_bell() -> void:
	var deck := _build({"hit_tags": [_rake, _rake, _rake, _rake, _rake, _rake, _rake, _rake]})
	var officer = deck.defenders.filter(func(e): return e["data"].is_officer)[0]
	assert_eq(officer["hp"], 1, "a wound leaves the officer standing")
	assert_gt(deck.morale, _rules.strike_morale, "the colours are not struck by the pre-battle rakes")


func test_a_ship_bled_of_crew_is_thinly_manned_but_keeps_its_officer() -> void:
	var deck := _build({"crew_fraction": 0.5})
	assert_eq(deck.defenders.size(), 3, "6 heads at half crew")
	assert_eq(_ids(deck).count(&"officer"), 1, "the officer is never the one trimmed")
	var thin := _build({"crew_fraction": 0.0})
	assert_eq(thin.defenders.size(), _profile.min_defenders, "never below the floor")


func test_tag_removals_come_before_the_crew_trim() -> void:
	# Grape removes 3 deckhands; the trim target (50% of 6 = 3) is then already met by the rest.
	var deck := _build({"hit_tags": [_grape, _grape, _grape], "crew_fraction": 0.5})
	assert_eq(_ids(deck).count(&"deckhand"), 0)
	assert_eq(deck.defenders.size(), 3)


# === Entry by bearing ===

func test_entry_zone_follows_the_bearing() -> void:
	assert_eq(_build({"facing": &"bow"}).entry_zone, BoardingZone.Id.FORECASTLE)
	assert_eq(_build({"facing": &"beam"}).entry_zone, BoardingZone.Id.WAIST)
	assert_eq(_build({"facing": &"stern"}).entry_zone, BoardingZone.Id.QUARTERDECK)


func test_entry_facing_from_positions() -> void:
	var fwd := Vector3(0, 0, -1)  # the enemy sails toward -Z
	var o := Vector3.ZERO
	assert_eq(BoardingDeckBuilder.entry_facing(o, fwd, Vector3(0, 0, -10), _profile), &"bow", "player ahead")
	assert_eq(BoardingDeckBuilder.entry_facing(o, fwd, Vector3(0, 0, 10), _profile), &"stern", "player astern")
	assert_eq(BoardingDeckBuilder.entry_facing(o, fwd, Vector3(10, 0, 0), _profile), &"beam", "player abeam")
	assert_eq(BoardingDeckBuilder.entry_facing(o, fwd, Vector3(-10, 0, 1), _profile), &"beam")
	assert_eq(BoardingDeckBuilder.entry_facing(o, fwd, o, _profile), &"beam", "no bearing, no arc")


# === The party and the escorts ===

func test_the_party_is_a_clamped_fraction_of_the_players_crew() -> void:
	assert_eq(_build({"player_crew": 40.0}).player_hp, 10, "40 x 0.25")
	assert_eq(_build({"player_crew": 4.0}).player_hp, _rules.boarder_min)
	assert_eq(_build({"player_crew": 4000.0}).player_hp, _rules.boarder_max)


func test_outside_threats_come_from_nearby_hostiles_up_to_the_cap() -> void:
	var near := [{"id": &"a", "name": "A"}, {"id": &"b", "name": "B"}, {"id": &"c", "name": "C"}]
	var deck := _build({"threats": near})
	assert_eq(deck.outside_threats.size(), _rules.max_outside_threats)
	assert_eq(deck.outside_threats[0]["hp"], _profile.threat_hp)
	assert_eq(deck.outside_threats[0]["damage"], _profile.threat_damage)
	assert_eq(_build().outside_threats.size(), 0)


func test_the_deck_plays_in_a_battle() -> void:
	var deck := _build({"hit_tags": [_grape], "facing": &"stern"})
	var battle := BoardingBattle.new(deck, _rules, 5)
	assert_eq(battle.zone, BoardingZone.Id.QUARTERDECK)
	assert_eq(battle.defenders.size(), 5)
	assert_eq(battle.player_hp, deck.player_hp)


func test_summary_reads_the_deck() -> void:
	var s := BoardingDeckBuilder.summarize(_build({"facing": &"bow", "hull_fraction": 0.3}), _rules)
	assert_eq(s["defenders"], 6)
	assert_eq(s["officers"], 1)
	assert_eq(s["bells"], 4)
	assert_eq(s["entry"], BoardingZone.Id.FORECASTLE)


# === Picking a profile ===

func test_pick_profile_prefers_faction_and_class_then_faction_then_generic() -> void:
	var navy_small := _prof("royal_navy", 1, 2)
	var navy_big := _prof("royal_navy", 3, 5)
	var generic := _prof("", 1, 5)
	var all := [generic, navy_small, navy_big]
	assert_same(BoardingDeckBuilder.pick_profile(all, "royal_navy", 2), navy_small)
	assert_same(BoardingDeckBuilder.pick_profile(all, "royal_navy", 4), navy_big)
	assert_same(BoardingDeckBuilder.pick_profile(all, "pirate_clans", 2), generic, "no pirate profile")
	assert_same(BoardingDeckBuilder.pick_profile([navy_small], "royal_navy", 5), navy_small,
			"faction-only beats nothing when the class range misses")
	var fallback := _prof("", 1, 5)
	assert_same(BoardingDeckBuilder.pick_profile([navy_small], "pirate_clans", 2, fallback), fallback)
	assert_null(BoardingDeckBuilder.pick_profile([], "x", 1))


func _prof(faction: String, lo: int, hi: int) -> BoardingDeckProfile:
	var p := BoardingDeckProfile.new()
	p.faction_id = faction
	p.ship_class_min = lo
	p.ship_class_max = hi
	return p


# === BoardingSystem keeps the hit_tags log ===

func test_boarding_system_logs_the_players_hits_on_a_target() -> void:
	var scene := Node3D.new()
	get_tree().root.add_child(scene)
	var system := BoardingSystem.new()
	system.boarding_data = _rules
	scene.add_child(system)
	var player := _ship(scene, true)
	var enemy := _ship(scene, false)
	await wait_process_frames(2)  # _process tracks every enemy hull

	var dmg = enemy.get_node("ShipDamage")
	dmg.hit_resolved.emit(player, &"beam", {}, &"grape", _grape)
	dmg.hit_resolved.emit(null, &"beam", {}, &"round", _round)  # no source: ignored
	dmg.hit_resolved.emit(enemy, &"beam", {}, &"round", _round)  # another enemy's shot: ignored
	dmg.hit_resolved.emit(player, &"stern", {}, &"round", _rake)
	var log: Array = enemy.get_meta(BoardingSystem.HIT_LOG_META, [])
	assert_eq(log.size(), 2)
	assert_eq(log[0], _grape)

	for i in 20:
		dmg.hit_resolved.emit(player, &"beam", {}, &"round", _round)
	assert_eq((enemy.get_meta(BoardingSystem.HIT_LOG_META) as Array).size(), _rules.hit_log_size, "bounded")
	get_tree().root.remove_child(scene)
	scene.free()


func _ship(scene: Node, is_player: bool) -> Node:
	var parent := MockShipParent.new()
	parent.add_to_group("player_ship" if is_player else "enemy_ship")
	var stats := ShipStats.new()
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	scene.add_child(parent)
	return parent
