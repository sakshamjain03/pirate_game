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
## M30 W2 (2.5): what boarding this eligible target would face, for the preview strip on its
## health bar. Re-emitted as gunnery changes the deck. `summary` is BoardingDeckBuilder.summarize().
signal deck_preview_changed(enemy_ship: Node, summary: Dictionary)
## The two outcomes that take a ship's colours (M30 2.8): the Quarterdeck objective and the crew
## striking. Either opens the Prize Ledger (unless the hull is a boss, which is simply destroyed).
const COLOURS_OUTCOMES: Array[String] = ["colours", "struck"]

## begin_boarding() skipped the battle: reason is "quick" (setting) or "overwhelm".
signal boarding_routed(reason: String)

@export var boarding_data: BoardingData

var _eligible_enemy: Node = null
## The target of a tactical boarding in progress. Held apart from
## `_eligible_enemy`, which keeps tracking range while the battle is open.
var _locked_enemy: Node = null
## The Three Bells battle for the locked target (M30 2.3), built when it is locked and
## driven by the BoardingOverlay. Null outside a tactical boarding.
var battle: BoardingBattle = null
## The deck that battle started from, kept for the overlay's preview and the tests.
var deck: BoardingDeck = null

func _ready() -> void:
	# A debug capture harness instances World under its own root, so a fixed scene path
	# misses; WorldHUD finds the system through this group there (as with EncounterManager).
	add_to_group(&"boarding_system")
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
		_track_hits(enemy)

		var dmg = enemy.get_node_or_null("ShipDamage")
		if not dmg or dmg.hull <= 0.0:
			continue
			
		var max_hp = dmg.get_effective_max_health() if dmg.has_method("get_effective_max_health") else dmg.ship_stats.max_health
		var hull_pct = dmg.hull / max(max_hp, 1.0)
		# M30 W2 (2.6) - a ship that struck its colours is takeable at any hull.
		if hull_pct > boarding_data.hull_threshold and not _is_struck(enemy):
			continue
			
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist <= best_dist:
			best_enemy = enemy
			best_dist = dist
			
	if best_enemy != _eligible_enemy:
		_eligible_enemy = best_enemy
		if _eligible_enemy:
			boarding_prompt_available.emit(_eligible_enemy)
			_emit_preview(_eligible_enemy)
		else:
			_clear_prompt()

func _clear_prompt() -> void:
	if _eligible_enemy != null:
		_eligible_enemy = null
		boarding_prompt_unavailable.emit()

func _is_struck(enemy: Node) -> bool:
	return is_instance_valid(enemy) and enemy.get_meta(&"struck", false)


## The Board verb applies: a target is in range and has not struck.
func can_board() -> bool:
	return is_instance_valid(_eligible_enemy) and not _is_struck(_eligible_enemy)


## The Take Prize verb applies: the target in range has struck its colours.
func can_take_prize() -> bool:
	return is_instance_valid(_eligible_enemy) and _is_struck(_eligible_enemy)


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

	var built := _build_deck(players[0], _eligible_enemy, player_dmg, enemy_dmg)
	if built == null:
		# No deck profile is authored for this hull: play it as the old instant comparison
		# rather than opening an empty battle.
		push_error("BoardingSystem: no BoardingDeckProfile for this target; resolving instantly")
		return attempt_boarding()

	_provoke(_eligible_enemy)
	if AudioManager: AudioManager.play_sound("boarding_start")
	_locked_enemy = _eligible_enemy
	deck = built
	battle = BoardingBattle.new(deck, boarding_data, randi())
	boarding_started.emit(_locked_enemy)
	return true


## Ends a tactical boarding without a result (the player's ship died, the world
## unloaded). The target is left exactly as it was.
func cancel_boarding() -> void:
	_locked_enemy = null
	battle = null
	deck = null


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
	# Read before the hull is zeroed below: how much hull the target had when it was taken.
	var hull_fraction := 0.0
	var captives := int(round(enemy_dmg.crew)) if enemy_dmg else 0
	if enemy_dmg and enemy_dmg.ship_stats:
		var max_hull: float = enemy_dmg.get_effective_max_health() if enemy_dmg.has_method("get_effective_max_health") \
				else enemy_dmg.ship_stats.max_health
		hull_fraction = clampf(enemy_dmg.hull / maxf(max_hull, 1.0), 0.0, 1.0)

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
		# M30 W2 (2.8) - a ship taken by its colours is CAPTURED, not sunk: ShipController._on_died
		# skips the explosion and the notoriety for it. A boss is never captured.
		if outcome_id in COLOURS_OUTCOMES and bool(details.get("captures_ship", false)) \
				and not enemy.is_in_group("boss_ship"):
			enemy.set_meta("captured", true)
		# M30 W2 (2.6) - taking the surrendered rather than sinking them is Renown.
		if _is_struck(enemy) and EmpireManager:
			EmpireManager.shift_axis(-NotorietyGainsData.get_default().renown_take_prize)
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
	battle = null
	deck = null

	boarding_resolved.emit(success, loot, target_faction_id, target_ship_id)
	boarding_outcome.emit(outcome_id, {
		"success": success, "loot": loot, "enemy": enemy,
		"target_faction_id": target_faction_id, "target_ship_id": target_ship_id,
		# What the Prize Ledger needs, read before the hull is gone.
		"captured": is_instance_valid(enemy) and bool(enemy.get_meta("captured", false)),
		"officers_escaped": bool(details.get("officers_escaped", false)),
		"ship_class": enemy_dmg.ship_stats.ship_class if enemy_dmg and enemy_dmg.ship_stats else 1,
		"is_boss": is_instance_valid(enemy) and enemy.is_in_group("boss_ship"),
		"hull_fraction": hull_fraction,
		"captives": captives,
	})
	_clear_prompt()


## Keeps the last few player hits on each enemy (one PackedStringArray of "ammo:<id>" and
## "facing:<facing>" per hit) as node meta, so the deck can be shaped by the gunnery that
## brought the target down. Meta dies with the hull; nothing needs pruning.
const HIT_LOG_META := &"hit_tag_log"

func _track_hits(enemy: Node) -> void:
	var dmg = enemy.get_node_or_null("ShipDamage")
	if dmg == null or not dmg.has_signal("hit_resolved") or dmg.has_meta(&"boarding_tracked"):
		return
	dmg.set_meta(&"boarding_tracked", true)
	dmg.hit_resolved.connect(func(source: Node, _facing: StringName, _deltas: Dictionary,
			_ammo: StringName, hit_tags: PackedStringArray):
		if not is_instance_valid(enemy) or source == null or not source.is_in_group("player_ship"):
			return
		var log: Array = enemy.get_meta(HIT_LOG_META, [])
		log.append(hit_tags)
		while log.size() > boarding_data.hit_log_size:
			log.pop_front()
		enemy.set_meta(HIT_LOG_META, log)
		if enemy == _eligible_enemy:
			_emit_preview(enemy))


func _build_deck(player: Node, enemy: Node, player_dmg: Node, enemy_dmg: Node) -> BoardingDeck:
	var faction_id := ""
	if "faction" in enemy and enemy.get("faction"):
		faction_id = str(enemy.get("faction").get("faction_id"))
	var stats: ShipStats = enemy_dmg.ship_stats
	var profile := BoardingDeckBuilder.pick_profile(boarding_data.deck_profiles, faction_id,
			stats.ship_class if stats else 1, boarding_data.default_profile)
	if profile == null:
		return null
	var max_hp: float = enemy_dmg.get_effective_max_health() if enemy_dmg.has_method("get_effective_max_health") 			else stats.max_health
	var forward: Vector3 = -(enemy as Node3D).global_transform.basis.z
	var threats: Array = []
	for other in get_tree().get_nodes_in_group("enemy_ship"):
		if other == enemy or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		var odmg = other.get_node_or_null("ShipDamage")
		if odmg == null or odmg.hull <= 0.0:
			continue
		if (other as Node3D).global_position.distance_to((enemy as Node3D).global_position) 				<= boarding_data.outside_range:
			threats.append({"id": StringName(odmg.ship_stats.ship_id if odmg.ship_stats else "escort"),
					"name": odmg.ship_stats.display_name if odmg.ship_stats else "Escort"})
	var roles: Array[StringName] = []
	return BoardingDeckBuilder.build(profile, boarding_data, {
		"hit_tags": enemy.get_meta(HIT_LOG_META, []),
		"facing": BoardingDeckBuilder.entry_facing((enemy as Node3D).global_position, forward,
				(player as Node3D).global_position, profile),
		"hull_fraction": enemy_dmg.hull / maxf(max_hp, 1.0),
		"crew_fraction": enemy_dmg.crew / maxf(stats.max_crew if stats else 1.0, 1.0),
		"player_crew": player_dmg.crew,
		"morale_scale": _morale_scale(enemy),
		"threats": threats,
		"roles": roles,
	})


## How much of its nerve the target has left, 0..1, or -1 when it has no MoraleComponent. A
## struck ship reads low, so Take Prize opens with the Colours already weakened.
func _morale_scale(enemy: Node) -> float:
	var morale = enemy.get_node_or_null("MoraleComponent")
	if morale and morale.has_method("morale_fraction"):
		return morale.morale_fraction()
	return -1.0


## The deck summary the target would present right now, or {} when it cannot be built.
func preview_for(enemy: Node) -> Dictionary:
	var players = get_tree().get_nodes_in_group("player_ship")
	if players.size() == 0 or not is_instance_valid(enemy):
		return {}
	var player_dmg = players[0].get_node_or_null("ShipDamage")
	var enemy_dmg = enemy.get_node_or_null("ShipDamage")
	if not player_dmg or not enemy_dmg:
		return {}
	var built := _build_deck(players[0], enemy, player_dmg, enemy_dmg)
	if built == null:
		return {}
	return BoardingDeckBuilder.summarize(built, boarding_data)


func _emit_preview(enemy: Node) -> void:
	var summary := preview_for(enemy)
	if not summary.is_empty():
		deck_preview_changed.emit(enemy, summary)
