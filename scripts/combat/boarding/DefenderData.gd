@tool
class_name DefenderData extends Resource

## Purpose: one kind of man (or woman) defending a ship in a Three Bells boarding (M30 2.2).
## Responsibilities: pure data. `BoardingDeckBuilder` places these by zone; `BoardingBattle`
##   plays them. `removed_by_tags` is how gunnery shapes the deck: a hit tag logged on the target
##   before boarding ("grape", "chain", "stern_rake") removes or wounds the matching defenders.

@export var id: StringName = &""
@export var display_name: String = ""
@export var hp: int = 3  # placeholder: tune in M31
## Base damage of this defender's STRIKE/SHOOT intents (the intent's `power` is added).
@export var attack: int = 1  # placeholder: tune in M31
## Enemy morale lost when this defender goes down.
@export var morale_value: int = 4  # placeholder: tune in M31
## Hit tags that remove one of these from the deck before the battle starts.
@export var removed_by_tags: Array[StringName] = []
## Hit tags that wound (rather than remove) this defender before the battle starts.
@export var wounded_by_tags: Array[StringName] = []
## The rotation this defender cycles through, one intent per bell.
@export var intents: Array[DefenderIntentData] = []
## Officers are the leader: their fall costs extra morale, and they flee at the last bell.
@export var is_officer: bool = false
@export var glyph: String = ""
