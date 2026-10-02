## M29 D.4 — Resource export property lint test.
## Purpose: Scan all .tres files and verify their properties match the script definitions.
## Catches silently-dropped properties on load (D3/D14 class defect).

extends GutTest

func test_lint_resource_exports() -> void:
	## Parse every res://resources/**/*.tres and verify each key matches the script.
	var violations = _scan_resource_exports()

	if violations.is_empty():
		print("\nResource Lint: PASS (all .tres properties are defined)")
		assert_true(true)
	else:
		var message = "Resource Lint: %d violations found:\n" % violations.size()
		for violation in violations:
			message += "  %s: %s\n" % [violation["file"], violation["reason"]]
		print(message)
		assert_true(false, message)


func _scan_resource_exports() -> Array:
	## Scan all .tres files in res://resources and check property validity.
	var violations = []
	var resources_dir = "res://resources"
	var current_section = ""
	var current_script: GDScript = null
	var script_properties = {}

	var dir = DirAccess.open(resources_dir)
	if not dir:
		push_error("Could not open resources directory: %s" % resources_dir)
		return violations

	var tres_files = _find_tres_files(resources_dir)

	for tres_path in tres_files:
		# Load the .tres as text to parse it
		var file_access = FileAccess.open(tres_path, FileAccess.READ)
		if not file_access:
			continue

		var content = file_access.get_as_text()
		var lines = content.split("\n")

		current_script = null
		script_properties = {}

		for line in lines:
			line = line.strip_edges()

			# Track section headers [resource] and [sub_resource ...]
			if line.begins_with("[resource]"):
				current_section = "resource"
			elif line.begins_with("[sub_resource"):
				current_section = "sub_resource"
			elif line.begins_with("[ext_resource"):
				current_section = "ext_resource"

			# Track script definitions [ext_resource type="Script"
			if "type=\"Script\"" in line and "path=" in line:
				var script_path = _extract_path_from_line(line)
				if script_path:
					current_script = load(script_path) as GDScript
					if current_script:
						script_properties = _get_script_properties(current_script)

			# Check property assignments (key = value)
			if "=" in line and not line.begins_with("[") and not line.begins_with("#"):
				var parts = line.split("=", true, 1)
				if parts.size() >= 1:
					var key = parts[0].strip_edges()

					# Skip known special properties
					if _is_built_in_property(key) or _is_special_property(key):
						continue

					# If we have a script, check if property exists
					if current_script and current_section in ["resource", "sub_resource"]:
						if key not in script_properties:
							violations.append({
								"file": tres_path,
								"reason": "Property '%s' not defined in script" % key
							})

	return violations


func _find_tres_files(dir_path: String) -> Array:
	## Recursively find all .tres files
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
			files.append_array(_find_tres_files(full_path))
		elif file_name.ends_with(".tres"):
			files.append(full_path)

		file_name = dir.get_next()

	return files


func _extract_path_from_line(line: String) -> String:
	## Extract path="..." from a line
	var regex = RegEx.new()
	regex.compile("path=\"([^\"]+)\"")
	var match = regex.search(line)
	if match:
		return match.get_string(1)
	return ""


func _get_script_properties(script: GDScript) -> Dictionary:
	## Get all exported properties from a script
	var properties = {}

	if script.has_method("get_script_property_list"):
		var prop_list = script.get_script_property_list()
		for prop in prop_list:
			if prop is Dictionary and "name" in prop:
				properties[prop["name"]] = true

	return properties


func _is_built_in_property(name: String) -> bool:
	## Built-in Resource properties that are always valid
	var built_ins = ["script", "resource_name", "resource_local_to_scene", "resource_path"]
	return name in built_ins


func _is_special_property(name: String) -> bool:
	## Metadata and other special properties
	return name.begins_with("metadata/")
