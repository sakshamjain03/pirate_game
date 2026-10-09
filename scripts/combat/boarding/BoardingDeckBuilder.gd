class_name BoardingDeckBuilder extends RefCounted

## Purpose: turns the ship the player's gunnery left behind into a `BoardingDeck` (M30 2.3).
## Responsibilities: static and pure — no Node access, so it tests without a scene.
##   - which profile (faction x class) applies,
##   - removals and wounds from the target's recent `hit_tags` (grape removes Deckhands, chain
##     removes Riggers, a stern rake wounds the Officer and drains morale),
##   - the entry zone from the bearing the player closes on (bow -> Forecastle, beam -> Waist,
##     stern -> Quarterdeck),
##   - the crew fraction trimming the rest, and the player's boarders from their own crew.
##
## `hit_tags` is the log `BoardingSystem` keeps from the target's `ShipDamage.hit_resolved`:
## one PackedStringArray per recent player hit, holding "ammo:<id>" and "facing:<facing>".


## The best profile for this faction and hull class, or `fallback`. An exact faction whose class
## range covers the hull wins; then any matching-faction profile; then a faction-less one.
static func pick_profile(profiles: Array, faction_id: String, ship_class: int,
		fallback: BoardingDeckProfile = null) -> BoardingDeckProfile:
	var faction_only: BoardingDeckProfile = null
	var generic: BoardingDeckProfile = null
	for p in profiles:
		var prof := p as BoardingDeckProfile
		if prof == null:
			continue
		var covers := ship_class >= prof.ship_class_min and ship_class <= prof.ship_class_max
		if prof.faction_id == faction_id and not faction_id.is_empty():
			if covers:
				return prof
			if faction_only == null:
				faction_only = prof
		elif prof.faction_id.is_empty() and covers and generic == null:
			generic = prof
	if faction_only != null:
		return faction_only
	if generic != null:
		return generic
	return fallback


## &"bow", &"stern" or &"beam": which side of the enemy the player is closing on.
## `enemy_forward` is the enemy's forward axis (its -basis.z, per the hull-basis rule).
static func entry_facing(enemy_pos: Vector3, enemy_forward: Vector3, player_pos: Vector3,
		profile: BoardingDeckProfile) -> StringName:
	var to_player := Vector3(player_pos.x - enemy_pos.x, 0.0, player_pos.z - enemy_pos.z)
	var fwd := Vector3(enemy_forward.x, 0.0, enemy_forward.z)
	if to_player.length_squared() < 0.0001 or fwd.length_squared() < 0.0001:
		return &"beam"
	var angle := rad_to_deg(to_player.normalized().angle_to(fwd.normalized()))
	var bow_arc := profile.bow_arc_degrees if profile else 100.0
	var stern_arc := profile.stern_arc_degrees if profile else 100.0
	if angle <= bow_arc * 0.5:
		return &"bow"
	if angle >= 180.0 - stern_arc * 0.5:
		return &"stern"
	return &"beam"


static func entry_zone_for(facing: StringName) -> int:
	match facing:
		&"bow":
			return BoardingZone.Id.FORECASTLE
		&"stern":
			return BoardingZone.Id.QUARTERDECK
	return BoardingZone.Id.WAIST


## Builds the deck. `ctx`:
##   hit_tags: Array[PackedStringArray]   recent player hits on the target (may be empty)
##   facing: StringName                   &"bow"/&"beam"/&"stern" the player closed on
##   hull_fraction: float, crew_fraction: float     the target's, 0..1
##   player_crew: float                   the player's current crew
##   threats: Array[Dictionary]           [{"id": StringName, "name": String}] hostile hulls nearby
##   roles: Array[StringName]             roles the party can field (optional)
static func build(profile: BoardingDeckProfile, rules: BoardingData, ctx: Dictionary) -> BoardingDeck:
	var deck := BoardingDeck.new()
	deck.hull_fraction = float(ctx.get("hull_fraction", 0.2))
	deck.entry_zone = entry_zone_for(ctx.get("facing", &"beam"))
	deck.objectives = profile.objectives.duplicate()
	deck.timed_events = profile.timed_events.duplicate(true)
	deck.morale = profile.morale
	var roles: Array = ctx.get("roles", [])
	for r in roles:
		deck.roles.append(r)

	# The full crew, one entry per head.
	var entries: Array = []
	for i in profile.defenders.size():
		var data := profile.defenders[i]
		if data == null:
			continue
		var z: int = profile.defender_zones[i] if i < profile.defender_zones.size() \
				else BoardingZone.Id.WAIST
		entries.append({"data": data, "zone": z, "hp": data.hp})

	var hits: Array = ctx.get("hit_tags", [])
	var rake_hits := 0
	for hit in hits:
		var tags: PackedStringArray = hit
		for tag in tags:
			var t := StringName(tag)
			# Removals: this hit's tag takes the first matching heads off the deck.
			var removed := 0
			var i := 0
			while i < entries.size() and removed < profile.removals_per_hit:
				if t in (entries[i]["data"] as DefenderData).removed_by_tags:
					entries.remove_at(i)
					removed += 1
				else:
					i += 1
			# Wounds: the first matching head that still has hp to give.
			for e in entries:
				if t in (e["data"] as DefenderData).wounded_by_tags and int(e["hp"]) > 1:
					e["hp"] = maxi(1, int(e["hp"]) - profile.wound_per_hit)
					break
		if "facing:stern" in tags or "facing:bow" in tags:
			rake_hits += 1
	# A rake rattles the crew, but never strikes the colours before the first bell.
	deck.morale = maxi(rules.strike_morale + 1, deck.morale - rake_hits * profile.rake_morale)

	# The crew fraction trims what is left: a ship already bled of men is thinly manned.
	var target := maxi(profile.min_defenders,
			int(ceil(profile.defenders.size() * clampf(float(ctx.get("crew_fraction", 1.0)), 0.0, 1.0))))
	var idx := entries.size() - 1
	while entries.size() > target and idx >= 0:
		if not (entries[idx]["data"] as DefenderData).is_officer:
			entries.remove_at(idx)
		idx -= 1
	deck.defenders = entries

	# The party: a fraction of the player's own crew, within bounds.
	deck.player_hp = clampi(int(round(float(ctx.get("player_crew", 0.0)) * rules.boarder_fraction)),
			rules.boarder_min, rules.boarder_max)

	# Escorts still firing from outside the grapple.
	var threats: Array = ctx.get("threats", [])
	for t in threats.slice(0, rules.max_outside_threats):
		deck.outside_threats.append({"id": t.get("id", &"escort"), "name": t.get("name", "Escort"),
				"hp": profile.threat_hp, "damage": profile.threat_damage})
	return deck


## What the preview strip on the enemy health bar shows (2.5): a cheap read of the deck.
static func summarize(deck: BoardingDeck, rules: BoardingData) -> Dictionary:
	var officers := 0
	for e in deck.defenders:
		if (e["data"] as DefenderData).is_officer:
			officers += 1
	return {
		"defenders": deck.defenders.size(), "officers": officers, "morale": deck.morale,
		"bells": BoardingBattle.bell_count(deck.hull_fraction, rules),
		"entry": deck.entry_zone, "threats": deck.outside_threats.size(),
	}
