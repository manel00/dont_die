@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## Physics commands: body setup, collision, raycast, layers.


func get_handlers() -> Dictionary:
	return {
		"setup_physics_body": Callable(self, "_cmd_setup_physics_body"),
		"setup_collision": Callable(self, "_cmd_setup_collision"),
		"set_physics_layers": Callable(self, "_cmd_set_physics_layers"),
		"get_physics_layers": Callable(self, "_cmd_get_physics_layers"),
		"get_collision_info": Callable(self, "_cmd_get_collision_info"),
		"add_raycast": Callable(self, "_cmd_add_raycast"),
	}


func _cmd_setup_physics_body(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path to a physics body")
	if node is CharacterBody2D:
		var cb := node as CharacterBody2D
		if p.has("speed"): cb.set_meta("speed", float(p.speed))
		if p.has("floorMaxAngle"): cb.floor_max_angle = deg_to_rad(float(p.floorMaxAngle))
		if p.has("upDirection"):
			var ud = _parse_value(p.upDirection)
			if ud is Vector2:
				cb.up_direction = ud
	elif node is CharacterBody3D:
		var cb := node as CharacterBody3D
		if p.has("floorMaxAngle"): cb.floor_max_angle = deg_to_rad(float(p.floorMaxAngle))
		if p.has("upDirection"):
			var ud = _parse_value(p.upDirection)
			if ud is Vector3:
				cb.up_direction = ud
	elif node is RigidBody2D:
		var rb := node as RigidBody2D
		if p.has("mass"): rb.mass = float(p.mass)
		if p.has("gravity_scale"): rb.gravity_scale = float(p.gravity_scale)
		if p.has("linearDamp"): rb.linear_damp = float(p.linearDamp)
		if p.has("angularDamp"): rb.angular_damp = float(p.angularDamp)
		if p.has("freeze"): rb.freeze = bool(p.freeze)
	elif node is RigidBody3D:
		var rb := node as RigidBody3D
		if p.has("mass"): rb.mass = float(p.mass)
		if p.has("gravity_scale"): rb.gravity_scale = float(p.gravity_scale)
		if p.has("linearDamp"): rb.linear_damp = float(p.linearDamp)
		if p.has("angularDamp"): rb.angular_damp = float(p.angularDamp)
		if p.has("freeze"): rb.freeze = bool(p.freeze)
	elif node is StaticBody2D or node is StaticBody3D:
		pass # No special config needed
	else:
		return _error(-32602, "Not a physics body", "Target must be CharacterBody/RigidBody/StaticBody")
	return {"path": String(node.get_path()), "type": node.get_class(), "ok": true}


func _cmd_setup_collision(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass path to a physics body or area")
	var shape_type := String(p.get("shapeType", "auto")).to_lower()
	# Auto-detect 2D/3D
	var is_3d := node is Node3D
	var collision_node: Node
	if is_3d:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var shape: Shape3D
		match shape_type:
			"box": shape = BoxShape3D.new()
			"sphere": shape = SphereShape3D.new()
			"capsule": shape = CapsuleShape3D.new()
			"cylinder": shape = CylinderShape3D.new()
			"convex": shape = ConvexPolygonShape3D.new()
			"concave": shape = ConcavePolygonShape3D.new()
			_: shape = BoxShape3D.new() # default
		if p.has("size") and shape is BoxShape3D:
			var s = _parse_value(p.size)
			if s is Vector3:
				(shape as BoxShape3D).size = s
		if p.has("radius"):
			if shape is SphereShape3D:
				(shape as SphereShape3D).radius = float(p.radius)
			elif shape is CapsuleShape3D:
				(shape as CapsuleShape3D).radius = float(p.radius)
		if p.has("height") and shape is CapsuleShape3D:
			(shape as CapsuleShape3D).height = float(p.height)
		cs.shape = shape
		collision_node = cs
	else:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var shape: Shape2D
		match shape_type:
			"rectangle", "rect", "box": shape = RectangleShape2D.new()
			"circle", "sphere": shape = CircleShape2D.new()
			"capsule": shape = CapsuleShape2D.new()
			"segment": shape = SegmentShape2D.new()
			_: shape = RectangleShape2D.new()
		if p.has("size") and shape is RectangleShape2D:
			var s = _parse_value(p.size)
			if s is Vector2:
				(shape as RectangleShape2D).size = s
		if p.has("radius") and shape is CircleShape2D:
			(shape as CircleShape2D).radius = float(p.radius)
		cs.shape = shape
		collision_node = cs
	_undo().add_child_node(node, collision_node, "MCP: Add collision to %s" % node.name)
	return {"parent": String(node.get_path()), "collision": String(collision_node.get_path()), "ok": true}


func _cmd_set_physics_layers(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	if p.has("collisionLayer"):
		var layer := int(p.collisionLayer)
		node.set("collision_layer", layer)
	if p.has("collisionMask"):
		var mask := int(p.collisionMask)
		node.set("collision_mask", mask)
	return {"path": String(node.get_path()), "ok": true}


func _cmd_get_physics_layers(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	return {
		"path": String(node.get_path()),
		"collision_layer": node.get("collision_layer"),
		"collision_mask": node.get("collision_mask")
	}


func _cmd_get_collision_info(p: Dictionary) -> Dictionary:
	var node := _find_node(String(p.get("path", "")))
	if node == null:
		return _error(-32602, "Node not found", "Pass valid path")
	var shapes: Array[Dictionary] = []
	for child in node.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			shapes.append({
				"name": child.name,
				"path": String(child.get_path()),
				"type": "2D",
				"shape": cs.shape.get_class() if cs.shape else "none",
				"disabled": cs.disabled
			})
		elif child is CollisionShape3D:
			var cs := child as CollisionShape3D
			shapes.append({
				"name": child.name,
				"path": String(child.get_path()),
				"type": "3D",
				"shape": cs.shape.get_class() if cs.shape else "none",
				"disabled": cs.disabled
			})
	return {"path": String(node.get_path()), "collision_layer": node.get("collision_layer"), "collision_mask": node.get("collision_mask"), "shapes": shapes}


func _cmd_add_raycast(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", p.get("path", "")))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass parentPath")
	var is_3d := parent is Node3D
	var raycast: Node
	if is_3d:
		var rc := RayCast3D.new()
		rc.name = String(p.get("name", "RayCast3D"))
		rc.enabled = bool(p.get("enabled", true))
		if p.has("targetPosition"):
			var tp = _parse_value(p.targetPosition)
			if tp is Vector3:
				rc.target_position = tp
		else:
			rc.target_position = Vector3(0, -1, 0)
		if p.has("collisionMask"):
			rc.collision_mask = int(p.collisionMask)
		raycast = rc
	else:
		var rc := RayCast2D.new()
		rc.name = String(p.get("name", "RayCast2D"))
		rc.enabled = bool(p.get("enabled", true))
		if p.has("targetPosition"):
			var tp = _parse_value(p.targetPosition)
			if tp is Vector2:
				rc.target_position = tp
		else:
			rc.target_position = Vector2(0, 50)
		if p.has("collisionMask"):
			rc.collision_mask = int(p.collisionMask)
		raycast = rc
	_undo().add_child_node(parent, raycast, "MCP: Add RayCast")
	return {"path": String(raycast.get_path()), "ok": true}
