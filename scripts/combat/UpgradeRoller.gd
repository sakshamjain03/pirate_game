class_name UpgradeRoller

## W0-4.4: Shared upgrade roller used by both EncounterManager and MaelstromRun.
## Provides weighted random selection without replacement, filtered by applicability.

static func roll(pool: Array, count: int, held: Dictionary = {},
		filters: Array = []) -> Array:
	## Weighted sample without replacement from pool. Returns an array of exactly
	## `count` upgrades (or fewer if pool is exhausted after filtering).
	##
	## Args:
	## - pool: Array of BattleUpgradeData to select from
	## - count: How many upgrades to pick
	## - held: (optional) Map of held upgrade_id to stack count, for weighting
	## - filters: (optional) Array of callables(upgrade) -> bool for filtering
	##
	## Both callers pre-filter by applicability (can_apply), so this is agnostic
	## to the context. Returns the same distribution as the inlined versions.

	var out: Array = []
	var available: Array = []

	# Apply filters (including applicability)
	for u in pool:
		if not u:
			continue
		var keep = true
		for filter in filters:
			if not filter.call(u):
				keep = false
				break
		if keep:
			available.append(u)

	# Weighted selection without replacement
	while out.size() < count and not available.is_empty():
		var total: float = 0.0
		for u in available:
			total += float(u.weight)

		if total <= 0.0:
			break

		var roll: float = randf() * total
		var acc: float = 0.0
		var picked = available[available.size() - 1]

		for u in available:
			acc += float(u.weight)
			if roll <= acc:
				picked = u
				break

		out.append(picked)
		available.erase(picked)

	return out
