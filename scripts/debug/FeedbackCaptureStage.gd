extends Node

## DEBUG HARNESS — not part of the game.
##
## Stages the M30 Wave 1 combat reads in front of the camera, with zero player
## input, so FeedbackCaptureHarness.tscn can screenshot them headful (tasks 1.5,
## 1.10 and 1.11 each require a headful capture; GUT's dummy renderer cannot
## prove any of them draw):
##   - an enemy hull on the player's starboard beam, holding a long broadside
##     wind-up aimed at the player -> ThreatDecals wedge in its ammo colour;
##   - that enemy marked as the player's priority target -> CombatFeedback's
##     rake cone off its stern;
##   - a powder keg floating astern of the player (fuse held open);
##   - the RibbonStack showing Rake!/Sunk!/Perfect Brace! (lifetime held open);
##   - colour damage numbers (chain shot, and a rake) over the enemy.
## Every node it touches is the real game node in World/WorldHUD; it only feeds
## them events and stretches lifetimes so the stills catch them.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const KEG_SCENE := preload("res://scenes/combat/PowderKeg.tscn")
const FLOATING_DAMAGE := preload("res://scenes/ui/FloatingDamage.tscn")
## Player-local: forward-starboard, so the camera (astern of the player) frames it.
const ENEMY_OFFSET := Vector3(26.0, 0.0, -28.0)
const HOLD_SECONDS := 999.0

var _player: Node3D
var _enemy: Node3D
var _decals: ThreatDecals
var _numbers_t: float = 0.0


func _ready() -> void:
	# Let World/WorldHUD finish their own _ready and the ocean settle a frame.
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player_ship") as Node3D
	if not _player:
		push_warning("FeedbackCaptureStage: no player_ship")
		set_process(false)
		return
	_stage_enemy()
	_stage_keg()
	_stage_ribbons()
	_decals = get_tree().root.find_child("ThreatDecals", true, false) as ThreatDecals


func _process(delta: float) -> void:
	if not is_instance_valid(_enemy) or not is_instance_valid(_player):
		return
	# The opening-chapter dialogue would cover the frame; it is not under test.
	var dlg = get_tree().root.find_child("TutorialDialogue", true, false)
	if dlg and dlg is CanvasItem:
		dlg.visible = false
	# Keep the wedge on the side that actually faces the player.
	if _decals:
		var to_player: Vector3 = _player.global_position - _enemy.global_position
		var side := "starboard" if to_player.dot(_enemy.global_transform.basis.x) >= 0.0 else "port"
		_decals.report_windup(_enemy, side, 2.0, _player)
	_numbers_t -= delta
	if _numbers_t <= 0.0:
		_numbers_t = 0.6
		_number(37.0, "chain", &"port", Vector3(-3, 7, 0))
		_number(64.0, "round", &"stern", Vector3(3, 9, 0))


func _stage_enemy() -> void:
	_enemy = ENEMY_SHIP.instantiate()
	_player.get_parent().add_child(_enemy)
	_enemy.global_position = _player.global_position + _player.global_transform.basis * ENEMY_OFFSET
	# Turned 40° off parallel so the rake cone off its stern is not hidden
	# under the wedge or the hull.
	_enemy.global_rotation.y = _player.global_rotation.y + deg_to_rad(40.0)
	var ai = _enemy.get_node_or_null("EnemyAI")
	if ai:
		ai.set_physics_process(false)
		ai.set_process(false)
	var combat = _enemy.get_node_or_null("ShipCombat")
	if combat:
		combat.auto_fire_enabled = false   # the staged wind-up never fires
	var solver := _player.get_node_or_null("FiringSolver") as FiringSolver
	if solver:
		solver.set_priority_target(_enemy)
	var player_combat = _player.get_node_or_null("ShipCombat")
	if player_combat:
		player_combat.auto_fire_enabled = false   # keep the frame readable


func _stage_keg() -> void:
	var keg: PowderKeg = KEG_SCENE.instantiate()
	var cfg: KegConfigData = keg.config.duplicate()
	cfg.fuse_seconds = HOLD_SECONDS
	cfg.proximity_radius = 0.0
	keg.config = cfg
	keg.dropped_by = _player
	_player.get_parent().add_child(keg)
	var aft: Vector3 = _player.global_transform.basis.z
	aft = Vector3(aft.x, 0.0, aft.z).normalized()
	keg.global_position = _player.global_position + aft * 9.0 + Vector3(0, 0.3, 0)


func _stage_ribbons() -> void:
	var rs := get_tree().root.find_child("RibbonStack", true, false) as RibbonStack
	if not rs:
		push_warning("FeedbackCaptureStage: no RibbonStack in the HUD")
		return
	var cfg: CombatFeedbackData = rs.config.duplicate()
	cfg.ribbon_lifetime = HOLD_SECONDS
	rs.config = cfg
	rs.add_ribbon("rake", tr("Rake!"))
	rs.add_ribbon("kill", tr("Sunk!"))
	rs.add_ribbon("perfect_brace", tr("Perfect Brace!"))


func _number(amount: float, ammo_id: String, facing: StringName, offset: Vector3) -> void:
	var n = FLOATING_DAMAGE.instantiate()
	n.damage_amount = amount
	n.ammo_id = ammo_id
	n.facing = facing
	get_tree().current_scene.add_child(n)
	n.global_position = _enemy.global_position + offset
