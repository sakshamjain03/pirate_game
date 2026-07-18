extends Node

# SceneManager.gd
# Handles loading, unloading, and transitioning between scenes smoothly.

func change_scene(scene_path: String) -> void:
	print("Changing scene to: ", scene_path)
	get_tree().change_scene_to_file(scene_path)
