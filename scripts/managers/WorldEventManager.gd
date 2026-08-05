extends Node

## Purpose: Manages global world events like Boss Spawns.
## Responsibilities: Runs a timer, spawns the boss, and alerts the UI.
## Dependencies: BossShip.tscn, WorldHUD

@export var event_interval: float = 300.0 # 5 minutes

var boss_scene: PackedScene = preload("res://scenes/world/BossShip.tscn")
var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = event_interval
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_on_event_timeout)
	add_child(timer)
	
	# Wait a short delay on game start so HUD is fully loaded before announcing things
	# Not strictly necessary if the first event is 5 mins out, but good for debug
	
func _on_event_timeout() -> void:
	# Don't spawn multiple bosses
	var existing = get_tree().get_nodes_in_group("boss_ship")
	if existing.size() > 0:
		return
		
	# Spawn boss far from origin
	var boss = boss_scene.instantiate() as Node3D
	get_parent().add_child(boss)
	
	# Spawn somewhere random between 200 and 400 units away from center
	var angle = randf() * PI * 2.0
	var dist = randf_range(200.0, 400.0)
	boss.global_position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	
	# Announce to UI
	var hud = get_tree().current_scene.get_node_or_null("%WorldHUD")
	if hud and hud.has_method("announce_event"):
		hud.announce_event("WORLD EVENT:\nAn Imperial Man-O-War has entered the waters!")
