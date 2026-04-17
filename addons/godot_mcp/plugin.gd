@tool
extends EditorPlugin

var command_router: Node
var websocket_server: Node
var status_label: Label


func _enter_tree() -> void:
	command_router = preload("res://addons/godot_mcp/command_router.gd").new() as Node
	command_router.name = "MCPCommandRouter"
	command_router.editor_plugin = self
	add_child(command_router)

	websocket_server = preload("res://addons/godot_mcp/websocket_server.gd").new() as Node
	websocket_server.name = "MCPWebSocketServer"
	websocket_server.command_router = command_router
	add_child(websocket_server)
	websocket_server.start_server()

	status_label = Label.new()
	status_label.text = "Godot MCP Bridge: running"
	add_control_to_bottom_panel(status_label, "MCP Bridge")
	print("[MCP] Godot MCP Bridge plugin started")


func _exit_tree() -> void:
	if websocket_server != null:
		websocket_server.stop_server()

	if status_label != null:
		remove_control_from_bottom_panel(status_label)
		status_label.queue_free()
		status_label = null

	if websocket_server != null:
		websocket_server.queue_free()
		websocket_server = null

	if command_router != null:
		command_router.queue_free()
		command_router = null

	print("[MCP] Godot MCP Bridge plugin stopped")
