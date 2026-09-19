class_name ShipVisuals extends Node3D

## Purpose: Manages all ship visual effects — sail animation, wake particles, damage visuals.
## Responsibilities: Responds to speed/turn signals from ShipController and animates accordingly.
##                   Also owns loading the tier-specific hull model + material (ship_stats.model_path
##                   / material_path), rebuilding it whenever ship_stats is swapped (e.g. ship upgrades).
## Dependencies: ShipController (parent), WakeParticles child (optional)

const DEFAULT_MODEL_PATH := "res://assets/models/ship-pirate-small.glb"

@export var controller: ShipController
@export var sails: Array[Node3D]
@export var sail_turn_speed: float  = 2.0
@export var max_sail_angle: float   = 30.0  # degrees
## How small sails shrink toward (scale.y) when fully furled — 1.0 would make
## furled indistinguishable from full sail.
@export_range(0.05, 1.0) var furled_sail_scale: float = 0.2

@export_group("Anchor")
## World-space depth the anchor drops below its stowed (BowMarker) position —
## deep enough to sink below the waterline (FloatPoints sit at y=0.0;
## BowMarker, where the anchor is stowed, sits at y=1.7).
@export var anchor_drop_depth: float = 5.5
@export var anchor_drop_time: float = 1.4

@export_group("Damage Visuals")
## `docs/navalCombat.md` §7's "visible critical state before sinking" — the one
## piece of the damage model that was still just a documented gap. Below this
## hull fraction, smoke starts drifting off the deck.
@export_range(0.0, 1.0) var hull_damaged_threshold: float = 0.5
## Below this, the hull itself darkens — planking scorched, not just smoking.
@export_range(0.0, 1.0) var hull_critical_threshold: float = 0.25
## M10 Requirement 6 — the one remaining open item from `docs/navalCombat.md`
## §7: a distinct near-destruction state below critical, so a badly-damaged
## hull visibly looks like it's about to sink rather than just staying at
## the same critical look all the way to 0. Visual only — a rotation offset
## on the hull model, never the parent ShipController's own transform, so
## BuoyancySimulator's float physics and FiringSolver's arc geometry (both of
## which read the ship's real transform) are unaffected.
@export_range(0.0, 1.0) var hull_sinking_threshold: float = 0.10
@export var sinking_list_degrees: float = 9.0
@export var scorch_tint_color: Color = Color(0.12, 0.10, 0.09)
@export_range(0.0, 1.0) var scorch_tint_strength: float = 0.55

# Wake particles found at runtime
var _wake: GPUParticles3D
var _model_instance: Node3D
var target_sail_angle: float = 0.0

# Anchor prop, built procedurally on first use — no anchor model exists in
# the project's assets, and this is small enough not to warrant one.
var _anchor_visual: Node3D = null
var _anchor_chain: MeshInstance3D = null
var _anchor_stowed_pos: Vector3 = Vector3.ZERO
var _anchor_tween: Tween = null

# Damage visuals: the toon material KenneyMaterialApplier assigns is a
# ShaderMaterial keyed by an "albedo" shader param, not a StandardMaterial3D —
# so the scorch tint has to blend that same param rather than touch
# albedo_color. Cached once per surface, right after the applier's own pass,
# so repeated tint updates always blend from the clean color instead of
# compounding against whatever the last tint left behind.
var _clean_albedo: Dictionary = {}
var _damage: Node = null
var _smoke: GPUParticles3D = null

# M16 — cosmetics currently equipped, keyed by slot name. Re-applied at the
# end of _rebuild_model() (a rebuild discards _model_instance and everything
# painted onto it) and read by get_save_data() for the equipped *selection*
# (ownership itself is account-scoped, via EntitlementManager, not saved here).
var _equipped_cosmetics: Dictionary = {}
var _figurehead_instance: Node3D = null

## Promoted from a local in _on_damage_pool_changed (M16 Task 11) so
## apply_cosmetic() can re-assert the current damage tint after a cosmetic
## changes the base albedo — see design.md §4.
var _current_damage_severity: float = 0.0

func _ready() -> void:
	if not controller:
		controller = get_parent() as ShipController

	if controller:
		controller.ship_speed_changed.connect(_on_speed_changed)
		controller.ship_stats_changed.connect(_rebuild_model)
		controller.sail_level_changed.connect(_on_sail_level_changed)
		controller.anchor_dropped.connect(_on_anchor_dropped)
		controller.anchor_raised.connect(_on_anchor_raised)

	# Find wake particles in parent ship's WakeSpawnPoint
	_wake = _find_wake_particles()

	var parent = get_parent()
	_damage = parent.get_node_or_null("ShipDamage") if parent else null
	if _damage and not _damage.pool_changed.is_connected(_on_damage_pool_changed):
		_damage.pool_changed.connect(_on_damage_pool_changed)

	# M17 Requirement 8.3 — a refund revoking a currently-equipped cosmetic
	# must fall back to default appearance live, mid-session, not just on
	# the next load_save_data() (which already handles the load-time case).
	if not EntitlementManager.entitlement_revoked.is_connected(_on_entitlement_revoked):
		EntitlementManager.entitlement_revoked.connect(_on_entitlement_revoked)

	_rebuild_model()


func _rebuild_model() -> void:
	## Load the hull model + material for the ship's current tier and swap
	## it in, replacing whatever was previously loaded.
	if _model_instance:
		_model_instance.queue_free()
		_model_instance = null
	# The old figurehead instance was a child of the just-freed model, so it
	# is going away too — drop the reference now rather than leaving it
	# pointing at a queue_free()-pending node until the next _apply_figurehead().
	_figurehead_instance = null

	var model_path := DEFAULT_MODEL_PATH
	var material_path := ""
	if controller and controller.ship_stats:
		if not controller.ship_stats.model_path.is_empty():
			model_path = controller.ship_stats.model_path
		material_path = controller.ship_stats.material_path

	var model_scene: PackedScene = load(model_path)
	if not model_scene:
		push_error("ShipVisuals: could not load ship model at %s" % model_path)
		return

	_model_instance = model_scene.instantiate()
	add_child(_model_instance)
	move_child(_model_instance, 0)

	# `sails` was never assigned in any ship scene, so the lean-animation
	# loop in _process() always had nothing to act on. Auto-discovering any
	# sail-named node in the freshly loaded hull means it works the moment a
	# model actually has one, with no per-ship scene wiring required.
	sails = _find_sail_nodes(_model_instance)
	if controller and controller.ship_stats:
		_apply_sail_scale(controller.sail_level, controller.ship_stats.sail_levels, false)

	# Colorize the freshly loaded hull only — flag/ropes keep their own look.
	var applier := preload("res://scripts/components/KenneyMaterialApplier.gd").new()
	applier.material_path = material_path
	_model_instance.add_child(applier)
	
	# Apply Faction colors
	if controller and "faction" in controller and controller.faction:
		var faction = controller.faction
		var flag = find_child("*Flag*", true, false)
		if flag:
			_apply_color_to_meshes(flag, faction.sail_color)

	# M16 Task 13 — a rebuild discards _model_instance and everything painted
	# onto it, so every equipped cosmetic must be re-applied here, inline
	# (never call_deferred — see the D45 defer-chain failure mode), before the
	# cache/re-tint below runs once for the whole freshly rebuilt model.
	for slot in _equipped_cosmetics:
		_apply_cosmetic_visual(slot, _equipped_cosmetics[slot])

	# A rebuild (ship purchase/switch) always yields a fresh hull, but re-derive
	# the tint from whatever ShipDamage currently reports rather than assuming
	# "clean" — the two must never independently disagree about hull state.
	_cache_clean_albedo()
	if _damage and _damage.ship_stats:
		# Pre-existing latent race, found via M16's own new cosmetic-damage
		# test: ShipModel is declared before ShipDamage in the ship scenes,
		# so on the very first _rebuild_model() call (from _ready()),
		# ShipDamage._ready() hasn't run yet and `hull` is still its
		# uninitialized 0.0 default. Reading that directly would wrongly
		# compute "critical damage" (and skip _update_smoke/_apply_list's own
		# lazy setup) on a ship that hasn't taken any hit yet. ShipDamage's
		# own _ready() only ever moves hull from 0.0 up to a real value, so
		# assuming full health for this one boot-time read whenever hull
		# still reads exactly 0.0 is a safe stand-in — genuine damage always
		# arrives afterward through the real pool_changed signal.
		var boot_safe_hull: float = _damage.hull if _damage.hull > 0.0 else _damage.get_pool_maximum("hull")
		_on_damage_pool_changed("hull", boot_safe_hull, _damage.get_pool_maximum("hull"))

func _apply_color_to_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		# Try to keep basic shading
		mat.roughness = 0.8
		node.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_color_to_meshes(child, color)


func _find_sail_nodes(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	_collect_sail_nodes(root, found)
	return found

func _collect_sail_nodes(node: Node, found: Array[Node3D]) -> void:
	if node is Node3D and "sail" in node.name.to_lower():
		found.append(node)
	for child in node.get_children():
		_collect_sail_nodes(child, found)

func _on_damage_pool_changed(pool: String, current: float, maximum: float) -> void:
	if pool != "hull":
		return
	var pct: float = current / max(maximum, 1.0)
	var is_sinking := pct < hull_sinking_threshold and pct > 0.0
	_update_smoke(pct < hull_damaged_threshold and pct > 0.0, is_sinking)
	_current_damage_severity = scorch_tint_strength if pct < hull_critical_threshold else 0.0
	_apply_damage_tint(_current_damage_severity)
	_apply_list(sinking_list_degrees if is_sinking else 0.0)


func _cache_clean_albedo() -> void:
	_clean_albedo.clear()
	if _model_instance:
		_collect_clean_albedo(_model_instance)


func _collect_clean_albedo(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var albedo = mat.get_shader_parameter("albedo")
				if albedo is Color:
					_clean_albedo["%d:%d" % [mi.get_instance_id(), i]] = albedo
	for child in node.get_children():
		_collect_clean_albedo(child)


func _apply_damage_tint(severity: float) -> void:
	## Blends each surface's own cached clean color toward `scorch_tint_color`.
	## Reads from `_clean_albedo`, never from the material's current value, so
	## healing back above the threshold restores the original color exactly
	## rather than drifting after repeated hits.
	if _model_instance:
		_apply_damage_tint_to(_model_instance, severity)


func _apply_damage_tint_to(node: Node, severity: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var key := "%d:%d" % [mi.get_instance_id(), i]
				if _clean_albedo.has(key):
					var clean: Color = _clean_albedo[key]
					mat.set_shader_parameter("albedo", clean.lerp(scorch_tint_color, severity))
	for child in node.get_children():
		_apply_damage_tint_to(child, severity)


## M16 §4 — the highest-risk integration point in the milestone. Equipping a
## hull skin changes the base albedo; if _clean_albedo isn't re-populated
## immediately, the next time damage clears, _apply_damage_tint(0.0) would
## restore the *pre-skin* albedo and silently revert the cosmetic. ORDER IS
## LOAD-BEARING: apply the visual change, THEN re-cache clean albedo, THEN
## re-assert the current damage tint on top of the new clean state.
## M17 Requirement 8.3 — falls back to default appearance if the just-
## revoked entitlement is the cosmetic currently equipped in some slot.
## Reuses _rebuild_model()'s existing "fresh default model, then only
## reapply what's still in _equipped_cosmetics" path (the same mechanism
## M16 Requirement 3.6 already built for an unresolvable/unowned cosmetic
## id) rather than adding a second fallback path — erasing the slot here
## before rebuilding is what makes the rebuild simply never re-apply it.
func _on_entitlement_revoked(id: StringName) -> void:
	var affected_slot := ""
	for slot in _equipped_cosmetics:
		var cosmetic: CosmeticData = _equipped_cosmetics[slot]
		if cosmetic and cosmetic.id == id:
			affected_slot = slot
			break
	if affected_slot == "":
		return
	_equipped_cosmetics.erase(affected_slot)
	_rebuild_model()


func apply_cosmetic(slot: String, cosmetic: CosmeticData) -> void:
	_equipped_cosmetics[slot] = cosmetic
	_apply_cosmetic_visual(slot, cosmetic)
	_cache_clean_albedo()
	_apply_damage_tint(_current_damage_severity)


## M16 Task 17 — visual-only application for the wardrobe's live preview:
## does NOT touch _equipped_cosmetics, so backing out without confirming can
## cleanly revert via cancel_preview() rather than having already committed
## the change.
func preview_cosmetic(slot: String, cosmetic: CosmeticData) -> void:
	_apply_cosmetic_visual(slot, cosmetic)
	_cache_clean_albedo()
	_apply_damage_tint(_current_damage_severity)


## Reverts a slot back to whatever is actually equipped (or the natural
## default, via a full rebuild, if nothing is equipped there) — the
## counterpart to preview_cosmetic() when the player backs out without
## confirming.
func cancel_preview(slot: String) -> void:
	if _equipped_cosmetics.has(slot):
		_apply_cosmetic_visual(slot, _equipped_cosmetics[slot])
		_cache_clean_albedo()
		_apply_damage_tint(_current_damage_severity)
	else:
		_rebuild_model()


func _apply_cosmetic_visual(slot: String, cosmetic: CosmeticData) -> void:
	match slot:
		"hull":       _apply_hull_skin(cosmetic)
		"sails":      _apply_sail_pattern(cosmetic)
		"flag":       _apply_flag(cosmetic)
		"figurehead": _apply_figurehead(cosmetic)
		_:            push_warning("ShipVisuals: unknown cosmetic slot '%s'" % slot)


func _apply_hull_skin(cosmetic: CosmeticData) -> void:
	if _model_instance:
		_apply_cosmetic_to_meshes(_model_instance, cosmetic, true)


func _apply_sail_pattern(cosmetic: CosmeticData) -> void:
	for sail in sails:
		if sail:
			_apply_cosmetic_to_meshes(sail, cosmetic, false)


func _apply_flag(cosmetic: CosmeticData) -> void:
	var flag := find_child("*Flag*", true, false)
	if flag:
		_apply_cosmetic_to_meshes(flag, cosmetic, false)


func _apply_figurehead(cosmetic: CosmeticData) -> void:
	if _figurehead_instance and is_instance_valid(_figurehead_instance):
		_figurehead_instance.queue_free()
	_figurehead_instance = null
	if cosmetic.mesh_override and _model_instance:
		_figurehead_instance = cosmetic.mesh_override.instantiate()
		_model_instance.add_child(_figurehead_instance)


## Applies a cosmetic's tint (and texture, if authored) to every mesh surface
## under `node`. `skip_other_slots` excludes sail/flag-named sub-parts so a
## hull skin doesn't bleed onto slots that have their own separate cosmetic —
## used for the hull only, since `sails`/flag are applied to their own
## already-isolated nodes directly.
func _apply_cosmetic_to_meshes(node: Node, cosmetic: CosmeticData, skip_other_slots: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				if cosmetic.albedo_texture:
					mat.set_shader_parameter("texture_albedo", cosmetic.albedo_texture)
				mat.set_shader_parameter("albedo", cosmetic.tint)
	for child in node.get_children():
		if skip_other_slots:
			var name_lower: String = child.name.to_lower()
			if "sail" in name_lower or "flag" in name_lower:
				continue
		_apply_cosmetic_to_meshes(child, cosmetic, skip_other_slots)


## M16 Task 14 — round-trips the equipped *selection* only; ownership lives in
## EntitlementManager's account-scoped store, never here.
func get_save_data() -> Dictionary:
	var data := {}
	for slot in _equipped_cosmetics:
		var cosmetic: CosmeticData = _equipped_cosmetics[slot]
		data[slot] = String(cosmetic.id)
	return data


func load_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	for slot in data:
		var id = data[slot]
		if typeof(id) != TYPE_STRING:
			continue
		var cosmetic := CosmeticCatalogue.get_cosmetic(StringName(id))
		# Req 3.5/3.6 — an id the account doesn't own, or that no longer
		# resolves to a real resource at all, falls back to the default
		# appearance silently: never a crash, never a null-material error.
		if cosmetic == null:
			continue
		if not EntitlementManager.has_entitlement(cosmetic.id):
			continue
		apply_cosmetic(slot, cosmetic)


func _ensure_smoke() -> GPUParticles3D:
	if _smoke and is_instance_valid(_smoke):
		return _smoke
	_smoke = GPUParticles3D.new()
	_smoke.name = "DamageSmoke"
	_smoke.amount = 10
	_smoke.lifetime = 1.4
	_smoke.emitting = false

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.5)
	quad.material = quad_mat
	_smoke.draw_pass_1 = quad

	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 20.0
	proc.gravity = Vector3(0, 0.5, 0)
	proc.initial_velocity_min = 0.5
	proc.initial_velocity_max = 1.1
	proc.scale_min = 0.5
	proc.scale_max = 1.1
	_smoke.process_material = proc

	add_child(_smoke)
	_smoke.position = Vector3(0.0, 2.4, 0.0)
	return _smoke


func _update_smoke(should_emit: bool, heavy: bool = false) -> void:
	var smoke := _ensure_smoke()
	smoke.emitting = should_emit
	# Heavier smoke for the sinking band: bigger, faster-moving puffs on the
	# same particle system rather than a second one — resizing `amount`
	# requires recreating the particle buffer, so intensity is conveyed
	# through velocity/scale instead.
	var proc := smoke.process_material as ParticleProcessMaterial
	if proc:
		if heavy:
			proc.initial_velocity_min = 0.9
			proc.initial_velocity_max = 1.8
			proc.scale_min = 0.9
			proc.scale_max = 1.6
		else:
			proc.initial_velocity_min = 0.5
			proc.initial_velocity_max = 1.1
			proc.scale_min = 0.5
			proc.scale_max = 1.1


func _apply_list(degrees: float) -> void:
	if _model_instance:
		_model_instance.rotation.z = deg_to_rad(degrees)


func _find_wake_particles() -> GPUParticles3D:
	## Look for a WakeParticles node in the parent ship scene
	var parent = get_parent()
	if not parent:
		return null
	var spawn = parent.find_child("WakeSpawnPoint", true, false)
	if spawn:
		var wake_scene = load("res://scenes/world/WakeParticles.tscn") as PackedScene
		if wake_scene:
			var wake = wake_scene.instantiate()
			spawn.add_child(wake)
			return wake as GPUParticles3D
	return null


func _process(delta: float) -> void:
	if not controller:
		return

	# Sail lean animation based on current turn input
	var turn_input = controller.current_turn_input
	target_sail_angle = -turn_input * deg_to_rad(max_sail_angle)

	for sail in sails:
		if sail:
			var cur = sail.rotation.y
			sail.rotation.y = lerp_angle(cur, target_sail_angle, sail_turn_speed * delta)


func _on_speed_changed(speed: float) -> void:
	if not _wake:
		return
	var normalized = clamp(speed / max(controller.ship_stats.max_speed, 0.01), 0.0, 1.0)
	_wake.emitting      = normalized > 0.08
	_wake.amount_ratio  = normalized


## Scales each sail node toward furled_sail_scale..1.0 based on sail_level, so
## the hull's existing sail meshes visibly fill/furl instead of needing new art.
func _apply_sail_scale(level: int, max_level: int, animate: bool) -> void:
	var ratio: float = float(level) / float(max(max_level, 1))
	var target_scale: float = lerp(furled_sail_scale, 1.0, ratio)
	for sail in sails:
		if not sail:
			continue
		if animate:
			create_tween().tween_property(sail, "scale:y", target_scale, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			sail.scale.y = target_scale


func _on_sail_level_changed(level: int, max_level: int) -> void:
	_apply_sail_scale(level, max_level, true)


## Builds the anchor + chain the first time it's needed. Parented directly to
## the ship root (controller), not this node, so its position lines up with
## BowMarker's coordinates without having to account for ShipModel's own
## (mirrored) local transform.
func _ensure_anchor_visual() -> void:
	if _anchor_visual or not controller:
		return

	var mount := controller.get_node_or_null("BowMarker")
	_anchor_stowed_pos = (mount as Node3D).position if mount else Vector3(0, 1.7, -4.3)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.28)
	mat.metallic = 0.6
	mat.roughness = 0.4

	_anchor_visual = Node3D.new()
	_anchor_visual.name = "AnchorVisual"
	controller.add_child(_anchor_visual)
	_anchor_visual.position = _anchor_stowed_pos

	var shank := MeshInstance3D.new()
	var shank_mesh := CapsuleMesh.new()
	shank_mesh.radius = 0.08
	shank_mesh.height = 0.9
	shank.mesh = shank_mesh
	shank.material_override = mat
	_anchor_visual.add_child(shank)

	var fluke := MeshInstance3D.new()
	var fluke_mesh := TorusMesh.new()
	fluke_mesh.inner_radius = 0.05
	fluke_mesh.outer_radius = 0.32
	fluke.mesh = fluke_mesh
	fluke.material_override = mat
	fluke.position = Vector3(0, -0.5, 0)
	fluke.rotation_degrees = Vector3(90, 0, 0)
	_anchor_visual.add_child(fluke)

	_anchor_chain = MeshInstance3D.new()
	_anchor_chain.name = "AnchorChain"
	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.04
	chain_mesh.bottom_radius = 0.04
	chain_mesh.height = 0.01
	_anchor_chain.mesh = chain_mesh
	_anchor_chain.material_override = mat
	_anchor_chain.visible = false
	controller.add_child(_anchor_chain)


## The anchor only ever moves straight down from its stowed position, so the
## chain (a vertical CylinderMesh) just needs its height and midpoint updated
## each step — no rotation math needed.
func _update_anchor_chain(pos: Vector3) -> void:
	if not _anchor_visual:
		return
	_anchor_visual.position = pos
	if not _anchor_chain:
		return
	var length: float = _anchor_stowed_pos.y - pos.y
	_anchor_chain.visible = length > 0.05
	_anchor_chain.position = Vector3(_anchor_stowed_pos.x, _anchor_stowed_pos.y - length * 0.5, _anchor_stowed_pos.z)
	var chain_mesh := _anchor_chain.mesh as CylinderMesh
	if chain_mesh:
		chain_mesh.height = max(length, 0.01)


func _on_anchor_dropped() -> void:
	_ensure_anchor_visual()
	if not _anchor_visual:
		return
	if _anchor_tween and _anchor_tween.is_valid():
		_anchor_tween.kill()
	var target := _anchor_stowed_pos - Vector3(0, anchor_drop_depth, 0)
	_anchor_tween = create_tween()
	_anchor_tween.tween_method(_update_anchor_chain, _anchor_visual.position, target, anchor_drop_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anchor_tween.tween_callback(_spawn_anchor_splash)
	if AudioManager: AudioManager.play_sound("anchor_drop")


func _on_anchor_raised() -> void:
	if not _anchor_visual:
		return
	if _anchor_tween and _anchor_tween.is_valid():
		_anchor_tween.kill()
	_anchor_tween = create_tween()
	_anchor_tween.tween_method(_update_anchor_chain, _anchor_visual.position, _anchor_stowed_pos, anchor_drop_time * 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if AudioManager: AudioManager.play_sound("anchor_raise")


## Same one-shot procedural particle pattern as ShipController's cannon
## smoke/explosion VFX (_spawn_cannon_smoke/_spawn_explosion).
func _spawn_anchor_splash() -> void:
	if not controller:
		return
	var splash := CPUParticles3D.new()
	splash.emitting = false
	splash.one_shot = true
	splash.amount = 20
	splash.lifetime = 1.0
	splash.explosiveness = 0.85
	splash.spread = 40.0
	splash.gravity = Vector3(0, -9.8, 0)
	splash.initial_velocity_min = 1.5
	splash.initial_velocity_max = 3.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh.material = mat
	splash.mesh = mesh

	controller.add_child(splash)
	splash.position = Vector3(_anchor_stowed_pos.x, 0.0, _anchor_stowed_pos.z)
	splash.emitting = true

	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func(): if is_instance_valid(splash): splash.queue_free())
