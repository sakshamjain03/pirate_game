class_name CelebrationQueue extends Node

## Purpose: the M22 celebration tier rules (design.md §10, Requirement 9.2).
## A plain Node owned by WorldHUD (not an autoload) that decides WHEN a
## celebration moment is shown; what a moment looks like is the moment's own
## business (a Control built by the caller, typically animated with UIMotion).
## Rules:
##   SMALL  — shows immediately, always (pill shine, "+50 gold").
##   MEDIUM — shows immediately over the live scene (sunk stamp, loot).
##   LARGE  — one at a time: while a Large is up, further Larges queue, and
##            the next starts only when the current one's CTA is pressed (or
##            the moment leaves the tree some other way). Never two at once.
## Dependencies: none — callers pass the host to add moments under.
## Limitations: moments are fire-and-forget for SMALL/MEDIUM (they free
## themselves); LARGE moments are freed by the queue when their CTA fires.

enum Tier { SMALL, MEDIUM, LARGE }

signal large_started(moment: Control)
signal large_finished(moment: Control)

## Where moments are added (WorldHUD's own CanvasLayer root). Must be set
## before play(); a moment already inside the tree is left where it is.
var host: Node = null

var _active_large: Control = null
var _pending: Array[Dictionary] = []


func play(tier: Tier, moment: Control, cta: BaseButton = null) -> void:
	if moment == null:
		return
	if tier == Tier.LARGE:
		if _active_large != null:
			_pending.append({"moment": moment, "cta": cta})
			return
		_start_large(moment, cta)
		return
	_show(moment)


## True while a Large moment is up (callers may hold back optional prompts).
func is_busy() -> bool:
	return _active_large != null


func pending_count() -> int:
	return _pending.size()


func _show(moment: Control) -> void:
	if moment.is_inside_tree():
		return
	if host == null:
		push_error("CelebrationQueue: no host set; cannot show %s" % moment.name)
		return
	host.add_child(moment)


func _start_large(moment: Control, cta: BaseButton) -> void:
	_active_large = moment
	_show(moment)
	var done := _on_large_done.bind(moment)
	if cta:
		cta.pressed.connect(done, CONNECT_ONE_SHOT)
	moment.tree_exiting.connect(done, CONNECT_ONE_SHOT)
	large_started.emit(moment)


func _on_large_done(moment: Control) -> void:
	if moment != _active_large:
		return
	_active_large = null
	large_finished.emit(moment)
	if is_instance_valid(moment) and not moment.is_queued_for_deletion():
		moment.queue_free()
	# Deferred: this can run from the finished moment's own tree_exiting,
	# where the host refuses new children until the removal completes.
	_start_next_pending.call_deferred()


func _start_next_pending() -> void:
	if _active_large != null:
		return
	while not _pending.is_empty():
		var next: Dictionary = _pending.pop_front()
		if is_instance_valid(next["moment"]):
			_start_large(next["moment"], next["cta"])
			return
