@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Navigation commands: region, agent, bake, layers, pathfinding.


func get_handlers() -> Dictionary:
	return {
		"setup_navigation_region": Callable(self, "_cmd_setup_navigation_region"),
		"setup_navigation_agent": Callable(self, "_cmd_setup_navigation_agent"),
		"bake_navigation_mesh": Callable(self, "_cmd_bake_navigation_mesh"),
		"set_navigation_layers": Callable(self, "_cmd_set_navigation_layers"),
		"get_navigation_info": Callable(self, "_cmd_get_navigation_info"),
		"get_navigation_path": Callable(self, "_cmd_get_navigation_path"),
	}


func _cmd_setup_navigation_region(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var is_3d := bool(p.get("is3D", parent is Node3D))
	var region: Node
	if is_3d:
		var nr := NavigationRegion3D.new()
		nr.name = String(p.get("name", "NavigationRegion3D"))
		var mesh := NavigationMesh.new()
		if p.has("agentRadius"):
			mesh.agent_radius = float(p.agentRadius)
		if p.has("agentHeight"):
			mesh.agent_height = float(p.agentHeight)
		if p.has("cellSize"):
			mesh.cell_size = float(p.cellSize)
		nr.navigation_mesh = mesh
		if p.has("navigationLayers"):
			nr.navigation_layers = int(p.navigationLayers)
		region = nr
	else:
		var nr := NavigationRegion2D.new()
		nr.name = String(p.get("name", "NavigationRegion2D"))
		var poly := NavigationPolygon.new()
		nr.navigation_polygon = poly
		if p.has("navigationLayers"):
			nr.navigation_layers = int(p.navigationLayers)
		region = nr
	_undo().add_child_node(parent, region, "MCP: Add NavigationRegion")
	return {"path": String(region.get_path()), "is3D": is_3d, "ok": true}


func _cmd_setup_navigation_agent(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var is_3d := bool(p.get("is3D", parent is Node3D))
	var agent: Node
	if is_3d:
		var na := NavigationAgent3D.new()
		na.name = String(p.get("name", "NavigationAgent3D"))
		if p.has("radius"): na.radius = float(p.radius)
		if p.has("targetDesiredDistance"): na.target_desired_distance = float(p.targetDesiredDistance)
		if p.has("pathDesiredDistance"): na.path_desired_distance = float(p.pathDesiredDistance)
		if p.has("maxSpeed"): na.max_speed = float(p.maxSpeed)
		if p.has("avoidanceEnabled"): na.avoidance_enabled = bool(p.avoidanceEnabled)
		agent = na
	else:
		var na := NavigationAgent2D.new()
		na.name = String(p.get("name", "NavigationAgent2D"))
		if p.has("radius"): na.radius = float(p.radius)
		if p.has("targetDesiredDistance"): na.target_desired_distance = float(p.targetDesiredDistance)
		if p.has("pathDesiredDistance"): na.path_desired_distance = float(p.pathDesiredDistance)
		if p.has("maxSpeed"): na.max_speed = float(p.maxSpeed)
		if p.has("avoidanceEnabled"): na.avoidance_enabled = bool(p.avoidanceEnabled)
		agent = na
	_undo().add_child_node(parent, agent, "MCP: Add NavigationAgent")
	return {"path": String(agent.get_path()), "ok": true}


func _cmd_bake_navigation_mesh(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "NavigationRegion not found", "Pass valid path")
	if node is NavigationRegion3D:
		(node as NavigationRegion3D).bake_navigation_mesh()
		return {"path": String(node.get_path()), "ok": true}
	elif node is NavigationRegion2D:
		(node as NavigationRegion2D).bake_navigation_polygon()
		return {"path": String(node.get_path()), "ok": true}
	return _error(-32602, "Not a NavigationRegion", "Target must be NavigationRegion2D/3D")


func _cmd_set_navigation_layers(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	if p.has("navigationLayers"):
		node.set("navigation_layers", int(p.navigationLayers))
	return {"path": String(node.get_path()), "ok": true}


func _cmd_get_navigation_info(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass path to a NavigationRegion or NavigationAgent")
	var info := {"path": String(node.get_path()), "type": node.get_class()}
	if node is NavigationRegion3D:
		var nr := node as NavigationRegion3D
		info["navigation_layers"] = nr.navigation_layers
		info["has_mesh"] = nr.navigation_mesh != null
		if nr.navigation_mesh:
			info["agent_radius"] = nr.navigation_mesh.agent_radius
			info["agent_height"] = nr.navigation_mesh.agent_height
			info["cell_size"] = nr.navigation_mesh.cell_size
	elif node is NavigationRegion2D:
		var nr := node as NavigationRegion2D
		info["navigation_layers"] = nr.navigation_layers
		info["has_polygon"] = nr.navigation_polygon != null
	elif node is NavigationAgent3D:
		var na := node as NavigationAgent3D
		info["radius"] = na.radius
		info["max_speed"] = na.max_speed
		info["avoidance_enabled"] = na.avoidance_enabled
		info["is_navigation_finished"] = na.is_navigation_finished()
	elif node is NavigationAgent2D:
		var na := node as NavigationAgent2D
		info["radius"] = na.radius
		info["max_speed"] = na.max_speed
		info["avoidance_enabled"] = na.avoidance_enabled
		info["is_navigation_finished"] = na.is_navigation_finished()
	return info


func _cmd_get_navigation_path(p: Dictionary) -> Dictionary:
	var from_pos = _parse_value(p.get("from", "Vector3(0,0,0)"))
	var to_pos = _parse_value(p.get("to", "Vector3(0,0,0)"))
	var is_3d := bool(p.get("is3D", true))
	if is_3d:
		if not (from_pos is Vector3):
			from_pos = Vector3.ZERO
		if not (to_pos is Vector3):
			to_pos = Vector3.ZERO
		var map := NavigationServer3D.get_maps()[0] if NavigationServer3D.get_maps().size() > 0 else RID()
		if not map.is_valid():
			return _error(-32010, "No navigation map", "Set up NavigationRegion3D first")
		var path := NavigationServer3D.map_get_path(map, from_pos as Vector3, to_pos as Vector3, true)
		var points: Array[Dictionary] = []
		for pt in path:
			points.append({"x": pt.x, "y": pt.y, "z": pt.z})
		return {"from": [from_pos.x, from_pos.y, from_pos.z], "to": [to_pos.x, to_pos.y, to_pos.z], "points": points}
	else:
		if not (from_pos is Vector2):
			from_pos = Vector2.ZERO
		if not (to_pos is Vector2):
			to_pos = Vector2.ZERO
		var map := NavigationServer2D.get_maps()[0] if NavigationServer2D.get_maps().size() > 0 else RID()
		if not map.is_valid():
			return _error(-32010, "No navigation map", "Set up NavigationRegion2D first")
		var path := NavigationServer2D.map_get_path(map, from_pos as Vector2, to_pos as Vector2, true)
		var points: Array[Dictionary] = []
		for pt in path:
			points.append({"x": pt.x, "y": pt.y})
		return {"from": [from_pos.x, from_pos.y], "to": [to_pos.x, to_pos.y], "points": points}
