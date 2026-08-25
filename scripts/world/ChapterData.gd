@tool
class_name ChapterData extends Resource

## Purpose: one campaign chapter — the frame `docs/04_GAME_LOOP.md` describes
## as "never a gate": opening beat, three-to-five objectives, closing beat,
## rewards. Adding a hypothetical Chapter 6 must require zero script changes
## (M7's own exit criterion) — this schema is the proof.
## Responsibilities: pure data. `CampaignManager` loads, gates and tracks these;
## nothing here runs on its own.

@export var chapter_id: String = ""
@export var chapter_number: int = 1
@export var title: String = ""
@export_multiline var log_summary: String = ""

@export_group("Gating")
## Empty = no region gate. A region's activation threshold already lives in
## `RegionData` — deliberately not duplicated here as a second notoriety number
## that could drift out of sync with it.
@export var required_region_id: String = ""
## Empty = no prior-chapter gate (Chapter 1).
@export var required_previous_chapter: String = ""

@export_group("Content")
@export var opening_beats: Array[DialogueBeatData] = []
@export var objectives: Array[ObjectiveData] = []
@export var closing_beats: Array[DialogueBeatData] = []

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_captain_id: String = ""
@export var reward_ship_id: String = ""
@export var reward_tech_id: String = ""
