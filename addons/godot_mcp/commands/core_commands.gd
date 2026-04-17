@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Core commands: project, scene, node, script, editor basics.


func get_handlers() -> Dictionary:
	return {
		# --- core ---
		"ping": Callable(self, "_cmd_ping"),
		"editor_info": Callable(self, "_cmd_editor_info"),
		# --- project ---
		"get_project_info": Callable(self, "_cmd_get_project_info"),
		"get_filesystem_tree": Callable(self, "_cmd_get_filesystem_tree"),
		"search_files": Callable(self, "_cmd_search_files"),
		"get_project_settings": Callable(self, "_cmd_get_project_settings"),
		"set_project_setting": Callable(self, "_cmd_set_project_setting"),
		"uid_to_project_path": Callable(self, "_cmd_uid_to_project_path"),
		"project_path_to_uid": Callable(self, "_cmd_project_path_to_uid"),
		# --- scene ---
		"get_scene_tree": Callable(self, "_cmd_get_scene_tree"),
		"get_scene_file_content": Callable(self, "_cmd_get_scene_file_content"),
		"create_scene": Callable(self, "_cmd_create_scene"),
		"open_scene": Callable(self, "_cmd_open_scene"),
		"delete_scene": Callable(self, "_cmd_delete_scene"),
		"save_scene": Callable(self, "_cmd_save_scene"),
		"add_scene_instance": Callable(self, "_cmd_add_scene_instance"),
		"play_scene": Callable(self, "_cmd_play_scene"),
		"stop_scene": Callable(self, "_cmd_stop_scene"),
		# --- node ---
		"add_node": Callable(self, "_cmd_add_node"),
		"delete_node": Callable(self, "_cmd_delete_node"),
		"rename_node": Callable(self, "_cmd_rename_node"),
		"move_node": Callable(self, "_cmd_move_node"),
		"duplicate_node": Callable(self, "_cmd_duplicate_node"),
		"update_property": Callable(self, "_cmd_update_property"),
		"get_node_properties": Callable(self, "_cmd_get_node_properties"),
		"add_resource": Callable(self, "_cmd_add_resource"),
		"set_anchor_preset": Callable(self, "_cmd_set_anchor_preset"),
		"connect_signal": Callable(self, "_cmd_connect_signal"),
		"disconnect_signal": Callable(self, "_cmd_disconnect_signal"),
		"get_node_groups": Callable(self, "_cmd_get_node_groups"),
		"set_node_groups": Callable(self, "_cmd_set_node_groups"),
		"find_nodes_in_group": Callable(self, "_cmd_find_nodes_in_group"),
		# --- script ---
		"list_scripts": Callable(self, "_cmd_list_scripts"),
		"read_script": Callable(self, "_cmd_read_script"),
		"create_script": Callable(self, "_cmd_create_script"),
		"edit_script": Callable(self, "_cmd_edit_script"),
		"attach_script": Callable(self, "_cmd_attach_script"),
		"get_open_scripts": Callable(self, "_cmd_get_open_scripts"),
		"validate_script": Callable(self, "_cmd_validate_script"),
		"search_in_files": Callable(self, "_cmd_search_in_files"),
		# --- editor basics ---
		"get_editor_errors": Callable(self, "_cmd_get_editor_errors"),
		"get_signals": Callable(self, "_cmd_get_signals"),
		"get_output_log": Callable(self, "_cmd_get_output_log"),
		"clear_output": Callable(self, "_cmd_clear_output"),
		"reload_plugin": Callable(self, "_cmd_reload_plugin"),
		"reload_project": Callable(self, "_cmd_reload_project"),
	}


func get_aliases() -> Dictionary:
	return {
		"get_game_scene_tree": "get_scene_tree",
		"get_game_node_properties": "get_node_properties",
		"set_game_node_property": "update_property",
		"set_game_node_properties": "update_property",
		"read_shader": "read_script",
		"edit_shader": "edit_script",
	}


var _output_log: Array[String] = []


# ─── Core ────────────────────────────────────────────

func _cmd_ping(_p: Dictionary) -> Dictionary:
	return {"ok": true, "engine": "godot", "is_editor": Engine.is_editor_hint(), "tools": 163}


func _cmd_editor_info(_p: Dictionary) -> Dictionary:
	return {"is_editor": Engine.is_editor_hint(), "version": Engine.get_version_info()}


# ─── Project ─────────────────────────────────────────

func _cmd_get_project_info(_p: Dictionary) -> Dictionary:
	var autoloads: Array[Dictionary] = []
	for prop in ProjectSettings.get_property_list():
		var pname := String(prop.get("name", ""))
		if pname.begins_with("autoload/"):
			autoloads.append({"name": pname.get_slice("/", 1), "path": String(ProjectSettings.get_setting(pname))})
	return {
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"is_editor": Engine.is_editor_hint(),
		"version": Engine.get_version_info(),
		"autoloads": autoloads
	}


func _cmd_get_filesystem_tree(p: Dictionary) -> Dictionary:
	var root := String(p.get("root", "res://"))
	var max_entries := int(p.get("maxEntries", 2000))
	var files: Array[String] = []
	_collect_files(root, files, max_entries)
	return {"root": root, "count": files.size(), "files": files}


func _cmd_search_files(p: Dictionary) -> Dictionary:
	var query := String(p.get("query", "")).to_lower()
	var root := String(p.get("root", "res://"))
	var max_results := int(p.get("maxResults", 200))
	var files: Array[String] = []
	_collect_files(root, files, 5000)
	var matches: Array[String] = []
	for fp in files:
		if query.is_empty() or fp.to_lower().contains(query):
			matches.append(fp)
		if matches.size() >= max_results:
			break
	return {"query": query, "count": matches.size(), "matches": matches}


func _cmd_get_project_settings(p: Dictionary) -> Dictionary:
	var keys: Array = p.get("keys", [])
	if typeof(keys) != TYPE_ARRAY or keys.is_empty():
		return {"settings": {
			"application/config/name": ProjectSettings.get_setting("application/config/name", ""),
			"application/run/main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
			"display/window/size/viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
			"display/window/size/viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height", 648),
			"rendering/renderer/rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		}}
	var result := {}
	for key in keys:
		var k := String(key)
		result[k] = _safe_value(ProjectSettings.get_setting(k, null))
	return {"settings": result}


func _cmd_set_project_setting(p: Dictionary) -> Dictionary:
	var key := String(p.get("key", ""))
	if key.is_empty():
		return _error(-32602, "Missing key", "Pass payload.key")
	var value = _parse_value(p.get("value"))
	ProjectSettings.set_setting(key, value)
	ProjectSettings.save()
	return {"key": key, "value": _safe_value(value), "ok": true}


func _cmd_uid_to_project_path(p: Dictionary) -> Dictionary:
	var uid_str := String(p.get("uid", ""))
	if uid_str.is_empty():
		return _error(-32602, "Missing uid", "Pass payload.uid")
	var uid := ResourceUID.text_to_id(uid_str)
	if uid == ResourceUID.INVALID_ID:
		return _error(-32602, "Invalid UID: %s" % uid_str, "Use format like uid://xxxxx")
	if not ResourceUID.has_id(uid):
		return _error(-32011, "UID not found: %s" % uid_str, "Verify UID exists in project")
	var path := ResourceUID.get_id_path(uid)
	return {"uid": uid_str, "path": path}


func _cmd_project_path_to_uid(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	if not ResourceLoader.exists(path):
		return _error(-32011, "Resource not found: %s" % path, "Verify file path")
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return {"path": path, "uid": "", "warning": "No UID assigned"}
	return {"path": path, "uid": ResourceUID.id_to_text(uid)}


# ─── Scene ────────────────────────────────────────────

func _cmd_get_scene_tree(p: Dictionary) -> Dictionary:
	var max_depth := int(p.get("maxDepth", 8))
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No active scene tree", "Open a scene first")
	return _serialize_node(root, 0, max_depth)


func _cmd_get_scene_file_content(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		var root := _edited_root()
		if root:
			path = String(root.scene_file_path)
	if path.is_empty():
		return _error(-32602, "Missing scene path", "Pass payload.path")
	var content := _read_text(path)
	if content == null:
		return _error(-32011, "Failed to read: %s" % path, "Verify file exists")
	return {"path": path, "content": content}


func _cmd_create_scene(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing scene path", "Pass payload.path")
	var root_type := String(p.get("rootType", "Node"))
	var root_name := String(p.get("rootName", "Root"))
	var root = ClassDB.instantiate(root_type)
	if root == null or not (root is Node):
		return _error(-32602, "Invalid rootType: %s" % root_type, "Use Node2D, Control, Node3D, etc.")
	root.name = root_name
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		return _error(-32013, "Failed to save scene: %s" % path, "Ensure folder exists")
	return {"path": path, "root_type": root_type, "ok": true}


func _cmd_open_scene(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	if editor_plugin:
		var ei := editor_plugin.get_editor_interface()
		if ei:
			ei.open_scene_from_path(path)
			return {"path": path, "ok": true}
	return _error(-32050, "Cannot open scene outside editor", "Ensure plugin is running in editor")


func _cmd_delete_scene(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var abs_path := ProjectSettings.globalize_path(path)
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		return _error(-32014, "Failed to delete: %s" % path, "Verify file exists")
	return {"path": path, "ok": true}


func _cmd_save_scene(_p: Dictionary) -> Dictionary:
	if editor_plugin:
		var ei := editor_plugin.get_editor_interface()
		if ei:
			ei.save_scene()
			return {"ok": true}
	var root := _edited_root()
	if root == null:
		return _error(-32015, "No scene to save", "Open a scene first")
	var path := String(root.scene_file_path)
	if path.is_empty():
		return _error(-32016, "Scene has no file path", "Save manually first")
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	return {"path": path, "ok": true}


func _cmd_add_scene_instance(p: Dictionary) -> Dictionary:
	var scene_path := String(p.get("scenePath", ""))
	var parent_path := String(p.get("parentPath", ""))
	if scene_path.is_empty():
		return _error(-32602, "Missing scenePath", "Pass payload.scenePath")
	if not ResourceLoader.exists(scene_path):
		return _error(-32011, "Scene not found: %s" % scene_path, "Verify file path")
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass valid parentPath")
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return _error(-32011, "Failed to load: %s" % scene_path, "Verify it's a .tscn")
	var instance := packed.instantiate()
	if p.has("name"):
		instance.name = String(p.name)
	_undo().add_child_node(parent, instance, "MCP: Instance %s" % scene_path.get_file())
	return {"path": String(instance.get_path()), "scene": scene_path, "ok": true}


func _cmd_play_scene(p: Dictionary) -> Dictionary:
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	var ei := editor_plugin.get_editor_interface()
	var path := String(p.get("path", ""))
	if path.is_empty():
		ei.play_current_scene()
	else:
		ei.play_custom_scene(path)
	return {"ok": true, "path": path}


func _cmd_stop_scene(_p: Dictionary) -> Dictionary:
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	editor_plugin.get_editor_interface().stop_playing_scene()
	return {"ok": true}


# ─── Node ─────────────────────────────────────────────

func _cmd_add_node(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var node_type := String(p.get("type", "Node"))
	var node_name := String(p.get("name", node_type))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found: %s" % parent_path, "Use get_scene_tree")
	var node = ClassDB.instantiate(node_type)
	if node == null or not (node is Node):
		return _error(-32602, "Invalid type: %s" % node_type, "Use Node2D, Control, etc.")
	node.name = node_name
	var properties := p.get("properties", {})
	if typeof(properties) == TYPE_DICTIONARY:
		var parsed := _parse_properties(properties)
		for key in parsed.keys():
			node.set(StringName(key), parsed[key])
	_undo().add_child_node(parent, node, "MCP: Add %s" % node_name)
	return {"path": String(node.get_path()), "type": node_type}


func _cmd_delete_node(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Use get_scene_tree")
	var path := String(node.get_path())
	_undo().remove_node(node, "MCP: Delete %s" % node.name)
	return {"path": path, "ok": true}


func _cmd_rename_node(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	var new_name := String(p.get("newName", ""))
	if node == null or new_name.is_empty():
		return _error(-32602, "Invalid arguments", "Pass path and newName")
	_undo().rename_node(node, new_name)
	return {"path": String(node.get_path()), "name": new_name}


func _cmd_move_node(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	var new_parent := _find_node(String(p.get("newParentPath", "")))
	if node == null or new_parent == null:
		return _error(-32602, "Invalid arguments", "Pass path and newParentPath")
	var old_path := String(node.get_path())
	_undo().reparent_node(node, new_parent)
	return {"old_path": old_path, "new_path": String(node.get_path())}


func _cmd_duplicate_node(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var parent := node.get_parent()
	if parent == null:
		return _error(-32021, "Cannot duplicate root", "Duplicate child nodes")
	var clone := node.duplicate()
	_undo().add_child_node(parent, clone, "MCP: Duplicate %s" % node.name)
	return {"path": String(clone.get_path())}


func _cmd_update_property(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	var prop := String(p.get("property", ""))
	if node == null or prop.is_empty():
		return _error(-32602, "Invalid arguments", "Pass path, property, value")
	var value = _parse_value(p.get("value"))
	_undo().set_property(node, StringName(prop), value)
	return {"path": String(node.get_path()), "property": prop, "value": _safe_value(node.get(StringName(prop)))}


func _cmd_get_node_properties(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var properties := {}
	for prop in node.get_property_list():
		var key := String(prop.get("name", ""))
		if key.is_empty():
			continue
		properties[key] = _safe_value(node.get(StringName(key)))
	return {"path": String(node.get_path()), "type": node.get_class(), "properties": properties}


func _cmd_add_resource(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var resource_type := String(p.get("resourceType", ""))
	var property := String(p.get("property", ""))
	if resource_type.is_empty() or property.is_empty():
		return _error(-32602, "Missing resourceType or property", "e.g. resourceType=RectangleShape2D, property=shape")
	var res = ClassDB.instantiate(resource_type)
	if res == null:
		return _error(-32602, "Invalid resource type: %s" % resource_type, "Use valid Resource class name")
	var props := p.get("properties", {})
	if typeof(props) == TYPE_DICTIONARY:
		var parsed := _parse_properties(props)
		for key in parsed.keys():
			res.set(StringName(key), parsed[key])
	_undo().set_property(node, StringName(property), res, "MCP: Add %s to %s" % [resource_type, node.name])
	return {"path": String(node.get_path()), "property": property, "resource": resource_type, "ok": true}


func _cmd_set_anchor_preset(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is Control):
		return _error(-32602, "Control node not found", "Target must be a Control")
	var preset := int(p.get("preset", 0))
	(node as Control).set_anchors_preset(preset)
	return {"path": String(node.get_path()), "preset": preset, "ok": true}


func _cmd_connect_signal(p: Dictionary) -> Dictionary:
	var source := _find_node(String(p.get("sourcePath", "")))
	var target := _find_node(String(p.get("targetPath", "")))
	var signal_name := String(p.get("signal", ""))
	var method := String(p.get("method", ""))
	if source == null or target == null or signal_name.is_empty() or method.is_empty():
		return _error(-32602, "Invalid arguments", "Pass sourcePath, targetPath, signal, method")
	if source.is_connected(signal_name, Callable(target, method)):
		return {"ok": true, "already_connected": true}
	source.connect(signal_name, Callable(target, method))
	return {"source": String(source.get_path()), "target": String(target.get_path()), "signal": signal_name, "method": method, "ok": true}


func _cmd_disconnect_signal(p: Dictionary) -> Dictionary:
	var source := _find_node(String(p.get("sourcePath", "")))
	var target := _find_node(String(p.get("targetPath", "")))
	var signal_name := String(p.get("signal", ""))
	var method := String(p.get("method", ""))
	if source == null or target == null or signal_name.is_empty() or method.is_empty():
		return _error(-32602, "Invalid arguments", "Pass sourcePath, targetPath, signal, method")
	if not source.is_connected(signal_name, Callable(target, method)):
		return _error(-32030, "Signal not connected", "Verify connection exists")
	source.disconnect(signal_name, Callable(target, method))
	return {"ok": true}


func _cmd_get_node_groups(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var groups: Array[String] = []
	for g in node.get_groups():
		groups.append(String(g))
	return {"path": String(node.get_path()), "groups": groups}


func _cmd_set_node_groups(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var groups: Array = p.get("groups", [])
	for g in node.get_groups():
		if not String(g).begins_with("_"):
			node.remove_from_group(g)
	for g in groups:
		node.add_to_group(String(g))
	return {"path": String(node.get_path()), "groups": groups, "ok": true}


func _cmd_find_nodes_in_group(p: Dictionary) -> Dictionary:
	var group_name := String(p.get("group", ""))
	if group_name.is_empty():
		return _error(-32602, "Missing group", "Pass payload.group")
	var tree := _tree()
	if tree == null:
		return _error(-32010, "No scene tree", "Open a scene first")
	var nodes: Array[Dictionary] = []
	for node in tree.get_nodes_in_group(group_name):
		nodes.append({"name": node.name, "path": String(node.get_path()), "type": node.get_class()})
	return {"group": group_name, "count": nodes.size(), "nodes": nodes}


# ─── Script ────────────────────────────────────────────

func _cmd_list_scripts(p: Dictionary) -> Dictionary:
	var root := String(p.get("root", "res://"))
	var files: Array[String] = []
	_collect_files(root, files, 5000)
	var scripts: Array[String] = []
	for fp in files:
		if fp.ends_with(".gd") or fp.ends_with(".cs") or fp.ends_with(".gdshader"):
			scripts.append(fp)
	return {"count": scripts.size(), "scripts": scripts}


func _cmd_read_script(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var content := _read_text(path)
	if content == null:
		return _error(-32019, "Failed to read: %s" % path, "Verify file path")
	return {"path": path, "content": content}


func _cmd_create_script(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var content := String(p.get("content", "extends Node\n"))
	var write := _write_text(path, content)
	if write.has("__error"):
		return write
	return {"path": path, "ok": true}


func _cmd_edit_script(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var content := _read_text(path)
	if content == null:
		return _error(-32020, "Cannot read: %s" % path, "Verify file path")
	if p.has("newContent"):
		content = String(p.newContent)
	elif p.has("find") and p.has("replace"):
		content = content.replace(String(p.find), String(p.replace))
	elif p.has("replacements") and typeof(p.replacements) == TYPE_ARRAY:
		for repl in p.replacements:
			if typeof(repl) != TYPE_DICTIONARY:
				continue
			var search := String(repl.get("search", ""))
			var replace := String(repl.get("replace", ""))
			if not search.is_empty():
				content = content.replace(search, replace)
	elif p.has("insert_after"):
		var after := String(p.insert_after)
		var code := String(p.get("code", ""))
		var idx: int = content.find(after)
		if idx >= 0:
			content = content.insert(idx + after.length(), "\n" + code)
	else:
		return _error(-32602, "Missing edit args", "Pass newContent OR find+replace OR replacements[]")
	var write := _write_text(path, content)
	if write.has("__error"):
		return write
	return {"path": path, "ok": true}


func _cmd_attach_script(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("nodePath", "")))
	var script_path := String(p.get("scriptPath", ""))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid nodePath")
	if script_path.is_empty():
		return _error(-32602, "Missing scriptPath", "Pass payload.scriptPath")
	var script: Script = load(script_path)
	if script == null:
		return _error(-32011, "Script not found: %s" % script_path, "Verify file path")
	_undo().set_property(node, &"script", script, "MCP: Attach script to %s" % node.name)
	return {"node": String(node.get_path()), "script": script_path, "ok": true}


func _cmd_get_open_scripts(_p: Dictionary) -> Dictionary:
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	var ei := editor_plugin.get_editor_interface()
	var se := ei.get_script_editor()
	var scripts: Array[String] = []
	for s in se.get_open_scripts():
		if s is Script:
			scripts.append(s.resource_path)
	return {"count": scripts.size(), "scripts": scripts}


func _cmd_validate_script(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path")
	var content := _read_text(path)
	if content == null:
		return _error(-32019, "Cannot read: %s" % path, "Verify path")
	var script := GDScript.new()
	script.source_code = content
	var err := script.reload()
	return {"path": path, "valid": err == OK, "error_code": err}


func _cmd_search_in_files(p: Dictionary) -> Dictionary:
	var query := String(p.get("query", "")).to_lower()
	if query.is_empty():
		return _error(-32602, "Missing query", "Pass payload.query")
	var root := String(p.get("root", "res://"))
	var max_results := int(p.get("maxResults", 100))
	var files: Array[String] = []
	_collect_files(root, files, 3000)
	var matches: Array[Dictionary] = []
	for fp in files:
		if not (fp.ends_with(".gd") or fp.ends_with(".tscn") or fp.ends_with(".tres") or fp.ends_with(".gdshader") or fp.ends_with(".cfg")):
			continue
		var text := _read_text(fp)
		if text == null:
			continue
		var lower: String = text.to_lower()
		if lower.contains(query):
			# Find line numbers
			var lines: Array = text.split("\n")
			var line_matches: Array[Dictionary] = []
			for i in range(lines.size()):
				if lines[i].to_lower().contains(query):
					line_matches.append({"line": i + 1, "text": lines[i].strip_edges()})
					if line_matches.size() >= 5:
						break
			matches.append({"path": fp, "lines": line_matches})
			if matches.size() >= max_results:
				break
	return {"query": query, "count": matches.size(), "matches": matches}


# ─── Editor basics ────────────────────────────────────

func _cmd_get_editor_errors(_p: Dictionary) -> Dictionary:
	# Use the editor's log to collect errors
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	# We can't directly access error log, but we can check script errors
	var errors: Array[String] = []
	# Collect from our own log
	for line in _output_log:
		if "Error" in line or "error" in line:
			errors.append(line)
	return {"count": errors.size(), "errors": errors}


func _cmd_get_signals(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var signals: Array[Dictionary] = []
	for sig in node.get_signal_list():
		var sig_name := String(sig.get("name", ""))
		var connections: Array[Dictionary] = []
		for conn in node.get_signal_connection_list(sig_name):
			connections.append({
				"signal": sig_name,
				"target": String(conn.get("callable", Callable()).get_object().get_path()) if conn.get("callable", Callable()).get_object() else "",
				"method": conn.get("callable", Callable()).get_method()
			})
		signals.append({"name": sig_name, "connections": connections})
	return {"path": String(node.get_path()), "signals": signals}


func _cmd_get_output_log(_p: Dictionary) -> Dictionary:
	return {"count": _output_log.size(), "lines": _output_log}


func _cmd_clear_output(_p: Dictionary) -> Dictionary:
	_output_log.clear()
	return {"ok": true}


func _cmd_reload_plugin(_p: Dictionary) -> Dictionary:
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	var ei := editor_plugin.get_editor_interface()
	ei.set_plugin_enabled("godot_mcp", false)
	ei.set_plugin_enabled("godot_mcp", true)
	return {"ok": true}


func _cmd_reload_project(_p: Dictionary) -> Dictionary:
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	return {"ok": true}
