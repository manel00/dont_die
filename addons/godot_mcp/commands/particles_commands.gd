@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Particle commands: GPU particles, presets, material, color gradient.


func get_handlers() -> Dictionary:
	return {
		"create_particles": Callable(self, "_cmd_create_particles"),
		"set_particle_material": Callable(self, "_cmd_set_particle_material"),
		"set_particle_color_gradient": Callable(self, "_cmd_set_particle_color_gradient"),
		"apply_particle_preset": Callable(self, "_cmd_apply_particle_preset"),
		"get_particle_info": Callable(self, "_cmd_get_particle_info"),
	}


func _cmd_create_particles(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var is_3d := bool(p.get("is3D", parent is Node3D))
	var node_name := String(p.get("name", "GPUParticles"))
	var particles: Node
	if is_3d:
		var gp := GPUParticles3D.new()
		gp.name = node_name
		gp.amount = int(p.get("amount", 16))
		gp.lifetime = float(p.get("lifetime", 1.0))
		gp.emitting = bool(p.get("emitting", true))
		gp.one_shot = bool(p.get("oneShot", false))
		var mat := ParticleProcessMaterial.new()
		gp.process_material = mat
		particles = gp
	else:
		var gp := GPUParticles2D.new()
		gp.name = node_name
		gp.amount = int(p.get("amount", 16))
		gp.lifetime = float(p.get("lifetime", 1.0))
		gp.emitting = bool(p.get("emitting", true))
		gp.one_shot = bool(p.get("oneShot", false))
		var mat := ParticleProcessMaterial.new()
		gp.process_material = mat
		particles = gp
	_undo().add_child_node(parent, particles, "MCP: Create %s" % node_name)
	# Apply preset if specified
	if p.has("preset"):
		_apply_preset(particles, String(p.preset))
	return {"path": String(particles.get_path()), "ok": true}


func _cmd_set_particle_material(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Particles not found", "Pass valid path")
	var mat: ParticleProcessMaterial
	if node is GPUParticles3D:
		mat = (node as GPUParticles3D).process_material as ParticleProcessMaterial
		if mat == null:
			mat = ParticleProcessMaterial.new()
			(node as GPUParticles3D).process_material = mat
	elif node is GPUParticles2D:
		mat = (node as GPUParticles2D).process_material as ParticleProcessMaterial
		if mat == null:
			mat = ParticleProcessMaterial.new()
			(node as GPUParticles2D).process_material = mat
	else:
		return _error(-32602, "Not a GPU particles node", "Use GPUParticles2D/3D")
	if p.has("direction"):
		var d = _parse_value(p.direction)
		if d is Vector3:
			mat.direction = d
	if p.has("spread"): mat.spread = float(p.spread)
	if p.has("gravity"):
		var g = _parse_value(p.gravity)
		if g is Vector3:
			mat.gravity = g
	if p.has("initialVelocityMin"): mat.initial_velocity_min = float(p.initialVelocityMin)
	if p.has("initialVelocityMax"): mat.initial_velocity_max = float(p.initialVelocityMax)
	if p.has("angularVelocityMin"): mat.angular_velocity_min = float(p.angularVelocityMin)
	if p.has("angularVelocityMax"): mat.angular_velocity_max = float(p.angularVelocityMax)
	if p.has("scaleMin"): mat.scale_min = float(p.scaleMin)
	if p.has("scaleMax"): mat.scale_max = float(p.scaleMax)
	if p.has("emissionShape"):
		match String(p.emissionShape).to_lower():
			"point": mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			"sphere": mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			"box": mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			"ring": mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	if p.has("emissionBoxExtents"):
		var e = _parse_value(p.emissionBoxExtents)
		if e is Vector3:
			mat.emission_box_extents = e
	if p.has("emissionSphereRadius"):
		mat.emission_sphere_radius = float(p.emissionSphereRadius)
	return {"path": String(node.get_path()), "ok": true}


func _cmd_set_particle_color_gradient(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Particles not found", "Pass valid path")
	var mat: ParticleProcessMaterial
	if node is GPUParticles3D:
		mat = (node as GPUParticles3D).process_material as ParticleProcessMaterial
	elif node is GPUParticles2D:
		mat = (node as GPUParticles2D).process_material as ParticleProcessMaterial
	if mat == null:
		return _error(-32602, "No process material", "Set particle material first")
	var gradient := Gradient.new()
	var stops: Array = p.get("stops", [])
	if stops.is_empty():
		return _error(-32602, "Missing stops", "Pass [{offset, color}]")
	var offsets: PackedFloat32Array = []
	var colors: PackedColorArray = []
	for stop in stops:
		if typeof(stop) != TYPE_DICTIONARY:
			continue
		offsets.append(float(stop.get("offset", 0)))
		colors.append(_parse_value(stop.get("color", "#ffffff")))
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	mat.color_ramp = tex
	return {"path": String(node.get_path()), "stops": stops.size(), "ok": true}


func _cmd_apply_particle_preset(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Particles not found", "Pass valid path")
	var preset := String(p.get("preset", "fire")).to_lower()
	_apply_preset(node, preset)
	return {"path": String(node.get_path()), "preset": preset, "ok": true}


func _apply_preset(node: Node, preset: String) -> void:
	var mat: ParticleProcessMaterial
	if node is GPUParticles3D:
		mat = (node as GPUParticles3D).process_material as ParticleProcessMaterial
		if mat == null:
			mat = ParticleProcessMaterial.new()
			(node as GPUParticles3D).process_material = mat
	elif node is GPUParticles2D:
		mat = (node as GPUParticles2D).process_material as ParticleProcessMaterial
		if mat == null:
			mat = ParticleProcessMaterial.new()
			(node as GPUParticles2D).process_material = mat
	if mat == null:
		return
	match preset:
		"fire":
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 15.0
			mat.gravity = Vector3(0, 0, 0)
			mat.initial_velocity_min = 1.0
			mat.initial_velocity_max = 3.0
			mat.scale_min = 0.5
			mat.scale_max = 1.5
			_set_gradient(mat, [
				{offset = 0.0, color = Color(1.0, 0.8, 0.0)},
				{offset = 0.5, color = Color(1.0, 0.3, 0.0)},
				{offset = 1.0, color = Color(0.2, 0.0, 0.0, 0.0)}
			])
		"smoke":
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 30.0
			mat.gravity = Vector3(0, -0.5, 0)
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 1.5
			mat.scale_min = 1.0
			mat.scale_max = 3.0
			_set_gradient(mat, [
				{offset = 0.0, color = Color(0.5, 0.5, 0.5, 0.8)},
				{offset = 1.0, color = Color(0.3, 0.3, 0.3, 0.0)}
			])
		"rain":
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 5.0
			mat.gravity = Vector3(0, -9.8, 0)
			mat.initial_velocity_min = 10.0
			mat.initial_velocity_max = 15.0
			mat.scale_min = 0.1
			mat.scale_max = 0.3
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(10, 0, 10)
		"snow":
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 20.0
			mat.gravity = Vector3(0, -1, 0)
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 2.0
			mat.scale_min = 0.1
			mat.scale_max = 0.4
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(10, 0, 10)
		"sparks":
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 90.0
			mat.gravity = Vector3(0, -5, 0)
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 8.0
			mat.scale_min = 0.05
			mat.scale_max = 0.15
			_set_gradient(mat, [
				{offset = 0.0, color = Color(1.0, 1.0, 0.5)},
				{offset = 0.5, color = Color(1.0, 0.5, 0.0)},
				{offset = 1.0, color = Color(0.5, 0.0, 0.0, 0.0)}
			])
	if node is GPUParticles3D:
		(node as GPUParticles3D).amount = 32
	elif node is GPUParticles2D:
		(node as GPUParticles2D).amount = 32


func _set_gradient(mat: ParticleProcessMaterial, stops: Array) -> void:
	var grad := Gradient.new()
	var offsets: PackedFloat32Array = []
	var colors: PackedColorArray = []
	for s in stops:
		offsets.append(float(s.get("offset", 0)))
		colors.append(s.get("color", Color.WHITE))
	grad.offsets = offsets
	grad.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex


func _cmd_get_particle_info(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Particles not found", "Pass valid path")
	var info := {"path": String(node.get_path()), "type": node.get_class()}
	if node is GPUParticles3D:
		var gp := node as GPUParticles3D
		info["amount"] = gp.amount
		info["lifetime"] = gp.lifetime
		info["emitting"] = gp.emitting
		info["one_shot"] = gp.one_shot
		if gp.process_material is ParticleProcessMaterial:
			var mat := gp.process_material as ParticleProcessMaterial
			info["direction"] = [mat.direction.x, mat.direction.y, mat.direction.z]
			info["spread"] = mat.spread
			info["gravity"] = [mat.gravity.x, mat.gravity.y, mat.gravity.z]
	elif node is GPUParticles2D:
		var gp := node as GPUParticles2D
		info["amount"] = gp.amount
		info["lifetime"] = gp.lifetime
		info["emitting"] = gp.emitting
		info["one_shot"] = gp.one_shot
		if gp.process_material is ParticleProcessMaterial:
			var mat := gp.process_material as ParticleProcessMaterial
			info["direction"] = [mat.direction.x, mat.direction.y, mat.direction.z]
			info["spread"] = mat.spread
	return info
