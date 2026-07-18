extends Node
class_name SaveManager

## SaveManager
## Handles saving and loading player empire data.
## 
## Responsibilities:
## - Provide placeholder API for save/load functionality
## - Stub methods for future milestone implementation
## 
## Dependencies:
## - GameManager (for game state awareness)
## - ConfigFile (for JSON/text serialization - future)
## 
## Limitations:
## - Milestone 1: No persistent data is written
## - All methods are no-op stubs
## - does_save_data() always returns false
## 
## TODO:
## - M2: Implement save_game() with empire state serialization
## - M2: Implement load_game() with data deserialization
## - M2: Implement has_save_data() to check file existence
## - M3: Add save validation and version checking
## - M4: Implement cloud save fallback

const SAVE_PATH := "user://save_data.json"

func save_game() -> void:
	pass

func load_game() -> void:
	pass

func has_save_data() -> bool:
	return false
