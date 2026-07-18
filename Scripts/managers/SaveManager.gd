extends Node

# SaveManager.gd
# Handles saving and loading player empire data.

const SAVE_PATH := "user://save_data.json"

func save_game() -> void:
	print("Saving game...")

func load_game() -> void:
	print("Loading game...")
