@tool
class_name DialogueBeatData extends Resource

## Purpose: one line of chapter dialogue — the opening/closing beats a
## `ChapterData` carries (`docs/06_NARRATIVE_AND_WORLD.md` §6).
## Responsibilities: pure data, rendered by `TutorialDialogue.tscn` (speaker +
## portrait + text + Continue), which already exists and is reused unchanged.

@export var speaker_id: String = ""
@export var speaker_name: String = ""
## Empty renders name-only — portraits are a later art pass, not a blocker
## (`docs/12_CHARACTER_BIBLE.md` §7).
@export var portrait_path: String = ""
@export_multiline var text: String = ""

enum Mood { NEUTRAL, WARM, GRIM, ANGRY, AMUSED }
@export var mood: Mood = Mood.NEUTRAL
