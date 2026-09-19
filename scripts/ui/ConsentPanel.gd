class_name ConsentPanel extends Control

## ConsentPanel (M17 Requirement 5.4/5.6)
## The UMP-equivalent consent flow. No real UMP SDK is integrated yet (that
## arrives with M20's real ad backend) so this custom panel *is* the consent
## mechanism today, not a stand-in for one. Declining is genuine: it
## resolves to READY_NONPERSONALIZED and never blocks play (Requirement
## 5.4). Reused for Requirement 5.6's "review/change later" path from
## Settings — AdManager.reopen_consent() re-enters CONSENT_PENDING, which is
## exactly what this panel already listens for.

@onready var personalize_button: Button = %PersonalizeButton
@onready var decline_button: Button = %DeclineButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	personalize_button.pressed.connect(_on_choice.bind(true))
	decline_button.pressed.connect(_on_choice.bind(false))
	AdManager.state_changed.connect(_on_ad_state_changed)
	PirateThemeBuilder.apply_button_juice(self)
	_on_ad_state_changed(AdManager.state)


func _on_ad_state_changed(new_state: AdManager.State) -> void:
	if new_state == AdManager.State.CONSENT_PENDING:
		show()
		get_tree().paused = true
	elif visible:
		hide()
		get_tree().paused = false


func _on_choice(personalized: bool) -> void:
	AdManager.submit_consent_choice(personalized)
