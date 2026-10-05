class_name KegConfigData extends Resource

## Purpose: powder keg configuration for player ship — M30 W1 task 1.10.
## Kegs are droppable consumables that detonate in a radius, dealing area damage.
## Driven by Resource data, never hardcoded.

@export_group("Stock")
## Number of kegs available per sortie before restocking at a friendly port.
@export_range(1, 10) var stock_per_sortie: int = 3  # placeholder: tune in M31

@export_group("Detonation")
## Radius (in world units) from the keg's position where damage is applied.
## # placeholder: tune in M31
@export_range(10.0, 100.0) var detonation_radius: float = 30.0
## Flat damage dealt to every hull within the radius.
## # placeholder: tune in M31
@export_range(10.0, 200.0) var detonation_damage: float = 80.0
