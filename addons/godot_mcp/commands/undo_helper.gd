@tool
extends RefCounted
## UndoRedo helper — wraps Godot's UndoRedo system for all mutations.
## Every node/property change goes through undo so users can Ctrl+Z AI actions.

var editor_plugin: EditorPlugin


func get_undo_redo() -> EditorUndoRedoManager:
	if editor_plugin == null:
		return null
	return editor_plugin.get_undo_redo()


func set_property(node: Node, prop: StringName, value: Variant, action_name: String = "") -> bool:
	var undo_redo := get_undo_redo()
	if undo_redo == null:
		node.set(prop, value)
		return true

	var old_value = node.get(prop)
	if action_name.is_empty():
		action_name = "MCP: Set %s.%s" % [node.name, prop]

	undo_redo.create_action(action_name)
	undo_redo.add_do_property(node, prop, value)
	undo_redo.add_undo_property(node, prop, old_value)
	undo_redo.commit_action()
	return true


func add_child_node(parent: Node, child: Node, action_name: String = "") -> bool:
	var undo_redo := get_undo_redo()
	if undo_redo == null:
		parent.add_child(child)
		child.owner = _get_scene_owner(parent)
		return true

	if action_name.is_empty():
		action_name = "MCP: Add %s to %s" % [child.name, parent.name]

	var owner := _get_scene_owner(parent)
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", child)
	undo_redo.add_do_method(child, "set_owner", owner)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(parent, "remove_child", child)
	undo_redo.commit_action()
	return true


func remove_node(node: Node, action_name: String = "") -> bool:
	var undo_redo := get_undo_redo()
	var parent := node.get_parent()
	if undo_redo == null or parent == null:
		node.queue_free()
		return true

	if action_name.is_empty():
		action_name = "MCP: Remove %s" % node.name

	var idx := node.get_index()
	var owner := node.owner

	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(parent, "move_child", node, idx)
	undo_redo.add_undo_method(node, "set_owner", owner)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()
	return true


func rename_node(node: Node, new_name: String, action_name: String = "") -> bool:
	var undo_redo := get_undo_redo()
	if undo_redo == null:
		node.name = new_name
		return true

	var old_name := node.name

	if action_name.is_empty():
		action_name = "MCP: Rename %s to %s" % [old_name, new_name]

	undo_redo.create_action(action_name)
	undo_redo.add_do_property(node, "name", new_name)
	undo_redo.add_undo_property(node, "name", old_name)
	undo_redo.commit_action()
	return true


func reparent_node(node: Node, new_parent: Node, action_name: String = "") -> bool:
	var undo_redo := get_undo_redo()
	var old_parent := node.get_parent()
	if undo_redo == null or old_parent == null:
		if old_parent:
			old_parent.remove_child(node)
		new_parent.add_child(node)
		node.owner = _get_scene_owner(new_parent)
		return true

	var old_idx := node.get_index()
	var old_owner := node.owner
	var new_owner := _get_scene_owner(new_parent)

	if action_name.is_empty():
		action_name = "MCP: Move %s to %s" % [node.name, new_parent.name]

	undo_redo.create_action(action_name)
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", new_owner)
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node)
	undo_redo.add_undo_method(old_parent, "move_child", node, old_idx)
	undo_redo.add_undo_method(node, "set_owner", old_owner)
	undo_redo.commit_action()
	return true


func _get_scene_owner(node: Node) -> Node:
	if node.owner != null:
		return node.owner
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.edited_scene_root:
		return tree.edited_scene_root
	return node
