class_name DefeatPenaltyData extends Resource

## Purpose: what sinking costs the player (M30 0.19). DeathScreen hardcoded a
## 20% gold loss. Wave 4 (4.1, owner decision 2026-10-05) replaces this with
## "lose only the unbanked Hold"; until then the default reproduces 20%.

const DEFAULT_PATH := "res://resources/balance/DefeatPenalty.tres"

## Fraction of current gold lost on sinking.
@export_range(0.0, 1.0) var gold_loss_fraction: float = 0.2  # placeholder: tune in M31


static func load_default() -> DefeatPenaltyData:
	var data := load(DEFAULT_PATH) as DefeatPenaltyData
	if data == null:
		push_error("DefeatPenaltyData: could not load %s; using built-in defaults." % DEFAULT_PATH)
		data = DefeatPenaltyData.new()
	return data


func gold_lost(current_gold: int) -> int:
	return int(current_gold * gold_loss_fraction)
