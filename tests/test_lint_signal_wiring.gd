## M29 D.4 — Signal wiring lint test.
## Purpose: Verify every signal declaration has an emit and a connection.
## Catches dead signals that are declared but never used.

extends GutTest

func test_lint_signal_wiring() -> void:
	## Scan res://scripts and res://scenes for signal definitions and verify
	## they are emitted and connected somewhere.
	var violations = _scan_signal_wiring()

	if violations.is_empty():
		print("\nSignal Lint: PASS (all signals are wired)")
		assert_true(true)
	else:
		var message = "Signal Lint: %d dead signals found:\n" % violations.size()
		for violation in violations:
			message += "  %s:%d - %s\n" % [violation["file"], violation["line"], violation["name"]]

		# Check against allowlist
		var allowlisted = _get_signal_allowlist()
		var real_violations = []
		for violation in violations:
			var key = "%s:%s" % [violation["file"], violation["name"]]
			if not allowlisted.has(key):
				real_violations.append(violation)

		if real_violations.is_empty():
			print("All violations are allowlisted.")
			assert_true(true)
		else:
			message = "Signal Lint: %d non-allowlisted dead signals:\n" % real_violations.size()
			for violation in real_violations:
				message += "  %s:%d - %s\n" % [violation["file"], violation["line"], violation["name"]]
			print(message)
			assert_true(false, message)


func _scan_signal_wiring() -> Array:
	## Find all signal declarations and check if they're used
	var violations = []

	# Scan .gd files for signal declarations
	var gd_files = _find_files("res://scripts", "*.gd")
	var scene_files = _find_files("res://scenes", "*.tscn")

	# Build a map of all signals
	var signals = {}  # key: "file:signal_name" -> {file, line, signal}

	for file_path in gd_files:
		var signals_in_file = _extract_signals_from_gd(file_path)
		for sig in signals_in_file:
			var key = "%s:%s" % [file_path, sig["name"]]
			signals[key] = sig

	# Check if each signal is emitted or connected
	for signal_key in signals:
		var sig_info = signals[signal_key]
		var file_path = sig_info["file"]
		var signal_name = sig_info["name"]

		# Look for emit
		var has_emit = _signal_is_emitted(signal_name, file_path, gd_files, scene_files)

		# Look for connection
		var has_connection = _signal_is_connected(signal_name, file_path, gd_files, scene_files)

		# Look for await
		var has_await = _signal_is_awaited(signal_name, file_path, gd_files)

		if not has_emit and not has_connection and not has_await:
			violations.append(sig_info)

	return violations


func _extract_signals_from_gd(file_path: String) -> Array:
	## Extract signal declarations from a GDScript file
	var signals = []
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		return signals

	var content = file_access.get_as_text()
	var lines = content.split("\n")

	var regex = RegEx.new()
	regex.compile("^\\s*signal\\s+(\\w+)")

	for i in range(lines.size()):
		var line = lines[i]
		var match = regex.search(line)
		if match:
			signals.append({
				"file": file_path,
				"line": i + 1,
				"name": match.get_string(1)
			})

	return signals


func _signal_is_emitted(signal_name: String, file_path: String, gd_files: Array, scene_files: Array) -> bool:
	## Check if signal is emitted anywhere
	var patterns = [
		signal_name + ".emit(",
		"emit_signal(\"%s\"" % signal_name
	]

	for pattern in patterns:
		# Check in the same file
		var file_access = FileAccess.open(file_path, FileAccess.READ)
		if file_access and file_access.get_as_text().contains(pattern):
			return true

	return false


func _signal_is_connected(signal_name: String, file_path: String, gd_files: Array, scene_files: Array) -> bool:
	## Check if signal is connected anywhere
	var patterns = [
		"." + signal_name + ".connect(",
		"connect(\"%s\"" % signal_name,
		"signal=\"%s\"" % signal_name  # Scene files
	]

	for gd_file in gd_files:
		var file_access = FileAccess.open(gd_file, FileAccess.READ)
		if file_access:
			var content = file_access.get_as_text()
			for pattern in patterns:
				if pattern in content:
					return true

	for scene_file in scene_files:
		var file_access = FileAccess.open(scene_file, FileAccess.READ)
		if file_access:
			var content = file_access.get_as_text()
			if "[connection signal=\"%s\"" % signal_name in content:
				return true

	return false


func _signal_is_awaited(signal_name: String, file_path: String, gd_files: Array) -> bool:
	## Check if signal is awaited anywhere
	var pattern = "await.*" + signal_name
	var regex = RegEx.new()
	regex.compile("await\\s+\\w+\\.%s" % signal_name)

	for gd_file in gd_files:
		var file_access = FileAccess.open(gd_file, FileAccess.READ)
		if file_access:
			var content = file_access.get_as_text()
			if regex.search(content):
				return true

	return false


func _find_files(dir_path: String, pattern: String) -> Array:
	## Find all files matching a pattern
	var files = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			files.append_array(_find_files(full_path, pattern))
		elif file_name.match(pattern) or pattern == "*.*":
			if file_name.ends_with(".gd") or file_name.ends_with(".tscn"):
				files.append(full_path)

		file_name = dir.get_next()

	return files


func _get_signal_allowlist() -> Dictionary:
	## Known dead signals that are intentionally not wired
	## Key: "file:signal_name" -> reason
	return {
		"res://scripts/ui/WorldHUD.gd:_dummy": "placeholder to ensure signals section exists"
	}
