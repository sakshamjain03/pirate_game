class_name RewardedBonusOffer extends Control

## RewardedBonusOffer (M17 design.md §6)
## One reusable panel for all three permitted rewarded surfaces
## (offline-return, post-battle salvage, event-reroll) rather than three
## near-identical ones (AGENTS.md: no duplicate systems). The caller
## supplies which surface this instance represents, the offer text, and a
## Callable for what "grant the bonus" actually means for that surface —
## this panel never computes or touches a baseline itself; the baseline is
## already granted, unconditionally, before present() is ever called.
##
## Requirement 6.4 — declining (or dismissing after a failure) never
## re-prompts for this occurrence, and there is no confirmation dialog
## either way. Requirement 6.8 — a failed/dismissed ad keeps the offer
## available; only a decline or an actual grant closes the panel.

@onready var offer_label: Label = %OfferLabel
@onready var watch_button: Button = %WatchAdButton
@onready var decline_button: Button = %DeclineButton

var _surface: StringName = &""
var _on_bonus_granted: Callable


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	watch_button.pressed.connect(_on_watch_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	PirateThemeBuilder.apply_button_juice(self)


## on_bonus_granted is called with no arguments the moment the bonus is
## actually available (ad-free short-circuit or a completed ad) — the
## caller performs the real grant. Silently does nothing if the surface is
## already capped for today, per Requirement 6.3 (no confirmation prompt,
## no error — the offer just never appears).
func present(surface: StringName, offer_text: String, on_bonus_granted: Callable) -> void:
	if not AdManager.can_offer(surface):
		return
	_surface = surface
	_on_bonus_granted = on_bonus_granted
	offer_label.text = offer_text
	watch_button.disabled = false
	show()
	get_tree().paused = true


func _on_watch_pressed() -> void:
	watch_button.disabled = true
	AdManager.bonus_granted.connect(_on_ad_manager_bonus_granted)
	AdManager.bonus_unavailable.connect(_on_ad_manager_bonus_unavailable)
	AdManager.bonus_ad_failed.connect(_on_ad_manager_bonus_ad_failed)
	AdManager.request_bonus(_surface)


func _on_ad_manager_bonus_granted(surface: StringName) -> void:
	if surface != _surface:
		return
	_disconnect_ad_signals()
	_on_bonus_granted.call()
	_close()


func _on_ad_manager_bonus_unavailable(surface: StringName) -> void:
	if surface != _surface:
		return
	_disconnect_ad_signals()
	_close()


func _on_ad_manager_bonus_ad_failed(surface: StringName, _reason: String) -> void:
	if surface != _surface:
		return
	_disconnect_ad_signals()
	# Requirement 6.8 — the baseline and the offer both survive; the player
	# can retry or decline, never silently lose the chance.
	watch_button.disabled = false


func _on_decline_pressed() -> void:
	_close()


func _disconnect_ad_signals() -> void:
	if AdManager.bonus_granted.is_connected(_on_ad_manager_bonus_granted):
		AdManager.bonus_granted.disconnect(_on_ad_manager_bonus_granted)
	if AdManager.bonus_unavailable.is_connected(_on_ad_manager_bonus_unavailable):
		AdManager.bonus_unavailable.disconnect(_on_ad_manager_bonus_unavailable)
	if AdManager.bonus_ad_failed.is_connected(_on_ad_manager_bonus_ad_failed):
		AdManager.bonus_ad_failed.disconnect(_on_ad_manager_bonus_ad_failed)


func _close() -> void:
	hide()
	get_tree().paused = false
	queue_free()
