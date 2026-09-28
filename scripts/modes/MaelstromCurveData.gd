class_name MaelstromCurveData extends Resource

## Purpose: every tunable number of a Maelstrom run (M26), in one authored file
##   (resources/balance/MaelstromCurve.tres). No escalation value lives in a script.
## Responsibilities: pure data plus three lookups — band_at(), xp_for_level(),
##   eights_for().

## Sorted by start_seconds (tests/test_maelstrom_curve.gd enforces it).
@export var bands: Array[MaelstromBandData] = []

@export_group("Levelling")
## Plunder needed to go from level n+1 to n+2 (index 0 = the first level-up).
## The last value repeats forever.
@export var xp_per_level: Array[int] = []
## The level-up offer pool. Authored here rather than scanned from the folder:
## directory listing is unreliable in exported builds.
@export var upgrade_pool: Array[BattleUpgradeData] = []
@export var choices_per_offer: int = 3

@export_group("Pickups")
## Each entry: {"kind": "plunder"|"repair"|"powerup"|"keg", "weight": float,
##   "amount": float, "effect": Dictionary (powerup), "duration": float (powerup)}.
@export var drops: Array[Dictionary] = []
## Inclusive range of pickups rolled per kill.
@export var drops_per_kill: Vector2i = Vector2i(1, 2)
@export var pickup_lifetime: float = 25.0
@export var base_pickup_radius: float = 6.0
## Pickups inside (pickup radius x this) drift toward the ship.
@export var magnet_range_mult: float = 2.0
@export var keg_radius: float = 25.0
@export var keg_damage: float = 60.0

@export_group("Arena")
## Storm-wall radius around the origin; past it the ship is pushed back in.
@export var arena_radius: float = 400.0
@export var storm_push_force: float = 40.0

@export_group("Reward")
## (survived_seconds, eights) — every reached milestone pays once.
@export var eights_milestones: Array[Vector2i] = []
@export var eights_cap_per_run: int = 25


func band_at(seconds: float) -> MaelstromBandData:
	## The last band whose start is <= seconds; the first band before any starts.
	if bands.is_empty():
		push_error("MaelstromCurveData: no bands authored")
		return null
	var found: MaelstromBandData = bands[0]
	for band in bands:
		if band and band.start_seconds <= seconds:
			found = band
	return found


func band_index_at(seconds: float) -> int:
	var idx := 0
	for i in range(bands.size()):
		if bands[i] and bands[i].start_seconds <= seconds:
			idx = i
	return idx


func xp_for_level(level: int) -> int:
	## Plunder needed to leave `level` (1-based). The last authored value repeats.
	if xp_per_level.is_empty():
		push_error("MaelstromCurveData: no xp_per_level authored")
		return 1
	var i := clampi(level - 1, 0, xp_per_level.size() - 1)
	return maxi(1, xp_per_level[i])


func eights_for(seconds: float) -> int:
	var total := 0
	for m in eights_milestones:
		if seconds >= float(m.x):
			total += m.y
	return mini(total, eights_cap_per_run)
