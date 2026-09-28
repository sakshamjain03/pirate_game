extends GutTest

## Guards M26's campaign isolation (Requirements 1.2, 1.4, 2.x): a Maelstrom run
## must leave the campaign exactly as it found it, apart from the Eights grant.


const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const LOOT_DROP := preload("res://scenes/combat/LootDrop.tscn")
const EMPIRE_FACTION := preload("res://resources/factions/RoyalNavy.tres")

var _scene: Node3D = null
var _notoriety_before: float
var _resources_before: Dictionary


func before_each() -> void:
	# _on_died()/_spawn_loot() add explosions and crates to current_scene.
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_notoriety_before = EmpireManager.notoriety
	_resources_before = ResourceManager.current_resources.duplicate()


func after_each() -> void:
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	EmpireManager.notoriety = _notoriety_before
	ResourceManager.current_resources = _resources_before
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.free()
	_scene = null


func _kill_enemy() -> ShipController:
	var enemy := ENEMY_SHIP.instantiate() as ShipController
	enemy.faction = EMPIRE_FACTION
	_scene.add_child(enemy)
	enemy._on_died()
	return enemy


func _crates_in_scene() -> int:
	var n := 0
	for child in _scene.get_children():
		if child is LootDrop:
			n += 1
	return n


func test_empire_faction_fixture_is_empire() -> void:
	# If this ever flips, the notoriety assertions below would pass for the wrong reason.
	assert_true(EMPIRE_FACTION.get("is_empire"))


func test_maelstrom_kill_changes_no_notoriety_and_drops_no_crate() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	_kill_enemy()
	assert_eq(EmpireManager.notoriety, _notoriety_before, "Req 2.1: no notoriety from a Maelstrom kill")
	assert_eq(_crates_in_scene(), 0, "no campaign-resource crate from a Maelstrom kill")


func test_campaign_kill_still_grants_notoriety_and_crate() -> void:
	_kill_enemy()
	assert_eq(EmpireManager.notoriety, _notoriety_before + 5.0, "empire kill still +5 in the campaign")
	assert_eq(_crates_in_scene(), 1, "campaign kill still drops a crate")


func test_maelstrom_pickup_grants_no_campaign_resource_but_still_emits() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	var drop := LOOT_DROP.instantiate() as LootDrop
	drop.loot_data = {"gold": 50, "wood": 10}
	_scene.add_child(drop)
	watch_signals(drop)
	drop._collect()
	assert_signal_emitted(drop, "collected", "collected still fires so MaelstromRun can route it")
	assert_eq(ResourceManager.current_resources, _resources_before, "Req 2.2: no add_resource in the Maelstrom")


func test_campaign_pickup_still_grants_resources() -> void:
	ResourceManager.current_resources["gold"] = 0   # below any storage cap
	var gold_before: int = ResourceManager.get_resource("gold") if ResourceManager.has_method("get_resource") else int(ResourceManager.current_resources.get("gold", 0))
	var drop := LOOT_DROP.instantiate() as LootDrop
	drop.loot_data = {"gold": 50}
	_scene.add_child(drop)
	drop._collect()
	var gold_after: int = ResourceManager.get_resource("gold") if ResourceManager.has_method("get_resource") else int(ResourceManager.current_resources.get("gold", 0))
	assert_gt(gold_after, gold_before, "campaign crate still pays out")


func test_game_mode_defaults_to_campaign() -> void:
	assert_eq(SceneManager.game_mode, SceneManager.GameMode.CAMPAIGN)
	assert_true(SceneManager.is_campaign())


func test_is_campaign_flips_with_mode() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	assert_false(SceneManager.is_campaign())
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	assert_true(SceneManager.is_campaign())
