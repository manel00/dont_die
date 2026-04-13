@tool
extends RefCounted
## Base class for all command handlers. Provides shared utilities.

var editor_plugin: EditorPlugin
var _type_parser = preload("res://addons/godot_mcp/commands/type_parser.gd")
var _undo_helper_instance: RefCounted = null


func set_editor_plugin(plugin: EditorPlugin) -> void:
	editor_plugin = plugin


func get_handlers() -> Dictionary:
	return {}


func get_aliases() -> Dictionary:
	return {}


func _undo() -> RefCounted:
	if _undo_helper_instance == null:
		_undo_helper_instance = preload("res://addons/godot_mcp/commands/undo_helper.gd").new()
		_undo_helper_instance.editor_plugin = editor_plugin
	return _undo_helper_instance


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _edited_root() -> Node:
	var tree := _tree()
	if tree == null:
		return null
	if tree.edited_scene_root:
		return tree.edited_scene_root
	return tree.current_scene if tree.current_scene else tree.root


func _find_node(path: String) -> Node:
	if path.is_empty():
		return null
	var tree := _tree()
	if tree == null or tree.root == null:
		return null
	if path == "/root":
		return tree.root

	var root := _edited_root()
	if root != null:
		var node := root.get_node_or_null(path)
		if node != null:
			return node

	var node := tree.root.get_node_or_null(path)
	if node != null:
		return node
	return null


func _parse_value(value: Variant) -> Variant:
	return _type_parser.parse_value(value)


func _parse_properties(props: Dictionary) -> Dictionary:
	return _type_parser.parse_properties(props)


func _read_text(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, content: String) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(path)
	var folder := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var err := DirAccess.make_dir_recursive_absolute(folder)
		if err != OK:
			return _error(-32022, "Failed to create directory", "Check path permissions")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error(-32023, "Failed to open file: %s" % path, "Check permissions")
	file.store_string(content)
	file.close()
	return {"ok": true}


func _collect_files(root: String, output: Array[String], max_entries: int) -> void:
	if output.size() >= max_entries:
		return
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var fname := dir.get_next()
		if fname.is_empty():
			break
		if fname.begins_with("."):
			continue
		var child := root.path_join(fname)
		if dir.current_is_dir():
			_collect_files(child, output, max_entries)
		else:
			output.append(child)
			if output.size() >= max_entries:
				break
	dir.list_dir_end()


func _serialize_node(node: Node, depth: int, max_depth: int) -> Dictionary:
	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": String(node.get_path()),
		"children": []
	}
	if depth >= max_depth:
		return result
	var children: Array[Dictionary] = []
	for child in node.get_children():
		if child is Node:
			children.append(_serialize_node(child, depth + 1, max_depth))
	result.children = children
	return result


func _safe_value(value: Variant) -> Variant:
	if value is Object:
		return str(value)
	return value


func _error(code: int, message: String, suggestion: String) -> Dictionary:
	return {
		"__error": {
			"code": code,
			"message": message,
			"suggestion": suggestion
		}
	}
