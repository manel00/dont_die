@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Resource commands: read, edit, create resources; autoload management; preview.


func get_handlers() -> Dictionary:
	return {
		"read_resource": Callable(self, "_cmd_read_resource"),
		"edit_resource": Callable(self, "_cmd_edit_resource"),
		"create_resource": Callable(self, "_cmd_create_resource"),
		"get_resource_preview": Callable(self, "_cmd_get_resource_preview"),
		"add_autoload": Callable(self, "_cmd_add_autoload"),
		"remove_autoload": Callable(self, "_cmd_remove_autoload"),
	}


func _cmd_read_resource(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	if not ResourceLoader.exists(path):
		return _error(-32011, "Resource not found: %s" % path, "Verify file path")
	var res := load(path)
	if res == null:
		return _error(-32011, "Failed to load: %s" % path, "Check file format")
	var properties := {}
	for prop in res.get_property_list():
		var key := String(prop.get("name", ""))
		if key.is_empty() or key.begins_with("_"):
			continue
		var usage := int(prop.get("usage", 0))
		if usage & PROPERTY_USAGE_EDITOR or usage & PROPERTY_USAGE_STORAGE:
			properties[key] = _safe_value(res.get(StringName(key)))
	return {"path": path, "type": res.get_class(), "properties": properties}


func _cmd_edit_resource(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var res := load(path)
	if res == null:
		return _error(-32011, "Resource not found: %s" % path, "Check path")
	var properties := p.get("properties", {})
	if typeof(properties) != TYPE_DICTIONARY:
		return _error(-32602, "Missing properties", "Pass {property: value}")
	var parsed := _parse_properties(properties)
	for key in parsed.keys():
		res.set(StringName(key), parsed[key])
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _error(-32013, "Failed to save resource", "Check file permissions")
	return {"path": path, "ok": true}


func _cmd_create_resource(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	var resource_type := String(p.get("type", "Resource"))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var res = ClassDB.instantiate(resource_type)
	if res == null or not (res is Resource):
		return _error(-32602, "Invalid resource type: %s" % resource_type, "Use valid Resource class")
	var properties := p.get("properties", {})
	if typeof(properties) == TYPE_DICTIONARY:
		var parsed := _parse_properties(properties)
		for key in parsed.keys():
			res.set(StringName(key), parsed[key])
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _error(-32013, "Failed to save: %s" % path, "Ensure folder exists")
	return {"path": path, "type": resource_type, "ok": true}


func _cmd_get_resource_preview(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	var ei := editor_plugin.get_editor_interface()
	var previewer := ei.get_resource_previewer()
	# Resource previewer is async; we return what info we can
	return {"path": path, "info": "Preview generation is async; use get_editor_screenshot for captures", "ok": true}


func _cmd_add_autoload(p: Dictionary) -> Dictionary:
	var name := String(p.get("name", ""))
	var path := String(p.get("path", ""))
	if name.is_empty() or path.is_empty():
		return _error(-32602, "Missing name or path", "Pass name and path")
	var setting_key := "autoload/%s" % name
	# Autoload paths prefixed with * are singletons
	var singleton := bool(p.get("singleton", true))
	var value := ("*" if singleton else "") + path
	ProjectSettings.set_setting(setting_key, value)
	ProjectSettings.save()
	return {"name": name, "path": path, "singleton": singleton, "ok": true}


func _cmd_remove_autoload(p: Dictionary) -> Dictionary:
	var name := String(p.get("name", ""))
	if name.is_empty():
		return _error(-32602, "Missing name", "Pass payload.name")
	var setting_key := "autoload/%s" % name
	if not ProjectSettings.has_setting(setting_key):
		return _error(-32011, "Autoload not found: %s" % name, "Check name")
	ProjectSettings.set_setting(setting_key, null)
	ProjectSettings.save()
	return {"name": name, "ok": true}
