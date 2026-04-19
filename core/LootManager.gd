extends Node

## LootManager (Autoload)
## Spawnea armas cerca del jugador para que siempre haya disponibles.

const DROP_CHANCE = 0.5

var loot_item_scene = preload("res://entities/interactables/LootItem.tscn")
var weapon_pickup_scene = preload("res://entities/interactables/StylooWeaponPickup.tscn")

# Armas disponibles
const WEAPON_TYPES = [
	"bayonet", "coolknife", "doubleAxe", "katana", "kunai", "longsword",
	"normalsword", "pickaxe", "shuriken1", "shuriken2", "shuriken3", "shuriken4",
	"simpleAxe", "sword1"
]

func _ready() -> void:
	if multiplayer.is_server():
		# Esperar 1 segundo para que el jugador esté listo, luego spawnear armas iniciales
		var init_timer = get_tree().create_timer(1.0)
		init_timer.timeout.connect(_spawn_initial_weapons_near_player)
		
		# Timer periódico - cada 10 segundos spawnea armas cerca del jugador
		var timer = Timer.new()
		timer.wait_time = 10.0
		timer.timeout.connect(_on_weapon_spawn_timer)
		add_child(timer)
		timer.start()

func _spawn_initial_weapons_near_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		# Si no hay jugador, reintentar en 2 segundos
		var retry_timer = get_tree().create_timer(2.0)
		retry_timer.timeout.connect(_spawn_initial_weapons_near_player)
		return
	
	var player = players[0] # Primer jugador
	var player_pos = player.global_position
	
	# Spawnear 8 armas alrededor del jugador, muy cerca (3-8 unidades)
	for i in range(8):
		var angle = (TAU / 8.0) * i + randf_range(-0.3, 0.3) # Distribuidas en círculo con variación
		var dist = randf_range(3.0, 8.0)
		var pos = player_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_spawn_weapon_pickup.call_deferred(pos, WEAPON_TYPES[i % WEAPON_TYPES.size()])
	
	print("LootManager: Spawned 8 weapons near player at ", player_pos)

func _on_weapon_spawn_timer() -> void:
	if not multiplayer.is_server(): return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	
	# Spawnear 2-3 armas cerca del jugador
	var player = players.pick_random()
	var player_pos = player.global_position
	
	for i in range(randi() % 2 + 2): # 2 o 3 armas
		var angle = randf() * TAU
		var dist = randf_range(4.0, 10.0) # Cerca pero no encima
		var pos = player_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_spawn_weapon_pickup(pos)

func try_drop_loot(position: Vector3) -> void:
	if not multiplayer.is_server(): return
	
	var r = randf()
	if r <= 0.10:
		rpc("_spawn_loot", position)
	elif r <= 0.20:
		rpc("_spawn_weapon_pickup", position)

@rpc("authority", "call_local")
func _spawn_weapon_pickup(position: Vector3, specific_weapon: String = "") -> void:
	if not weapon_pickup_scene: return
	var tree := get_tree()
	if not tree or not tree.current_scene: return
	
	var instance = weapon_pickup_scene.instantiate()
	
	if specific_weapon.is_empty():
		instance.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	else:
		instance.weapon_type = specific_weapon
	
	tree.current_scene.add_child(instance)
	instance.global_position = position + Vector3(0, 0.05, 0) # Apenas elevado del suelo

@rpc("authority", "call_local")
func _spawn_loot(position: Vector3) -> void:
	if not loot_item_scene: return
	var tree := get_tree()
	if not tree or not tree.current_scene: return
	var loot = loot_item_scene.instantiate()
	tree.current_scene.add_child(loot)
	loot.global_position = position + Vector3(0, 0.5, 0)
