@tool
class_name EnemyCaptainData extends Resource

## Purpose: a named enemy officer who can become a Nemesis (M30 2.11). When a boarding ends with
##   the officers slipping away in a boat, the officer of that faction is remembered; the next ship
##   of that faction carries them back, PROMOTED, harder, and on a wanted poster. Seizing a ship
##   with the officers still aboard ends the matter (and collects the bounty).
## Responsibilities: pure data and pure text. The registry (who has escaped how often) lives in
##   `EmpireManager.nemeses` and is saved there. Every number is a placeholder (M31 tunes them).

const COURTS_DIR := "res://resources/enemy_captains"

@export var captain_id: String = ""
@export var display_name: String = ""
## The faction whose ships this officer sails with.
@export var faction_id: String = ""
## The promotion ladder, lowest first. Each escape moves the officer one title up the ladder
## (capped at the top); `titles[0]` is the rank at which they first got away.
@export var titles: PackedStringArray = PackedStringArray(["Lieutenant", "Captain", "Commodore"])
## Per promotion: extra hit points and attack on the deck.
@export var hp_per_promotion: int = 3  # placeholder: tune in M31
@export var attack_per_promotion: int = 1  # placeholder: tune in M31
## Gold for ending them (seizing a ship of theirs with the officers still aboard), per promotion + 1.
@export var bounty_per_promotion: int = 150  # placeholder: tune in M31
@export_multiline var wanted_text: String = "Wanted for escaping the Pirate Empire's grapples."


func max_promotion() -> int:
	return maxi(titles.size() - 1, 0)


func clamp_promotion(promotion: int) -> int:
	return clampi(promotion, 0, max_promotion())


func title_for(promotion: int) -> String:
	return titles[clamp_promotion(promotion)] if titles.size() > 0 else ""


## "Captain Hargreave" at promotion 1.
func full_name(promotion: int) -> String:
	return ("%s %s" % [title_for(promotion), display_name]).strip_edges()


func bounty(promotion: int) -> int:
	return bounty_per_promotion * (clamp_promotion(promotion) + 1)


## The poster line shown to the player.
func poster(promotion: int) -> String:
	return "WANTED: %s. %s Bounty: %d gold." % [full_name(promotion), wanted_text, bounty(promotion)]


## The officer of `faction_id`, or null.
static func for_faction(faction_id: String) -> EnemyCaptainData:
	return ResourceLookup.find_by_id(COURTS_DIR, "faction_id", faction_id) as EnemyCaptainData


static func by_id(id: String) -> EnemyCaptainData:
	return ResourceLookup.find_by_id(COURTS_DIR, "captain_id", id) as EnemyCaptainData
