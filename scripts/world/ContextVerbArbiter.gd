class_name ContextVerbArbiter extends RefCounted

## Purpose: decides what the ONE context button does right now (M30 Wave 0,
## task 0.20). Phone steering is two buttons plus an ~11-button HUD; every new
## M30 verb (Brace, Repel, Take Prize, Keg, Land, Assault, Spyglass) shares this
## single slot instead of adding a persistent button.
## Responsibilities: hold registered providers, rank the available ones by the
## fixed verb priority, perform the winner. Owns no game state: each provider's
## `available`/`perform` callables query and act on the system that owns it
## (BoardingSystem, DockingSystem, ...). WorldManager owns the one instance and
## routes the "dock" input action through it; MobileControls labels the button
## from it.

## Highest first: a threat to the player beats an opportunity, which beats
## housekeeping. Wave 0 registers board + dock; later waves register the rest.
const PRIORITY: Array[StringName] = [
	&"repel", &"brace", &"board", &"take_prize", &"keg", &"land",
	&"assault", &"spyglass", &"dock",
]

var _providers: Dictionary = {}   # verb -> {available: Callable, perform: Callable, label: String, icon: String}


## Registers (or replaces) the provider for `verb`. `available` returns bool;
## `perform` returns bool (true = it acted). An unknown verb push_errors — it
## would otherwise never be offered, silently.
func register_provider(verb: StringName, available: Callable, perform: Callable,
		label: String, icon: String = "") -> void:
	if not PRIORITY.has(verb):
		push_error("ContextVerbArbiter: unknown verb '%s' (add it to PRIORITY)" % verb)
		return
	_providers[verb] = {"available": available, "perform": perform, "label": label, "icon": icon}


func unregister_provider(verb: StringName) -> void:
	_providers.erase(verb)


## The highest-priority verb whose provider says it is available, or &"".
func get_context_verb() -> StringName:
	for verb in PRIORITY:
		var p: Dictionary = _providers.get(verb, {})
		if p.is_empty():
			continue
		var available: Callable = p["available"]
		if available.is_valid() and bool(available.call()):
			return verb
	return &""


func get_label(verb: StringName) -> String:
	return str(_providers.get(verb, {}).get("label", ""))


func get_icon(verb: StringName) -> String:
	return str(_providers.get(verb, {}).get("icon", ""))


## Performs the current winner. If it declines (returns false — e.g. boarding
## odds re-checked and refused), the next available verb gets the press, which
## preserves the old "board, else dock" fallthrough.
func perform() -> StringName:
	for verb in PRIORITY:
		var p: Dictionary = _providers.get(verb, {})
		if p.is_empty():
			continue
		var available: Callable = p["available"]
		if not (available.is_valid() and bool(available.call())):
			continue
		var act: Callable = p["perform"]
		if act.is_valid() and bool(act.call()):
			return verb
	return &""
