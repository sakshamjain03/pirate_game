@tool
class_name ShipStats extends Resource

@export_group("Identity")
## Stable key for save data and lookups, independent of the resource's filename
## or display text (`docs/13_CAMPAIGN_LEVELS_1-5.md` E2).
@export var ship_id: String = ""
## Shown in the Shipyard. Previously derived from the resource filename, which
## meant no hull could be renamed, re-skinned, or localised without moving the
## .tres itself.
@export var display_name: String = ""
## Size/power tier, 1 (Dinghy/Sloop) through 5 (Man O'War). Used for pricing,
## for the enemy notoriety ladder (previously approximated via `max_crew`), and
## for role/module gating.
@export_range(1, 5) var ship_class: int = 1

@export_group("Cost")
## Purchase price (`docs/13_CAMPAIGN_LEVELS_1-5.md` E1). Previously derived from
## `mass`, which produced a price ladder cheap enough to defeat M6 Requirement 8
## (loot funds the empire, the empire funds a better ship) and silently re-priced
## every hull whenever buoyancy tuning touched `mass`.
@export_range(0, 50000) var cost_gold: int = 0
@export_range(0, 5000) var cost_wood: int = 0
@export_range(0, 2000) var cost_iron: int = 0
@export_range(0, 500) var cost_rum: int = 0

@export_group("Movement")
@export_range(0.0, 100.0) var max_speed: float = 30.0
@export_range(0.0, 10.0) var acceleration: float = 2.0
@export_range(0.0, 10.0) var deceleration: float = 1.5
@export_range(0.0, 10.0) var turn_rate: float = 1.5
@export_range(0.0, 1.0) var drift_factor: float = 0.3

@export_group("Physics")
@export_range(0.0, 10000.0) var mass: float = 5000.0
@export_range(0.0, 1.0) var buoyancy: float = 0.8
@export_range(0.0, 1.0) var stability: float = 0.7
@export_range(0.0, 1.0) var reverse_turn_modifier: float = 0.5
@export_range(0.0, 20.0) var drift_compensation_multiplier: float = 5.0
@export_range(0.0, 10.0) var water_drag_multiplier: float = 2.0
## Range is 0..30 rather than 0..20 because the authored ships form a deliberate
## ladder scaling with hull size (Dinghy 8 -> Galleon 20 -> ManOWar 25), and
## ManOWar's 25 sat outside the old range. Out-of-range values still load at
## runtime, so this was never silently dropped — but the inspector clamped it,
## so editing ManOWar in the editor would have quietly snapped it to 20.
@export_range(0.0, 30.0) var stability_torque_multiplier: float = 10.0
@export_range(0.0, 10.0) var linear_damp: float = 0.5
@export_range(0.0, 10.0) var angular_damp: float = 2.0

@export_group("Visual")
@export var model_path: String = "res://assets/models/ships/player_ship.glb"
## Empty means "keep the model's own colormap colors". The previous default
## pointed at a ShipMaterial.tres that does not exist in the project, so any
## ShipStats that didn't override it made KenneyMaterialApplier fail to load a
## base material and silently skip the toon/outline pass entirely.
@export var material_path: String = ""

@export_group("Combat")
@export_range(1.0, 1000.0) var max_health: float = 100.0
@export_range(1.0, 1000.0) var max_sails: float = 100.0
@export_range(1.0, 200.0) var max_crew: float = 20.0
@export_range(1.0, 5.0) var stern_crit_multiplier: float = 1.5
@export_range(0.0, 180.0) var stern_arc_degrees: float = 60.0
@export_range(0.0, 1.0) var min_speed_fraction: float = 0.35
@export_range(0.0, 1.0) var optimal_crew_fraction: float = 0.5
@export_range(1.0, 100.0) var cannon_damage: float = 15.0
@export_range(0.1, 10.0) var fire_rate: float = 2.0
## Effective firing range. This is the range the auto-fire solver gates on, so it
## must be a distance a cannonball can actually reach: a ball leaves the gun port
## at y≈1.7 with `gravity_scale = 0.5`, so it splashes down after ~0.83 s and
## travels roughly `cannon_speed * 0.83`. The pre-auto-fire values (200–400) were
## 2–3× beyond that, which was harmless while firing was a manual key press but
## would have made auto-fire shoot endlessly at targets it could never hit.
@export_range(10.0, 1000.0) var cannon_range: float = 85.0
@export_range(10.0, 200.0) var cannon_speed: float = 100.0
## Half-width of the broadside firing cone, measured off the beam. Cannons
## auto-fire once a hostile is inside this cone and within `cannon_range`
## (`docs/navalCombat.md` §4/§5). Wider = more forgiving to aim.
@export_range(5.0, 90.0) var firing_arc_degrees: float = 35.0

@export_group("Chasers")
## Bow/stern weapon slots (`docs/navalCombat.md` §3: "Port broadside, Starboard
## broadside, Bow weapon, Stern weapon, Special weapon"). Most starter hulls
## have neither — §3 is explicit that "most starter ships need only broadside
## + one special" — so these default off rather than every hull growing chaser
## guns for free.
@export var has_bow_chaser: bool = false
@export var has_stern_chaser: bool = false
## A chaser is a single long gun, not a broadside battery: lower damage and a
## much narrower arc than the ship's broadside, traded for extra range so it
## can harass a target the broadside can't yet bear on.
@export_range(1.0, 100.0) var chaser_damage: float = 10.0
@export_range(10.0, 1000.0) var chaser_range: float = 110.0
@export_range(1.0, 45.0) var chaser_arc_degrees: float = 15.0

@export_group("Special Broadside")
## The player-timed full volley layered on top of automatic fire
## (`docs/navalCombat.md` §4). Fires both sides at once, ignoring the per-side
## reload, at a damage premium.
@export_range(1.0, 60.0) var special_broadside_cooldown: float = 12.0
@export_range(1.0, 5.0) var special_broadside_damage_multiplier: float = 1.75
