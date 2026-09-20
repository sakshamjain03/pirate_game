extends Node

## TEMPORARY DEBUG HARNESS — not part of the game.
##
## Spawns one enemy at a guaranteed mutual-broadside offset next to the
## player (the same Vector3(45, 0, 0) offset tests/test_combat_integration.gd
## uses) so CombatCaptureHarness.tscn can prove real hit registration and HUD
## feedback with zero player input — auto-fire only needs alignment, not
## steering, so no input is needed to start a fight.
##
## Delete this file and its scene once the combat-clarity fix is verified.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")


func _ready() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player_ship")
	if not player:
		push_warning("DebugEnemySpawner: no player_ship found in the scene")
		return
	var enemy := ENEMY_SHIP.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(45.0, 0.0, 0.0)
