@tool
class_name CaptainAbilityData extends Resource

## Purpose: one captain's player-triggered battle ability (`docs/navalCombat.md` §10).
## Responsibilities: pure data. `CaptainAbility` executes it via `CombatModifiers`.
##
## This is what turns the 20 captains from flat stat sticks into 20 distinct
## in-battle verbs. `CaptainData` already carried five passive multipliers and
## nothing the player could *press*; the passive says what a captain is, this says
## what they do.

@export var ability_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: String = "⚓"

@export_group("Timing")
## Seconds the multipliers below stay active. 0 means the ability is purely instant
## (a repair, a rally) with no buff window.
@export_range(0.0, 30.0) var duration: float = 5.0
@export_range(1.0, 300.0) var cooldown: float = 30.0

@export_group("Timed multipliers")
## Applied together for `duration`. 1.0 (or 0.0 for the additive arc) is neutral.
@export_range(0.1, 5.0) var damage_mult: float = 1.0
## > 1.0 reloads faster.
@export_range(0.1, 5.0) var fire_rate_mult: float = 1.0
@export_range(0.1, 5.0) var speed_mult: float = 1.0
@export_range(0.1, 5.0) var range_mult: float = 1.0
## ADDED to the firing cone half-width, in degrees.
@export_range(0.0, 60.0) var arc_bonus_degrees: float = 0.0

@export_group("Instant effects")
## Fractions of each pool's maximum, restored the moment the ability fires.
@export_range(0.0, 1.0) var instant_hull_fraction: float = 0.0
@export_range(0.0, 1.0) var instant_sails_fraction: float = 0.0
@export_range(0.0, 1.0) var instant_crew_fraction: float = 0.0


func get_timed_effects() -> Dictionary:
	## Keys match CombatModifiers' internal layer. Neutral entries are omitted so a
	## repair-only ability contributes no timed effect at all.
	var out: Dictionary = {}
	if not is_equal_approx(damage_mult, 1.0):
		out["damage"] = damage_mult
	if not is_equal_approx(fire_rate_mult, 1.0):
		out["fire_rate"] = fire_rate_mult
	if not is_equal_approx(speed_mult, 1.0):
		out["speed"] = speed_mult
	if not is_equal_approx(range_mult, 1.0):
		out["range"] = range_mult
	if arc_bonus_degrees > 0.0:
		out["arc"] = arc_bonus_degrees
	return out


func has_instant_effect() -> bool:
	return instant_hull_fraction > 0.0 or instant_sails_fraction > 0.0 \
		or instant_crew_fraction > 0.0


func describe() -> String:
	if description != "":
		return description
	var parts: PackedStringArray = []
	if not is_equal_approx(damage_mult, 1.0):
		parts.append("%+.0f%% damage" % ((damage_mult - 1.0) * 100.0))
	if not is_equal_approx(fire_rate_mult, 1.0):
		parts.append("%+.0f%% reload speed" % ((fire_rate_mult - 1.0) * 100.0))
	if not is_equal_approx(speed_mult, 1.0):
		parts.append("%+.0f%% speed" % ((speed_mult - 1.0) * 100.0))
	if not is_equal_approx(range_mult, 1.0):
		parts.append("%+.0f%% range" % ((range_mult - 1.0) * 100.0))
	if arc_bonus_degrees > 0.0:
		parts.append("+%.0f° arc" % arc_bonus_degrees)
	if instant_hull_fraction > 0.0:
		parts.append("restore %.0f%% hull" % (instant_hull_fraction * 100.0))
	if instant_sails_fraction > 0.0:
		parts.append("restore %.0f%% sails" % (instant_sails_fraction * 100.0))
	if instant_crew_fraction > 0.0:
		parts.append("rally %.0f%% crew" % (instant_crew_fraction * 100.0))
	if parts.is_empty():
		return "No effect."
	var body := ", ".join(parts)
	return body if duration <= 0.0 else "%s for %.0fs" % [body, duration]
