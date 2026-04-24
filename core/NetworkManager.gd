extends Node

const PORT: int = 8910
const MAX_PLAYERS: int = 4

signal connected_to_server
signal connection_failed
signal player_connected(id: int)
signal player_disconnected(id: int)
signal server_disconnected

## Dictionary of player info: { peer_id: { "name": String, "id": int } }
var players: Dictionary = {}

## Server discovery
var _discovery_socket: PacketPeerUDP
var _discovered_servers: Dictionary = {}
var _discovery_broadcast_port: int = 8911
var _discovery_response_socket: PacketPeerUDP

func _ready() -> void:
	# FIX: multiplayer is never null in Godot 4.x — remove impossible check
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# â”€â”€ Host â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func create_server() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: Failed to host on port %d (err=%d)" % [PORT, err])
		return err
	multiplayer.multiplayer_peer = peer
	# Register host as player 1 immediately
	players[1] = {"name": "Host", "id": 1}
	# Start discovery responder
	_start_discovery_responder()
	# print("NetworkManager: Server started on port ", PORT)
	return OK

# â”€â”€ Client â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func join_game(address: String = "127.0.0.1") -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		push_error("NetworkManager: Failed to create client for %s (err=%d)" % [address, err])
		return err
	multiplayer.multiplayer_peer = peer
	# print("NetworkManager: Connecting to %s:%d" % [address, PORT])
	return OK

# â”€â”€ Disconnect â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func leave_game() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	if _discovery_response_socket:
		_discovery_response_socket.close()
		_discovery_response_socket = null

# â”€â”€ Internal callbacks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func _on_peer_connected(id: int) -> void:
	# print("NetworkManager: Peer connected id=", id)
	players[id] = {"name": "Player_" + str(id), "id": id}
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	# print("NetworkManager: Peer disconnected id=", id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok() -> void:
	# Register ourselves with the server-assigned id
	var my_id := multiplayer.get_unique_id()
	players[my_id] = {"name": "Player_" + str(my_id), "id": my_id}
	# print("NetworkManager: Connected OK, our id=", my_id)
	connected_to_server.emit()

func _on_connected_fail() -> void:
	multiplayer.multiplayer_peer = null
	# print("NetworkManager: Connection failed")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	if _discovery_response_socket:
		_discovery_response_socket.close()
		_discovery_response_socket = null
	# print("NetworkManager: Server disconnected")
	server_disconnected.emit()

func _start_discovery_responder() -> void:
	_discovery_response_socket = PacketPeerUDP.new()
	_discovery_response_socket.set_broadcast_enabled(true)
	_discovery_response_socket.bind(PORT)
	_discovery_response_socket.set_dest_address("255.255.255.255", _discovery_broadcast_port)
	_dispatch_discovery_responses()

func _dispatch_discovery_responses() -> void:
	if not _discovery_response_socket:
		return
	while _discovery_response_socket.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _discovery_response_socket.get_packet()
		var sender_ip: String = _discovery_response_socket.get_packet_ip()
		if pkt.size() > 0:
			var request: String = pkt.get_string_from_utf8()
			if request == "DISCOVER_BIODEATH":
				_discovery_response_socket.set_dest_address(sender_ip, _discovery_broadcast_port)
				_discovery_response_socket.put_packet("BIODEATH_SERVER".to_utf8_buffer())
	get_tree().process_frame.connect(_dispatch_discovery_responses)

## Server Discovery — Broadcast to find servers on LAN
func discover_servers() -> void:
	_discovered_servers.clear()
	_discovery_socket = PacketPeerUDP.new()
	_discovery_socket.set_broadcast_enabled(true)
	_discovery_socket.bind(_discovery_broadcast_port)
	
	var local_ips: Array = IP.get_local_addresses()
	for ip: String in local_ips:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			var subnet_parts: PackedStringArray = ip.split(".")
			if subnet_parts.size() == 4:
				var broadcast_ip: String = subnet_parts[0] + "." + subnet_parts[1] + "." + subnet_parts[2] + ".255"
				_discovery_socket.set_dest_address(broadcast_ip, PORT)
				_discovery_socket.put_packet("DISCOVER_BIODEATH".to_utf8_buffer())
	
	# Listen for responses
	_start_discovery_listener()

func _start_discovery_listener() -> void:
	await get_tree().create_timer(2.0).timeout
	if _discovery_socket:
		while _discovery_socket.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _discovery_socket.get_packet()
			var sender_ip: String = _discovery_socket.get_packet_ip()
			if pkt.size() > 0:
				var response: String = pkt.get_string_from_utf8()
				if response == "BIODEATH_SERVER":
					_discovered_servers[sender_ip] = {"ip": sender_ip, "port": PORT}
		_discovery_socket.close()

func get_discovered_servers() -> Dictionary:
	return _discovered_servers
