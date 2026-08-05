extends Node

# GameManager.gd
# Handles high-level game state and flow.

enum GameState { BOOT, MAIN_MENU, IN_GAME, PAUSED, GAME_OVER }
var current_state: GameState = GameState.BOOT

func change_state(new_state: GameState) -> void:
	current_state = new_state
	print("Game state changed to: ", current_state)
