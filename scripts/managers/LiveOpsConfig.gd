extends Node

## Purpose: M14 Requirement 6 — the entire integration surface with M15's
## RemoteConfigManager. Two functions, both with a local answer that requires
## zero network/remote-config presence, per Requirement 6.1/6.2. Nothing else
## in this milestone references RemoteConfigManager directly — that keeps the
## M15 dependency contained to this one file, easy to verify (Requirement
## 6.3) by confirming the fallback path independently of whether a remote key
## is actually set.
##
## Simpler than design.md's own pseudocode anticipated: that pseudocode
## guessed at an Engine.has_singleton()-style "is M15 installed" check,
## written before M15 had actually landed. M15 shipped for real
## (RemoteConfigManager is a real, always-present autoload, registered 3rd in
## project.godot) — so "M15 not installed" collapses to "the key isn't set,"
## which RemoteConfigManager.get_value()'s own default already handles. No
## presence-detection needed.

## Returns {"start": "MM-DD", "end": "MM-DD"}. Checks RemoteConfigManager
## first (key "seasonal_window_<event_id>", expected to hold the same
## {"start", "end"} shape); falls back to the event's own authored
## fallback_window_*_month_day fields if the key is absent or the event
## itself doesn't exist.
func get_seasonal_window(event_id: String) -> Dictionary:
	var remote = RemoteConfigManager.get_value("seasonal_window_%s" % event_id, null)
	if remote is Dictionary and remote.has("start") and remote.has("end"):
		return remote

	var event_data := SeasonalEventManager.get_event_data(event_id)
	if not event_data:
		return {}
	return {
		"start": event_data.fallback_window_start_month_day,
		"end": event_data.fallback_window_end_month_day,
	}


## Live kill-switch (key "kill_switch_<content_id>"). Default true — content
## works until told otherwise, per Requirement 6.1's explicit "enabled" default.
func is_content_enabled(content_id: String) -> bool:
	return RemoteConfigManager.get_value("kill_switch_%s" % content_id, true)
