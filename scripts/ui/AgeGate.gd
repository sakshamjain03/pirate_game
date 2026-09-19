class_name AgeGate extends Control

## AgeGate (M17 Requirement 5.1/5.2/6.6)
## Neutral age check, shown lazily the first time a rewarded-ad surface
## wants to make an offer — never proactively at boot, and never during the
## tutorial or first session (no surface calls request_bonus() that early,
## so this is never reached then either). Listens to
## AdManager.state_changed rather than being told to open directly, so it
## can never drift out of sync with the state machine that owns the
## decision to show it.
##
## Requirement 5.2 — neither answer is pre-selected: no button calls
## grab_focus(), neither is styled as "recommended," and the phrasing below
## doesn't lean toward either answer.

@onready var over_button: Button = %OverThresholdButton
@onready var under_button: Button = %UnderThresholdButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	over_button.pressed.connect(_on_answered.bind(false))
	under_button.pressed.connect(_on_answered.bind(true))
	AdManager.state_changed.connect(_on_ad_state_changed)
	PirateThemeBuilder.apply_button_juice(self)
	_on_ad_state_changed(AdManager.state)


func _on_ad_state_changed(new_state: AdManager.State) -> void:
	if new_state == AdManager.State.AGE_GATE_PENDING:
		show()
		get_tree().paused = true
	elif visible:
		hide()
		get_tree().paused = false


func _on_answered(is_under_threshold: bool) -> void:
	AdManager.submit_age_gate_answer(is_under_threshold)
