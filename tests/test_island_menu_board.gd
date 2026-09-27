extends GutTest

# test_island_menu_board.gd
# M22 Phase 6.1 — IslandMenu's v0.3 screen 02 tile board + right-docked
# detail panel. The board re-parents the SAME row nodes the existing builders
# create (buttons, closures, signals intact) into the detail panel; these pin
# that contract so a later refactor can't silently disconnect a Build/Hire
# button, lose the selection on every economy tick (refresh runs from
# ResourceManager.resources_changed), or show two coral Primaries.

const IslandMenuScene = preload("res://scenes/ui/IslandMenu.tscn")
const IslandScript = preload("res://scripts/world/Island.gd")

var _menu: IslandMenu
var _island: Node3D


func before_each():
	_menu = IslandMenuScene.instantiate()
	add_child_autofree(_menu)
	_island = IslandScript.new()
	var data := IslandData.new()
	data.island_type = IslandData.IslandType.CAPITAL
	_island.island_data = data
	add_child_autofree(_island)
	_menu.open(_island)
	await wait_frames(3)


func after_each():
	get_tree().paused = false


func _page(tab: int) -> Control:
	return _menu.tab_container.get_child(tab)


func _tiles(tab: int) -> Array:
	var flow := _page(tab).find_child("Tiles", true, false)
	return flow.get_children() if flow else []


func _detail_buttons(tab: int) -> Array:
	var body := _page(tab).get_node("Detail/DetailBody")
	return body.find_children("*", "Button", true, false)


func test_construction_is_a_tile_board_with_a_docked_detail():
	var tiles := _tiles(0)
	assert_gt(tiles.size(), 3, "every building is a tile")
	for t in tiles:
		assert_eq(t.theme_type_variation, &"BoardTile")
	assert_eq(tiles.filter(func(t): return t.button_pressed).size(), 1, "exactly one tile selected")
	assert_eq(_detail_buttons(0).size(), 1, "the selected entry's own Build button is docked")


func test_selecting_a_tile_docks_that_entry_with_its_real_button():
	var tiles := _tiles(0)
	tiles[2].emit_signal("pressed")
	await wait_frames(1)
	var btns := _detail_buttons(0)
	assert_eq(btns.size(), 1)
	# It is the builder's own button — still wired to _on_build_pressed.
	assert_gt(btns[0].pressed.get_connections().size(), 0,
		"the docked Build button must keep its original pressed connection")


func test_selection_survives_an_economy_tick_refresh():
	var tiles := _tiles(0)
	tiles[2].emit_signal("pressed")
	var chosen: String = tiles[2].tooltip_text
	_menu._on_resources_changed({})
	await wait_frames(3)
	var selected := _tiles(0).filter(func(t): return t.button_pressed)
	assert_eq(selected.size(), 1)
	assert_eq(selected[0].tooltip_text, chosen, "a refresh must not reset the player's selection")


func test_only_one_primary_on_the_board_page():
	var primaries := _page(0).find_children("*", "Button", true, false).filter(
		func(b): return b.visible and b.theme_type_variation == &"PrimaryButton")
	assert_lte(primaries.size(), 1)
	# Colonize is hidden on a CAPITAL island, so the docked action may be it.
	assert_false(_menu.colonize_btn.visible)


func test_fleet_and_trade_stay_card_lists():
	# Fleet ships carry level/component/module/mission rows that belong
	# together; Trade is a short list of one-tap actions (design.md §11d).
	for tab in [3, 5]:
		assert_true(_page(tab) is ScrollContainer, "tab %d stays a scrolled card list" % tab)
		assert_null(_page(tab).find_child("Tiles", true, false))


# M22 6b — a neutral island hides Construction (tab 0). TabContainer only
# re-points a hidden current tab while it is visible, so on the FIRST open
# (menu still hidden when open() configures the tabs) Construction stayed
# current: a blank page with no tab highlighted. Uses a fresh, never-shown
# menu for exactly that reason.
func test_a_neutral_island_opens_on_a_visible_tab():
	var fresh: IslandMenu = IslandMenuScene.instantiate()
	add_child_autofree(fresh)
	var neutral := IslandScript.new()
	var data := IslandData.new()
	data.island_type = IslandData.IslandType.NEUTRAL
	neutral.island_data = data
	add_child_autofree(neutral)
	fresh.open(neutral)
	await wait_frames(2)
	assert_true(fresh.tab_container.is_tab_hidden(0), "precondition: Construction is hidden on a neutral island")
	assert_false(fresh.tab_container.is_tab_hidden(fresh.tab_container.current_tab),
		"the current tab must be one the player can see")
	fresh.close()
