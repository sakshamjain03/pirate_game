class_name UpgradeRoller

## Purpose: the one battle-upgrade offer roll (M30 Wave 0, task 0.15 / B8).
## EncounterManager.roll_upgrade_choices() and MaelstromRun.pick_choices() each
## carried their own copy of this loop; Wave 5's tags, keystones and faction
## pools land here once instead of twice.
## Responsibilities: weighted sample without replacement, never offering an
## upgrade the ship's CombatModifiers can no longer take (a maxed option on a
## choice screen does nothing — fewer options is better). Optional seeded RNG
## for deterministic callers and tests.

static func roll(pool: Array, count: int, mods: CombatModifiers = null,
		rng: RandomNumberGenerator = null) -> Array[BattleUpgradeData]:
	var available: Array[BattleUpgradeData] = []
	for u in pool:
		if u is BattleUpgradeData and (mods == null or mods.can_apply(u)):
			available.append(u)

	var out: Array[BattleUpgradeData] = []
	while out.size() < count and not available.is_empty():
		var total := 0.0
		for u in available:
			total += maxf(0.0, u.weight)
		if total <= 0.0:
			break
		var r: float = (rng.randf() if rng else randf()) * total
		var acc := 0.0
		var picked: BattleUpgradeData = available[available.size() - 1]
		for u in available:
			acc += maxf(0.0, u.weight)
			if r <= acc:
				picked = u
				break
		out.append(picked)
		available.erase(picked)
	return out
