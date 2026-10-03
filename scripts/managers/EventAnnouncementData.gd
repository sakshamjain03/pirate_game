## M29 D.1 — what the player is told when EventManager.trigger_event() fires.
## Maps event name -> English title (this project's tr() keys ARE the English
## strings — see translations/en.csv). An empty title is deliberately silent.
## A name missing from the table is a bug: WorldHUD push_warnings it.
class_name EventAnnouncementData extends Resource

@export var announcements: Dictionary = {}


## The title for `event_name`, "" for a silent event, or null if unknown.
func get_title(event_name: String) -> Variant:
	if not announcements.has(event_name):
		return null
	return String(announcements[event_name])
