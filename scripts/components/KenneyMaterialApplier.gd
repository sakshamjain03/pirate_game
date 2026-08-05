class_name KenneyMaterialApplier extends Node

## Purpose: Applies a stylized toon material (with a chained outline pass) to all
## GLB model children at runtime, replacing whatever material the import brought in.
## Responsibilities: Recursively finds MeshInstance3D children and assigns the
##                   resolved material to any surface that doesn't already have
##                   a custom override.
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

var _material: Material

func _ready() -> void:
	_material = _resolve_material()
	_apply_to_children(get_parent())


func _resolve_material() -> Material:
	var path := material_path
	if path.is_empty():
		var stats := _find_ship_stats()
		if stats and not stats.material_path.is_empty():
			path = stats.material_path
	if path.is_empty():
		path = FALLBACK_MATERIAL_PATH

	var mat: Material = load(path)
	if not mat:
		push_error("KenneyMaterialApplier: Could not load material at: %s" % path)
	return mat


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
	## Recursively walks the scene tree and assigns the resolved material
	## to every MeshInstance3D surface that doesn't already have a custom
	## surface material set.
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			var surface_count := mesh_inst.get_surface_override_material_count()
			for i in range(surface_count):
				if mesh_inst.get_surface_override_material(i) == null:
					mesh_inst.set_surface_override_material(i, _material)

		# Always recurse into children
		_apply_to_children(child)
