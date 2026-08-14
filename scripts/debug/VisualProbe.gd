extends Node

## TEMPORARY DIAGNOSTIC HARNESS — not part of the game.
##
## Loads the World scene directly (Boot goes to MainMenu, which is not what we
## need to look at), lets it settle, then writes BOTH:
##   1. a PNG of the real rendered viewport, and
##   2. a text report of the actual runtime state of the render pipeline —
##      light colour/energy, environment tonemap/adjustments, and the resolved
##      shader parameters on real ship/island surfaces.
##
## The report matters as much as the image: it records what the GPU was actually
## handed, so a colour problem can be attributed to a specific stage (atlas ->
## material -> light -> tonemap) instead of guessed at from source.
##
## Usage:
##   godot --headless -s scripts/debug/VisualProbe.gd -- --out=<abs dir>
## Runs headless via SceneTree so no autoload edit is needed.

const WORLD := "res://scenes/world/World.tscn"

var _out := ""
var _frame := 0
var _shots := {}


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--shots="):
			for pair in a.trim_prefix("--shots=").split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					_shots[int(kv[0])] = kv[1]
	if _shots.is_empty():
		_shots = {5: "t0", 120: "t2s", 300: "t5s"}
	if _out.is_empty():
		push_error("VisualProbe: --out=<dir> is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	print("[probe] out=", _out)

	var scn := load(WORLD)
	if not scn:
		push_error("VisualProbe: could not load " + WORLD)
		get_tree().quit(1)
		return
	var world := scn.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	print("[probe] World instantiated")


func _process(_d: float) -> void:
	_frame += 1
	if not _shots.has(_frame):
		return

	await RenderingServer.frame_post_draw

	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var p: String = _out.path_join("%s.png" % _shots[_frame])
			var err := img.save_png(p)
			print("[probe] %s -> err=%d %dx%d" % [_shots[_frame], err, img.get_width(), img.get_height()])

	if _frame >= _shots.keys().max():
		_report()
		get_tree().quit(0)


func _report() -> void:
	var L: Array[String] = []
	L.append("=== RENDER PIPELINE RUNTIME STATE ===")

	for n in _find_all(get_tree().root, "DirectionalLight3D"):
		var d := n as DirectionalLight3D
		L.append("DirectionalLight3D '%s': color=%s energy=%.3f visible=%s" % [
			d.name, d.light_color, d.light_energy, d.visible])

	for n in _find_all(get_tree().root, "WorldEnvironment"):
		var e := (n as WorldEnvironment).environment
		if not e:
			continue
		L.append("Environment: ambient_src=%d ambient_color=%s ambient_energy=%.3f" % [
			e.ambient_light_source, e.ambient_light_color, e.ambient_light_energy])
		L.append("  tonemap_mode=%d exposure=%.3f white=%.3f" % [
			e.tonemap_mode, e.tonemap_exposure, e.tonemap_white])
		L.append("  adjust_enabled=%s brightness=%.3f contrast=%.3f saturation=%.3f" % [
			e.adjustment_enabled, e.adjustment_brightness,
			e.adjustment_contrast, e.adjustment_saturation])
		L.append("  glow=%s glow_intensity=%.2f glow_hdr_threshold=%.2f" % [
			e.glow_enabled, e.glow_intensity, e.glow_hdr_threshold])
		L.append("  fog=%s fog_color=%s fog_density=%.6f" % [
			e.fog_enabled, e.fog_light_color, e.fog_density])

	# Real surfaces: what did the shader actually receive?
	L.append("")
	L.append("=== RESOLVED SURFACE PARAMETERS (first 12 MeshInstance3D) ===")
	var seen := 0
	for mi in _find_all(get_tree().root, "MeshInstance3D"):
		if seen >= 12:
			break
		var m := mi as MeshInstance3D
		for i in range(m.get_surface_override_material_count()):
			var mat := m.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var sm := mat as ShaderMaterial
				var tex = sm.get_shader_parameter("texture_albedo")
				L.append("%-28s surf%d albedo=%s tex=%s shader=%s" % [
					m.name, i, sm.get_shader_parameter("albedo"),
					("SET" if tex else "NULL"),
					(sm.shader.resource_path.get_file() if sm.shader else "?")])
				seen += 1
				break

	var txt := "\n".join(L)
	print(txt)
	var f := FileAccess.open(_out.path_join("report.txt"), FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()


func _find_all(root: Node, cls: String) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_class(cls):
			found.append(n)
		for c in n.get_children():
			stack.append(c)
	return found
