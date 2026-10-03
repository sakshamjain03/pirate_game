extends Node

## TEMPORARY DEBUG HARNESS — not part of the game.
##
## Captures the real rendered viewport at several settle points and writes them
## to disk, so visual bugs (island/ship colour, sky, ship attitude on the water)
## can be diagnosed from what is actually on screen instead of inferred from
## source. Guessing from source has already produced two wrong diagnoses this
## session, hence this.
##
## Usage: autoloaded via a temporary entry in project.godot, with the capture
## directory passed as `--capture-dir=<abs path>`. Quits the game once the last
## capture is written so a headless run terminates on its own.
##
## Delete this file and its autoload entry once the visual bugs are closed.

var _frame := 0
var _dir := ""
var _perf_log := ""
var _perf_file: FileAccess = null

# frame number -> label. Physics runs at 60Hz, so these are ~0.03s, 1s, 3s, 7s
# and 12s. The spread matters: an unstable ship looks fine on frame 2 and only
# reveals itself after buoyancy and the stability torque have had time to act.
const CAPTURES := {
	2: "t0.00s_initial",
	60: "t1.00s",
	180: "t3.00s",
	420: "t7.00s",
	720: "t12.00s",
}


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--capture-dir="):
			_dir = a.trim_prefix("--capture-dir=")
		elif a.begins_with("--perf-log="):
			_perf_log = a.trim_prefix("--perf-log=")
		elif a.begins_with("--graphics-quality="):
			# M29 E.1 — compare tiers without touching user://settings.cfg: set
			# in memory only (never save_settings()) and let World/Ocean re-apply.
			SettingsManager.graphics_quality = int(a.trim_prefix("--graphics-quality="))
			SettingsManager.settings_changed.emit.call_deferred()
	if _dir.is_empty():
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	print("[capture] writing to ", _dir)

	# Initialize perf log if requested
	if not _perf_log.is_empty():
		_perf_file = FileAccess.open(_perf_log, FileAccess.WRITE)
		if _perf_file:
			# Write CSV header
			_perf_file.store_line("frame,label,fps,time_process_ms,time_physics_ms,draw_calls,objects,primitives")
			print("[perf] logging to ", _perf_log)
		else:
			print("[perf] ERROR: could not open ", _perf_log)


func _process(_delta: float) -> void:
	_frame += 1
	if not CAPTURES.has(_frame):
		return

	# Must wait until the frame has actually been drawn, otherwise the capture
	# is the previous frame (or blank on the very first ones).
	await RenderingServer.frame_post_draw

	var vp := get_viewport()
	if not vp:
		return
	var img := vp.get_texture().get_image()
	if not img:
		return

	var name := "%s_%s.png" % [str(_frame).pad_zeros(4), CAPTURES[_frame]]
	var path := _dir.path_join(name)
	var err := img.save_png(path)
	print("[capture] frame %d -> %s (err=%d, %dx%d)" % [_frame, path, err, img.get_width(), img.get_height()])

	# Log performance metrics if requested
	if _perf_file:
		_log_perf_metrics(CAPTURES[_frame])

	if _frame >= 720:
		print("[capture] done")
		if _perf_file:
			_perf_file.flush()
		get_tree().quit(0)


func _log_perf_metrics(label: String) -> void:
	if not _perf_file:
		return

	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var time_process = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0  # Convert to ms
	var time_physics = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0  # Convert to ms
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

	var csv_line = "%d,%s,%.2f,%.2f,%.2f,%d,%d,%d" % [
		_frame,
		label,
		fps,
		time_process,
		time_physics,
		draw_calls,
		objects,
		primitives
	]
	_perf_file.store_line(csv_line)
	print("[perf] frame %d: fps=%.2f draw_calls=%d objects=%d" % [_frame, fps, draw_calls, objects])
