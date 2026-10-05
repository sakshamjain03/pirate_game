extends GutTest

## Test Fury mechanic: fills from hits, rakes, perfect braces, kills.
## Requirement W1-2.4: Fury fills from hits, rakes, Perfect Brace and kills, as
## extra fill on the existing special timer. At 1.0 the special is ready early.

var fury_data: FuryData
var brace_data: BraceData


func before_each():
	fury_data = load("res://resources/balance/Fury.tres") as FuryData
	brace_data = load("res://resources/balance/Brace.tres") as BraceData
	assert_not_null(fury_data, "FuryData must exist")
	assert_not_null(brace_data, "BraceData must exist")


func test_fury_data_exists():
	assert_not_null(fury_data)
	assert_gt(fury_data.fury_per_hit, 0.0)
	assert_gt(fury_data.rake_multiplier, 0.0)
	assert_gt(fury_data.fury_on_kill, 0.0)


func test_fury_rake_multiplier_is_higher():
	# Rakes should fill more fury than regular hits
	assert_gt(fury_data.rake_multiplier, 1.0)


func test_fury_on_kill_is_significant():
	# Killing should grant a meaningful amount of fury
	assert_gt(fury_data.fury_on_kill, 0.0)
	assert_lte(fury_data.fury_on_kill, 1.0)


func test_brace_grants_fury():
	# Perfect brace should grant fury
	assert_gt(brace_data.perfect_fury_grant, 0.0)
	assert_lte(brace_data.perfect_fury_grant, 1.0)


func test_fury_fill_rate_is_positive():
	assert_gt(fury_data.fury_fill_rate, 0.0)


func test_fury_data_values_are_reasonable():
	# Sanity checks on the values
	assert_lte(fury_data.fury_per_hit, 0.1, "fury_per_hit should be small")
	assert_lt(fury_data.fury_on_perfect_brace, 1.0, "fury_on_perfect_brace should be less than max")
