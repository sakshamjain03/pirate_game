extends GutTest

var faction_manager: FactionManager
var empire_manager: EnemyManager
var spawner: Node

func before_each() -> void:
	faction_manager = FactionManager
	# Reset reputation to known state
	faction_manager.reputation_scores = {
		"pirate_clans": -50,
		"royal_navy": -50,
		"merchant_guild": 20
	}

func test_reputation_loss_on_enemy_destroyed() -> void:
	pending("Wait for EnemySpawner signal wiring to be implemented")

	# Get initial reputation
	var initial = faction_manager.get_reputation("royal_navy")

	# Simulate enemy destroyed signal with faction metadata
	var mock_enemy = Node.new()
	var navy_faction = load("res://resources/factions/RoyalNavy.tres") as FactionData
	mock_enemy.set_meta("faction", navy_faction)

	# Signal the destruction
	var spawner_mock = Node.new()
	if spawner_mock.has_signal("enemy_destroyed"):
		spawner_mock.emit_signal("enemy_destroyed", mock_enemy)

	# Should have lost reputation equal to sink_reputation_loss
	var final = faction_manager.get_reputation("royal_navy")
	assert_eq(final, initial - navy_faction.sink_reputation_loss,
		"Reputation should decrease by sink_reputation_loss")

func test_no_reputation_loss_in_maelstrom() -> void:
	pending("Maelstrom mode detection needed")

	# When not in campaign, no reputation loss should apply
	var initial = faction_manager.get_reputation("royal_navy")

	# Simulate enemy destroyed in non-campaign mode
	# (Would need to mock SceneManager.is_campaign() returning false)

	var final = faction_manager.get_reputation("royal_navy")
	assert_eq(final, initial, "No reputation change outside campaign mode")

func test_no_double_count_on_boarded_ship() -> void:
	pending("Boarded ship loot_claimed meta check needed")

	# When a ship is boarded, only boarding loss applies, not sink loss
	var initial_rep = faction_manager.get_reputation("royal_navy")

	# Would need to simulate boarding_resolved being called first,
	# then enemy_destroyed with loot_claimed meta set

func test_boarding_reputation_loss() -> void:
	pending("Wait for BoardingSystem signal wiring")

	# Simulate boarding_resolved signal
	var initial = faction_manager.get_reputation("royal_navy")
	var boarding_data = load("res://resources/factions/RoyalNavy.tres") as FactionData

	# This would be emitted by BoardingSystem
	# boarding_resolved.emit(true, {}, "royal_navy", "ship_id")

	var final = faction_manager.get_reputation("royal_navy")
	assert_eq(final, initial - boarding_data.boarding_reputation_loss,
		"Reputation should decrease by boarding_reputation_loss on successful board")

func test_unknown_faction_id_pushes_error() -> void:
	pending("Error handling on unknown faction")

	# Attempting to apply loss to unknown faction should push_error
	# This needs to be tested once the signal handlers are implemented
	pass
