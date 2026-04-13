@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## 3D Scene commands: mesh, lighting, camera, environment, gridmap, material.


func get_handlers() -> Dictionary:
	return {
		"add_mesh_instance": Callable(self, "_cmd_add_mesh_instance"),
		"setup_camera_3d": Callable(self, "_cmd_setup_camera_3d"),
		"setup_lighting": Callable(self, "_cmd_setup_lighting"),
		"setup_environment": Callable(self, "_cmd_setup_environment"),
		"add_gridmap": Callable(self, "_cmd_add_gridmap"),
		"set_material_3d": Callable(self, "_cmd_set_material_3d"),
	}


func _cmd_add_mesh_instance(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass valid parentPath")
	var mesh_type := String(p.get("meshType", "box")).to_lower()
	var node_name := String(p.get("name", "MeshInstance3D"))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	match mesh_type:
		"box": mi.mesh = BoxMesh.new()
		"sphere": mi.mesh = SphereMesh.new()
		"capsule": mi.mesh = CapsuleMesh.new()
		"cylinder": mi.mesh = CylinderMesh.new()
		"plane", "quad": mi.mesh = PlaneMesh.new()
		"prism": mi.mesh = PrismMesh.new()
		"torus": mi.mesh = TorusMesh.new()
		_:
			# Try to load as file (.glb, .gltf, .obj)
			if ResourceLoader.exists(mesh_type):
				var res = load(mesh_type)
				if res is Mesh:
					mi.mesh = res
				elif res is PackedScene:
					mi.free()
					var instance := (res as PackedScene).instantiate()
					instance.name = node_name
					_undo().add_child_node(parent, instance)
					return {"path": String(instance.get_path()), "type": "imported_scene", "ok": true}
			else:
				mi.mesh = BoxMesh.new()
	# Apply size/properties
	if mi.mesh is BoxMesh and p.has("size"):
		var s = _parse_value(p.size)
		if s is Vector3:
			(mi.mesh as BoxMesh).size = s
	elif mi.mesh is SphereMesh and p.has("radius"):
		(mi.mesh as SphereMesh).radius = float(p.radius)
	elif mi.mesh is CylinderMesh:
		if p.has("radius"):
			(mi.mesh as CylinderMesh).top_radius = float(p.radius)
			(mi.mesh as CylinderMesh).bottom_radius = float(p.radius)
		if p.has("height"):
			(mi.mesh as CylinderMesh).height = float(p.height)
	# Position
	if p.has("position"):
		var pos = _parse_value(p.position)
		if pos is Vector3:
			mi.position = pos
	if p.has("rotation"):
		var rot = _parse_value(p.rotation)
		if rot is Vector3:
			mi.rotation_degrees = rot
	_undo().add_child_node(parent, mi, "MCP: Add %s" % node_name)
	return {"path": String(mi.get_path()), "mesh": mesh_type, "ok": true}


func _cmd_setup_camera_3d(p: Dictionary) -> Dictionary:
	var path := String(p.get("path", ""))
	var node := _find_node(path)
	if node == null or not (node is Camera3D):
		# Create camera if not found
		if p.has("parentPath") or path.is_empty():
			var parent := _find_node(String(p.get("parentPath", "")))
			if parent == null:
				parent = _edited_root()
			if parent == null:
				return _error(-32602, "Parent not found", "Pass parentPath")
			var cam := Camera3D.new()
			cam.name = String(p.get("name", "Camera3D"))
			_undo().add_child_node(parent, cam)
			node = cam
		else:
			return _error(-32602, "Camera not found: %s" % path, "Pass valid path")
	var cam := node as Camera3D
	if p.has("fov"): cam.fov = float(p.fov)
	if p.has("near"): cam.near = float(p.near)
	if p.has("far"): cam.far = float(p.far)
	if p.has("current"): cam.current = bool(p.current)
	if p.has("position"):
		var pos = _parse_value(p.position)
		if pos is Vector3:
			cam.position = pos
	if p.has("rotation"):
		var rot = _parse_value(p.rotation)
		if rot is Vector3:
			cam.rotation_degrees = rot
	if p.has("projection"):
		match String(p.projection).to_lower():
			"perspective": cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			"orthogonal": cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	return {"path": String(cam.get_path()), "ok": true}


func _cmd_setup_lighting(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var preset := String(p.get("preset", "sun")).to_lower()
	var created: Array[String] = []
	match preset:
		"sun", "outdoor":
			var dl := DirectionalLight3D.new()
			dl.name = "SunLight"
			dl.rotation_degrees = Vector3(-45, -45, 0)
			dl.light_energy = float(p.get("energy", 1.0))
			dl.shadow_enabled = bool(p.get("shadows", true))
			if p.has("color"):
				dl.light_color = _parse_value(p.color)
			_undo().add_child_node(parent, dl)
			created.append(String(dl.get_path()))
		"indoor":
			var ol := OmniLight3D.new()
			ol.name = "IndoorLight"
			ol.light_energy = float(p.get("energy", 1.5))
			ol.omni_range = float(p.get("range", 10))
			ol.shadow_enabled = bool(p.get("shadows", true))
			if p.has("position"):
				ol.position = _parse_value(p.position)
			else:
				ol.position = Vector3(0, 3, 0)
			_undo().add_child_node(parent, ol)
			created.append(String(ol.get_path()))
		"dramatic":
			var dl := DirectionalLight3D.new()
			dl.name = "KeyLight"
			dl.rotation_degrees = Vector3(-30, -60, 0)
			dl.light_energy = 1.5
			dl.shadow_enabled = true
			_undo().add_child_node(parent, dl)
			created.append(String(dl.get_path()))
			var fill := OmniLight3D.new()
			fill.name = "FillLight"
			fill.light_energy = 0.3
			fill.position = Vector3(3, 2, 3)
			_undo().add_child_node(parent, fill)
			created.append(String(fill.get_path()))
		"spot":
			var sl := SpotLight3D.new()
			sl.name = "SpotLight"
			sl.light_energy = float(p.get("energy", 2.0))
			sl.spot_range = float(p.get("range", 10))
			sl.spot_angle = float(p.get("angle", 30))
			sl.shadow_enabled = bool(p.get("shadows", true))
			if p.has("position"):
				sl.position = _parse_value(p.position)
			_undo().add_child_node(parent, sl)
			created.append(String(sl.get_path()))
	return {"preset": preset, "created": created, "ok": true}


func _cmd_setup_environment(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var we := WorldEnvironment.new()
	we.name = String(p.get("name", "WorldEnvironment"))
	var env := Environment.new()
	# Background
	var bg := String(p.get("background", "sky")).to_lower()
	match bg:
		"sky":
			env.background_mode = Environment.BG_SKY
			var sky := Sky.new()
			var sky_mat := ProceduralSkyMaterial.new()
			if p.has("skyTopColor"):
				sky_mat.sky_top_color = _parse_value(p.skyTopColor)
			if p.has("skyHorizonColor"):
				sky_mat.sky_horizon_color = _parse_value(p.skyHorizonColor)
			sky.sky_material = sky_mat
			env.sky = sky
		"color":
			env.background_mode = Environment.BG_COLOR
			if p.has("bgColor"):
				env.background_color = _parse_value(p.bgColor)
		"clear_color":
			env.background_mode = Environment.BG_CLEAR_COLOR
	# Ambient light
	if p.has("ambientColor"):
		env.ambient_light_color = _parse_value(p.ambientColor)
	if p.has("ambientEnergy"):
		env.ambient_light_energy = float(p.ambientEnergy)
	# Fog
	if p.has("fog") and bool(p.fog):
		env.fog_enabled = true
		if p.has("fogDensity"):
			env.fog_density = float(p.fogDensity)
		if p.has("fogColor"):
			env.fog_light_color = _parse_value(p.fogColor)
	# Glow
	if p.has("glow") and bool(p.glow):
		env.glow_enabled = true
		if p.has("glowIntensity"):
			env.glow_intensity = float(p.glowIntensity)
	# SSAO
	if p.has("ssao") and bool(p.ssao):
		env.ssao_enabled = true
	# SSR
	if p.has("ssr") and bool(p.ssr):
		env.ssr_enabled = true
	# Tonemap
	if p.has("tonemap"):
		match String(p.tonemap).to_lower():
			"linear": env.tonemap_mode = Environment.TONE_MAP_LINEAR
			"reinhardt": env.tonemap_mode = Environment.TONE_MAP_REINHARDT
			"filmic": env.tonemap_mode = Environment.TONE_MAP_FILMIC
			"aces": env.tonemap_mode = Environment.TONE_MAP_ACES
	we.environment = env
	_undo().add_child_node(parent, we, "MCP: Setup Environment")
	return {"path": String(we.get_path()), "ok": true}


func _cmd_add_gridmap(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var gm := GridMap.new()
	gm.name = String(p.get("name", "GridMap"))
	if p.has("cellSize"):
		var cs = _parse_value(p.cellSize)
		if cs is Vector3:
			gm.cell_size = cs
	if p.has("meshLibrary"):
		var lib = load(String(p.meshLibrary))
		if lib is MeshLibrary:
			gm.mesh_library = lib
	_undo().add_child_node(parent, gm, "MCP: Add GridMap")
	return {"path": String(gm.get_path()), "ok": true}


func _cmd_set_material_3d(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null or not (node is MeshInstance3D):
		return _error(-32602, "MeshInstance3D not found", "Pass valid path")
	var mi := node as MeshInstance3D
	var mat := StandardMaterial3D.new()
	if p.has("albedoColor"):
		mat.albedo_color = _parse_value(p.albedoColor)
	if p.has("metallic"):
		mat.metallic = float(p.metallic)
	if p.has("roughness"):
		mat.roughness = float(p.roughness)
	if p.has("emission") and bool(p.emission):
		mat.emission_enabled = true
		if p.has("emissionColor"):
			mat.emission = _parse_value(p.emissionColor)
		if p.has("emissionEnergy"):
			mat.emission_energy_multiplier = float(p.emissionEnergy)
	if p.has("transparency"):
		match String(p.transparency).to_lower():
			"alpha": mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"alpha_scissor": mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			"disabled": mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	if p.has("albedoTexture"):
		var tex = load(String(p.albedoTexture))
		if tex is Texture2D:
			mat.albedo_texture = tex
	var surface_idx := int(p.get("surfaceIndex", 0))
	mi.set_surface_override_material(surface_idx, mat)
	return {"path": String(mi.get_path()), "surface": surface_idx, "ok": true}
