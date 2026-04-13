@tool
extends "res://addons/godot_mcp/commands/base_commands.gd"
## AnimationTree, State Machine, and Blend Tree commands.


func get_handlers() -> Dictionary:
	return {
		"create_animation_tree": Callable(self, "_cmd_create_animation_tree"),
		"get_animation_tree_structure": Callable(self, "_cmd_get_animation_tree_structure"),
		"set_tree_parameter": Callable(self, "_cmd_set_tree_parameter"),
		"add_state_machine_state": Callable(self, "_cmd_add_state_machine_state"),
		"remove_state_machine_state": Callable(self, "_cmd_remove_state_machine_state"),
		"add_state_machine_transition": Callable(self, "_cmd_add_state_machine_transition"),
		"remove_state_machine_transition": Callable(self, "_cmd_remove_state_machine_transition"),
		"set_blend_tree_node": Callable(self, "_cmd_set_blend_tree_node"),
	}


func _get_anim_tree(p: Dictionary) -> AnimationTree:
	var path := String(p.get("treePath", p.get("path", "")))
	if path.is_empty():
		return null
	var node := _find_node(path)
	if node is AnimationTree:
		return node as AnimationTree
	return null


func _cmd_create_animation_tree(p: Dictionary) -> Dictionary:
	var parent_path := String(p.get("parentPath", ""))
	var parent := _find_node(parent_path) if not parent_path.is_empty() else _edited_root()
	if parent == null:
		return _error(-32602, "Parent not found", "Pass valid parentPath")
	var tree_name := String(p.get("name", "AnimationTree"))
	var anim_tree := AnimationTree.new()
	anim_tree.name = tree_name
	# Create root state machine
	var root_type := String(p.get("rootType", "StateMachine")).to_lower()
	match root_type:
		"statemachine", "state_machine":
			var sm := AnimationNodeStateMachine.new()
			anim_tree.tree_root = sm
		"blendtree", "blend_tree":
			var bt := AnimationNodeBlendTree.new()
			anim_tree.tree_root = bt
		_:
			var sm := AnimationNodeStateMachine.new()
			anim_tree.tree_root = sm
	# Link to AnimationPlayer if specified
	var player_path := String(p.get("animPlayerPath", ""))
	if not player_path.is_empty():
		anim_tree.anim_player = NodePath(player_path)
	_undo().add_child_node(parent, anim_tree, "MCP: Create AnimationTree")
	return {"path": String(anim_tree.get_path()), "rootType": root_type, "ok": true}


func _cmd_get_animation_tree_structure(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var root := anim_tree.tree_root
	if root == null:
		return {"path": String(anim_tree.get_path()), "root": null}
	var structure := _describe_anim_node(root, "")
	return {"path": String(anim_tree.get_path()), "structure": structure}


func _describe_anim_node(node: AnimationRootNode, prefix: String) -> Dictionary:
	var info: Dictionary = {"type": node.get_class()}
	if node is AnimationNodeStateMachine:
		var sm := node as AnimationNodeStateMachine
		var states: Array[Dictionary] = []
		# Get node list from state machine
		for i in range(sm.get_node_count()) if sm.has_method("get_node_count") else []:
			pass
		info["node_type"] = "StateMachine"
	elif node is AnimationNodeBlendTree:
		info["node_type"] = "BlendTree"
	elif node is AnimationNodeAnimation:
		info["node_type"] = "Animation"
		info["animation"] = (node as AnimationNodeAnimation).animation
	return info


func _cmd_set_tree_parameter(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var param := String(p.get("parameter", ""))
	var value = _parse_value(p.get("value"))
	if param.is_empty():
		return _error(-32602, "Missing parameter", "e.g. 'parameters/conditions/is_running'")
	anim_tree.set(param, value)
	return {"parameter": param, "value": _safe_value(value), "ok": true}


func _cmd_add_state_machine_state(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var root := anim_tree.tree_root
	if not (root is AnimationNodeStateMachine):
		return _error(-32602, "Root is not StateMachine", "Create tree with StateMachine root")
	var sm := root as AnimationNodeStateMachine
	var state_name := String(p.get("state", p.get("name", "")))
	if state_name.is_empty():
		return _error(-32602, "Missing state name", "Pass payload.state")
	var node_type := String(p.get("nodeType", "Animation")).to_lower()
	var anim_node: AnimationRootNode
	match node_type:
		"animation":
			var an := AnimationNodeAnimation.new()
			an.animation = StringName(String(p.get("animation", state_name)))
			anim_node = an
		"statemachine", "state_machine":
			anim_node = AnimationNodeStateMachine.new()
		"blendtree", "blend_tree":
			anim_node = AnimationNodeBlendTree.new()
		_:
			var an := AnimationNodeAnimation.new()
			an.animation = StringName(state_name)
			anim_node = an
	var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	sm.add_node(state_name, anim_node, pos)
	return {"state": state_name, "type": node_type, "ok": true}


func _cmd_remove_state_machine_state(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var root := anim_tree.tree_root
	if not (root is AnimationNodeStateMachine):
		return _error(-32602, "Root is not StateMachine", "Use StateMachine root")
	var sm := root as AnimationNodeStateMachine
	var state_name := String(p.get("state", p.get("name", "")))
	if state_name.is_empty():
		return _error(-32602, "Missing state", "Pass payload.state")
	if not sm.has_node(state_name):
		return _error(-32011, "State not found: %s" % state_name, "Check state name")
	sm.remove_node(state_name)
	return {"state": state_name, "ok": true}


func _cmd_add_state_machine_transition(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var root := anim_tree.tree_root
	if not (root is AnimationNodeStateMachine):
		return _error(-32602, "Root is not StateMachine", "Use StateMachine root")
	var sm := root as AnimationNodeStateMachine
	var from_state := String(p.get("from", ""))
	var to_state := String(p.get("to", ""))
	if from_state.is_empty() or to_state.is_empty():
		return _error(-32602, "Missing from/to", "Pass from and to state names")
	var transition := AnimationNodeStateMachineTransition.new()
	var switch_mode := String(p.get("switchMode", "immediate")).to_lower()
	match switch_mode:
		"immediate": transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		"sync": transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
		"at_end": transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	if p.has("advanceCondition"):
		transition.advance_condition = StringName(String(p.advanceCondition))
	if p.has("autoAdvance"):
		transition.auto_advance = bool(p.autoAdvance)
	sm.add_transition(from_state, to_state, transition)
	return {"from": from_state, "to": to_state, "ok": true}


func _cmd_remove_state_machine_transition(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var root := anim_tree.tree_root
	if not (root is AnimationNodeStateMachine):
		return _error(-32602, "Root is not StateMachine", "Use StateMachine root")
	var sm := root as AnimationNodeStateMachine
	var from_state := String(p.get("from", ""))
	var to_state := String(p.get("to", ""))
	if from_state.is_empty() or to_state.is_empty():
		return _error(-32602, "Missing from/to", "Pass from and to state names")
	sm.remove_transition(from_state, to_state)
	return {"from": from_state, "to": to_state, "ok": true}


func _cmd_set_blend_tree_node(p: Dictionary) -> Dictionary:
	var anim_tree := _get_anim_tree(p)
	if anim_tree == null:
		return _error(-32602, "AnimationTree not found", "Pass valid treePath")
	var root := anim_tree.tree_root
	if not (root is AnimationNodeBlendTree):
		return _error(-32602, "Root is not BlendTree", "Create tree with BlendTree root")
	var bt := root as AnimationNodeBlendTree
	var node_name := String(p.get("name", ""))
	var node_type := String(p.get("type", "Animation")).to_lower()
	if node_name.is_empty():
		return _error(-32602, "Missing name", "Pass node name")
	var anim_node: AnimationNode
	match node_type:
		"animation":
			var an := AnimationNodeAnimation.new()
			if p.has("animation"):
				an.animation = StringName(String(p.animation))
			anim_node = an
		"add2":
			anim_node = AnimationNodeAdd2.new()
		"blend2":
			anim_node = AnimationNodeBlend2.new()
		"timescale", "time_scale":
			anim_node = AnimationNodeTimeScale.new()
		"oneshot", "one_shot":
			anim_node = AnimationNodeOneShot.new()
		"transition":
			anim_node = AnimationNodeTransition.new()
		_:
			var an := AnimationNodeAnimation.new()
			anim_node = an
	var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	bt.add_node(node_name, anim_node, pos)
	return {"name": node_name, "type": node_type, "ok": true}
