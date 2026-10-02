## M29 D.1 — Event announcement data mapping event names to displayable information.
## Purpose: Decouples EventManager (which triggers events) from WorldHUD (which displays them).
## Maps event_id strings to tr() keys and icons, so the banner text is data-driven, not hardcoded.

class_name EventAnnouncementData extends Resource

## Dictionary mapping event name → {title_key: String, icon_path: String}
## title_key is passed to tr() to get the localized banner text.
@export var announcements: Dictionary = {
	"merchant_convoy_spotted": {
		"title_key": "event_merchant_convoy_spotted",
		"icon_path": "res://assets/icons/event_merchant.png"
	},
	"floating_treasure_spotted": {
		"title_key": "event_floating_treasure_spotted",
		"icon_path": "res://assets/icons/event_treasure.png"
	},
	"ghost_ship_spotted": {
		"title_key": "event_ghost_ship_spotted",
		"icon_path": "res://assets/icons/event_ghost_ship.png"
	},
	"iron_vulture_spotted": {
		"title_key": "event_iron_vulture_spotted",
		"icon_path": "res://assets/icons/event_iron_vulture.png"
	},
	"fortunes_toll_spotted": {
		"title_key": "event_fortunes_toll_spotted",
		"icon_path": "res://assets/icons/event_fortunes_toll.png"
	},
	"drifting_wreckage_spotted": {
		"title_key": "event_drifting_wreckage_spotted",
		"icon_path": "res://assets/icons/event_wreckage.png"
	},
	"smugglers_cache_spotted": {
		"title_key": "event_smugglers_cache_spotted",
		"icon_path": "res://assets/icons/event_smugglers.png"
	},
	"pirate_raiding_party_spotted": {
		"title_key": "event_pirate_raiding_party_spotted",
		"icon_path": "res://assets/icons/event_pirates.png"
	},
	"royal_navy_patrol_spotted": {
		"title_key": "event_royal_navy_patrol_spotted",
		"icon_path": "res://assets/icons/event_navy.png"
	},
	"wind_shifted": {
		"title_key": "event_wind_shifted",
		"icon_path": "res://assets/icons/event_wind.png"
	},
	"island_discovered": {
		"title_key": "event_island_discovered",
		"icon_path": "res://assets/icons/event_island.png"
	},
	"ship_docked": {
		"title_key": "event_ship_docked",
		"icon_path": "res://assets/icons/event_dock.png"
	}
}

func get_announcements() -> Dictionary:
	return announcements

func get_announcement(event_name: String) -> Dictionary:
	return announcements.get(event_name, {})
