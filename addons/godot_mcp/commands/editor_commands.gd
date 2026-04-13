@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Editor commands: screenshots, execute script, compare screenshots.


func get_handlers() -> Dictionary:
	return {
		"get_editor_screenshot": Callable(self, "_cmd_get_editor_screenshot"),
		"get_game_screenshot": Callable(self, "_cmd_get_game_screenshot"),
		"compare_screenshots": Callable(self, "_cmd_compare_screenshots"),
		"execute_editor_script": Callable(self, "_cmd_execute_editor_script"),
	}


func _cmd_get_editor_screenshot(p: Dictionary) -> Dictionary:
	if not editor_plugin:
		return _error(-32050, "Not in editor", "Run from editor")
	var ei := editor_plugin.get_editor_interface()
	var viewport := ei.get_editor_viewport_2d() if ei.has_method("get_editor_viewport_2d") else null
	# Capture the main viewport
	var img: Image
	var vp := ei.get_editor_main_screen()
	if vp and vp is Control:
		await _tree().process_frame
		img = vp.get_viewport().get_texture().get_image()
	else:
		img = _tree().root.get_viewport().get_texture().get_image()
	if img == null:
		return _error(-32051, "Failed to capture screenshot", "Try again after frame renders")
	var buffer := img.save_png_to_buffer()
	return {"ok": true, "width": img.get_width(), "height": img.get_height(), "base64": Marshalls.raw_to_base64(buffer)}


func _cmd_get_game_screenshot(p: Dictionary) -> Dictionary:
	var tree := _tree()
	if tree == null:
		return _error(-32010, "No scene tree", "Open a scene first")
	# Try to get the running game viewport
	var root := tree.root
	if root == null:
		return _error(-32010, "No root", "Run a scene first")
	await tree.process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		return _error(-32051, "Failed to capture game screenshot", "Ensure game is running")
	var buffer := img.save_png_to_buffer()
	return {"ok": true, "width": img.get_width(), "height": img.get_height(), "base64": Marshalls.raw_to_base64(buffer)}


func _cmd_compare_screenshots(p: Dictionary) -> Dictionary:
	var base64_a := String(p.get("imageA", ""))
	var base64_b := String(p.get("imageB", ""))
	if base64_a.is_empty() or base64_b.is_empty():
		return _error(-32602, "Missing imageA or imageB", "Pass base64 PNG data")
	var buf_a := Marshalls.base64_to_raw(base64_a)
	var buf_b := Marshalls.base64_to_raw(base64_b)
	var img_a := Image.new()
	var img_b := Image.new()
	img_a.load_png_from_buffer(buf_a)
	img_b.load_png_from_buffer(buf_b)
	if img_a.get_size() != img_b.get_size():
		return {"match": false, "reason": "Size mismatch", "sizeA": [img_a.get_width(), img_a.get_height()], "sizeB": [img_b.get_width(), img_b.get_height()]}
	var diff_count := 0
	var total := img_a.get_width() * img_a.get_height()
	var threshold := float(p.get("threshold", 0.05))
	for y in range(img_a.get_height()):
		for x in range(img_a.get_width()):
			var ca := img_a.get_pixel(x, y)
			var cb := img_b.get_pixel(x, y)
			if abs(ca.r - cb.r) > threshold or abs(ca.g - cb.g) > threshold or abs(ca.b - cb.b) > threshold:
				diff_count += 1
	var diff_pct := float(diff_count) / float(total) * 100.0
	return {"match": diff_count == 0, "diff_pixels": diff_count, "total_pixels": total, "diff_percent": snapped(diff_pct, 0.01)}


func _cmd_execute_editor_script(p: Dictionary) -> Dictionary:
	var code := String(p.get("code", ""))
	if code.is_empty():
		return _error(-32602, "Missing code", "Pass payload.code with GDScript to execute")
	var script := GDScript.new()
	script.source_code = "extends SceneTree\nfunc _run_mcp():\n"
	# Indent user code
	for line in code.split("\n"):
		script.source_code += "\t" + line + "\n"
	script.source_code += "\treturn null\n"
	var err := script.reload()
	if err != OK:
		return _error(-32052, "Script compilation failed", "Check GDScript syntax")
	var obj = script.new()
	if obj == null:
		return _error(-32052, "Failed to instantiate script", "Check code")
	var result = obj._run_mcp()
	return {"ok": true, "result": _safe_value(result)}
