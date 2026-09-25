extends Resource
class_name WorldBoundsData

## Purpose: the outer edge of the sailable world.
## Responsibilities: pure data — how far from the origin (Port Royal) a ship may sail before
## being held at the wall. Square, centered on the world origin, sized to comfortably contain
## every currently authored region (Ghost Reaches' 1150u ring is the outermost) with headroom.
## Growing past this in a future milestone means revisiting this one number.
## Dependencies: None — loaded directly by ShipController.

@export var half_extent: float = 1400.0
## M23 — inside `half_extent - edge_margin` a ship is pushed back inward by a soft spring
## (`edge_spring` m/s² of inward acceleration per metre of penetration), so it turns away
## gracefully instead of slamming into the hard position clamp at `half_extent` and grinding
## along it. The clamp stays as the backstop.
@export var edge_margin: float = 25.0
@export var edge_spring: float = 0.6
