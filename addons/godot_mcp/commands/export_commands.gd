@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Export commands: presets, build, info.


func get_handlers() -> Dictionary:
	return {
		"list_export_presets": Callable(self, "_cmd_list_export_presets"),
		"export_project": Callable(self, "_cmd_export_project"),
		"get_export_info": Callable(self, "_cmd_get_export_info"),
	}


func _cmd_list_export_presets(_p: Dictionary) -> Dictionary:
	var presets_path := "res://export_presets.cfg"
	var content := _read_text(presets_path)
	if content == null:
		return {"count": 0, "presets": [], "info": "No export_presets.cfg found. Configure exports in Godot first."}
	var presets: Array[Dictionary] = []
	var current_preset: Dictionary = {}
	for line in content.split("\n"):
		line = line.strip_edges()
		if line.begins_with("[preset."):
			if not current_preset.is_empty():
				presets.append(current_preset)
			current_preset = {}
		elif "=" in line:
			var parts := line.split("=", true, 1)
			var key := parts[0].strip_edges()
			var value := parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
			if key == "name":
				current_preset["name"] = value
			elif key == "platform":
				current_preset["platform"] = value
			elif key == "export_path":
				current_preset["export_path"] = value
			elif key == "runnable":
				current_preset["runnable"] = value == "true"
	if not current_preset.is_empty():
		presets.append(current_preset)
	return {"count": presets.size(), "presets": presets}


func _cmd_export_project(p: Dictionary) -> Dictionary:
	var preset_name := String(p.get("preset", ""))
	var output_path := String(p.get("outputPath", ""))
	if preset_name.is_empty():
		return _error(-32602, "Missing preset", "Pass preset name from list_export_presets")
	# Build the export command
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var cmd := "%s --headless --path \"%s\" --export-release \"%s\"" % [godot_path, project_path, preset_name]
	if not output_path.is_empty():
		cmd += " \"%s\"" % output_path
	return {"command": cmd, "info": "Run this command in terminal to export", "ok": true}


func _cmd_get_export_info(_p: Dictionary) -> Dictionary:
	var godot_path := OS.get_executable_path()
	var templates_path := ""
	# Get export templates path
	var os_name := OS.get_name()
	match os_name:
		"Windows":
			templates_path = OS.get_environment("APPDATA").path_join("Godot/export_templates")
		"macOS":
			templates_path = OS.get_environment("HOME").path_join("Library/Application Support/Godot/export_templates")
		"Linux":
			templates_path = OS.get_environment("HOME").path_join(".local/share/godot/export_templates")
	var version := Engine.get_version_info()
	var version_str := "%d.%d.%s" % [version.major, version.minor, version.status]
	return {
		"godot_path": godot_path,
		"templates_path": templates_path,
		"version": version_str,
		"os": os_name,
		"project_path": ProjectSettings.globalize_path("res://")
	}
