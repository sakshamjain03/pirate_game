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
	if _dir.is_empty():
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	print("[capture] writing to ", _dir)


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

	if _frame >= 720:
		print("[capture] done")
		get_tree().quit(0)
