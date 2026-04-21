extends Node

## WeaponSpawner — Spawnea armas al inicio de la partida
## Genera 10 armas en posiciones aleatorias en un radio de 50m alrededor del jugador

const MAX_WEAPONS := 10
const SPAWN_RADIUS := 50.0
const MIN_DISTANCE_FROM_PLAYER := 10.0  # No spawnear muy cerca del jugador

const StylooWeaponPickupScript = preload("res://entities/interactables/StylooWeaponPickup.gd")

var _spawned_weapons: Array[Node] = []
var _player: Node3D = null

func _ready() -> void:
	# Esperar un frame para que todo esté listo
	call_deferred("_start_spawning")

func _start_spawning() -> void:
	# Encontrar jugador
	_player = _find_player()
	if not _player:
		push_warning("WeaponSpawner: No player found, delaying spawn")
		# Intentar de nuevo en 1 segundo
		await get_tree().create_timer(1.0).timeout
		_player = _find_player()
		if not _player:
			push_error("WeaponSpawner: Could not find player after retry")
			return
	
	# Spawnear armas
	_spawn_weapons()

func _find_player() -> Node3D:
	var tree := get_tree()
	if not tree:
		return null
	
	# Buscar en grupo "player"
	var players := tree.get_nodes_in_group("player")
	for p in players:
		if p is CharacterBody3D or p is Node3D:
			return p
	
	# Fallback: buscar en la escena actual
	var current := tree.current_scene
	if current:
		# Buscar cualquier nodo con "Player" en el nombre
		for child in current.get_children():
			if "Player" in child.name or "player" in child.name:
				return child
	
	return null

func _spawn_weapons() -> void:
	var pickup_scene = load("res://entities/interactables/StylooWeaponPickup.tscn")
	if not pickup_scene:
		push_error("WeaponSpawner: Could not load StylooWeaponPickup.tscn")
		return
	
	var player_pos := _player.global_position
	var spawned_count := 0
	
	for i in range(MAX_WEAPONS):
		# Generar posición aleatoria en círculo de 50m
		var spawn_pos := _get_random_spawn_position(player_pos)
		if spawn_pos == Vector3.ZERO:
			continue
		
		# Crear pickup
		var pickup = pickup_scene.instantiate()
		if not pickup:
			continue
		
		# Asignar tipo de arma aleatorio
		var weapon_type := StylooWeaponPickupScript.get_random_weapon_type()
		var weapon_data := StylooWeaponPickupScript.get_weapon_data(weapon_type)
		
		pickup.weapon_type = weapon_type
		pickup._weapon_data = weapon_data
		
		# Añadir a escena y posicionar
		get_tree().current_scene.add_child(pickup)
		pickup.global_position = spawn_pos
		
		_spawned_weapons.append(pickup)
		spawned_count += 1
	
	print("WeaponSpawner: Spawned ", spawned_count, " weapons around player at radius ", SPAWN_RADIUS)

func _get_random_spawn_position(player_pos: Vector3) -> Vector3:
	# Generar ángulo y distancia aleatorios
	var angle := randf() * TAU  # 0 a 2*PI
	var distance := MIN_DISTANCE_FROM_PLAYER + randf() * (SPAWN_RADIUS - MIN_DISTANCE_FROM_PLAYER)
	
	# Calcular posición
	var offset := Vector3(
		cos(angle) * distance,
		0.0,  # En el suelo
		sin(angle) * distance
	)
	
	var spawn_pos := player_pos + offset
	spawn_pos.y = 0.3  # Justo encima del suelo
	
	# TODO: Raycast hacia abajo para encontrar el suelo real si hay terreno irregular
	# Por ahora asumimos plano en Y=0
	
	return spawn_pos

func get_spawned_weapons_count() -> int:
	# Limpiar referencias nulas
	_spawned_weapons = _spawned_weapons.filter(func(n): return is_instance_valid(n))
	return _spawned_weapons.size()
