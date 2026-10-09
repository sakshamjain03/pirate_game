@tool
class_name PrizeCourtData extends Resource

## Purpose: the law of a port's prize court (M30 2.9) — what it will pay for a taken ship,
##   which prizes it refuses, and what becomes of the captives.
## Responsibilities: pure data and three pure questions (`refuses`, `quote`, `court_for`). The
##   sale itself is `FleetManager.sell_prize()`. A court belongs to the faction that owns the port
##   (`faction_id`): a Navy-held port sits a Navy court, a pirate haven a haven, your own ports a
##   plain one. Every number is a placeholder (M31 tunes them).

enum CaptivePolicy {
	PRESSED,  ## the captives are pressed into your crew
	LOYAL,    ## the captives stay loyal to their flag and are handed back, for goodwill
}

const COURTS_DIR := "res://resources/prize_courts"

@export var court_id: String = ""
@export var display_name: String = ""
## The faction whose ports hold this court.
@export var faction_id: String = ""
## Prizes taken from these factions are refused: the court will not condemn a ship of a friend of
## the crown, and trying costs reputation with the court's own faction.
@export var refuses_prizes_from: Array[String] = []
@export var refusal_reputation_cost: int = 5  # placeholder: tune in M31
## Share of the full price this court pays (a pirate haven pays 0.7).
@export_range(0.0, 2.0) var payout_mult: float = 1.0  # placeholder: tune in M31
## Full price per ship class at condition 1.0.
@export var gold_per_class: int = 200  # placeholder: tune in M31
@export var captive_policy: CaptivePolicy = CaptivePolicy.PRESSED
## PRESSED: the share of captives who sign on.
@export_range(0.0, 1.0) var pressed_fraction: float = 0.5  # placeholder: tune in M31
## LOYAL: reputation with the captives' own faction for handing them back.
@export var loyal_reputation: int = 2  # placeholder: tune in M31


func refuses(prize_faction_id: String) -> bool:
	return not prize_faction_id.is_empty() and prize_faction_id in refuses_prizes_from


## Gold for a hull of `ship_class` in `condition` (0..1), rounded down.
func quote(ship_class: int, condition: float) -> int:
	return int(floor(float(gold_per_class) * float(maxi(ship_class, 1)) * clampf(condition, 0.0, 1.0) * payout_mult))


## The court that sits in ports owned by `owner_faction_id`, or null when there is none. Looked up
## by the court's own `faction_id` (never a guessed file name).
static func court_for(owner_faction_id: String) -> PrizeCourtData:
	if owner_faction_id.is_empty():
		return null
	return ResourceLookup.find_by_id(COURTS_DIR, "faction_id", owner_faction_id) as PrizeCourtData
