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
	# print("NetworkManager: Server disconnected")
	server_disconnected.emit()
