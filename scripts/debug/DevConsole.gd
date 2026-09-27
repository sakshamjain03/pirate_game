extends CanvasLayer

## Purpose: developer-only cheat console (docs plan Wave 0, 1.12). Lets a
## developer reach any game state without playing to it — max resources, jump
## chapters, grant/level/downgrade ships, capture islands, set building levels.
##
## SAFETY CONTRACT — read before editing:
##   1. This file lives in scripts/debug/ and is reachable ONLY through
##      scenes/debug/DevHarness.tscn, the same pattern CaptureHarness already
##      uses. NO shipping script may reference it, and no gameplay file may
##      carry an `if dev_mode` branch. tests/test_no_shipping_reference_to_debug.gd
##      fails the build if that is ever violated.
##   2. It calls only PUBLIC manager APIs and public fields. If a cheat would
##      need a new hook inside a manager, that hook must be an API the game
##      itself uses — otherwise the cheat does not get built.
##   3. export_presets.cfg excludes scripts/debug/* and scenes/debug/*, so this
##      is physically absent from a release build -- but that file is GITIGNORED,
##      so the filter is per-machine and a fresh clone will not have it. It is a
##      step in docs/RELEASE_CHECKLIST.md section 4, not something the repo can
##      enforce. Rules 1 and 2 are the guarantees that survive a clone.
##
## Toggle with F1. Debug builds only — frees itself in a release build as a
## third layer of defence behind the export filter and the harness scene.

const TOGGLE_ACTION_KEY := KEY_F1
const RESOURCE_KEYS := ["gold", "wood", "iron", "rum", "research"]

var _root: PanelContainer
var _tabs: TabContainer
var _status: Label
var _god_mode := false


func _ready() -> void:
	if not OS.is_debug_build():
		push_warning("DevConsole reached a non-debug build and removed itself.")
		queue_free()
		return
	layer = 128
	_build_ui()
	_root.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == TOGGLE_ACTION_KEY:
		_root.visible = not _root.visible
		if _root.visible:
			_refresh_all()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- UI plumbing

func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.custom_minimum_size = Vector2(560, 620)
	_root.position = Vector2(16, 16)
	add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_root.add_child(outer)

	var title := Label.new()
	title.text = "DEV CONSOLE  —  F1 to close  —  debug build only"
	outer.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Ready."
	outer.add_child(_status)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_tabs)

	_tabs.add_child(_make_resources_tab())
	_tabs.add_child(_make_progression_tab())
	_tabs.add_child(_make_fleet_tab())
	_tabs.add_child(_make_islands_tab())
	_tabs.add_child(_make_combat_tab())


## Every tab is a scrolling VBox — the console outgrows one screen fast, and a
## fixed layout would start hiding cheats as waves add more.
func _make_page(tab_name: String) -> ScrollContainer:
	var page := ScrollContainer.new()
	page.name = tab_name
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.name = "Body"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(box)
	return page


func _body_of(page: Node) -> VBoxContainer:
	return page.get_node("Body") as VBoxContainer


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	return b


func _row(buttons: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	for b in buttons:
		h.add_child(b)
	return h


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = "— %s —" % text
	return l


func _say(text: String) -> void:
	_status.text = text
	print("[DevConsole] ", text)


func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func _refresh_all() -> void:
	for page in _tabs.get_children():
		match page.name:
			"Resources": _fill_resources()
			"Progression": _fill_progression()
			"Fleet": _fill_fleet()
			"Islands": _fill_islands()


# ------------------------------------------------------------------ Resources

func _make_resources_tab() -> ScrollContainer:
	var page := _make_page("Resources")
	var body := _body_of(page)
	body.add_child(_heading("Bulk"))
	body.add_child(_row([
		_button("Max all", _cheat_max_resources),
		_button("Zero all", _cheat_zero_resources),
		_button("+1000 each", func(): _cheat_add_all(1000)),
	]))
	body.add_child(_heading("Current"))
	var list := VBoxContainer.new()
	list.name = "List"
	body.add_child(list)
	return page


func _fill_resources() -> void:
	var page := _tabs.get_node_or_null("Resources")
	if not page:
		return
	var list := _body_of(page).get_node_or_null("List")
	if not list:
		return
	_clear(list)
	for key in RESOURCE_KEYS:
		var have := int(ResourceManager.get_resource(key))
		var cap := int(ResourceManager.max_storage.get(key, 0))
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%-10s %6d / %-6d" % [key, have, cap]
		l.custom_minimum_size.x = 220
		row.add_child(l)
		row.add_child(_button("+100", func(): _cheat_add(key, 100)))
		row.add_child(_button("+1k", func(): _cheat_add(key, 1000)))
		row.add_child(_button("Fill", func(): _cheat_fill(key)))
		row.add_child(_button("Empty", func(): _cheat_empty(key)))
		list.add_child(row)


func _cheat_add(key: String, amount: int) -> void:
	ResourceManager.add_resource(key, amount)
	_say("+%d %s" % [amount, key])
	_fill_resources()


func _cheat_fill(key: String) -> void:
	var missing := int(ResourceManager.max_storage.get(key, 0)) - int(ResourceManager.get_resource(key))
	if missing > 0:
		ResourceManager.add_resource(key, missing)
	_say("filled %s to cap" % key)
	_fill_resources()


func _cheat_empty(key: String) -> void:
	ResourceManager.spend_resource(key, int(ResourceManager.get_resource(key)))
	_say("emptied %s" % key)
	_fill_resources()


func _cheat_add_all(amount: int) -> void:
	for key in RESOURCE_KEYS:
		ResourceManager.add_resource(key, amount)
	_say("+%d to every resource" % amount)
	_fill_resources()


func _cheat_max_resources() -> void:
	for key in RESOURCE_KEYS:
		_cheat_fill(key)
	_say("all resources at cap")


func _cheat_zero_resources() -> void:
	for key in RESOURCE_KEYS:
		_cheat_empty(key)
	_say("all resources zeroed")


# ---------------------------------------------------------------- Progression

func _make_progression_tab() -> ScrollContainer:
	var page := _make_page("Progression")
	var body := _body_of(page)
	body.add_child(_heading("Notoriety"))
	body.add_child(_row([
		_button("+25", func(): _cheat_notoriety(25.0)),
		_button("+60 (Contested)", func(): _cheat_notoriety_to(60.0)),
		_button("+150 (Imperial)", func(): _cheat_notoriety_to(150.0)),
		_button("Reset", func(): _cheat_notoriety_to(0.0)),
	]))
	body.add_child(_heading("Research"))
	body.add_child(_row([_button("Unlock all techs", _cheat_unlock_all_techs)]))
	body.add_child(_heading("Chapters"))
	var list := VBoxContainer.new()
	list.name = "List"
	body.add_child(list)
	return page


func _fill_progression() -> void:
	var page := _tabs.get_node_or_null("Progression")
	if not page:
		return
	var list := _body_of(page).get_node_or_null("List")
	if not list:
		return
	_clear(list)

	var head := Label.new()
	head.text = "Notoriety %.1f   |   %d chapter(s) enabled" % [
		EmpireManager.notoriety, CampaignManager.chapters.size()]
	list.add_child(head)

	for chapter in CampaignManager.chapters:
		var done: bool = CampaignManager.is_chapter_completed(chapter.chapter_id)
		var cur: bool = CampaignManager.is_chapter_current(chapter.chapter_id)
		var row := HBoxContainer.new()
		var l := Label.new()
		var mark := "DONE" if done else ("NOW " if cur else "    ")
		l.text = "%s Ch%d  %s" % [mark, chapter.chapter_number, chapter.title]
		l.custom_minimum_size.x = 330
		row.add_child(l)
		var id: String = chapter.chapter_id
		row.add_child(_button("Complete", func(): _cheat_complete_chapter(id)))
		list.add_child(row)


func _cheat_notoriety(delta: float) -> void:
	EmpireManager.add_notoriety(delta)
	_say("notoriety %.1f" % EmpireManager.notoriety)
	_fill_progression()


func _cheat_notoriety_to(target: float) -> void:
	EmpireManager.add_notoriety(target - EmpireManager.notoriety)
	_say("notoriety set to %.1f" % EmpireManager.notoriety)
	_fill_progression()


## Marks a chapter complete through CampaignManager's own save path rather than
## poking privates: write completed_chapter_ids, then round-trip load_save_data
## so the manager re-runs its real catch-up/gating logic. A dev shortcut must
## not be able to reach a state the game itself cannot reach.
func _cheat_complete_chapter(chapter_id: String) -> void:
	var data: Dictionary = CampaignManager.get_save_data()
	var done: Array = data.get("completed_chapter_ids", [])
	for c in CampaignManager.chapters:
		if not done.has(c.chapter_id):
			done.append(c.chapter_id)
		if c.chapter_id == chapter_id:
			break
	data["completed_chapter_ids"] = done
	CampaignManager.load_save_data(data)
	_say("completed through %s" % chapter_id)
	_fill_progression()


func _cheat_unlock_all_techs() -> void:
	var dir := DirAccess.open("res://resources/techs/")
	if not dir:
		_say("no resources/techs/ directory")
		return
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var tech = load("res://resources/techs/" + file_name)
			if tech and not TechManager.is_unlocked(tech.tech_id):
				TechManager.unlock_tech(tech)
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	_say("unlocked %d tech(s)" % count)


# --------------------------------------------------------------------- Fleet

func _make_fleet_tab() -> ScrollContainer:
	var page := _make_page("Fleet")
	var body := _body_of(page)
	body.add_child(_heading("Grant"))
	body.add_child(_row([
		_button("All hulls", _cheat_grant_all_hulls),
		_button("All captains", _cheat_grant_all_captains),
	]))
	body.add_child(_heading("Owned ships"))
	var ships := VBoxContainer.new()
	ships.name = "Ships"
	body.add_child(ships)
	body.add_child(_heading("Owned captains"))
	var caps := VBoxContainer.new()
	caps.name = "Captains"
	body.add_child(caps)
	return page


func _fill_fleet() -> void:
	var page := _tabs.get_node_or_null("Fleet")
	if not page:
		return
	var body := _body_of(page)
	var ships := body.get_node_or_null("Ships")
	var caps := body.get_node_or_null("Captains")
	if not ships or not caps:
		return
	_clear(ships)
	_clear(caps)

	for i in FleetManager.owned_ships.size():
		var owned = FleetManager.owned_ships[i]
		if owned == null:
			continue
		var idx := i
		var row := HBoxContainer.new()
		var l := Label.new()
		var hull_name: String = owned.ship_stats.display_name if owned.ship_stats else "?"
		var active := " *ACTIVE*" if i == FleetManager.active_ship_index else ""
		l.text = "%-14s L%-2d%s" % [hull_name, owned.level, active]
		l.custom_minimum_size.x = 220
		row.add_child(l)
		row.add_child(_button("L+", func(): _cheat_set_ship_level(idx, owned.level + 1)))
		row.add_child(_button("L-", func(): _cheat_set_ship_level(idx, owned.level - 1)))
		row.add_child(_button("Max", func(): _cheat_set_ship_level(idx, OwnedShipData.MAX_LEVEL)))
		row.add_child(_button("Make active", func(): _cheat_set_active_ship(idx)))
		ships.add_child(row)

	for i in FleetManager.owned_captains.size():
		var cap = FleetManager.owned_captains[i]
		if cap == null:
			continue
		var c = cap
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%-16s L%-3d" % [cap.captain_name, cap.level]
		l.custom_minimum_size.x = 220
		row.add_child(l)
		row.add_child(_button("L+", func(): _cheat_set_captain_level(c, c.level + 1)))
		row.add_child(_button("L-", func(): _cheat_set_captain_level(c, c.level - 1)))
		row.add_child(_button("L10", func(): _cheat_set_captain_level(c, 10)))
		caps.add_child(row)


## Sets level directly rather than going through FleetManager.level_up_ship(),
## which charges resources and enforces the component-catch-up gate. Dev mode
## needs to go DOWN as well as up, which no shipping path offers.
func _cheat_set_ship_level(index: int, to_level: int) -> void:
	if index < 0 or index >= FleetManager.owned_ships.size():
		return
	var owned = FleetManager.owned_ships[index]
	owned.level = clampi(to_level, 1, OwnedShipData.MAX_LEVEL)
	# Components are capped at the ship's level, so a downgrade has to bring
	# them with it or the ship lands in a state the game cannot produce.
	owned.set_all_components(owned.level)
	_reapply_active_ship()
	FleetManager.fleet_changed.emit()
	_say("ship %d -> level %d" % [index, owned.level])
	_fill_fleet()


func _cheat_set_active_ship(index: int) -> void:
	FleetManager.active_ship_index = index
	_reapply_active_ship()
	FleetManager.fleet_changed.emit()
	_say("active ship -> %d" % index)
	_fill_fleet()


func _cheat_set_captain_level(captain, to_level: int) -> void:
	captain.level = maxi(1, to_level)
	captain.current_xp = 0
	FleetManager.fleet_changed.emit()
	_say("%s -> level %d" % [captain.captain_name, captain.level])
	_fill_fleet()


## Mirrors what FleetManager does internally after a level/module change, using
## only its public get_active_ship().
func _reapply_active_ship() -> void:
	var player := get_tree().get_first_node_in_group("player_ship")
	if player and "ship_stats" in player:
		player.ship_stats = FleetManager.get_active_ship()


func _cheat_grant_all_hulls() -> void:
	var count := 0
	var dir := DirAccess.open("res://resources/ships/")
	if not dir:
		_say("no resources/ships/ directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var hull = load("res://resources/ships/" + file_name)
			if hull is ShipStats and not FleetManager.owns_ship_stats(hull):
				FleetManager.add_ship(hull)
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	_say("granted %d hull(s)" % count)
	_fill_fleet()


func _cheat_grant_all_captains() -> void:
	var count := 0
	var dir := DirAccess.open("res://resources/captains/")
	if not dir:
		_say("no resources/captains/ directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var cap = load("res://resources/captains/" + file_name)
			# Respects the MVP content gate on purpose: the console is for
			# testing the game that ships, not the one that does not.
			if cap is CaptainData and ResourceLookup.is_content_enabled(cap) \
					and not FleetManager.owned_captains.has(cap):
				FleetManager.add_captain(cap)
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	_say("granted %d captain(s)" % count)
	_fill_fleet()


# ------------------------------------------------------------------- Islands

func _make_islands_tab() -> ScrollContainer:
	var page := _make_page("Islands")
	var body := _body_of(page)
	body.add_child(_heading("Bulk"))
	body.add_child(_row([
		_button("Capture all", func(): _cheat_capture_all(true)),
		_button("Release all", func(): _cheat_capture_all(false)),
	]))
	body.add_child(_heading("Live islands (content-gated ones are absent by design)"))
	var list := VBoxContainer.new()
	list.name = "List"
	body.add_child(list)
	return page


func _fill_islands() -> void:
	var page := _tabs.get_node_or_null("Islands")
	if not page:
		return
	var list := _body_of(page).get_node_or_null("List")
	if not list:
		return
	_clear(list)
	for island in get_tree().get_nodes_in_group("islands"):
		if not is_instance_valid(island):
			continue
		var node := island
		var row := HBoxContainer.new()
		var l := Label.new()
		var owned: bool = island.island_data and island.island_data.is_owned_by_player()
		l.text = "%-20s T%d %s" % [
			island.get_island_name(), island.get_island_tier(), "[OWNED]" if owned else ""]
		l.custom_minimum_size.x = 250
		row.add_child(l)
		row.add_child(_button("Capture", func(): _cheat_capture(node, true)))
		row.add_child(_button("Release", func(): _cheat_capture(node, false)))
		row.add_child(_button("Sail to", func(): _cheat_teleport_to(node)))
		list.add_child(row)


func _cheat_capture(island: Node, owned: bool) -> void:
	if not is_instance_valid(island) or not island.island_data:
		return
	if owned:
		island.capture_island(FactionManager.get_player_faction())
	else:
		# capture_island() is the only ownership mutator the game exposes and it
		# is one-way, so releasing writes island_type back directly -- the same
		# field capture_island() sets.
		island.island_data.island_type = IslandData.IslandType.NEUTRAL
		island.island_data.owner_faction = null
	_say("%s -> %s" % [island.get_island_name(), "owned" if owned else "neutral"])
	_fill_islands()


func _cheat_capture_all(owned: bool) -> void:
	for island in get_tree().get_nodes_in_group("islands"):
		_cheat_capture(island, owned)
	_say("all islands -> %s" % ("owned" if owned else "neutral"))


## Puts the player just outside the island's collision radius rather than on top
## of it -- EnemySpawner.min_distance_from_islands (55u) is the established
## "clear of the terrain" number, and dropping a RigidBody3D inside the hull
## mesh is how ships end up beached or capsized.
func _cheat_teleport_to(island: Node) -> void:
	var player := get_tree().get_first_node_in_group("player_ship")
	if not player or not is_instance_valid(island):
		_say("no player ship in the tree")
		return
	var target: Vector3 = island.global_position + Vector3(60.0, 0.0, 0.0)
	target.y = player.global_position.y
	player.global_position = target
	if player is RigidBody3D:
		player.linear_velocity = Vector3.ZERO
		player.angular_velocity = Vector3.ZERO
	_say("sailed to %s" % island.get_island_name())


# -------------------------------------------------------------------- Combat

func _make_combat_tab() -> ScrollContainer:
	var page := _make_page("Combat")
	var body := _body_of(page)
	body.add_child(_heading("Player"))
	body.add_child(_row([
		_button("Heal to full", _cheat_heal_player),
		_button("God mode", _cheat_toggle_god),
	]))
	body.add_child(_heading("Enemies"))
	body.add_child(_row([
		_button("Kill all enemies", _cheat_kill_enemies),
		_button("Damage all to 10%", _cheat_cripple_enemies),
	]))
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Timer and siege controls arrive with ScheduleManager and SiegeManager."
	body.add_child(note)
	return page


func _player_damage() -> Node:
	var player := get_tree().get_first_node_in_group("player_ship")
	return player.get_node_or_null("ShipDamage") if player else null


func _cheat_heal_player() -> void:
	var dmg := _player_damage()
	if not dmg:
		_say("no player ShipDamage node")
		return
	if dmg.has_method("restore_all"):
		dmg.restore_all()
		_say("player restored to full")
	else:
		_say("ShipDamage has no restore_all()")


func _cheat_toggle_god() -> void:
	_god_mode = not _god_mode
	_say("god mode %s (re-applies each time you heal)" % ("ON" if _god_mode else "OFF"))
	if _god_mode:
		_cheat_heal_player()


func _process(_delta: float) -> void:
	if not _god_mode:
		return
	var dmg := _player_damage()
	if dmg and dmg.has_method("restore_all"):
		dmg.restore_all()


func _cheat_kill_enemies() -> void:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy_ship"):
		if not is_instance_valid(enemy):
			continue
		var dmg = enemy.get_node_or_null("ShipDamage")
		if dmg and dmg.has_method("mark_destroyed"):
			dmg.hull = 0.0
			dmg.mark_destroyed()
			count += 1
	_say("destroyed %d enemy ship(s)" % count)


func _cheat_cripple_enemies() -> void:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy_ship"):
		if not is_instance_valid(enemy):
			continue
		var dmg = enemy.get_node_or_null("ShipDamage")
		if dmg == null:
			continue
		var maximum: float = dmg.get_effective_max_health() \
			if dmg.has_method("get_effective_max_health") else dmg.ship_stats.max_health
		dmg.hull = maximum * 0.1
		count += 1
	_say("crippled %d enemy ship(s) to 10%% hull" % count)
