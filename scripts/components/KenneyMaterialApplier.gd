class_name KenneyMaterialApplier extends Node

## Purpose: Passes every GLB model surface through the stylized toon shader
## (with a chained outline pass). When a specific `material_path` is given
## (island props each pick their own — sand, grass, wood_dark, crimson, ...),
## that deliberately-authored color is respected as-is. Only the generic
## fallback (used when nothing more specific is set, e.g. ship hulls) seeds
## its color from the surface's OWN imported material instead of flattening
## every part of the model to one hardcoded color.
## Responsibilities: Recursively finds MeshInstance3D children and, for every
##                   surface that doesn't already have a custom override,
##                   assigns the resolved toon material.
## Dependencies: res://resources/materials/*.tres (ShaderMaterial using
##               res://resources/shaders/toon.gdshader, chained to outline.tres).
## Usage: Add as a child of any Node3D that contains Kenney GLB models. Set
##        `material_path` explicitly, or leave empty to fall back to whatever
##        `ship_stats.material_path` an ancestor ShipController exposes, or
##        finally the fallback material below.

const FALLBACK_MATERIAL_PATH := "res://resources/materials/wood_light.tres"

## Explicit override — set this when instantiating dynamically (e.g. from
## ShipVisuals) so resolution doesn't depend on tree position.
@export var material_path: String = ""

var _base_material: ShaderMaterial
var _using_fallback: bool = false

func _ready() -> void:
	_base_material = _resolve_material()
	_apply_to_children(get_parent())


func _resolve_material() -> ShaderMaterial:
	var path := material_path
	if path.is_empty():
		var stats := _find_ship_stats()
		if stats and not stats.material_path.is_empty():
			path = stats.material_path
	if path.is_empty():
		path = FALLBACK_MATERIAL_PATH
		_using_fallback = true

	var mat: Material = load(path)
	if not mat:
		push_error("KenneyMaterialApplier: Could not load material at: %s" % path)
		return null
	return mat as ShaderMaterial


func _find_ship_stats() -> ShipStats:
	## Walk up the tree looking for a node exposing a `ship_stats` resource
	## (e.g. ShipController on the ship's root RigidBody3D).
	var node := get_parent()
	while node:
		var value = node.get("ship_stats")
		if value is ShipStats:
			return value
		node = node.get_parent()
	return null


func _apply_to_children(node: Node) -> void:
	## Recursively walks the scene tree and assigns the resolved toon material
	## to every MeshInstance3D surface that doesn't already have a custom
	## override. Only the no-material_path fallback case seeds per-surface
	## color from that surface's own original material (see _build_toon_material).
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			var surface_count := mesh_inst.get_surface_override_material_count()
			for i in range(surface_count):
				if mesh_inst.get_surface_override_material(i) == null:
					if _using_fallback:
						var original := mesh_inst.mesh.surface_get_material(i) if mesh_inst.mesh else null
						mesh_inst.set_surface_override_material(i, _build_toon_material(original))
					else:
						mesh_inst.set_surface_override_material(i, _base_material)

		# Always recurse into children
		_apply_to_children(child)


func _build_toon_material(original: Material) -> ShaderMaterial:
	## Duplicates the shared toon base (keeping its shader + chained outline
	## next_pass) and re-seeds its color/texture from the surface's own
	## original material, so the toon shading style applies without flattening
	## every part of a model to the same color. Fallback-only — a model with no
	## explicit material_path (e.g. a ship hull) still needs part-to-part variety.
	if not _base_material:
		return null
	var mat := _base_material.duplicate() as ShaderMaterial
	if original is BaseMaterial3D:
		mat.set_shader_parameter("albedo", original.albedo_color)
		if original.albedo_texture:
			mat.set_shader_parameter("texture_albedo", original.albedo_texture)
		mat.set_shader_parameter("metallic", original.metallic)
		mat.set_shader_parameter("roughness", original.roughness)
	return mat
