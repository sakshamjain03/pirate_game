class_name KenneyMaterialApplier extends Node

## Purpose: Passes every GLB model surface through the stylized toon shader
## (with a chained outline pass), while preserving each surface's own
## imported color/texture — the Kenney kit's colormap.png atlas is the
## project's only texture and the entire color identity of the art style.
## Responsibilities: Recursively finds MeshInstance3D children and, for every
##                   surface that doesn't already have a custom override,
##                   assigns a toon material seeded from that surface's own
##                   original color/texture. An authored `material_path`
##                   contributes its color only in proportion to
##                   `tint_strength`, which defaults to 0 — i.e. the colormap
##                   atlas is left alone.
##
##                   Why 0 by default: every model this runs on is a Kenney GLB
##                   whose colors come entirely from the colormap.png atlas, so
##                   the atlas is already the authored per-part color. The
##                   previous behavior multiplied every surface by the authored
##                   color unconditionally, which dragged the whole model toward
##                   that one hue — wood_light's (0.85, 0.55, 0.25) turned white
##                   sails and skull emblems bright orange, and wood_dark's
##                   (0.38, 0.2, 0.12) muddied everything to brown. Tinting is
##                   now opt-in for the cases that genuinely mean "recolor this
##                   whole model" (Island.gd's frozen/volcanic terrain themes).
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

## How far to pull each surface from its own colormap color toward the
## authored `material_path` color. 0 keeps the atlas exactly as imported
## (correct for every stock Kenney model); 1 reproduces the old
## multiply-everything behavior. Blending rather than multiplying means a
## partial value shifts hue without also crushing brightness.
@export_range(0.0, 1.0) var tint_strength: float = 0.0

var _base_material: ShaderMaterial
var _using_fallback: bool = false

func _ready() -> void:
	_base_material = _resolve_material()
	_apply_to_children(get_parent())


func override_material_path(new_path: String, new_tint_strength: float = 1.0) -> void:
	## Re-resolves and re-applies with a different material_path after the
	## initial _ready() pass — e.g. Island.gd re-tinting a shared terrain
	## tile for a specific island's theme (volcanic, frozen, ...). Calling
	## this before _ready() has no effect since _ready() would just
	## overwrite it; call it afterwards instead.
	##
	## Defaults to a full-strength tint because the callers of this method are
	## deliberately recoloring a whole model (a frozen reef, a scorched
	## volcano); that intent is the exception the 0 default is guarding against.
	material_path = new_path
	tint_strength = new_tint_strength
	_using_fallback = false
	_base_material = _resolve_material()
	# force, because _ready() has already put an override on every surface and
	# the normal pass deliberately skips those — without this the re-apply
	# silently did nothing and themed islands rendered as tropical ones.
	_apply_to_children(get_parent(), true)


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


func _apply_to_children(node: Node, force: bool = false) -> void:
	## Recursively walks the scene tree and assigns a toon material — seeded
	## from each surface's own original color/texture — to every
	## MeshInstance3D surface that doesn't already have a custom override.
	## `force` re-applies over this component's own earlier pass; the seed is
	## always re-read from the mesh's built-in material, which set_surface_
	## override_material never touches, so repeated calls don't compound.
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			var surface_count := mesh_inst.get_surface_override_material_count()
			for i in range(surface_count):
				if force or mesh_inst.get_surface_override_material(i) == null:
					var original := mesh_inst.mesh.surface_get_material(i) if mesh_inst.mesh else null
					var built := _build_toon_material(original)
					# Guard against assigning null: _build_toon_material returns
					# null when the base material failed to resolve, and a null
					# surface override leaves the mesh unshaded. Keeping the
					# mesh's own imported material is the better fallback.
					# (Note: this is defensive only — it is NOT the source of the
					# startup `Parameter "material" is null` errors; those were
					# measured to be unchanged by this guard.)
					if built:
						mesh_inst.set_surface_override_material(i, built)

		# Always recurse into children
		_apply_to_children(child, force)


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

	if _using_fallback or tint_strength <= 0.0:
		# Either nothing was authored for this object at all, or the authored
		# material is only supplying surface properties — keep the surface's
		# own imported color, which for these models is the colormap atlas.
		mat.set_shader_parameter("albedo", base_albedo)
	else:
		# Blend toward the authored color rather than multiplying by it.
		# Multiplying can only ever darken, so it compounded across every
		# surface; a lerp lands on the authored hue at full strength while
		# leaving brightness intact at partial strength.
		var tint_param = _base_material.get_shader_parameter("albedo")
		var tint: Color = tint_param if tint_param is Color else Color.WHITE
		mat.set_shader_parameter("albedo", base_albedo.lerp(tint, tint_strength))

	# Surface properties always come from the authored material when there is
	# one — these are style choices (how glossy wood or brass reads under the
	# toon light ramp) and carry none of the color problem above.
	if not _using_fallback:
		var m = _base_material.get_shader_parameter("metallic")
		var r = _base_material.get_shader_parameter("roughness")
		if m != null:
			base_metallic = m
		if r != null:
			base_roughness = r

	if base_texture:
		mat.set_shader_parameter("texture_albedo", base_texture)
	mat.set_shader_parameter("metallic", base_metallic)
	mat.set_shader_parameter("roughness", base_roughness)
	return mat
