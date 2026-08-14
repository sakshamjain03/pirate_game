class_name BoardingSystem extends Node

signal boarding_prompt_available(enemy_ship: Node)
signal boarding_prompt_unavailable()
signal boarding_resolved(success: bool, loot: Dictionary)

@export var boarding_data: BoardingData

var _eligible_enemy: Node = null

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
		
	var captain_mod = 1.0
	if "active_captain" in player and player.active_captain:
		captain_mod = player.active_captain.get("boarding_modifier") if "boarding_modifier" in player.active_captain else 1.0
		
	var attacker_strength = player_dmg.crew * captain_mod * boarding_data.attacker_advantage
	var defender_strength = enemy_dmg.crew
	
	var success = attacker_strength > defender_strength
	var loot = {}
	
	if success:
		player_dmg.crew = max(0.0, player_dmg.crew - player_dmg.ship_stats.max_crew * boarding_data.win_crew_loss_fraction)
		
		# calculate loot
		var loot_table: LootTableData = null
		if _eligible_enemy.is_in_group("boss_ship"):
			loot_table = load("res://resources/loot/BossLoot.tres")
		elif "faction" in _eligible_enemy and _eligible_enemy.get("faction") and _eligible_enemy.get("faction").get("faction_id") == "merchant_guild":
			loot_table = load("res://resources/loot/MerchantLoot.tres")
		else:
			loot_table = load("res://resources/loot/StandardEnemyLoot.tres")
			
		if loot_table:
			loot = loot_table.roll()
			
			var class_mult = 1.0
			if enemy_dmg.ship_stats:
				class_mult = clamp(enemy_dmg.ship_stats.max_crew / 8.0, 1.0, 3.0)
				
			var not_mult = 1.0
			if get_tree().root.has_node("EmpireManager"):
				var emp = get_tree().root.get_node("EmpireManager")
				not_mult = 1.0 + (emp.notoriety / 100.0)
				
			for key in loot.keys():
				loot[key] = int(loot[key] * boarding_data.loot_multiplier * class_mult * not_mult)
			
			var rm = get_node_or_null("/root/ResourceManager")
			if rm and rm.has_method("add_resource"):
				for res in loot:
					rm.add_resource(res, loot[res])
					
		# enemy loses. Route through ShipDamage's own destroy path rather than
		# emitting `destroyed` directly, so `_is_destroyed` is actually set —
		# otherwise the wreck stays eligible and a second attempt_boarding()
		# call re-rolls and re-grants the whole loot table.
		enemy_dmg.hull = 0.0
		enemy_dmg.mark_destroyed()
	else:
		player_dmg.crew = max(0.0, player_dmg.crew - player_dmg.ship_stats.max_crew * boarding_data.lose_crew_loss_fraction)
		# enemy survives
		
	# Clear eligibility either way. On a win the target is a wreck; on a loss the
	# player must re-close and re-qualify rather than mashing the prompt against
	# the same enemy until the deterministic comparison happens to flip.
	_eligible_enemy = null

	boarding_resolved.emit(success, loot)
	_clear_prompt()
	return true
