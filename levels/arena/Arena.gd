## Arena.gd
## Handles spawning of human players and bots in both Solo and LAN modes.
## "Solo mode" is detected when GameManager.solo_mode == true.

extends Node3D

var _player_scene: PackedScene = preload("res://entities/player/Player.tscn")
var _bot_scene: PackedScene = preload("res://entities/player/BotPlayer.tscn")

const BOT_COUNT_SOLO := 2  # Number of AI allies in solo mode

func _ready() -> void:
	if not multiplayer.is_server():
		return  # Clients wait for MultiplayerSpawner replication
	
	print("Arena: Server ready, starting spawn sequence...")
	call_deferred("_initial_spawn")
	
	# Watch for future remote joiners (LAN mode only)
	if NetworkManager and not GameManager.solo_mode:
		NetworkManager.player_connected.connect(_on_new_player_connected)
		NetworkManager.player_disconnected.connect(remove_player)

# ── Initial Spawn ────────────────────────────────────────────────
func _initial_spawn() -> void:
	if GameManager.solo_mode:
		_spawn_solo_mode()
	else:
		_spawn_lan_mode()

func _spawn_solo_mode() -> void:
	print("Arena: Spawning solo mode player + ", BOT_COUNT_SOLO, " bots")
	_spawn_player_at(1, _get_spawn_position(0))
	
	for i in range(BOT_COUNT_SOLO):
		_spawn_bot_at(i, _get_spawn_position(i + 1))

func _spawn_lan_mode() -> void:
	if not NetworkManager:
		return
	for i in range(NetworkManager.players.keys().size()):
		var id: int = NetworkManager.players.keys()[i]
		spawn_player(id)

# ── LAN spawning ─────────────────────────────────────────────────
func _on_new_player_connected(id: int) -> void:
	if id == 1:
		return  # Host already spawned in _initial_spawn
	spawn_player(id)

@onready var _players_node: Node = $Players

func spawn_player(id: int) -> void:
	if _players_node.get_node_or_null(str(id)):
		return
	var idx = NetworkManager.players.keys().find(id)
	print("Arena: Spawning player authority=", id)
	var p: Node = _player_scene.instantiate()
	p.name = str(id)
	p.position = _get_spawn_position(idx)
	_players_node.add_child(p, true)

func remove_player(id: int) -> void:
	var p: Node = _players_node.get_node_or_null(str(id))
	if p:
		p.queue_free()
		print("Arena: Removed player ", id)

# ── Solo-mode bot helpers ─────────────────────────────────────────
func _spawn_player_at(id: int, spawn_pos: Vector3) -> void:
	if _players_node.get_node_or_null(str(id)):
		return
	var p: Node = _player_scene.instantiate()
	p.name = str(id)
	p.position = spawn_pos
	_players_node.add_child(p)

func _spawn_bot_at(bot_index: int, spawn_pos: Vector3) -> void:
	var bot: Node = _bot_scene.instantiate()
	bot.name = "Bot_" + str(bot_index)
	bot.position = spawn_pos
	_players_node.add_child(bot)

# ── Utilities ─────────────────────────────────────────────────────
func _get_spawn_position(index: int) -> Vector3:
	var spawn_markers := get_tree().get_nodes_in_group("player_spawns")
	if spawn_markers.size() > 0:
		var marker_index: int = index % spawn_markers.size()
		return (spawn_markers[marker_index] as Node3D).global_position
	
	var offsets: Array[Vector3] = [
		Vector3(0, 1, 0),
		Vector3(2, 1, 2),
		Vector3(-2, 1, -2),
		Vector3(2, 1, -2)
	]
	return offsets[index % offsets.size()]
