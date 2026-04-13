@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Input simulation commands: keyboard, mouse, action, sequence.


func get_handlers() -> Dictionary:
	return {
		"simulate_key": Callable(self, "_cmd_simulate_key"),
		"simulate_mouse_click": Callable(self, "_cmd_simulate_mouse_click"),
		"simulate_mouse_move": Callable(self, "_cmd_simulate_mouse_move"),
		"simulate_action": Callable(self, "_cmd_simulate_action"),
		"simulate_sequence": Callable(self, "_cmd_simulate_sequence"),
		"get_input_actions": Callable(self, "_cmd_get_input_actions"),
		"set_input_action": Callable(self, "_cmd_set_input_action"),
	}


func _cmd_simulate_key(p: Dictionary) -> Dictionary:
	var key_str := String(p.get("key", ""))
	if key_str.is_empty():
		return _error(-32602, "Missing key", "Pass key like 'A', 'Space', 'Enter'")
	var pressed := bool(p.get("pressed", true))
	var ev := InputEventKey.new()
	ev.keycode = _key_from_string(key_str)
	ev.pressed = pressed
	ev.shift_pressed = bool(p.get("shift", false))
	ev.ctrl_pressed = bool(p.get("ctrl", false))
	ev.alt_pressed = bool(p.get("alt", false))
	ev.meta_pressed = bool(p.get("meta", false))
	Input.parse_input_event(ev)
	# If no explicit released, auto-release after press
	if pressed and bool(p.get("autoRelease", true)):
		var ev_up := ev.duplicate()
		ev_up.pressed = false
		var tree := _tree()
		if tree:
			await tree.create_timer(float(p.get("duration", 0.05))).timeout
		Input.parse_input_event(ev_up)
	return {"ok": true, "key": key_str, "pressed": pressed}


func _cmd_simulate_mouse_click(p: Dictionary) -> Dictionary:
	var x := float(p.get("x", 0))
	var y := float(p.get("y", 0))
	var button := int(p.get("button", MOUSE_BUTTON_LEFT))
	var double := bool(p.get("double", false))
	var ev := InputEventMouseButton.new()
	ev.position = Vector2(x, y)
	ev.global_position = Vector2(x, y)
	ev.button_index = button
	ev.pressed = true
	ev.double_click = double
	Input.parse_input_event(ev)
	var tree := _tree()
	if tree:
		await tree.create_timer(0.05).timeout
	var ev_up := ev.duplicate()
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	return {"ok": true, "x": x, "y": y, "button": button}


func _cmd_simulate_mouse_move(p: Dictionary) -> Dictionary:
	var x := float(p.get("x", 0))
	var y := float(p.get("y", 0))
	var relative_x := float(p.get("relativeX", 0))
	var relative_y := float(p.get("relativeY", 0))
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(x, y)
	ev.global_position = Vector2(x, y)
	ev.relative = Vector2(relative_x, relative_y)
	Input.parse_input_event(ev)
	return {"ok": true, "x": x, "y": y}


func _cmd_simulate_action(p: Dictionary) -> Dictionary:
	var action_name := String(p.get("action", ""))
	if action_name.is_empty():
		return _error(-32602, "Missing action", "Pass action like 'ui_accept', 'jump'")
	var pressed := bool(p.get("pressed", true))
	var strength := float(p.get("strength", 1.0))
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)
	if pressed and bool(p.get("autoRelease", true)):
		var tree := _tree()
		if tree:
			await tree.create_timer(float(p.get("duration", 0.1))).timeout
		var ev_up := ev.duplicate()
		ev_up.pressed = false
		ev_up.strength = 0.0
		Input.parse_input_event(ev_up)
	return {"ok": true, "action": action_name, "pressed": pressed}


func _cmd_simulate_sequence(p: Dictionary) -> Dictionary:
	var steps: Array = p.get("steps", [])
	if steps.is_empty():
		return _error(-32602, "Missing steps", "Pass array of {type, ...} objects")
	var tree := _tree()
	var results: Array[Dictionary] = []
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_type := String(step.get("type", ""))
		var delay := float(step.get("delay", 0.0))
		if delay > 0 and tree:
			await tree.create_timer(delay).timeout
		match step_type:
			"key":
				results.append(_cmd_simulate_key(step))
			"click":
				results.append(_cmd_simulate_mouse_click(step))
			"move":
				results.append(_cmd_simulate_mouse_move(step))
			"action":
				results.append(_cmd_simulate_action(step))
			"wait":
				if tree:
					await tree.create_timer(float(step.get("duration", 0.5))).timeout
				results.append({"ok": true, "waited": float(step.get("duration", 0.5))})
	return {"ok": true, "steps": results.size()}


func _cmd_get_input_actions(_p: Dictionary) -> Dictionary:
	var actions: Array[Dictionary] = []
	for prop in ProjectSettings.get_property_list():
		var pname := String(prop.get("name", ""))
		if pname.begins_with("input/"):
			var action_name := pname.substr(6)
			var action_data = ProjectSettings.get_setting(pname)
			var events: Array[String] = []
			if typeof(action_data) == TYPE_DICTIONARY:
				var event_list: Array = action_data.get("events", [])
				for ev in event_list:
					events.append(str(ev))
			actions.append({"name": action_name, "events": events})
	return {"count": actions.size(), "actions": actions}


func _cmd_set_input_action(p: Dictionary) -> Dictionary:
	var action_name := String(p.get("action", ""))
	if action_name.is_empty():
		return _error(-32602, "Missing action", "Pass payload.action")
	var key := String(p.get("key", ""))
	var deadzone := float(p.get("deadzone", 0.5))
	var setting_key := "input/%s" % action_name
	var events: Array = []
	if not key.is_empty():
		var ev := InputEventKey.new()
		ev.keycode = _key_from_string(key)
		events.append(ev)
	ProjectSettings.set_setting(setting_key, {"deadzone": deadzone, "events": events})
	ProjectSettings.save()
	return {"action": action_name, "ok": true}


func _key_from_string(key_str: String) -> Key:
	var upper := key_str.to_upper().strip_edges()
	match upper:
		"A": return KEY_A
		"B": return KEY_B
		"C": return KEY_C
		"D": return KEY_D
		"E": return KEY_E
		"F": return KEY_F
		"G": return KEY_G
		"H": return KEY_H
		"I": return KEY_I
		"J": return KEY_J
		"K": return KEY_K
		"L": return KEY_L
		"M": return KEY_M
		"N": return KEY_N
		"O": return KEY_O
		"P": return KEY_P
		"Q": return KEY_Q
		"R": return KEY_R
		"S": return KEY_S
		"T": return KEY_T
		"U": return KEY_U
		"V": return KEY_V
		"W": return KEY_W
		"X": return KEY_X
		"Y": return KEY_Y
		"Z": return KEY_Z
		"0": return KEY_0
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"7": return KEY_7
		"8": return KEY_8
		"9": return KEY_9
		"SPACE", " ": return KEY_SPACE
		"ENTER", "RETURN": return KEY_ENTER
		"ESCAPE", "ESC": return KEY_ESCAPE
		"TAB": return KEY_TAB
		"BACKSPACE": return KEY_BACKSPACE
		"DELETE", "DEL": return KEY_DELETE
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"SHIFT": return KEY_SHIFT
		"CTRL", "CONTROL": return KEY_CTRL
		"ALT": return KEY_ALT
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
		"HOME": return KEY_HOME
		"END": return KEY_END
		"PAGEUP": return KEY_PAGEUP
		"PAGEDOWN": return KEY_PAGEDOWN
		"INSERT": return KEY_INSERT
		"MINUS": return KEY_MINUS
		"EQUAL": return KEY_EQUAL
		"COMMA": return KEY_COMMA
		"PERIOD": return KEY_PERIOD
		"SLASH": return KEY_SLASH
		"SEMICOLON": return KEY_SEMICOLON
		"APOSTROPHE": return KEY_APOSTROPHE
		"BRACKETLEFT": return KEY_BRACKETLEFT
		"BRACKETRIGHT": return KEY_BRACKETRIGHT
		"BACKSLASH": return KEY_BACKSLASH
	return KEY_NONE
