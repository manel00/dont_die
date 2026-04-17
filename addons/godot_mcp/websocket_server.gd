@tool
extends Node

@export var start_port: int = 6505
@export var max_port: int = 6509

var command_router: Node

var _tcp_server := TCPServer.new()
var _clients: Array[WebSocketPeer] = []
var _active_port: int = -1
var _running: bool = false


func _process(_delta: float) -> void:
	if not _running:
		return
	_accept_new_clients()
	_poll_clients()


func start_server() -> Dictionary:
	if _running:
		return {"ok": true, "port": _active_port, "already_running": true}

	for port in range(start_port, max_port + 1):
		var err := _tcp_server.listen(port)
		if err == OK:
			_active_port = port
			_running = true
			print("[MCP] WebSocket server listening on ws://127.0.0.1:%d" % port)
			return {"ok": true, "port": port}

	push_error("[MCP] Failed to bind WebSocket server on ports %d-%d" % [start_port, max_port])
	return {
		"ok": false,
		"error": "No free port",
		"port_range": "%d-%d" % [start_port, max_port]
	}


func stop_server() -> void:
	_running = false
	for i in range(_clients.size() - 1, -1, -1):
		var client := _clients[i]
		if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
			client.close()
		_clients.remove_at(i)

	if _active_port != -1:
		print("[MCP] WebSocket server stopped on port %d" % _active_port)
	_active_port = -1
	_tcp_server.stop()


func _accept_new_clients() -> void:
	while _tcp_server.is_connection_available():
		var connection := _tcp_server.take_connection()
		var peer := WebSocketPeer.new()
		var err := peer.accept_stream(connection)
		if err == OK:
			_clients.append(peer)
			print("[MCP] Client connected")
		else:
			print("[MCP] Failed to accept websocket stream")


func _poll_clients() -> void:
	for i in range(_clients.size() - 1, -1, -1):
		var client := _clients[i]
		client.poll()
		var state := client.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			while client.get_available_packet_count() > 0:
				var text := client.get_packet().get_string_from_utf8()
				_handle_request(client, text)
		elif state == WebSocketPeer.STATE_CLOSED:
			_clients.remove_at(i)
			print("[MCP] Client disconnected")


func _handle_request(client: WebSocketPeer, raw_text: String) -> void:
	var parsed := JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var id: Variant = parsed.get("id", null)
	var command := String(parsed.get("method", parsed.get("command", "")))
	var payload: Variant = parsed.get("params", parsed.get("payload", {}))
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}

	if command.is_empty():
		_send_error(client, id, -32600, "Missing method/command", "Send a valid MCP tool name")
		return

	if command_router == null:
		_send_error(client, id, -32050, "Command router unavailable", "Re-enable plugin")
		return

	var execution: Dictionary = command_router.execute(command, payload)
	if execution.has("error"):
		var err_obj: Dictionary = execution.error
		_send_error(
			client,
			id,
			int(err_obj.get("code", -32000)),
			String(err_obj.get("message", "Command failed")),
			String(err_obj.get("suggestion", ""))
		)
		return

	_send_result(client, id, execution.get("result", {}))


func _send_result(client: WebSocketPeer, id: Variant, result: Variant) -> void:
	var response := {
		"jsonrpc": "2.0",
		"id": id,
		"result": result
	}
	client.send_text(JSON.stringify(response))


func _send_error(client: WebSocketPeer, id: Variant, code: int, message: String, suggestion: String) -> void:
	var response := {
		"jsonrpc": "2.0",
		"id": id,
		"error": {
			"code": code,
			"message": message,
			"data": {
				"suggestion": suggestion
			}
		}
	}
	client.send_text(JSON.stringify(response))
