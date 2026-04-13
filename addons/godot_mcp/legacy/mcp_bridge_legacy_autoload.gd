extends Node

@export var port: int = 6505

var _tcp_server := TCPServer.new()
var _clients: Array[WebSocketPeer] = []
var _tool_handlers: Dictionary = {}
var _tool_aliases: Dictionary = {}
var _output_log: Array[String] = []

func _ready() -> void:
	_register_tool_handlers()
	var err := _tcp_server.listen(port)
	if err != OK:
		_log("MCP Bridge failed to listen on port %d" % port)
		return
	_log("MCP Bridge listening on ws://127.0.0.1:%d" % port)

func _process(_delta: float) -> void:
	_accept_new_clients()
	_poll_clients()

func _accept_new_clients() -> void:
	while _tcp_server.is_connection_available():
		var connection := _tcp_server.take_connection()
		var peer := WebSocketPeer.new()
		var err := peer.accept_stream(connection)
		if err == OK:
			_clients.append(peer)
			_log("Client connected")
		else:
			_log("Failed to accept websocket stream")

func _poll_clients() -> void:
	for i in range(_clients.size() - 1, -1, -1):
		var client := _clients[i]
		client.poll()
		var state := client.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			while client.get_available_packet_count() > 0:
				var text := client.get_packet().get_string_from_utf8()
				_handle_request(client, text)
		elif state == WebSocketPeer.STATE_CLOSED:
			_log("Client disconnected")
			_clients.remove_at(i)

func _handle_request(client: WebSocketPeer, raw_text: String) -> void:
	var parsed := JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var id := parsed.get("id", null)
	var command := String(parsed.get("method", parsed.get("command", "")))
	var payload := parsed.get("params", parsed.get("payload", {}))
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}

	if command.is_empty():
		_send_error(client, id, -32600, "Missing method/command", "Send a valid MCP tool name")
		return

	var execution := _execute_command(command, payload)
	if execution.has("error"):
		var err_obj: Dictionary = execution.error
		_send_error(
			client,
			id,
			int(err_obj.get("code", -32000)),
			String(err_obj.get("message", "Command failed")),
			String(err_obj.get("suggestion", ""))
		)
		return

	_send_result(client, id, execution.get("result", {}))

func _register_tool_handlers() -> void:
	_tool_handlers = {
		"ping": Callable(self, "_cmd_ping"),
		"editor_info": Callable(self, "_cmd_editor_info"),
		"get_project_info": Callable(self, "_cmd_get_project_info"),
		"get_filesystem_tree": Callable(self, "_cmd_get_filesystem_tree"),
		"search_files": Callable(self, "_cmd_search_files"),
		"get_scene_tree": Callable(self, "_cmd_get_scene_tree"),
		"get_scene_file_content": Callable(self, "_cmd_get_scene_file_content"),
		"create_scene": Callable(self, "_cmd_create_scene"),
		"delete_scene": Callable(self, "_cmd_delete_scene"),
		"save_scene": Callable(self, "_cmd_save_scene"),
		"list_scripts": Callable(self, "_cmd_list_scripts"),
		"read_script": Callable(self, "_cmd_read_script"),
		"create_script": Callable(self, "_cmd_create_script"),
		"edit_script": Callable(self, "_cmd_edit_script"),
		"search_in_files": Callable(self, "_cmd_search_in_files"),
		"add_node": Callable(self, "_cmd_add_node"),
		"delete_node": Callable(self, "_cmd_delete_node"),
		"rename_node": Callable(self, "_cmd_rename_node"),
		"move_node": Callable(self, "_cmd_move_node"),
		"duplicate_node": Callable(self, "_cmd_duplicate_node"),
		"update_property": Callable(self, "_cmd_update_property"),
		"get_node_properties": Callable(self, "_cmd_get_node_properties"),
		"get_output_log": Callable(self, "_cmd_get_output_log"),
		"clear_output": Callable(self, "_cmd_clear_output")
	}

	_tool_aliases = {
		"get_game_scene_tree": "get_scene_tree",
		"get_game_node_properties": "get_node_properties",
		"set_game_node_property": "update_property",
		"set_game_node_properties": "update_property",
		"read_shader": "read_script",
		"edit_shader": "edit_script",
		"open_scene": "get_scene_file_content"
	}

func _execute_command(command: String, payload: Dictionary) -> Dictionary:
	var target := command
	if _tool_aliases.has(command):
		target = String(_tool_aliases[command])

	if not _tool_handlers.has(target):
		return {
			"error": {
				"code": -32601,
				"message": "Tool '%s' is not implemented in this bridge yet" % command,
				"suggestion": "Use implemented core tools first or extend mcp_bridge.gd handlers"
			}
		}

	var callable: Callable = _tool_handlers[target]
	var result = callable.call(payload)
	if typeof(result) == TYPE_DICTIONARY and result.has("__error"):
		return { "error": result.get("__error") }

	return {
		"result": {
			"tool": command,
			"implemented": true,
			"data": result
		}
	}

func _send_result(client: WebSocketPeer, id: Variant, result: Variant) -> void:
	var response := {
		"jsonrpc": "2.0",
		"id": id,
		"result": result
	}
	client.send_text(JSON.stringify(response))

func _send_error(client: WebSocketPeer, id: Variant, code: int, message: String, suggestion: String) -> void:
	var error_obj := {
		"code": code,
		"message": message,
		"data": {
			"suggestion": suggestion
		}
	}
	var response := {
		"jsonrpc": "2.0",
		"id": id,
		"error": error_obj
	}
	client.send_text(JSON.stringify(response))
	_log("Error [%d] %s" % [code, message])

func _cmd_ping(_payload: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"engine": "godot",
		"is_editor": Engine.is_editor_hint()
	}

func _cmd_editor_info(_payload: Dictionary) -> Dictionary:
	return {
		"is_editor": Engine.is_editor_hint(),
		"version": Engine.get_version_info()
	}

func _cmd_get_project_info(_payload: Dictionary) -> Dictionary:
	return {
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"is_editor": Engine.is_editor_hint(),
		"version": Engine.get_version_info()
	}

func _cmd_get_filesystem_tree(payload: Dictionary) -> Dictionary:
	var root := String(payload.get("root", "res://"))
	var max_entries := int(payload.get("maxEntries", 2000))
	var files: Array[String] = []
	_collect_files(root, files, max_entries)
	return {
		"root": root,
		"count": files.size(),
		"files": files
	}

func _cmd_search_files(payload: Dictionary) -> Dictionary:
	var query := String(payload.get("query", "")).to_lower()
	var root := String(payload.get("root", "res://"))
	var max_results := int(payload.get("maxResults", 200))
	var files: Array[String] = []
	_collect_files(root, files, 5000)
	var matches: Array[String] = []
	for path in files:
		if query.is_empty() or path.to_lower().contains(query):
			matches.append(path)
		if matches.size() >= max_results:
			break
	return {
		"query": query,
		"count": matches.size(),
		"matches": matches
	}

func _cmd_get_scene_tree(payload: Dictionary) -> Dictionary:
	var max_depth := int(payload.get("maxDepth", 8))
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		return {
			"__error": {
				"code": -32010,
				"message": "No active scene tree available",
				"suggestion": "Run scene or open project scene first"
			}
		}

	return _serialize_node(root, 0, max_depth)

func _cmd_get_scene_file_content(payload: Dictionary) -> Dictionary:
	var path := String(payload.get("path", ""))
	if path.is_empty():
		path = String(get_tree().current_scene.scene_file_path) if get_tree().current_scene != null else ""
	if path.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing scene path",
				"suggestion": "Pass payload.path like res://scenes/main.tscn"
			}
		}

	var content := _read_text(path)
	if content == null:
		return {
			"__error": {
				"code": -32011,
				"message": "Failed to read scene file: %s" % path,
				"suggestion": "Verify the file exists and path uses res://"
			}
		}

	return {
		"path": path,
		"content": content
	}

func _cmd_create_scene(payload: Dictionary) -> Dictionary:
	var path := String(payload.get("path", ""))
	if path.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing scene path",
				"suggestion": "Pass payload.path like res://scenes/new_scene.tscn"
			}
		}

	var root_type := String(payload.get("rootType", "Node"))
	var root_name := String(payload.get("rootName", "Root"))
	var root = ClassDB.instantiate(root_type)
	if root == null or not (root is Node):
		return {
			"__error": {
				"code": -32602,
				"message": "Invalid rootType: %s" % root_type,
				"suggestion": "Use built-in node types like Node2D, Control, Node3D"
			}
		}

	root.name = root_name
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		return {
			"__error": {
				"code": -32012,
				"message": "Failed to pack scene",
				"suggestion": "Check node setup and try again"
			}
		}

	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		return {
			"__error": {
				"code": -32013,
				"message": "Failed to save scene at %s" % path,
				"suggestion": "Ensure target folder exists and is writable"
			}
		}

	return {
		"path": path,
		"root_type": root_type,
		"ok": true
	}

func _cmd_delete_scene(payload: Dictionary) -> Dictionary:
	var path := String(payload.get("path", ""))
	if path.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing scene path",
				"suggestion": "Pass payload.path"
			}
		}

	var abs_path := ProjectSettings.globalize_path(path)
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		return {
			"__error": {
				"code": -32014,
				"message": "Failed to delete scene at %s" % path,
				"suggestion": "Verify file exists and is not locked"
			}
		}

	return {
		"path": path,
		"ok": true
	}

func _cmd_save_scene(_payload: Dictionary) -> Dictionary:
	if get_tree().current_scene == null:
		return {
			"__error": {
				"code": -32015,
				"message": "No current scene to save",
				"suggestion": "Open or run a scene first"
			}
		}

	var scene := get_tree().current_scene
	var path := String(scene.scene_file_path)
	if path.is_empty():
		return {
			"__error": {
				"code": -32016,
				"message": "Current scene has no file path",
				"suggestion": "Save scene manually once to assign a path"
			}
		}

	var packed := PackedScene.new()
	var pack_err := packed.pack(scene)
	if pack_err != OK:
		return {
			"__error": {
				"code": -32017,
				"message": "Failed to pack current scene",
				"suggestion": "Check scene for invalid nodes"
			}
		}

	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		return {
			"__error": {
				"code": -32018,
				"message": "Failed to save current scene",
				"suggestion": "Ensure scene path is writable"
			}
		}

	return {
		"path": path,
		"ok": true
	}

func _cmd_list_scripts(payload: Dictionary) -> Dictionary:
	var root := String(payload.get("root", "res://"))
	var files: Array[String] = []
	_collect_files(root, files, 5000)
	var scripts: Array[String] = []
	for path in files:
		if path.ends_with(".gd") or path.ends_with(".cs") or path.ends_with(".gdshader"):
			scripts.append(path)
	return {
		"count": scripts.size(),
		"scripts": scripts
	}

func _cmd_read_script(payload: Dictionary) -> Dictionary:
	var path := String(payload.get("path", ""))
	if path.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing script path",
				"suggestion": "Pass payload.path"
			}
		}

	var content := _read_text(path)
	if content == null:
		return {
			"__error": {
				"code": -32019,
				"message": "Failed to read script: %s" % path,
				"suggestion": "Verify file path"
			}
		}

	return {
		"path": path,
		"content": content
	}

func _cmd_create_script(payload: Dictionary) -> Dictionary:
	var path := String(payload.get("path", ""))
	if path.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing script path",
				"suggestion": "Pass payload.path"
			}
		}

	var content := String(payload.get("content", "extends Node\n"))
	var write := _write_text(path, content)
	if not bool(write.get("ok", false)):
		return { "__error": write.get("error") }

	return {
		"path": path,
		"ok": true
	}

func _cmd_edit_script(payload: Dictionary) -> Dictionary:
	var path := String(payload.get("path", ""))
	if path.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing script path",
				"suggestion": "Pass payload.path"
			}
		}

	var content := _read_text(path)
	if content == null:
		return {
			"__error": {
				"code": -32020,
				"message": "Cannot edit unreadable script: %s" % path,
				"suggestion": "Verify file path"
			}
		}

	if payload.has("newContent"):
		content = String(payload.newContent)
	elif payload.has("find") and payload.has("replace"):
		content = content.replace(String(payload.find), String(payload.replace))
	else:
		return {
			"__error": {
				"code": -32602,
				"message": "Missing edit arguments",
				"suggestion": "Pass newContent OR find+replace"
			}
		}

	var write := _write_text(path, content)
	if not bool(write.get("ok", false)):
		return { "__error": write.get("error") }

	return {
		"path": path,
		"ok": true
	}

func _cmd_search_in_files(payload: Dictionary) -> Dictionary:
	var query := String(payload.get("query", "")).to_lower()
	if query.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Missing query",
				"suggestion": "Pass payload.query"
			}
		}

	var root := String(payload.get("root", "res://"))
	var max_results := int(payload.get("maxResults", 100))
	var files: Array[String] = []
	_collect_files(root, files, 3000)

	var matches: Array[Dictionary] = []
	for path in files:
		if not (path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres") or path.ends_with(".gdshader")):
			continue

		var text := _read_text(path)
		if text == null:
			continue

		if text.to_lower().contains(query):
			matches.append({ "path": path })
			if matches.size() >= max_results:
				break

	return {
		"query": query,
		"count": matches.size(),
		"matches": matches
	}

func _cmd_add_node(payload: Dictionary) -> Dictionary:
	var parent_path := String(payload.get("parentPath", ""))
	var node_type := String(payload.get("type", "Node"))
	var node_name := String(payload.get("name", node_type))

	var parent := _find_node(parent_path)
	if parent == null:
		return {
			"__error": {
				"code": -32602,
				"message": "Parent node not found: %s" % parent_path,
				"suggestion": "Use get_scene_tree to inspect valid node paths"
			}
		}

	var node = ClassDB.instantiate(node_type)
	if node == null or not (node is Node):
		return {
			"__error": {
				"code": -32602,
				"message": "Invalid node type: %s" % node_type,
				"suggestion": "Use built-in classes like Node2D, Control, Node3D"
			}
		}

	node.name = node_name
	parent.add_child(node)

	var properties := payload.get("properties", {})
	if typeof(properties) == TYPE_DICTIONARY:
		for key in properties.keys():
			node.set(StringName(key), properties[key])

	return {
		"path": String(node.get_path()),
		"type": node_type
	}

func _cmd_delete_node(payload: Dictionary) -> Dictionary:
	var node := _find_node(String(payload.get("path", "")))
	if node == null:
		return {
			"__error": {
				"code": -32602,
				"message": "Node not found",
				"suggestion": "Use get_scene_tree to inspect node paths"
			}
		}

	var deleted_path := String(node.get_path())
	node.queue_free()
	return {
		"path": deleted_path,
		"ok": true
	}

func _cmd_rename_node(payload: Dictionary) -> Dictionary:
	var node := _find_node(String(payload.get("path", "")))
	var new_name := String(payload.get("newName", ""))
	if node == null or new_name.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Invalid rename arguments",
				"suggestion": "Pass valid path and newName"
			}
		}

	node.name = new_name
	return {
		"path": String(node.get_path()),
		"name": new_name
	}

func _cmd_move_node(payload: Dictionary) -> Dictionary:
	var node := _find_node(String(payload.get("path", "")))
	var new_parent := _find_node(String(payload.get("newParentPath", "")))
	if node == null or new_parent == null:
		return {
			"__error": {
				"code": -32602,
				"message": "Invalid move arguments",
				"suggestion": "Pass valid path and newParentPath"
			}
		}

	var old_path := String(node.get_path())
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	new_parent.add_child(node)
	return {
		"old_path": old_path,
		"new_path": String(node.get_path())
	}

func _cmd_duplicate_node(payload: Dictionary) -> Dictionary:
	var node := _find_node(String(payload.get("path", "")))
	if node == null:
		return {
			"__error": {
				"code": -32602,
				"message": "Node not found",
				"suggestion": "Pass valid path"
			}
		}

	var parent := node.get_parent()
	if parent == null:
		return {
			"__error": {
				"code": -32021,
				"message": "Cannot duplicate root without parent",
				"suggestion": "Duplicate child nodes inside a scene"
			}
		}

	var clone := node.duplicate()
	parent.add_child(clone)
	return {
		"path": String(clone.get_path())
	}

func _cmd_update_property(payload: Dictionary) -> Dictionary:
	var node := _find_node(String(payload.get("path", "")))
	var prop := String(payload.get("property", ""))
	if node == null or prop.is_empty():
		return {
			"__error": {
				"code": -32602,
				"message": "Invalid update_property arguments",
				"suggestion": "Pass path, property, and value"
			}
		}

	node.set(StringName(prop), payload.get("value"))
	return {
		"path": String(node.get_path()),
		"property": prop,
		"value": node.get(StringName(prop))
	}

func _cmd_get_node_properties(payload: Dictionary) -> Dictionary:
	var node := _find_node(String(payload.get("path", "")))
	if node == null:
		return {
			"__error": {
				"code": -32602,
				"message": "Node not found",
				"suggestion": "Pass a valid node path"
			}
		}

	var properties: Dictionary = {}
	for prop in node.get_property_list():
		var key := String(prop.get("name", ""))
		if key.is_empty():
			continue
		properties[key] = node.get(StringName(key))

	return {
		"path": String(node.get_path()),
		"properties": properties
	}

func _cmd_get_output_log(_payload: Dictionary) -> Dictionary:
	return {
		"count": _output_log.size(),
		"lines": _output_log
	}

func _cmd_clear_output(_payload: Dictionary) -> Dictionary:
	_output_log.clear()
	return {
		"ok": true
	}

func _collect_files(root: String, output: Array[String], max_entries: int) -> void:
	if output.size() >= max_entries:
		return

	var dir := DirAccess.open(root)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		var child := root.path_join(name)
		if dir.current_is_dir():
			_collect_files(child, output, max_entries)
		else:
			output.append(child)
			if output.size() >= max_entries:
				break

	dir.list_dir_end()

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
		var mkdir_err := DirAccess.make_dir_recursive_absolute(folder)
		if mkdir_err != OK:
			return {
				"ok": false,
				"error": {
					"code": -32022,
					"message": "Failed to create parent directory",
					"suggestion": "Check path permissions"
				}
			}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": {
				"code": -32023,
				"message": "Failed to open file for write: %s" % path,
				"suggestion": "Check file path and permissions"
			}
		}

	file.store_string(content)
	file.close()
	return { "ok": true }

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

func _find_node(path: String) -> Node:
	if path.is_empty():
		return null

	if path == "/root" and get_tree().root != null:
		return get_tree().root

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		return null

	var node := root.get_node_or_null(path)
	if node != null:
		return node

	node = get_tree().root.get_node_or_null(path)
	if node != null:
		return node

	if path.begins_with("/"):
		node = get_node_or_null(path)
		if node != null:
			return node

	return null

func _log(message: String) -> void:
	_output_log.append(message)
	if _output_log.size() > 200:
		_output_log.remove_at(0)
	print("[MCP Bridge] %s" % message)
