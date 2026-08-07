class_name KenneyMaterialApplier extends Node

## Purpose: Passes every GLB model surface through the stylized toon shader
## (with a chained outline pass), while preserving each surface's own
## imported color/texture — the Kenney kit's colormap.png atlas is the
## project's only texture and the entire color identity of the art style.
## Responsibilities: Recursively finds MeshInstance3D children and, for every
##                   surface that doesn't already have a custom override,
##                   assigns a toon material seeded from that surface's own
##                   original color/texture. When a `material_path` is given
##                   (island props each pick their own — sand, grass,
##                   wood_dark, ...), its authored color is applied as a
##                   multiplicative TINT on top of that per-surface color,
##                   not a flat replacement — replacing outright flattened
##                   every part of a model to one solid color (e.g. a palm's
##                   trunk and fronds, or a house's walls/windows/door, all
##                   came out identical).
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


func override_material_path(new_path: String) -> void:
	## Re-resolves and re-applies with a different material_path after the
	## initial _ready() pass — e.g. Island.gd re-tinting a shared terrain
	## tile for a specific island's theme (volcanic, frozen, ...). Calling
	## this before _ready() has no effect since _ready() would just
	## overwrite it; call it afterwards instead.
	material_path = new_path
	_using_fallback = false
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
	## Recursively walks the scene tree and assigns a toon material — seeded
	## from each surface's own original color/texture — to every
	## MeshInstance3D surface that doesn't already have a custom override.
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			var surface_count := mesh_inst.get_surface_override_material_count()
			for i in range(surface_count):
				if mesh_inst.get_surface_override_material(i) == null:
					var original := mesh_inst.mesh.surface_get_material(i) if mesh_inst.mesh else null
					mesh_inst.set_surface_override_material(i, _build_toon_material(original))

		# Always recurse into children
		_apply_to_children(child)


func _build_toon_material(original: Material) -> ShaderMaterial:
	## Duplicates the shared toon base (keeping its shader + chained outline
	## next_pass) and re-seeds it from the surface's own original color and
	## texture, so the toon shading style applies without flattening every
	## part of a model to the same color.
	if not _base_material:
		return null
	var mat := _base_material.duplicate() as ShaderMaterial

	var base_albedo := Color.WHITE
	var base_texture: Texture2D = null
	var base_metallic := 0.0
	var base_roughness := 0.5
	if original is BaseMaterial3D:
		base_albedo = original.albedo_color
		base_texture = original.albedo_texture
		base_metallic = original.metallic
		base_roughness = original.roughness

	if _using_fallback:
		# Nothing was authored for this object at all — use its own imported
		# look untouched rather than tinting toward the generic placeholder
		# material, which was never meant to represent this specific object.
		mat.set_shader_parameter("albedo", base_albedo)
	else:
		# An explicit material_path (or ship_stats.material_path) is an
		# authored TINT on top of the surface's own color, not a full
		# replacement — multiplying preserves per-part variation (e.g. a
		# house's window/door/wall colors, a palm's trunk vs fronds) while
		# still pushing the overall hue/tone toward what was authored (e.g.
		# "wood_dark" reads as darker, warmer wood without erasing detail).
		var tint: Color = _base_material.get_shader_parameter("albedo")
		if tint == null:
			tint = Color.WHITE
		mat.set_shader_parameter("albedo", base_albedo * tint)
		base_metallic = _base_material.get_shader_parameter("metallic") if _base_material.get_shader_parameter("metallic") != null else base_metallic
		base_roughness = _base_material.get_shader_parameter("roughness") if _base_material.get_shader_parameter("roughness") != null else base_roughness

	if base_texture:
		mat.set_shader_parameter("texture_albedo", base_texture)
	mat.set_shader_parameter("metallic", base_metallic)
	mat.set_shader_parameter("roughness", base_roughness)
	return mat
