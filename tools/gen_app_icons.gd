extends SceneTree

## One-off tool: rasterizes assets/branding/emblem.svg into the actual app-icon
## files Android/PC use. Run once via:
##   godot --headless --script res://tools/gen_app_icons.gd
## Not part of the game at runtime — safe to delete after use.

const NAVY := Color(0.051, 0.071, 0.145, 1.0)  # PirateThemeBuilder.COLOR_DARK_NAVY, opaque

func _init() -> void:
	var svg_text := FileAccess.get_file_as_string("res://assets/branding/emblem.svg")
	if svg_text.is_empty():
		push_error("gen_app_icons: could not read emblem.svg")
		quit(1)
		return

	_write_layer(svg_text, "res://assets/icons/fg_432.png", 432, 0.68, false)
	_write_solid("res://assets/icons/bg_432.png", 432, NAVY)
	_write_layer(svg_text, "res://assets/icons/mono_432.png", 432, 0.68, true)
	_write_composited("res://assets/icons/main_192.png", svg_text, 192, 0.78)
	# res://icon.svg is hand-authored (same navy+wheel composition, kept vector) — not regenerated here.

	print("gen_app_icons: done")
	quit()


func _rasterize(svg_text: String, target_px: int, safe_zone_fraction: float) -> Image:
	var content_px := int(round(target_px * safe_zone_fraction))
	var scale := float(content_px) / 256.0
	var img := Image.new()
	var err := img.load_svg_from_string(svg_text, scale)
	if err != OK:
		push_error("gen_app_icons: svg rasterize failed: %s" % err)
	return img


func _write_layer(svg_text: String, out_path: String, canvas_px: int, safe_zone_fraction: float, monochrome: bool) -> void:
	var content := _rasterize(svg_text, canvas_px, safe_zone_fraction)
	content.convert(Image.FORMAT_RGBA8)
	if monochrome:
		for y in content.get_height():
			for x in content.get_width():
				var c := content.get_pixel(x, y)
				if c.a > 0.0:
					content.set_pixel(x, y, Color(1, 1, 1, c.a))

	var canvas := Image.create(canvas_px, canvas_px, false, Image.FORMAT_RGBA8)
	var offset := Vector2i((canvas_px - content.get_width()) / 2, (canvas_px - content.get_height()) / 2)
	canvas.blend_rect(content, Rect2i(Vector2i.ZERO, content.get_size()), offset)
	canvas.save_png(out_path)
	print("wrote ", out_path)


func _write_solid(out_path: String, size_px: int, color: Color) -> void:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(out_path)
	print("wrote ", out_path)


func _write_composited(out_path: String, svg_text: String, canvas_px: int, safe_zone_fraction: float) -> void:
	var canvas := Image.create(canvas_px, canvas_px, false, Image.FORMAT_RGBA8)
	canvas.fill(NAVY)
	var content := _rasterize(svg_text, canvas_px, safe_zone_fraction)
	content.convert(Image.FORMAT_RGBA8)
	var offset := Vector2i((canvas_px - content.get_width()) / 2, (canvas_px - content.get_height()) / 2)
	canvas.blend_rect(content, Rect2i(Vector2i.ZERO, content.get_size()), offset)
	canvas.save_png(out_path)
	print("wrote ", out_path)
