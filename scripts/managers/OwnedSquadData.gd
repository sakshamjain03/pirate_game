class_name OwnedSquadData extends Resource

## Purpose: one squad of the Ship's Company (M30 2.10) - a named body of the crew with a role, a
##   rank earned by xp, wounds from the last fight and maybe a trait.
## Responsibilities: pure data + save round trip. `ShipDamage.crew` stays the crew TOTAL (so an
##   old save loads unchanged); squads are a layer over it, held by `FleetManager.squads`. The rules
##   they follow live in `CrewRankTable`.

@export var uid: String = ""
@export var squad_name: String = ""
@export var role: StringName = &"gunners"
@export var headcount: int = 8
## Total xp, of which `boarding_xp` was won boarding (only boarding xp reaches the top ranks).
@export var xp: int = 0
@export var boarding_xp: int = 0
@export var wounds: int = 0
@export var trait_id: StringName = &""


func rank(table: CrewRankTable = null) -> int:
	if table == null:
		table = CrewRankTable.get_default()
	return table.rank_for(xp, boarding_xp)


func get_trait(table: CrewRankTable = null) -> CrewTraitData:
	if table == null:
		table = CrewRankTable.get_default()
	return table.trait_by_id(trait_id) if trait_id != &"" else null


func wound_cap(table: CrewRankTable = null) -> int:
	if table == null:
		table = CrewRankTable.get_default()
	var t := get_trait(table)
	return table.wound_cap + (t.wound_cap_bonus if t else 0)


## Out of action: no station bonus and no boarding until the wounds heal.
func is_fit(table: CrewRankTable = null) -> bool:
	return wounds < wound_cap(table)


## The sea-station multiplier now: the rank's, plus the trait's.
func station_mult(table: CrewRankTable = null) -> float:
	if table == null:
		table = CrewRankTable.get_default()
	var t := get_trait(table)
	return table.station_mult(rank(table)) + (t.station_mult_bonus if t else 0.0)


## Boarding hit points this squad brings to a Three Bells battle (0 when it is out of action).
func boarding_hp(table: CrewRankTable = null) -> int:
	if table == null:
		table = CrewRankTable.get_default()
	if not is_fit(table):
		return 0
	var per_rank := table.boarding_hp_per_rank
	var hp: int = per_rank[clampi(rank(table), 0, per_rank.size() - 1)] if per_rank.size() > 0 else 0
	var t := get_trait(table)
	return hp + (t.boarding_hp_bonus if t else 0)


func get_save_data() -> Dictionary:
	var data := {
		"uid": uid, "name": squad_name, "role": str(role), "headcount": headcount,
		"xp": xp, "boarding_xp": boarding_xp, "wounds": wounds,
	}
	# An optional key is omitted at its default.
	if trait_id != &"":
		data["trait"] = str(trait_id)
	return data


static func from_save_data(data: Dictionary) -> OwnedSquadData:
	var s := OwnedSquadData.new()
	s.uid = str(data.get("uid", ""))
	s.squad_name = str(data.get("name", ""))
	s.role = StringName(str(data.get("role", "gunners")))
	s.headcount = maxi(1, int(data.get("headcount", 8)))
	s.xp = maxi(0, int(data.get("xp", 0)))
	s.boarding_xp = clampi(int(data.get("boarding_xp", 0)), 0, s.xp)
	s.wounds = maxi(0, int(data.get("wounds", 0)))
	s.trait_id = StringName(str(data.get("trait", "")))
	return s
