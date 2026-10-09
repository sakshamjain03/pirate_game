@tool
class_name BoardingDeckProfile extends Resource

## Purpose: what a faction's ship of a given class carries when boarded (M30 2.3) — its
##   roster, where they stand, its morale, its timed events and which zones are worth seizing.
## Responsibilities: pure data, picked by `BoardingDeckBuilder.pick_profile()` (an exact faction
##   plus class-range match beats a faction-only one, which beats the faction-less default).

## The faction this profile is for; empty matches any faction (the fallback).
@export var faction_id: String = ""
## Ship classes (ShipStats.ship_class, 1..5) this profile covers.
@export_range(1, 5) var ship_class_min: int = 1
@export_range(1, 5) var ship_class_max: int = 5

## The full crew, one entry per head. `defender_zones` is parallel to it (a
## BoardingZone.Id per entry; a missing entry means the Waist).
@export var defenders: Array[DefenderData] = []
@export var defender_zones: PackedInt32Array = PackedInt32Array()

## Enemy morale before the first bell.
@export var morale: int = 60  # placeholder: tune in M31
## However thin gunnery and a damaged crew leave the deck, at least this many stay.
@export var min_defenders: int = 2  # placeholder: tune in M31
## Heads one matching hit tag removes from the deck (grape / chain).
@export var removals_per_hit: int = 1  # placeholder: tune in M31
## HP a matching hit tag takes off a wounded-by defender (a stern-rake and the officer).
@export var wound_per_hit: int = 2  # placeholder: tune in M31
## Morale a bow or stern rake drains before the battle starts.
@export var rake_morale: int = 6  # placeholder: tune in M31
## HP and damage per bell of an escort still firing from outside the grapple.
@export var threat_hp: int = 3  # placeholder: tune in M31
@export var threat_damage: int = 2  # placeholder: tune in M31
## Entry arcs: a boarding from within this many degrees of the enemy's bow (stern) lands on
## the Forecastle (Quarterdeck); anything else on the Waist.
@export var bow_arc_degrees: float = 100.0
@export var stern_arc_degrees: float = 100.0

## Each: {"bell": int, "kind": "jettison" | "officers_escape"}; a bell of -1 is the last bell.
@export var timed_events: Array[Dictionary] = []
@export var objectives: Array[BoardingObjectiveData] = []
