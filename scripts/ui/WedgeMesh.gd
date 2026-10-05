class_name WedgeMesh extends RefCounted

## Purpose: the one flat "cone on the water" shape M30's readable-combat
## overlays share — the enemy wind-up wedge (ThreatDecals) and the rake cone on
## the player's target (RakeConeIndicator). One builder so both read as the same
## visual language and neither re-derives the fan geometry.
## Responsibilities: build a triangle-fan ArrayMesh in the local XZ plane, apex at
## the origin, pointing along local +X (a hull's starboard beam, the same axis
## ShipCombat fires along), and an unshaded translucent material for it.
## Dependencies: none.

## Local yaw (radians, about +Y) that turns the +X wedge to face each firing
## side of a hull. +X is starboard; rotating +X by +90° about Y gives -Z (bow).
const SIDE_YAW := {
	"starboard": 0.0,
	"port": PI,
	"bow": PI * 0.5,
	"stern": -PI * 0.5,
}


## `half_angle_deg` is measured off the wedge's centre line (FiringSolver's arc
## convention: a target is in arc when its angle off the beam is <= the arc).
static func build(half_angle_deg: float, length: float, segments: int = 12) -> ArrayMesh:
	var half := deg_to_rad(clampf(half_angle_deg, 1.0, 89.0))
	segments = maxi(segments, 2)
	var verts := PackedVector3Array()
	for i in range(segments):
		var a0 := -half + (2.0 * half) * float(i) / float(segments)
		var a1 := -half + (2.0 * half) * float(i + 1) / float(segments)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a1), 0.0, -sin(a1)) * length)
		verts.append(Vector3(cos(a0), 0.0, -sin(a0)) * length)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.albedo_color = color
	return mat


## A fresh, top-level MeshInstance3D wedge (top_level so a parent hull's roll and
## pitch never tilt the decal off the water — callers set global_transform).
static func make_instance(half_angle_deg: float, length: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build(half_angle_deg, length)
	mi.material_override = make_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	return mi


## Flat transform for a wedge on `ship`'s `side`, at world height `y`.
static func flat_transform(ship: Node3D, side: String, y: float) -> Transform3D:
	var yaw: float = ship.global_rotation.y + float(SIDE_YAW.get(side, 0.0))
	var origin := ship.global_position
	origin.y = y
	return Transform3D(Basis(Vector3.UP, yaw), origin)
