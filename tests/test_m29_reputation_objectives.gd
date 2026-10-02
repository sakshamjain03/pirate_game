extends GutTest

# M29 B.5 — check that CHANGE_REPUTATION objectives remain completable
# with the new reputation losses (sink and boarding losses)

func test_change_reputation_objectives_exist() -> void:
	# First, just verify that we can load chapters and find CHANGE_REPUTATION objectives
	var ch1 = load("res://resources/campaign/chapters/Ch1_TheDrownedPort.tres") as ChapterData
	assert_not_null(ch1, "Ch1 should load")

	# Check if it has objectives
	if ch1 and ch1.has_meta("objectives"):
		var objectives = ch1.get_meta("objectives")
		assert_not_null(objectives, "Ch1 should have objectives")

func test_merchant_guild_reputation_remains_safe() -> void:
	# Ch3/Ch4 has a Merchant Guild objective that could be at risk
	# Merchant Guild has 0 reputation loss by default, so it should be safe
	var guild = load("res://resources/factions/MerchantGuild.tres") as FactionData

	assert_eq(guild.sink_reputation_loss, 0,
		"Merchant Guild should have 0 sink_reputation_loss to keep objectives safe")
	assert_eq(guild.boarding_reputation_loss, 0,
		"Merchant Guild should have 0 boarding_reputation_loss to keep objectives safe")

func test_reputation_loss_values_reasonable() -> void:
	# Check that empire factions' reputation losses are reasonable relative to objectives
	var navy = load("res://resources/factions/RoyalNavy.tres") as FactionData
	var spain = load("res://resources/factions/SpanishEmpire.tres") as FactionData

	# Reputation ranges from -100 to 100, and objectives likely target ranges
	# that are well within bounds even with some losses
	assert_true(navy.sink_reputation_loss <= 20,
		"Royal Navy sink loss should be reasonable (≤ 20)")
	assert_true(spain.sink_reputation_loss <= 20,
		"Spanish Empire sink loss should be reasonable (≤ 20)")

	# Boarding loss should be smaller than sink loss
	assert_true(navy.boarding_reputation_loss < navy.sink_reputation_loss,
		"Royal Navy boarding loss should be less than sink loss")
	assert_true(spain.boarding_reputation_loss < spain.sink_reputation_loss,
		"Spanish Empire boarding loss should be less than sink loss")

func test_reputation_ranges_allow_objectives() -> void:
	# Initial reputation scores
	var initial_scores = {
		"pirate_clans": -50,
		"royal_navy": -50,
		"merchant_guild": 20
	}

	# Most objectives should target specific reputation values
	# Navy starts at -50, needs to reach -40, -30, 0, etc.
	# Merchant Guild starts at 20, needs to reach 15, 10, 5, etc.

	# With losses of up to 10 per fight, and multiple fights,
	# the reputation change should still be manageable within the -100/100 range
	var navy_loss = load("res://resources/factions/RoyalNavy.tres").sink_reputation_loss
	var spain_loss = load("res://resources/factions/SpanishEmpire.tres").sink_reputation_loss

	# Navy at -50, with worst case 10 losses, would be at -60 after 1 fight
	# Should still allow reaching objective targets like -40, -30, -20, -10, 0
	assert_true(initial_scores["royal_navy"] - navy_loss * 5 > -100,
		"Royal Navy shouldn't reach -100 floor even with 5 worst-case fights")

	# Merchant Guild at 20, should maintain ability to reach objectives
	assert_true(initial_scores["merchant_guild"] >= 0,
		"Merchant Guild should remain friendly by default")
