class_name BoardingSystem extends Node

signal boarding_prompt_available(enemy_ship: Node)
signal boarding_prompt_unavailable()
## `target_faction_id`/`target_ship_id` let `CampaignManager` resolve
## BOARD_SHIPS objectives against a specific faction or a specific dedicated
## boss hull (`docs/13_CAMPAIGN_LEVELS_1-5.md` §8, M7 Task 11) — captured before
## `_eligible_enemy` is cleared, since the signal used to carry nothing that
## identified what was actually boarded.
signal boarding_resolved(success: bool, loot: Dictionary, target_faction_id: String, target_ship_id: String)

## M30 W2 (2.1): a tactical (Three Bells) boarding began against a locked target.
## The BoardingOverlay (2.5) listens for this; nothing in the world reacts to it.
signal boarding_started(enemy_ship: Node)
## M30 W2 (2.1): how a boarding ended, on every path (quick, overwhelm, tactical).
## `outcome_id` is "auto_win"/"auto_loss" for the instant comparison, an objective's
## outcome id ("colours", "hold", ...) for a seized zone, or "cut_loose"/"struck".
## `details` carries success, loot, target_faction_id, target_ship_id and enemy.
## Emitted right after `boarding_resolved`, which still fires exactly once.
signal boarding_outcome(outcome_id: String, details: Dictionary)
## begin_boarding() skipped the battle: reason is "quick" (setting) or "overwhelm".
signal boarding_routed(reason: String)

@export var boarding_data: BoardingData

var _eligible_enemy: Node = null
## The target of a tactical boarding in progress. Held apart from
## `_eligible_enemy`, which keeps tracking range while the battle is open.
var _locked_enemy: Node = null

func _ready() -> void:
	if not boarding_data:
		boarding_data = load("res://resources/combat/Boarding.tres")

func _process(_delta: float) -> void:
	_check_eligibility()

func _check_eligibility() -> void:
	var players = get_tree().get_nodes_in_group("player_ship")
	if players.size() == 0:
		_clear_prompt()
		return
	var player = players[0]
	
	var enemies = get_tree().get_nodes_in_group("enemy_ship")
	var best_enemy = null
	var best_dist = boarding_data.range
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
			
		var dmg = enemy.get_node_or_null("ShipDamage")
		if not dmg or dmg.hull <= 0.0:
			continue
			
		var max_hp = dmg.get_effective_max_health() if dmg.has_method("get_effective_max_health") else dmg.ship_stats.max_health
		var hull_pct = dmg.hull / max(max_hp, 1.0)
		if hull_pct > boarding_data.hull_threshold:
			continue
			
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist <= best_dist:
			best_enemy = enemy
			best_dist = dist
			
	if best_enemy != _eligible_enemy:
		_eligible_enemy = best_enemy
		if _eligible_enemy:
			boarding_prompt_available.emit(_eligible_enemy)
		else:
			_clear_prompt()

func _clear_prompt() -> void:
	if _eligible_enemy != null:
		_eligible_enemy = null
		boarding_prompt_unavailable.emit()

func is_boarding_active() -> bool:
	return is_instance_valid(_locked_enemy)


## The tactical entry point behind the "Board" verb. Quick boarding and an
## overwhelming crew advantage take the instant path (`attempt_boarding`, exactly
## as before); anything else locks the target and opens the Three Bells battle.
## Returns true when a boarding began or resolved.
func begin_boarding() -> bool:
	if is_boarding_active():
		return false
	var players = get_tree().get_nodes_in_group("player_ship")
	if not is_instance_valid(_eligible_enemy) or players.size() == 0:
		return false
	var player_dmg = players[0].get_node_or_null("ShipDamage")
	var enemy_dmg = _eligible_enemy.get_node_or_null("ShipDamage")
	if not player_dmg or not enemy_dmg or enemy_dmg.is_destroyed():
		return false

	var reason := _auto_route_reason(players[0], player_dmg, enemy_dmg)
	if reason != "":
		boarding_routed.emit(reason)
		return attempt_boarding()

	_provoke(_eligible_enemy)
	if AudioManager: AudioManager.play_sound("boarding_start")
	_locked_enemy = _eligible_enemy
	boarding_started.emit(_locked_enemy)
	return true


## Ends a tactical boarding without a result (the player's ship died, the world
## unloaded). The target is left exactly as it was.
func cancel_boarding() -> void:
	_locked_enemy = null


## Called by the BoardingOverlay when the battle ends. `details` may carry
## `loot_mult` (float), `rng` (the battle's RandomNumberGenerator, so loot is
## replayable) and `crew_loss_fraction` (overrides the BoardingData default).
func resolve_tactical(outcome_id: String, success: bool, details: Dictionary = {}) -> void:
	if not is_boarding_active():
		_locked_enemy = null
		return
	_apply_outcome(_locked_enemy, success, outcome_id, details)


func _auto_route_reason(player: Node, player_dmg: Node, enemy_dmg: Node) -> String:
	if SettingsManager and SettingsManager.quick_boarding:
		return "quick"
	if _attacker_strength(player, player_dmg) >= boarding_data.overwhelm_ratio * enemy_dmg.crew:
		return "overwhelm"
	return ""


func _attacker_strength(player: Node, player_dmg: Node) -> float:
	var captain_mod = 1.0
	if "active_captain" in player and player.active_captain:
		captain_mod = player.active_captain.get("boarding_modifier") if "boarding_modifier" in player.active_captain else 1.0
	return player_dmg.crew * captain_mod * boarding_data.attacker_advantage


func _provoke(enemy: Node) -> void:
	# M25 heat — grappling a passive ambient hull provokes it, so a failed boarding
	# leaves you in a real fight rather than beside a ship that keeps ignoring you.
	var target_ai = enemy.get_node_or_null("EnemyAI")
	if target_ai and target_ai.has_method("provoke"):
		target_ai.provoke()


func attempt_boarding() -> bool:
	if not is_instance_valid(_eligible_enemy):
		return false

	var players = get_tree().get_nodes_in_group("player_ship")
	if players.size() == 0:
		return false
	var player = players[0]

	var player_dmg = player.get_node_or_null("ShipDamage")
	var enemy_dmg = _eligible_enemy.get_node_or_null("ShipDamage")
	if not player_dmg or not enemy_dmg:
		return false

	# Never board a hull that is already destroyed.
	if enemy_dmg.is_destroyed():
		_eligible_enemy = null
		return false

	_provoke(_eligible_enemy)

	if AudioManager: AudioManager.play_sound("boarding_start")

	var attacker_strength = _attacker_strength(player, player_dmg)
	var defender_strength = enemy_dmg.crew

	var success = attacker_strength > defender_strength
	_apply_outcome(_eligible_enemy, success, "auto_win" if success else "auto_loss")
	return true


## The shared tail of every boarding: crew loss, loot, destroying a beaten hull,
## and the signals. Extracted from `attempt_boarding` (M30 2.1) so the tactical
## battle pays out through exactly the same code, once.
func _apply_outcome(enemy: Node, success: bool, outcome_id: String, details: Dictionary = {}) -> void:
	var players = get_tree().get_nodes_in_group("player_ship")
	var player_dmg = players[0].get_node_or_null("ShipDamage") if players.size() > 0 else null
	var enemy_dmg = enemy.get_node_or_null("ShipDamage")
	var loot = {}

	if AudioManager: AudioManager.play_sound("boarding_success" if success else "boarding_fail")

	var loss_fraction: float = float(details.get("crew_loss_fraction",
		boarding_data.win_crew_loss_fraction if success else boarding_data.lose_crew_loss_fraction))
	if player_dmg:
		player_dmg.crew = max(0.0, player_dmg.crew - player_dmg.ship_stats.max_crew * loss_fraction)

	if success:
		# calculate loot
		var loot_table: LootTableData = null
		if enemy.is_in_group("boss_ship"):
			loot_table = load("res://resources/loot/BossLoot.tres")
		elif "faction" in enemy and enemy.get("faction") and enemy.get("faction").get("faction_id") == "merchant_guild":
			loot_table = load("res://resources/loot/MerchantLoot.tres")
		else:
			loot_table = load("res://resources/loot/StandardEnemyLoot.tres")

		if loot_table:
			loot = loot_table.roll(details.get("rng", null))

			# M29 A.3: use shared loot scaling data
			var notoriety = 0.0
			if get_tree().root.has_node("EmpireManager"):
				notoriety = get_tree().root.get_node("EmpireManager").notoriety

			var loot_mult = LootScalingData.multiplier(int(enemy_dmg.ship_stats.max_crew), notoriety)
			var outcome_mult: float = float(details.get("loot_mult", 1.0))

			for key in loot.keys():
				loot[key] = int(loot[key] * boarding_data.loot_multiplier * loot_mult * outcome_mult)

			var rm = get_node_or_null("/root/ResourceManager")
			if rm and rm.has_method("add_resource"):
				for res in loot:
					rm.add_resource(res, loot[res])

		# enemy loses. Route through ShipDamage's own destroy path rather than
		# emitting `destroyed` directly, so `_is_destroyed` is actually set —
		# otherwise the wreck stays eligible and a second attempt_boarding()
		# call re-rolls and re-grants the whole loot table.
		# M29 A.1: mark loot as claimed so ShipController._on_died() skips _spawn_loot()
		enemy.set_meta("loot_claimed", true)
		enemy.set_meta("boarding_outcome", outcome_id)
		enemy_dmg.hull = 0.0
		enemy_dmg.mark_destroyed()
	# else: the enemy survives

	# Read identity before clearing eligibility below — a dedicated (non-shared)
	# boss ShipStats authors a unique ship_id, so this doubles as boss
	# identification without a second id field.
	var target_faction_id := ""
	if "faction" in enemy and enemy.get("faction"):
		target_faction_id = str(enemy.get("faction").get("faction_id"))
	var target_ship_id := ""
	if enemy_dmg.ship_stats:
		target_ship_id = enemy_dmg.ship_stats.ship_id

	# Clear eligibility either way. On a win the target is a wreck; on a loss the
	# player must re-close and re-qualify rather than mashing the prompt against
	# the same enemy until the deterministic comparison happens to flip.
	_eligible_enemy = null
	_locked_enemy = null

	boarding_resolved.emit(success, loot, target_faction_id, target_ship_id)
	boarding_outcome.emit(outcome_id, {
		"success": success, "loot": loot, "enemy": enemy,
		"target_faction_id": target_faction_id, "target_ship_id": target_ship_id,
	})
	_clear_prompt()
