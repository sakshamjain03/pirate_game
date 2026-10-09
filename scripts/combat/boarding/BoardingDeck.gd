class_name BoardingDeck extends RefCounted

## Purpose: everything `BoardingBattle` needs to start (M30 2.2) — the enemy ship as the
##   player's gunnery left it. Built by `BoardingDeckBuilder` (2.3); tests build one by hand.
## Responsibilities: a plain value holder, no logic.

## Each entry: {"data": DefenderData, "zone": BoardingZone.Id, "hp": int (optional, a wound)}.
var defenders: Array = []
## Where the boarding party lands (from the relative bearing at the tap).
var entry_zone: int = BoardingZone.Id.WAIST
var objectives: Array[BoardingObjectiveData] = []
## Enemy hull fraction when boarding began; sets the number of bells.
var hull_fraction: float = 0.2
## Boarders the player brings (the party's pool, lost to enemy blows).
var player_hp: int = 12
## Enemy morale before the first bell. Gunnery rakes pre-drain it.
var morale: int = 60
## Hostiles still firing from outside the grapple: {"id": StringName, "name": String,
## "hp": int, "damage": int}. Answered with Brace or Point-Blank.
var outside_threats: Array = []
## Timed events: {"bell": int, "kind": "jettison"|"officers_escape"}. A bell of -1 means the last bell.
var timed_events: Array = []
## Roles the party can field (2.10); empty means every action is available to anyone.
var roles: Array[StringName] = []
