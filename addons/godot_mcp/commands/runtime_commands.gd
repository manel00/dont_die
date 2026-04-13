@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Runtime analysis commands: live game inspection, capture, recording, UI.

var _recordings: Dictionary = {} # name -> Array[InputEvent]
var _current_recording_name: String = ""
var _current_recording: Array = []
var _is_recording: bool = false


func get_handlers() -> Dictionary:
	return {
		"execute_game_script": Callable(self, "_cmd_execute_game_script"),
		"capture_frames": Callable(self, "_cmd_capture_frames"),
		"monitor_properties": Callable(self, "_cmd_monitor_properties"),
		"start_recording": Callable(self, "_cmd_start_recording"),
		"stop_recording": Callable(self, "_cmd_stop_recording"),
		"replay_recording": Callable(self, "_cmd_replay_recording"),
		"find_nodes_by_script": Callable(self, "_cmd_find_nodes_by_script"),
		"get_autoload": Callable(self, "_cmd_get_autoload"),
		"batch_get_properties": Callable(self, "_cmd_batch_get_properties"),
		"find_ui_elements": Callable(self, "_cmd_find_ui_elements"),
		"click_button_by_text": Callable(self, "_cmd_click_button_by_text"),
		"wait_for_node": Callable(self, "_cmd_wait_for_node"),
		"find_nearby_nodes": Callable(self, "_cmd_find_nearby_nodes"),
		"navigate_to": Callable(self, "_cmd_navigate_to"),
		"move_to": Callable(self, "_cmd_move_to"),
	}


func _cmd_execute_game_script(p: Dictionary) -> Dictionary:
	var code := String(p.get("code", ""))
	if code.is_empty():
		return _error(-32602, "Missing code", "Pass GDScript code")
	var node_path := String(p.get("nodePath", ""))
	var target: Node = null
	if not node_path.is_empty():
		target = _find_node(node_path)
	if target == null:
		target = _edited_root()
	if target == null:
		return _error(-32010, "No target node", "Run a scene first")
	# Build a temporary script
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _mcp_exec():\n"
	for line in code.split("\n"):
		script.source_code += "\t" + line + "\n"
	script.source_code += "\treturn null\n"
	var err := script.reload()
	if err != OK:
		return _error(-32052, "Script compile failed", "Check syntax")
	var temp := Node.new()
	temp.set_script(script)
	target.add_child(temp)
	var result = temp.call("_mcp_exec")
	temp.queue_free()
	return {"ok": true, "result": _safe_value(result)}


func _cmd_capture_frames(p: Dictionary) -> Dictionary:
	var count := int(p.get("count", 3))
	var interval := float(p.get("interval", 0.5))
	var tree := _tree()
	if tree == null:
		return _error(-32010, "No scene tree", "Run a scene first")
	var frames: Array[Dictionary] = []
	for i in range(count):
		if i > 0:
			await tree.create_timer(interval).timeout
		await tree.process_frame
		var img := tree.root.get_viewport().get_texture().get_image()
		if img:
			var buf := img.save_png_to_buffer()
			frames.append({"frame": i, "width": img.get_width(), "height": img.get_height(), "base64": Marshalls.raw_to_base64(buf)})
	return {"ok": true, "count": frames.size(), "frames": frames}


func _cmd_monitor_properties(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var props: Array = p.get("properties", [])
	if props.is_empty():
		return _error(-32602, "Missing properties", "Pass array of property names")
	var duration := float(p.get("duration", 2.0))
	var interval := float(p.get("interval", 0.5))
	var tree := _tree()
	var samples: Array[Dictionary] = []
	var elapsed := 0.0
	while elapsed < duration:
		var sample := {"time": snapped(elapsed, 0.01)}
		for prop in props:
			var pname := String(prop)
			sample[pname] = _safe_value(node.get(StringName(pname)))
		samples.append(sample)
		if tree:
			await tree.create_timer(interval).timeout
		elapsed += interval
	return {"path": String(node.get_path()), "samples": samples}


func _cmd_start_recording(p: Dictionary) -> Dictionary:
	_current_recording_name = String(p.get("name", "default"))
	_current_recording = []
	_is_recording = true
	return {"ok": true, "name": _current_recording_name}


func _cmd_stop_recording(_p: Dictionary) -> Dictionary:
	_is_recording = false
	_recordings[_current_recording_name] = _current_recording.duplicate()
	var count := _current_recording.size()
	_current_recording = []
	return {"ok": true, "name": _current_recording_name, "events": count}


func _cmd_replay_recording(p: Dictionary) -> Dictionary:
	var name := String(p.get("name", "default"))
	if not _recordings.has(name):
		return _error(-32011, "Recording not found: %s" % name, "Use start_recording/stop_recording first")
	var events: Array = _recordings[name]
	var tree := _tree()
	for ev in events:
		if ev is InputEvent:
			Input.parse_input_event(ev)
			if tree:
				await tree.create_timer(0.016).timeout
	return {"ok": true, "name": name, "events": events.size()}


func _cmd_find_nodes_by_script(p: Dictionary) -> Dictionary:
	var script_path := String(p.get("scriptPath", ""))
	if script_path.is_empty():
		return _error(-32602, "Missing scriptPath", "Pass payload.scriptPath")
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var matches: Array[Dictionary] = []
	_find_by_script_recursive(root, script_path, matches)
	return {"scriptPath": script_path, "count": matches.size(), "nodes": matches}


func _find_by_script_recursive(node: Node, script_path: String, output: Array[Dictionary]) -> void:
	if node.get_script() is Script:
		var s: Script = node.get_script()
		if s.resource_path == script_path:
			output.append({"name": node.name, "path": String(node.get_path()), "type": node.get_class()})
	for child in node.get_children():
		_find_by_script_recursive(child, script_path, output)


func _cmd_get_autoload(p: Dictionary) -> Dictionary:
	var name := String(p.get("name", ""))
	if name.is_empty():
		# List all autoloads
		var autoloads: Array[Dictionary] = []
		for prop in ProjectSettings.get_property_list():
			var pname := String(prop.get("name", ""))
			if pname.begins_with("autoload/"):
				var al_name := pname.get_slice("/", 1)
				autoloads.append({"name": al_name, "path": String(ProjectSettings.get_setting(pname))})
		return {"count": autoloads.size(), "autoloads": autoloads}
	var setting := "autoload/%s" % name
	if not ProjectSettings.has_setting(setting):
		return _error(-32011, "Autoload not found: %s" % name, "Check project autoloads")
	return {"name": name, "path": String(ProjectSettings.get_setting(setting))}


func _cmd_batch_get_properties(p: Dictionary) -> Dictionary:
	var queries: Array = p.get("queries", [])
	if queries.is_empty():
		return _error(-32602, "Missing queries", "Pass [{path, properties: []}]")
	var results: Array[Dictionary] = []
	for q in queries:
		if typeof(q) != TYPE_DICTIONARY:
			continue
		var node := _find_node(String(q.get("path", "")))
		if node == null:
			results.append({"path": String(q.get("path", "")), "error": "Node not found"})
			continue
		var props: Array = q.get("properties", [])
		var values := {}
		for prop in props:
			values[String(prop)] = _safe_value(node.get(StringName(String(prop))))
		results.append({"path": String(node.get_path()), "values": values})
	return {"count": results.size(), "results": results}


func _cmd_find_ui_elements(p: Dictionary) -> Dictionary:
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var ui_types := ["Button", "Label", "TextEdit", "LineEdit", "CheckBox", "CheckButton", "OptionButton", "SpinBox", "HSlider", "VSlider", "ProgressBar", "TextureRect", "Panel", "TabContainer", "ItemList", "Tree"]
	var elements: Array[Dictionary] = []
	_find_ui_recursive(root, ui_types, elements)
	return {"count": elements.size(), "elements": elements}


func _find_ui_recursive(node: Node, types: Array, output: Array[Dictionary]) -> void:
	for t in types:
		if node.is_class(t):
			var info := {"name": node.name, "path": String(node.get_path()), "type": node.get_class()}
			if node is BaseButton and node.has_method("get_text"):
				info["text"] = node.text
			elif node is Label:
				info["text"] = (node as Label).text
			elif node is LineEdit:
				info["text"] = (node as LineEdit).text
			output.append(info)
			break
	for child in node.get_children():
		_find_ui_recursive(child, types, output)


func _cmd_click_button_by_text(p: Dictionary) -> Dictionary:
	var text := String(p.get("text", ""))
	if text.is_empty():
		return _error(-32602, "Missing text", "Pass button text to click")
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var btn := _find_button_by_text(root, text)
	if btn == null:
		return _error(-32011, "Button not found: %s" % text, "Check button text")
	btn.emit_signal("pressed")
	return {"ok": true, "path": String(btn.get_path()), "text": text}


func _find_button_by_text(node: Node, text: String) -> BaseButton:
	if node is BaseButton and node.has_method("get_text"):
		if node.text == text or node.text.contains(text):
			return node as BaseButton
	for child in node.get_children():
		var result := _find_button_by_text(child, text)
		if result:
			return result
	return null


func _cmd_wait_for_node(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass node path to wait for")
	var timeout := float(p.get("timeout", 5.0))
	var interval := float(p.get("interval", 0.25))
	var tree := _tree()
	var elapsed := 0.0
	while elapsed < timeout:
		var node := _find_node(path)
		if node != null:
			return {"ok": true, "found": true, "path": String(node.get_path()), "elapsed": snapped(elapsed, 0.01)}
		if tree:
			await tree.create_timer(interval).timeout
		elapsed += interval
	return {"ok": true, "found": false, "timeout": timeout}


func _cmd_find_nearby_nodes(p: Dictionary) -> Dictionary:
	var pos_x := float(p.get("x", 0))
	var pos_y := float(p.get("y", 0))
	var radius := float(p.get("radius", 200))
	var pos := Vector2(pos_x, pos_y)
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var nearby: Array[Dictionary] = []
	_find_nearby_recursive(root, pos, radius, nearby)
	return {"position": [pos_x, pos_y], "radius": radius, "count": nearby.size(), "nodes": nearby}


func _find_nearby_recursive(node: Node, pos: Vector2, radius: float, output: Array[Dictionary]) -> void:
	if node is Node2D:
		var dist := (node as Node2D).global_position.distance_to(pos)
		if dist <= radius:
			output.append({"name": node.name, "path": String(node.get_path()), "type": node.get_class(), "distance": snapped(dist, 0.1)})
	for child in node.get_children():
		_find_nearby_recursive(child, pos, radius, output)


func _cmd_navigate_to(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var target_x := float(p.get("x", 0))
	var target_y := float(p.get("y", 0))
	if node is Node2D:
		(node as Node2D).global_position = Vector2(target_x, target_y)
	elif node is Node3D:
		var z := float(p.get("z", 0))
		(node as Node3D).global_position = Vector3(target_x, target_y, z)
	return {"ok": true, "path": String(node.get_path()), "position": [target_x, target_y]}


func _cmd_move_to(p: Dictionary) -> Dictionary:
	return _cmd_navigate_to(p)
