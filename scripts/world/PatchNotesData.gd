class_name PatchNotesData extends Resource

## Purpose: M14 Requirement 5 — hand-authored patch notes for the "What's
## New" panel. A single append-only resource rather than one .tres per
## release (design.md's own preference: "whichever needs less new schema" —
## patch notes are read, not queried/filtered). Deliberately NOT auto-
## generated from git log (Requirement 5.3): this project's content updates
## are infrequent and small enough that hand-written notes are both accurate
## and low-effort.
##
## Each entry: {"version": String, "date": String, "notes": String}. Entries
## are authored oldest-first; WhatsNewScreen reads them newest-first. The
## last entry's "version" is the one WorldHUD compares against
## SaveManager.last_seen_whats_new_version to decide whether to auto-show.
@export var entries: Array[Dictionary] = []


func latest_version() -> String:
	if entries.is_empty():
		return ""
	return str(entries[-1].get("version", ""))
