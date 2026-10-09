class_name BoardingZone extends RefCounted

## Purpose: the shape of an enemy deck for the Three Bells battle (M30 2.2) — which zones
##   exist and which touch. Static data and helpers only, kept apart from `BoardingBattle`
##   so the resource scripts can name a zone without a dependency cycle.
## Layout: FORECASTLE — WAIST — QUARTERDECK, with the HOLD reached below the WAIST.

enum Id { FORECASTLE, WAIST, QUARTERDECK, HOLD }

const COUNT := 4
const NAMES := ["Forecastle", "Waist", "Quarterdeck", "Hold"]

const _NEIGHBOURS := {
	Id.FORECASTLE: [Id.WAIST],
	Id.WAIST: [Id.FORECASTLE, Id.QUARTERDECK, Id.HOLD],
	Id.QUARTERDECK: [Id.WAIST],
	Id.HOLD: [Id.WAIST],
}


static func neighbours(zone: int) -> Array:
	return _NEIGHBOURS.get(zone, [])


static func are_adjacent(a: int, b: int) -> bool:
	return b in neighbours(a)


## Steps between two zones along the deck graph (0 = same zone).
static func distance(a: int, b: int) -> int:
	if a == b:
		return 0
	var seen := {a: 0}
	var frontier: Array = [a]
	while not frontier.is_empty():
		var next: Array = []
		for z in frontier:
			for n in neighbours(z):
				if not seen.has(n):
					seen[n] = int(seen[z]) + 1
					if n == b:
						return seen[n]
					next.append(n)
		frontier = next
	return -1


## The adjacent zone one step closer to `target` (the first such neighbour), or -1.
static func step_toward(from_zone: int, target: int) -> int:
	var d := distance(from_zone, target)
	for n in neighbours(from_zone):
		if distance(n, target) < d:
			return n
	return -1


## The adjacent zone one step farther from `away_from`, or -1 when there is none.
static func step_away(from_zone: int, away_from: int) -> int:
	var d := distance(from_zone, away_from)
	for n in neighbours(from_zone):
		if distance(n, away_from) > d:
			return n
	return -1
