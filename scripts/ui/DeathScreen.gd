class_name DeathScreen extends Control

## Purpose: UI menu shown when the player's ship is destroyed.
## Responsibilities: Pauses the game, displays penalty info, handles respawning.
## Dependencies: ResourceManager, ShipController, PirateThemeBuilder

@onready var respawn_button: Button = %RespawnButton
@onready var penalty_label: Label = %PenaltyLabel
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel

var player_ship: ShipController = null
var _penalty_amount: int = 0

func _ready() -> void:
	respawn_button.pressed.connect(_on_respawn_pressed)
	hide()

	# Ensure this UI can process while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.apply_button_juice(self)

	if PirateThemeBuilder.is_mobile():
		panel.custom_minimum_size = PirateThemeBuilder.scaled_size(panel.custom_minimum_size)
		title_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(42))
		penalty_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(18))
		respawn_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(respawn_button.custom_minimum_size)
		respawn_button.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(24))

func open(ship: ShipController) -> void:
	player_ship = ship
	
	# Calculate 20% gold penalty
	var current_gold = ResourceManager.get_resource("gold")
	_penalty_amount = int(current_gold * 0.2)
	
	penalty_label.text = "Your crew salvaged the ship, but %d Gold was lost to the sea." % _penalty_amount
	
	show()
	get_tree().paused = true
	respawn_button.grab_focus()

func _on_respawn_pressed() -> void:
	# Apply penalty
	if _penalty_amount > 0:
		ResourceManager.spend_resource("gold", _penalty_amount)
	
	# Respawn ship at origin (0,1,0) for now. Future: closest friendly island.
	if player_ship and player_ship.has_method("respawn"):
		player_ship.respawn(Vector3(0, 1, 0))
	
	hide()
	get_tree().paused = false
