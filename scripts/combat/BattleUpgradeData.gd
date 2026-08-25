@tool
class_name BattleUpgradeData extends Resource

## Purpose: one temporary in-battle upgrade choice (`docs/navalCombat.md` §11).
## Responsibilities: pure data. `CombatModifiers.apply_upgrade()` interprets it.
##
## These are the Vampire-Survivors-style build choices: active for the current
## encounter only, never a replacement for permanent ship progression. Adding a new
## one is a `.tres`, not a code change.

enum Effect {
	DAMAGE,            ## multiplies cannon damage
	RELOAD_SPEED,      ## multiplies fire_rate — higher reloads faster
	SHIP_SPEED,        ## multiplies top speed
	CANNON_RANGE,      ## multiplies firing range
	FIRING_ARC,        ## ADDS degrees to the broadside cone half-width
	SPECIAL_COOLDOWN,  ## multiplies the special volley's cooldown — lower is better
	REPAIR_HULL,       ## instant: restores this FRACTION of max hull
	REPAIR_SAILS,      ## instant: restores this FRACTION of max sails
	RALLY_CREW,        ## instant: restores this FRACTION of max crew
}

@export var upgrade_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Shown on the choice card. Emoji rather than an icon path because the project has
## no authored UI icon set yet (`docs/14_SYSTEM_INVENTORY.md` §3).
@export var icon: String = "⚙"

@export_group("Effect")
@export var effect: Effect = Effect.DAMAGE
## Read per-effect: a multiplier for the scaling effects, added degrees for
## FIRING_ARC, and a fraction of the pool maximum for the instant repairs.
@export_range(0.05, 5.0) var magnitude: float = 1.25
## How many times this may be taken in one battle. Instant repairs are worth
## repeating; a compounding damage multiplier is not.
@export_range(1, 5) var max_stacks: int = 1

@export_group("Offer")
## Relative likelihood of appearing in a choice set.
@export_range(0.1, 10.0) var weight: float = 1.0


func describe() -> String:
	if description != "":
		return description
	# Fall back to something honest rather than an empty card.
	match effect:
		Effect.FIRING_ARC:
			return "+%.0f° firing arc" % magnitude
		Effect.REPAIR_HULL, Effect.REPAIR_SAILS, Effect.RALLY_CREW:
			return "Restore %.0f%%" % (magnitude * 100.0)
		Effect.SPECIAL_COOLDOWN, Effect.RELOAD_SPEED:
			return "%.0f%% faster" % (abs(1.0 - magnitude) * 100.0)
		_:
			return "%+.0f%%" % ((magnitude - 1.0) * 100.0)
