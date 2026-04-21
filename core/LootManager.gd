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
	
	# Spawnear armas distribuidas, respetando la distancia de 30m entre ellas
	# Para que 8 armas estén a 30m entre sí en un círculo, el radio debe ser ~40m
	var spawned_count = 0
	var attempts = 0
	while spawned_count < 8 and attempts < 100:
		attempts += 1
		var angle = randf() * TAU
		var dist = randf_range(3.0, 50.0) # Buscamos en un radio más amplio
		var pos = player_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		
		if not _is_too_close(pos, 30.0):
			_spawn_weapon_pickup.call_deferred(pos, WEAPON_TYPES[spawned_count % WEAPON_TYPES.size()])
			spawned_count += 1
	
	print("LootManager: Spawned ", spawned_count, " initial weapons (min 30m distance)")

func _on_weapon_spawn_timer() -> void:
	if not multiplayer.is_server(): return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	
	# Intentar spawnear 1 arma nueva si hay sitio
	var player = players.pick_random()
	var player_pos = player.global_position
	
	for attempt in range(10): # 10 intentos para encontrar un sitio libre
		var angle = randf() * TAU
		var dist = randf_range(20.0, 60.0) # Más lejos para encontrar hueco
		var pos = player_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		
		if not _is_too_close(pos, 30.0):
			_spawn_weapon_pickup(pos)
			break

func try_drop_loot(pos: Vector3) -> void:
	if not multiplayer.is_server(): return
	
	var r = randf()
	if r <= 0.10:
		rpc("_spawn_loot", pos)
	elif r <= 0.20:
		# Solo spawnear arma si no hay otra a 30m
		if not _is_too_close(pos, 30.0):
			rpc("_spawn_weapon_pickup", pos)

func _is_too_close(pos: Vector3, min_dist: float) -> bool:
	var pickups = get_tree().get_nodes_in_group("styloo_pickups")
	for p in pickups:
		if p is Node3D:
			if p.global_position.distance_to(pos) < min_dist:
				return true
	return false

@rpc("authority", "call_local")
func _spawn_weapon_pickup(pos: Vector3, specific_weapon: String = "") -> void:
	if not weapon_pickup_scene: return
	var tree := get_tree()
	if not tree or not tree.current_scene: return
	
	var instance = weapon_pickup_scene.instantiate()
	
	if specific_weapon.is_empty():
		instance.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	else:
		instance.weapon_type = specific_weapon
	
	tree.current_scene.add_child(instance)
	instance.global_position = pos + Vector3(0, 0.05, 0) # Apenas elevado del suelo

@rpc("authority", "call_local")
func _spawn_loot(pos: Vector3) -> void:
	if not loot_item_scene: return
	var tree := get_tree()
	if not tree or not tree.current_scene: return
	var loot = loot_item_scene.instantiate()
	tree.current_scene.add_child(loot)
	loot.global_position = pos + Vector3(0, 0.5, 0)
