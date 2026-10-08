extends GutTest

# test_m30_profile_pool.gd — M30 W1 task 1.3 (Requirement W1-1.1).
#
# Verify: "A profile-pool test asserts each faction's mix." Each region's
# enemy_profile_pool is pinned to its faction's authored mix (profiles, weights,
# hence tactic shares), the real EnemySpawner weighted pick is shown to honour
# those weights, and every AIProfileData.Tactic can actually spawn in the shipped
# game (a content-enabled region pool or a heat-tier squad).

const REGIONS_DIR := "res://resources/world/regions/"
const HEAT_DIR := "res://resources/balance/heat_tiers/"

## region file -> {faction, mix: {profile file: weight}}. Changing a faction's mix
## is a deliberate design change; update this table with it.
const EXPECTED := {
	"BeginnerWaters.tres": {"faction": "pirate_clans",
		"mix": {"StandardEnemy.tres": 3.0, "HarassingSloop.tres": 1.0, "Raker.tres": 1.0}},
	"ContestedWaters.tres": {"faction": "royal_navy",
		"mix": {"StandardEnemy.tres": 2.0, "HarassingSloop.tres": 2.0, "ArtilleryFrigate.tres": 1.0,
			"SupportGalleon.tres": 1.0, "LongGunner.tres": 1.0, "Fireship.tres": 1.0}},
	"ImperialWaters.tres": {"faction": "spanish_empire",
		"mix": {"StandardEnemy.tres": 1.0, "ArtilleryFrigate.tres": 2.0, "Tender.tres": 1.0,
			"AggressiveGalleon.tres": 1.0, "RamRunner.tres": 1.0}},
	"AncientOcean.tres": {"faction": "pirate_clans",
		"mix": {"AggressiveGalleon.tres": 2.0, "ArtilleryFrigate.tres": 1.0, "SupportGalleon.tres": 1.0,
			"RamRunner.tres": 1.0}},
	"GhostReaches.tres": {"faction": "ghost_fleet",
		"mix": {"AggressiveGalleon.tres": 2.0, "HarassingSloop.tres": 1.0, "Fireship.tres": 1.0}},
}

## Each faction's tactic character: tactic -> minimum normalized share of the pool.
const FACTION_TACTICS := {
	"BeginnerWaters.tres": {AIProfileData.Tactic.STANDARD: 0.5, AIProfileData.Tactic.STERN_RAKER: 0.15},
	"ContestedWaters.tres": {AIProfileData.Tactic.LONG_GUNNER: 0.1, AIProfileData.Tactic.FIRESHIP: 0.1},
	"ImperialWaters.tres": {AIProfileData.Tactic.RAM_RUNNER: 0.15, AIProfileData.Tactic.TENDER: 0.15},
	"AncientOcean.tres": {AIProfileData.Tactic.RAM_RUNNER: 0.15},
	"GhostReaches.tres": {AIProfileData.Tactic.FIRESHIP: 0.2},
}

const DRAWS := 4000
const TOLERANCE := 0.03


func _region(file: String) -> RegionData:
	var r := load(REGIONS_DIR + file) as RegionData
	assert_not_null(r, "region %s loads" % file)
	return r


## profile file -> normalized weight, read from the region exactly as authored.
func _shares(r: RegionData) -> Dictionary:
	var out := {}
	var total := 0.0
	for i in range(r.enemy_profile_pool.size()):
		var w: float = r.enemy_profile_weights[i] if r.enemy_profile_weights.size() == r.enemy_profile_pool.size() else 1.0
		total += w
	for i in range(r.enemy_profile_pool.size()):
		var p: AIProfileData = r.enemy_profile_pool[i]
		var w: float = r.enemy_profile_weights[i] if r.enemy_profile_weights.size() == r.enemy_profile_pool.size() else 1.0
		var key := p.resource_path.get_file()
		out[key] = float(out.get(key, 0.0)) + w / total
	return out


func test_every_region_file_is_covered_by_the_mix_table():
	for f in DirAccess.get_files_at(REGIONS_DIR):
		if f.ends_with(".tres") and (load(REGIONS_DIR + f) as RegionData).enemy_profile_pool.size() > 0:
			assert_true(EXPECTED.has(f), "%s has an enemy pool but no expected faction mix" % f)


func test_each_faction_region_has_its_authored_mix():
	for file in EXPECTED:
		var r := _region(file)
		var want: Dictionary = EXPECTED[file]
		assert_eq(r.dominant_faction, want["faction"], "%s faction" % file)
		assert_eq(r.enemy_profile_weights.size(), r.enemy_profile_pool.size(), "%s: one weight per profile" % file)
		var mix: Dictionary = want["mix"]
		var total := 0.0
		for k in mix:
			total += float(mix[k])
		var got := _shares(r)
		assert_eq(got.size(), mix.size(), "%s: profile set %s" % [file, got.keys()])
		for k in mix:
			assert_true(got.has(k), "%s includes %s" % [file, k])
			assert_almost_eq(float(got.get(k, 0.0)), float(mix[k]) / total, 0.0001,
				"%s: %s share" % [file, k])


func test_each_faction_has_its_tactic_character():
	for file in FACTION_TACTICS:
		var r := _region(file)
		var by_tactic := {}
		var total := 0.0
		for w in r.enemy_profile_weights:
			total += w
		for i in range(r.enemy_profile_pool.size()):
			var p: AIProfileData = r.enemy_profile_pool[i]
			by_tactic[p.tactic] = float(by_tactic.get(p.tactic, 0.0)) + r.enemy_profile_weights[i] / total
		var want: Dictionary = FACTION_TACTICS[file]
		for tactic in want:
			assert_gte(float(by_tactic.get(tactic, 0.0)), float(want[tactic]),
				"%s: tactic %s share" % [file, AIProfileData.Tactic.keys()[tactic]])


func test_spawner_weighted_pick_honours_each_factions_mix():
	# The real EnemySpawner pick (global RNG, seeded) over many draws lands within
	# TOLERANCE of each region's authored shares.
	var spawner := EnemySpawner.new()
	for file in EXPECTED:
		var r := _region(file)
		seed(20261009)
		var counts := {}
		for _i in range(DRAWS):
			var p := spawner._pick_from_weighted_pool(r.enemy_profile_pool, r.enemy_profile_weights) as AIProfileData
			var key := p.resource_path.get_file() if p else "<null>"
			counts[key] = int(counts.get(key, 0)) + 1
		var want := _shares(r)
		for k in want:
			assert_almost_eq(float(counts.get(k, 0)) / DRAWS, float(want[k]), TOLERANCE,
				"%s: drawn share of %s" % [file, k])
	spawner.free()


func test_every_tactic_can_spawn_in_the_shipped_game():
	# Reachable = in a content-enabled region's pool, or in a heat-tier squad.
	var reach := {}
	for f in DirAccess.get_files_at(REGIONS_DIR):
		if not f.ends_with(".tres"):
			continue
		var r := load(REGIONS_DIR + f) as RegionData
		if r == null or not r.content_enabled:
			continue
		for p in r.enemy_profile_pool:
			reach[p.tactic] = "%s (region pool)" % f
	for f in DirAccess.get_files_at(HEAT_DIR):
		if not f.ends_with(".tres"):
			continue
		var tier := load(HEAT_DIR + f) as HeatTierData
		for squad in tier.squad_pool:
			for slot in squad.slots:
				if slot.ai_profile:
					reach[slot.ai_profile.tactic] = "%s (heat squad)" % f
	for tactic in AIProfileData.Tactic.values():
		assert_true(reach.has(tactic),
			"Tactic %s is authored into no content-enabled pool or heat squad" % AIProfileData.Tactic.keys()[tactic])


func test_tender_profile_heals():
	var tender := load("res://resources/combat/ai_profiles/Tender.tres") as AIProfileData
	assert_eq(tender.tactic, AIProfileData.Tactic.TENDER)
	assert_eq(tender.role, AIProfileData.Role.SUPPORT, "TENDER heals through the existing SUPPORT role")
	assert_gt(tender.support_heal_rate, 0.0)


func test_all_pool_profiles_load():
	for file in EXPECTED:
		for p in _region(file).enemy_profile_pool:
			assert_true(p is AIProfileData, "%s: every pool entry is an AIProfileData" % file)
