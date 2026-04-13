@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Shader commands: create, assign, set/get params.


func get_handlers() -> Dictionary:
	return {
		"create_shader": Callable(self, "_cmd_create_shader"),
		"assign_shader_material": Callable(self, "_cmd_assign_shader_material"),
		"set_shader_param": Callable(self, "_cmd_set_shader_param"),
		"get_shader_params": Callable(self, "_cmd_get_shader_params"),
	}


func _cmd_create_shader(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	if path.is_empty():
		return _error(-32602, "Missing path", "Pass payload.path like res://shaders/effect.gdshader")
	var template := String(p.get("template", "canvas_item")).to_lower()
	var code := String(p.get("code", ""))
	if code.is_empty():
		match template:
			"canvas_item":
				code = """shader_type canvas_item;

uniform vec4 modulate_color : source_color = vec4(1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	COLOR = texture(TEXTURE, UV) * modulate_color;
	COLOR.a *= alpha;
}
"""
			"spatial":
				code = """shader_type spatial;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = albedo_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""
			"particles":
				code = """shader_type particles;

uniform float speed = 1.0;
uniform float spread = 0.5;

void start() {
	VELOCITY = vec3(sin(float(INDEX) * spread), 1.0, cos(float(INDEX) * spread)) * speed;
}

void process() {
	VELOCITY.y -= 9.8 * DELTA;
}
"""
			"sky":
				code = """shader_type sky;

uniform vec4 top_color : source_color = vec4(0.3, 0.5, 0.9, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.9, 0.9, 1.0, 1.0);

void sky() {
	COLOR = mix(bottom_color.rgb, top_color.rgb, clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0));
}
"""
			_:
				code = "shader_type canvas_item;\n\nvoid fragment() {\n\tCOLOR = texture(TEXTURE, UV);\n}\n"
	var write := _write_text(path, code)
	if write.has("__error"):
		return write
	return {"path": path, "template": template, "ok": true}


func _cmd_assign_shader_material(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var shader_path := String(p.get("shaderPath", ""))
	if shader_path.is_empty():
		return _error(-32602, "Missing shaderPath", "Pass path to .gdshader file")
	var shader: Shader = load(shader_path)
	if shader == null:
		return _error(-32011, "Shader not found: %s" % shader_path, "Verify file path")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Apply initial uniforms
	var uniforms := p.get("uniforms", {})
	if typeof(uniforms) == TYPE_DICTIONARY:
		for key in uniforms.keys():
			mat.set_shader_parameter(StringName(key), _parse_value(uniforms[key]))
	# Assign to node
	if node is CanvasItem and node.has_method("set"):
		node.set("material", mat)
	elif node is MeshInstance3D:
		(node as MeshInstance3D).set_surface_override_material(0, mat)
	else:
		node.set("material", mat)
	return {"path": String(node.get_path()), "shader": shader_path, "ok": true}


func _cmd_set_shader_param(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var param_name := String(p.get("param", p.get("name", "")))
	var value = _parse_value(p.get("value"))
	if param_name.is_empty():
		return _error(-32602, "Missing param", "Pass shader parameter name")
	var mat = node.get("material")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(StringName(param_name), value)
		return {"path": String(node.get_path()), "param": param_name, "ok": true}
	return _error(-32602, "No ShaderMaterial on node", "Assign shader material first")


func _cmd_get_shader_params(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var mat = node.get("material")
	if not (mat is ShaderMaterial):
		return _error(-32602, "No ShaderMaterial", "Assign shader first")
	var shader_mat := mat as ShaderMaterial
	var params := {}
	if shader_mat.shader:
		for param in shader_mat.shader.get_shader_uniform_list():
			var name := String(param.get("name", ""))
			if not name.is_empty():
				params[name] = _safe_value(shader_mat.get_shader_parameter(StringName(name)))
	return {"path": String(node.get_path()), "params": params}
