extends Node

## GameManager (Autoload)
## Gestiona el estado global del juego (Puntos, Player, Game Over)

signal score_changed(new_score)
signal game_over

var current_score: int = 0
var is_game_over: bool = false
var player: Node = null
var solo_mode: bool = false  # true = single player + bots, false = LAN
var enemy_mode: String = "skeletons"  # "skeletons" | "mechas"
var selected_map_path: String = "res://levels/arena/Arena.tscn"

const MAP_ARENA = "res://levels/arena/Arena.tscn"
const MAP_SAGRERA = "res://levels/arena/LaSagrera.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if is_game_over and Input.is_action_just_pressed("ui_accept"): # Enter key
		restart_game()

func add_score(amount: int) -> void:
	if is_game_over: return
	
	current_score += amount
	score_changed.emit(current_score)
	# print("Puntos: ", current_score)

func register_player(player_node: Node) -> void:
	player = player_node
	player.add_to_group("player")

func trigger_game_over() -> void:
	if is_game_over: return
	
	is_game_over = true
	game_over.emit()
	# print("GAME OVER! PuntuaciÃ³n final: ", current_score)
	
	# Pausar el juego (pero permitir que el GameManager procese el input de reinicio)
	get_tree().paused = true

func restart_game() -> void:
	get_tree().paused = false
	is_game_over = false
	current_score = 0
	player = null
	# FIX: multiplayer restart — sync all peers, not just local client
	if solo_mode:
		get_tree().change_scene_to_file("res://ui/menu/MainMenu.tscn")
	else:
		# In multiplayer, notify all peers then reload for everyone
		rpc("sync_restart")
		get_tree().reload_current_scene()

@rpc("any_peer", "call_local")
func sync_restart() -> void:
	# Called on all peers — reset local state per client
	is_game_over = false
	current_score = 0
	player = null
	get_tree().paused = false
	# Recargar escena en todos los clientes
	get_tree().reload_current_scene()
