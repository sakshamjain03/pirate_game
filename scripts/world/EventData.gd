@tool
class_name EventData extends Resource

## Purpose: Defines one world event that can spawn during ocean exploration.
## Responsibilities: Stores event metadata (id, display text, spawn weight, region gating).
## Dependencies: None — pure data, loaded by EventManager from resources/world/events/.

@export var event_id: String
@export var display_text: String
@export var weight: float = 1.0
@export var min_region_tier: int = 1
