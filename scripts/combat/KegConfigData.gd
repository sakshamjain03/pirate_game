class_name KegConfigData extends Resource

## Purpose: powder keg configuration for the player ship — M30 W1 task 1.10.
## Kegs are droppable consumables that float astern on a fuse and blow up in a
## radius when a hostile hull comes close (or the fuse burns out).
## Driven by Resource data (resources/combat/KegConfig.tres), never hardcoded.
##
## "Sortie" = one trip out of port: the stock refills to stock_per_sortie when
## the player docks (WorldManager._on_dock_completed) and is NOT reset by
## starting an encounter — otherwise kegs would be unlimited at sea. A fresh
## World load also starts with a full stock (the count is not saved).

@export_group("Stock")
## Number of kegs available per sortie before restocking at port.
@export_range(1, 10) var stock_per_sortie: int = 3  # placeholder: tune in M31

@export_group("Drop")
## Full angle (degrees) of the stern cone an enemy must be inside for the
## context button to offer Keg. Centred on the hull's aft axis (+Z).
@export_range(1.0, 180.0) var stern_cone_degrees: float = 60.0  # placeholder: tune in M31
## How far astern (world units) that enemy may be.
@export var stern_cone_range: float = 60.0  # placeholder: tune in M31
## The keg lands this far astern of the hull's origin (clear of the rudder).
@export var drop_offset: float = 6.0  # placeholder: tune in M31

@export_group("Fuse")
## Seconds before an untouched keg detonates on its own.
@export var fuse_seconds: float = 12.0  # placeholder: tune in M31
## A hostile hull within this distance of the keg sets it off (contact or
## proximity — one distance check covers both).
@export var proximity_radius: float = 8.0  # placeholder: tune in M31

@export_group("Detonation")
## Radius (in world units) from the keg's position where damage is applied.
@export_range(1.0, 100.0) var detonation_radius: float = 30.0  # placeholder: tune in M31
## Flat damage dealt to every hostile hull within the radius.
@export_range(1.0, 200.0) var detonation_damage: float = 80.0  # placeholder: tune in M31
