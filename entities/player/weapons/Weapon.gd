class_name Weapon
extends Node3D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.2
@export var max_ammo: int = 30
@export var bullets_per_shot: int = 1
@export var spread_angle: float = 0.0

@export_category("Active Reload")
@export var normal_reload_time: float = 2.0
@export var active_reload_window_start: float = 0.8 # Inicia a los 0.8s
@export var active_reload_window_end: float = 1.2   # Acaba a los 1.2s
@export var jam_penalty_time: float = 1.0           # Penalización extra si "atasca"

var current_ammo: int = max_ammo
var is_reloading: bool = false
var _reload_timer: float = 0.0
var _fire_timer: float = 0.0

func _process(delta: float) -> void:
	if _fire_timer > 0:
		_fire_timer -= delta
		
	if is_reloading:
		_process_reload(delta)

# Función que llama el jugador cuando presiona un Numpad
func shoot(spawn_position: Vector3, shoot_direction: Vector3) -> bool:
	if is_reloading or current_ammo <= 0:
		return false
	
	if _fire_timer > 0.0:
		return false
		
	_fire_timer = fire_rate
	
	# SFX de disparo
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_shoot"):
		am.play_shoot()
	
	if multiplayer.is_server():
		rpc_spawn_projectile(spawn_position, shoot_direction)
	else:
		rpc_id(1, "rpc_request_shoot", spawn_position, shoot_direction)
	
	return true

@rpc("any_peer", "call_local")
func rpc_request_shoot(spawn_position: Vector3, shoot_direction: Vector3):
	if multiplayer.is_server():
		rpc_spawn_projectile(spawn_position, shoot_direction)

@rpc("authority", "call_local")
func rpc_spawn_projectile(spawn_position: Vector3, shoot_direction: Vector3) -> void:
	if not projectile_scene:
		return
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	
	for i in range(bullets_per_shot):
		var proj = projectile_scene.instantiate()
		scene_root.add_child(proj)
		proj.global_position = spawn_position
		
		if spread_angle > 0.0 and bullets_per_shot > 1:
			var spread_rads = deg_to_rad(spread_angle)
			var arc_start = -spread_rads / 2.0
			var arc_step = spread_rads / float(bullets_per_shot - 1)
			var angle_offset = arc_start + (i * arc_step)
			var base_angle = atan2(shoot_direction.x, shoot_direction.z)
			var new_angle = base_angle + angle_offset
			proj.direction = Vector3(sin(new_angle), 0, cos(new_angle)).normalized()
		else:
			proj.direction = shoot_direction

# Lógica principal del Active Reload
func attempt_reload() -> void:
	if current_ammo == max_ammo: return
	
	if not is_reloading:
		# Iniciar la recarga normal
		is_reloading = true
		_reload_timer = 0.0
		print("Recargando... (Pulsa R entre ", active_reload_window_start, "s y ", active_reload_window_end, "s para Active Reload)")
	else:
		# Intentó el active reload durante una recarga
		if _reload_timer >= active_reload_window_start and _reload_timer <= active_reload_window_end:
			print("¡ACTIVE RELOAD! Perfecto.")
			_finish_reload()
		else:
			print("¡JAM! Arma atascada...")
			_reload_timer -= jam_penalty_time # Penalización temporal

func _process_reload(delta: float) -> void:
	_reload_timer += delta
	
	if _reload_timer >= normal_reload_time:
		print("Recarga normal completada.")
		_finish_reload()

func _finish_reload() -> void:
	current_ammo = max_ammo
	is_reloading = false
	_reload_timer = 0.0
