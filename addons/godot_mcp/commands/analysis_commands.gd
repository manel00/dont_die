@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Analysis commands: scene complexity, signal flow, unused resources, project stats.


func get_handlers() -> Dictionary:
	return {
		"analyze_scene_complexity": Callable(self, "_cmd_analyze_scene_complexity"),
		"analyze_signal_flow": Callable(self, "_cmd_analyze_signal_flow"),
		"find_unused_resources": Callable(self, "_cmd_find_unused_resources"),
		"get_project_statistics": Callable(self, "_cmd_get_project_statistics"),
	}


func _cmd_analyze_scene_complexity(p: Dictionary) -> Dictionary:
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var stats := {"total_nodes": 0, "max_depth": 0, "types": {}}
	_count_nodes(root, 0, stats)
	return {
		"path": root.scene_file_path,
		"total_nodes": stats.total_nodes,
		"max_depth": stats.max_depth,
		"type_counts": stats.types,
		"complexity": _complexity_rating(stats.total_nodes, stats.max_depth)
	}


func _count_nodes(node: Node, depth: int, stats: Dictionary) -> void:
	stats.total_nodes += 1
	if depth > int(stats.max_depth):
		stats.max_depth = depth
	var type_name := node.get_class()
	if not stats.types.has(type_name):
		stats.types[type_name] = 0
	stats.types[type_name] = int(stats.types[type_name]) + 1
	for child in node.get_children():
		_count_nodes(child, depth + 1, stats)


func _complexity_rating(total: int, depth: int) -> String:
	if total > 500 or depth > 15:
		return "high"
	elif total > 100 or depth > 8:
		return "medium"
	return "low"


func _cmd_analyze_signal_flow(p: Dictionary) -> Dictionary:
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var connections: Array[Dictionary] = []
	var nodes_with_signals := 0
	var total_connections := 0
	_analyze_signals_recursive(root, connections, nodes_with_signals, total_connections)
	# Build graph summary
	var sources: Dictionary = {} # node -> outgoing count
	var targets: Dictionary = {} # node -> incoming count
	for conn in connections:
		var src := String(conn.get("source", ""))
		var tgt := String(conn.get("target", ""))
		if not sources.has(src): sources[src] = 0
		sources[src] = int(sources[src]) + 1
		if not tgt.is_empty():
			if not targets.has(tgt): targets[tgt] = 0
			targets[tgt] = int(targets[tgt]) + 1
	return {
		"total_connections": connections.size(),
		"connections": connections,
		"most_connected_sources": _top_n(sources, 5),
		"most_connected_targets": _top_n(targets, 5)
	}


func _analyze_signals_recursive(node: Node, output: Array[Dictionary], nodes_count: int, conn_count: int) -> void:
	var has_conn := false
	for sig in node.get_signal_list():
		var sig_name := String(sig.get("name", ""))
		for conn in node.get_signal_connection_list(sig_name):
			var callable: Callable = conn.get("callable", Callable())
			if callable.is_valid():
				has_conn = true
				output.append({
					"source": String(node.get_path()),
					"signal": sig_name,
					"target": String(callable.get_object().get_path()) if callable.get_object() is Node else "",
					"method": callable.get_method()
				})
	for child in node.get_children():
		_analyze_signals_recursive(child, output, nodes_count, conn_count)


func _top_n(dict: Dictionary, n: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for key in dict.keys():
		items.append({"path": key, "count": dict[key]})
	items.sort_custom(func(a, b): return int(a.count) > int(b.count))
	return items.slice(0, min(n, items.size()))


func _cmd_find_unused_resources(p: Dictionary) -> Dictionary:
	var files: Array[String] = []
	_collect_files("res://", files, 5000)
	# Collect all resource files
	var resource_files: Array[String] = []
	var reference_files: Array[String] = []
	for fp in files:
		if fp.ends_with(".png") or fp.ends_with(".jpg") or fp.ends_with(".svg") or fp.ends_with(".wav") or fp.ends_with(".ogg") or fp.ends_with(".mp3") or fp.ends_with(".tres") or fp.ends_with(".ttf") or fp.ends_with(".otf"):
			resource_files.append(fp)
		if fp.ends_with(".tscn") or fp.ends_with(".gd") or fp.ends_with(".tres") or fp.ends_with(".cfg"):
			reference_files.append(fp)
	# Collect all references
	var referenced: Dictionary = {}
	for fp in reference_files:
		var text := _read_text(fp)
		if text == null:
			continue
		for res_file in resource_files:
			if text.contains(res_file) or text.contains(res_file.get_file()):
				referenced[res_file] = true
	# Find unused
	var unused: Array[String] = []
	for res_file in resource_files:
		if not referenced.has(res_file):
			unused.append(res_file)
	return {"total_resources": resource_files.size(), "unused_count": unused.size(), "unused": unused}


func _cmd_get_project_statistics(_p: Dictionary) -> Dictionary:
	var files: Array[String] = []
	_collect_files("res://", files, 10000)
	var stats := {
		"total_files": files.size(),
		"scenes": 0,
		"scripts": 0,
		"shaders": 0,
		"textures": 0,
		"audio": 0,
		"resources": 0,
		"other": 0,
		"total_gd_lines": 0
	}
	for fp in files:
		if fp.ends_with(".tscn"):
			stats.scenes = int(stats.scenes) + 1
		elif fp.ends_with(".gd"):
			stats.scripts = int(stats.scripts) + 1
			var text := _read_text(fp)
			if text:
				stats.total_gd_lines = int(stats.total_gd_lines) + text.split("\n").size()
		elif fp.ends_with(".gdshader"):
			stats.shaders = int(stats.shaders) + 1
		elif fp.ends_with(".png") or fp.ends_with(".jpg") or fp.ends_with(".svg") or fp.ends_with(".webp"):
			stats.textures = int(stats.textures) + 1
		elif fp.ends_with(".wav") or fp.ends_with(".ogg") or fp.ends_with(".mp3"):
			stats.audio = int(stats.audio) + 1
		elif fp.ends_with(".tres"):
			stats.resources = int(stats.resources) + 1
		else:
			stats.other = int(stats.other) + 1
	# Autoload count
	var autoloads := 0
	for prop in ProjectSettings.get_property_list():
		if String(prop.get("name", "")).begins_with("autoload/"):
			autoloads += 1
	stats["autoloads"] = autoloads
	stats["project_name"] = ProjectSettings.get_setting("application/config/name", "")
	return stats
