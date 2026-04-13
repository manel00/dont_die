@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Theme & UI commands: theme resource, colors, constants, font sizes, styleboxes.


func get_handlers() -> Dictionary:
	return {
		"create_theme": Callable(self, "_cmd_create_theme"),
		"set_theme_color": Callable(self, "_cmd_set_theme_color"),
		"set_theme_constant": Callable(self, "_cmd_set_theme_constant"),
		"set_theme_font_size": Callable(self, "_cmd_set_theme_font_size"),
		"set_theme_stylebox": Callable(self, "_cmd_set_theme_stylebox"),
		"get_theme_info": Callable(self, "_cmd_get_theme_info"),
	}


func _cmd_create_theme(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path like res://theme.tres")
	var theme := Theme.new()
	if p.has("defaultFontSize"):
		theme.default_font_size = int(p.defaultFontSize)
	var err := ResourceSaver.save(theme, path)
	if err != OK:
		return _error(-32013, "Failed to save theme", "Ensure folder exists")
	# Optionally apply to a node
	if p.has("nodePath"):
		var node := _find_node(String(p.nodePath))
		if node is Control:
			(node as Control).theme = load(path)
	return {"path": path, "ok": true}


func _cmd_set_theme_color(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is Control):
		return _error(-32602, "Control node not found", "Pass valid path to Control")
	var ctrl := node as Control
	var color_name := String(p.get("name", ""))
	var type_name := String(p.get("type", ""))
	var color = _parse_value(p.get("color", "#ffffff"))
	if color_name.is_empty():
		return _error(-32602, "Missing name", "e.g. font_color, bg_color")
	if type_name.is_empty():
		type_name = ctrl.get_class()
	ctrl.add_theme_color_override(color_name, color)
	return {"path": String(ctrl.get_path()), "name": color_name, "ok": true}


func _cmd_set_theme_constant(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is Control):
		return _error(-32602, "Control node not found", "Pass valid path")
	var ctrl := node as Control
	var const_name := String(p.get("name", ""))
	var value := int(p.get("value", 0))
	if const_name.is_empty():
		return _error(-32602, "Missing name", "e.g. margin_left, separation")
	ctrl.add_theme_constant_override(const_name, value)
	return {"path": String(ctrl.get_path()), "name": const_name, "value": value, "ok": true}


func _cmd_set_theme_font_size(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is Control):
		return _error(-32602, "Control node not found", "Pass valid path")
	var ctrl := node as Control
	var font_name := String(p.get("name", "font_size"))
	var size := int(p.get("size", 16))
	ctrl.add_theme_font_size_override(font_name, size)
	return {"path": String(ctrl.get_path()), "name": font_name, "size": size, "ok": true}


func _cmd_set_theme_stylebox(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is Control):
		return _error(-32602, "Control node not found", "Pass valid path")
	var ctrl := node as Control
	var style_name := String(p.get("name", "panel"))
	var sb := StyleBoxFlat.new()
	if p.has("bgColor"): sb.bg_color = _parse_value(p.bgColor)
	if p.has("borderColor"): sb.border_color = _parse_value(p.borderColor)
	if p.has("borderWidth"):
		var bw := int(p.borderWidth)
		sb.border_width_top = bw
		sb.border_width_bottom = bw
		sb.border_width_left = bw
		sb.border_width_right = bw
	if p.has("cornerRadius"):
		var cr := int(p.cornerRadius)
		sb.corner_radius_top_left = cr
		sb.corner_radius_top_right = cr
		sb.corner_radius_bottom_left = cr
		sb.corner_radius_bottom_right = cr
	if p.has("contentMargin"):
		var cm := int(p.contentMargin)
		sb.content_margin_top = cm
		sb.content_margin_bottom = cm
		sb.content_margin_left = cm
		sb.content_margin_right = cm
	if p.has("shadowColor"): sb.shadow_color = _parse_value(p.shadowColor)
	if p.has("shadowSize"): sb.shadow_size = int(p.shadowSize)
	ctrl.add_theme_stylebox_override(style_name, sb)
	return {"path": String(ctrl.get_path()), "name": style_name, "ok": true}


func _cmd_get_theme_info(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is Control):
		return _error(-32602, "Control node not found", "Pass valid path")
	var ctrl := node as Control
	var info := {"path": String(ctrl.get_path()), "type": ctrl.get_class()}
	info["has_theme"] = ctrl.theme != null
	# Collect overrides
	var color_overrides := {}
	var constant_overrides := {}
	var font_size_overrides := {}
	for prop in ctrl.get_property_list():
		var pname := String(prop.get("name", ""))
		if pname.begins_with("theme_override_colors/"):
			var key := pname.substr(22)
			color_overrides[key] = _safe_value(ctrl.get(StringName(pname)))
		elif pname.begins_with("theme_override_constants/"):
			var key := pname.substr(25)
			constant_overrides[key] = ctrl.get(StringName(pname))
		elif pname.begins_with("theme_override_font_sizes/"):
			var key := pname.substr(26)
			font_size_overrides[key] = ctrl.get(StringName(pname))
	info["color_overrides"] = color_overrides
	info["constant_overrides"] = constant_overrides
	info["font_size_overrides"] = font_size_overrides
	return info
