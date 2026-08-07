class_name RaidReportScreen extends Control

## Purpose: Full-screen report shown after an empire raid resolves (M4).
## Responsibilities: Displays the attacking faction, repelled/not-repelled outcome, and stolen
##   resource amounts if applicable; clears EmpireManager.pending_raid_report on dismiss so it
##   doesn't re-show on the next World scene load.
## Dependencies: EmpireManager (RaidReport dictionary shape), instantiated by WorldManager.gd

@onready var dismiss_button: Button = %DismissButton
@onready var outcome_label: Label = %TitleLabel
@onready var details_label: Label = %DetailsLabel

func _ready() -> void:
	dismiss_button.pressed.connect(_on_dismiss_pressed)
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()

func open(report: Dictionary) -> void:
	var faction_id = report.get("faction_id", "Unknown Faction")
	var repelled = report.get("repelled", true)
	var stolen = report.get("stolen", {})
	
	if repelled:
		outcome_label.text = "Raid Repelled!"
		outcome_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		details_label.text = "Your home island defenses held off an attack from " + faction_id.capitalize() + "."
	else:
		outcome_label.text = "Raid Successful!"
		outcome_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		
		var stolen_text = "Your home island was raided by " + faction_id.capitalize() + ".\n\nStolen Resources:\n"
		if stolen.is_empty():
			stolen_text += "Nothing was stolen."
		else:
			for res in stolen:
				stolen_text += "- " + str(stolen[res]) + " " + res.capitalize() + "\n"
		details_label.text = stolen_text
		
	show()
	get_tree().paused = true
	dismiss_button.grab_focus()

func _on_dismiss_pressed() -> void:
	var emp = get_tree().root.get_node_or_null("EmpireManager")
	if emp:
		emp.pending_raid_report = null
	hide()
	get_tree().paused = false
