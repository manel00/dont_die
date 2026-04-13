@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Testing & QA commands: test scenarios, assertions, stress test, reports.

var _test_results: Array[Dictionary] = []


func get_handlers() -> Dictionary:
	return {
		"run_test_scenario": Callable(self, "_cmd_run_test_scenario"),
		"assert_node_state": Callable(self, "_cmd_assert_node_state"),
		"assert_screen_text": Callable(self, "_cmd_assert_screen_text"),
		"run_stress_test": Callable(self, "_cmd_run_stress_test"),
		"get_test_report": Callable(self, "_cmd_get_test_report"),
	}


func _cmd_run_test_scenario(p: Dictionary) -> Dictionary:
	var name := String(p.get("name", "Test"))
	var steps: Array = p.get("steps", [])
	if steps.is_empty():
		return _error(-32602, "Missing steps", "Pass [{action, ...}] steps")
	var tree := _tree()
	var results: Array[Dictionary] = []
	var passed := 0
	var failed := 0
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var action := String(step.get("action", ""))
		var result: Dictionary = {"action": action, "passed": false}
		match action:
			"assert":
				var node := _find_node(String(step.get("path", "")))
				if node == null:
					result["error"] = "Node not found"
				else:
					var prop := String(step.get("property", ""))
					var expected = _parse_value(step.get("expected"))
					var actual = node.get(StringName(prop))
					result["passed"] = str(actual) == str(expected)
					result["actual"] = _safe_value(actual)
					result["expected"] = _safe_value(expected)
			"wait":
				var duration := float(step.get("duration", 0.5))
				if tree:
					await tree.create_timer(duration).timeout
				result["passed"] = true
				result["waited"] = duration
			"input":
				var key := String(step.get("key", ""))
				if not key.is_empty():
					var ev := InputEventKey.new()
					ev.keycode = _key_from_string(key)
					ev.pressed = true
					Input.parse_input_event(ev)
					if tree:
						await tree.create_timer(0.05).timeout
					var ev_up := ev.duplicate()
					ev_up.pressed = false
					Input.parse_input_event(ev_up)
					result["passed"] = true
			"click":
				var ev := InputEventMouseButton.new()
				ev.position = Vector2(float(step.get("x", 0)), float(step.get("y", 0)))
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				Input.parse_input_event(ev)
				if tree:
					await tree.create_timer(0.05).timeout
				ev.pressed = false
				Input.parse_input_event(ev)
				result["passed"] = true
		if result["passed"]:
			passed += 1
		else:
			failed += 1
		results.append(result)
	var report := {"name": name, "total": results.size(), "passed": passed, "failed": failed, "results": results}
	_test_results.append(report)
	return report


func _cmd_assert_node_state(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var assertions: Array = p.get("assertions", [])
	if assertions.is_empty():
		# Single assertion mode
		var prop := String(p.get("property", ""))
		var expected = _parse_value(p.get("expected"))
		if prop.is_empty():
			return _error(-32602, "Missing property", "Pass property and expected")
		var actual = node.get(StringName(prop))
		var passed := str(actual) == str(expected)
		var result := {"path": String(node.get_path()), "property": prop, "expected": _safe_value(expected), "actual": _safe_value(actual), "passed": passed}
		_test_results.append({"name": "assert_%s_%s" % [node.name, prop], "total": 1, "passed": 1 if passed else 0, "failed": 0 if passed else 1, "results": [result]})
		return result
	# Multiple assertions
	var results: Array[Dictionary] = []
	var passed := 0
	for assertion in assertions:
		if typeof(assertion) != TYPE_DICTIONARY:
			continue
		var prop := String(assertion.get("property", ""))
		var expected = _parse_value(assertion.get("expected"))
		var actual = node.get(StringName(prop))
		var ok := str(actual) == str(expected)
		results.append({"property": prop, "expected": _safe_value(expected), "actual": _safe_value(actual), "passed": ok})
		if ok:
			passed += 1
	return {"path": String(node.get_path()), "total": results.size(), "passed": passed, "failed": results.size() - passed, "results": results}


func _cmd_assert_screen_text(p: Dictionary) -> Dictionary:
	var text := String(p.get("text", ""))
	if text.is_empty():
		return _error(-32602, "Missing text", "Pass text to search for on screen")
	var root := _edited_root()
	if root == null:
		return _error(-32010, "No scene", "Open a scene")
	var found := false
	var found_in: Array[Dictionary] = []
	_find_text_in_ui(root, text, found_in)
	found = not found_in.is_empty()
	var result := {"text": text, "found": found, "locations": found_in}
	_test_results.append({"name": "assert_text_%s" % text.left(20), "total": 1, "passed": 1 if found else 0, "failed": 0 if found else 1, "results": [result]})
	return result


func _find_text_in_ui(node: Node, text: String, output: Array[Dictionary]) -> void:
	if node is Label and (node as Label).text.contains(text):
		output.append({"path": String(node.get_path()), "type": "Label", "full_text": (node as Label).text})
	elif node is Button and (node as Button).text.contains(text):
		output.append({"path": String(node.get_path()), "type": "Button", "full_text": (node as Button).text})
	elif node is LineEdit and (node as LineEdit).text.contains(text):
		output.append({"path": String(node.get_path()), "type": "LineEdit", "full_text": (node as LineEdit).text})
	elif node is RichTextLabel and (node as RichTextLabel).get_parsed_text().contains(text):
		output.append({"path": String(node.get_path()), "type": "RichTextLabel"})
	for child in node.get_children():
		_find_text_in_ui(child, text, output)


func _cmd_run_stress_test(p: Dictionary) -> Dictionary:
	var duration := float(p.get("duration", 5.0))
	var actions_per_second := int(p.get("actionsPerSecond", 10))
	var tree := _tree()
	if tree == null:
		return _error(-32010, "No scene tree", "Run a scene first")
	var total_actions := 0
	var elapsed := 0.0
	var interval := 1.0 / float(actions_per_second)
	var errors: Array[String] = []
	while elapsed < duration:
		# Random input
		var rand_type := randi() % 3
		match rand_type:
			0: # Random key
				var ev := InputEventKey.new()
				ev.keycode = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_A, KEY_D, KEY_W, KEY_S].pick_random()
				ev.pressed = true
				Input.parse_input_event(ev)
				await tree.create_timer(0.03).timeout
				ev.pressed = false
				Input.parse_input_event(ev)
			1: # Random click
				var viewport_size := tree.root.get_viewport().get_visible_rect().size
				var ev := InputEventMouseButton.new()
				ev.position = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				Input.parse_input_event(ev)
				await tree.create_timer(0.03).timeout
				ev.pressed = false
				Input.parse_input_event(ev)
			2: # Random mouse move
				var ev := InputEventMouseMotion.new()
				ev.relative = Vector2(randf_range(-50, 50), randf_range(-50, 50))
				Input.parse_input_event(ev)
		total_actions += 1
		await tree.create_timer(interval).timeout
		elapsed += interval
	var report := {"duration": duration, "total_actions": total_actions, "errors": errors, "ok": true}
	_test_results.append({"name": "stress_test", "total": total_actions, "passed": total_actions, "failed": 0, "results": [report]})
	return report


func _cmd_get_test_report(_p: Dictionary) -> Dictionary:
	var total := 0
	var passed := 0
	var failed := 0
	for report in _test_results:
		total += int(report.get("total", 0))
		passed += int(report.get("passed", 0))
		failed += int(report.get("failed", 0))
	return {"total_tests": _test_results.size(), "total_assertions": total, "passed": passed, "failed": failed, "reports": _test_results}


func _key_from_string(key_str: String) -> Key:
	var upper := key_str.to_upper().strip_edges()
	match upper:
		"SPACE": return KEY_SPACE
		"ENTER": return KEY_ENTER
		"ESCAPE": return KEY_ESCAPE
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"A": return KEY_A
		"B": return KEY_B
		"C": return KEY_C
		"D": return KEY_D
		"W": return KEY_W
		"S": return KEY_S
	return KEY_NONE
