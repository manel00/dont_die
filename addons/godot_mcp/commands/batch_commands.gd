@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Batch & refactoring commands: find, bulk set, dependencies.


func get_handlers() -> Dictionary:
	return {
		"find_nodes_by_type": Callable(self, "_cmd_find_nodes_by_type"),
		"find_signal_connections": Callable(self, "_cmd_find_signal_connections"),
		"batch_set_property": Callable(self, "_cmd_batch_set_property"),
		"find_node_references": Callable(self, "_cmd_find_node_references"),
		"get_scene_dependencies": Callable(self, "_cmd_get_scene_dependencies"),
		"cross_scene_set_property": Callable(self, "_cmd_cross_scene_set_property"),
		"find_script_references": Callable(self, "_cmd_find_script_references"),
		"detect_circular_dependencies": Callable(self, "_cmd_detect_circular_dependencies"),
	}


func _cmd_find_nodes_by_type(p: Dictionary) -> Dictionary:
	var type_name := String(p.get("type", ""))
	if type_name.is_empty():
		return _error(-32602, "Missing type", "Pass class name like 'Sprite2D'")
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var matches: Array[Dictionary] = []
	_find_by_type_recursive(root, type_name, matches)
	return {"type": type_name, "count": matches.size(), "nodes": matches}


func _find_by_type_recursive(node: Node, type_name: String, output: Array[Dictionary]) -> void:
	if node.is_class(type_name) or node.get_class() == type_name:
		output.append({"name": node.name, "path": String(node.get_path()), "type": node.get_class()})
	for child in node.get_children():
		_find_by_type_recursive(child, type_name, output)


func _cmd_find_signal_connections(p: Dictionary) -> Dictionary:
	var root_path := String(p.get("path", ""))
	var root := _find_node(root_path) if not root_path.is_empty() else _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var connections: Array[Dictionary] = []
	_collect_signals_recursive(root, connections)
	return {"count": connections.size(), "connections": connections}


func _collect_signals_recursive(node: Node, output: Array[Dictionary]) -> void:
	for sig in node.get_signal_list():
		var sig_name := String(sig.get("name", ""))
		for conn in node.get_signal_connection_list(sig_name):
			var callable: Callable = conn.get("callable", Callable())
			if callable.is_valid():
				output.append({
					"source": String(node.get_path()),
					"signal": sig_name,
					"target": String(callable.get_object().get_path()) if callable.get_object() is Node else "",
					"method": callable.get_method()
				})
	for child in node.get_children():
		_collect_signals_recursive(child, output)


func _cmd_batch_set_property(p: Dictionary) -> Dictionary:
	var type_filter := String(p.get("type", ""))
	var property := String(p.get("property", ""))
	var value = _parse_value(p.get("value"))
	if property.is_empty():
		return _error(-32602, "Missing property", "Pass property name")
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var changed := 0
	_batch_set_recursive(root, type_filter, property, value, changed)
	return {"property": property, "changed": changed, "ok": true}


func _batch_set_recursive(node: Node, type_filter: String, property: String, value: Variant, changed: int) -> int:
	if type_filter.is_empty() or node.is_class(type_filter) or node.get_class() == type_filter:
		if node.has_method("get") and node.get(StringName(property)) != null:
			_undo().set_property(node, StringName(property), value)
			changed += 1
	for child in node.get_children():
		changed = _batch_set_recursive(child, type_filter, property, value, changed)
	return changed


func _cmd_find_node_references(p: Dictionary) -> Dictionary:
	var node_name := String(p.get("nodeName", ""))
	if node_name.is_empty():
		return _error(-32602, "Missing nodeName", "Pass node name to search")
	var files: Array[String] = []
	_collect_files("res://", files, 3000)
	var matches: Array[Dictionary] = []
	for fp in files:
		if not (fp.ends_with(".gd") or fp.ends_with(".tscn") or fp.ends_with(".tres")):
			continue
		var text := _read_text(fp)
		if text == null:
			continue
		if text.contains(node_name):
			matches.append({"path": fp})
	return {"nodeName": node_name, "count": matches.size(), "matches": matches}


func _cmd_get_scene_dependencies(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		var root := _edited_root()
		if root:
			path = root.scene_file_path
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass scene path")
	var content := _read_text(path)
	if content == null:
		return _error(-32011, "Cannot read: %s" % path, "Verify path")
	var deps: Array[String] = []
	for line in content.split("\n"):
		if line.contains("ext_resource") and line.contains("path="):
			var start := line.find("path=\"") + 6
			var end := line.find("\"", start)
			if start > 5 and end > start:
				deps.append(line.substr(start, end - start))
	return {"path": path, "count": deps.size(), "dependencies": deps}


func _cmd_cross_scene_set_property(p: Dictionary) -> Dictionary:
	var property := String(p.get("property", ""))
	var value := String(p.get("value", ""))
	var type_filter := String(p.get("type", ""))
	var find_text := String(p.get("find", ""))
	var replace_text := String(p.get("replace", ""))
	if property.is_empty() and find_text.is_empty():
		return _error(-32602, "Missing property or find/replace", "Pass property+value OR find+replace")
	var files: Array[String] = []
	_collect_files("res://", files, 3000)
	var modified := 0
	for fp in files:
		if not fp.ends_with(".tscn"):
			continue
		var text := _read_text(fp)
		if text == null:
			continue
		var new_text := text
		if not find_text.is_empty():
			new_text = text.replace(find_text, replace_text)
		if new_text != text:
			_write_text(fp, new_text)
			modified += 1
	return {"modified": modified, "ok": true}


func _cmd_find_script_references(p: Dictionary) -> Dictionary:
	var script_path := String(p.get("scriptPath", ""))
	if script_path.is_empty():
		return _error(-32602, "Missing scriptPath", "Pass payload.scriptPath")
	var files: Array[String] = []
	_collect_files("res://", files, 3000)
	var matches: Array[Dictionary] = []
	for fp in files:
		if not (fp.ends_with(".tscn") or fp.ends_with(".tres") or fp.ends_with(".gd")):
			continue
		var text := _read_text(fp)
		if text == null:
			continue
		if text.contains(script_path):
			matches.append({"path": fp})
	return {"scriptPath": script_path, "count": matches.size(), "matches": matches}


func _cmd_detect_circular_dependencies(p: Dictionary) -> Dictionary:
	var files: Array[String] = []
	_collect_files("res://", files, 3000)
	# Build dependency graph
	var graph: Dictionary = {} # path -> [dependencies]
	for fp in files:
		if not fp.ends_with(".tscn"):
			continue
		var content := _read_text(fp)
		if content == null:
			continue
		var deps: Array[String] = []
		for line in content.split("\n"):
			if line.contains("ext_resource") and line.contains("path="):
				var start := line.find("path=\"") + 6
				var end := line.find("\"", start)
				if start > 5 and end > start:
					var dep := line.substr(start, end - start)
					if dep.ends_with(".tscn"):
						deps.append(dep)
		graph[fp] = deps
	# Detect cycles using DFS
	var visited := {}
	var in_stack := {}
	var cycles: Array[Array] = []
	for node in graph.keys():
		if not visited.has(node):
			_dfs_cycle(node, graph, visited, in_stack, [], cycles)
	return {"cycles": cycles, "has_cycles": not cycles.is_empty()}


func _dfs_cycle(node: String, graph: Dictionary, visited: Dictionary, in_stack: Dictionary, path: Array, cycles: Array[Array]) -> void:
	visited[node] = true
	in_stack[node] = true
	path.append(node)
	var deps: Array = graph.get(node, [])
	for dep in deps:
		if not visited.has(dep):
			_dfs_cycle(dep, graph, visited, in_stack, path.duplicate(), cycles)
		elif in_stack.has(dep) and in_stack[dep]:
			# Cycle found
			var cycle_start := path.find(dep)
			if cycle_start >= 0:
				cycles.append(path.slice(cycle_start))
	in_stack[node] = false
