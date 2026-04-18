class_name PlayerController
extends CharacterBody3D

@export_category("Stats")
@export var max_health: int = 100
var current_health: int = 100

# Fall death system
const FALL_THRESHOLD: float = -10.0  # Y position below which player starts falling
const FALL_DEATH_TIME: float = 2.0   # Seconds before death when falling
var _fall_timer: float = 0.0
var _is_falling: bool = false

@export_category("Movement Settings")
@export var move_speed: float = 18.72  # 3x original 6.24
@export var acceleration: float = 9.36  # +30%
@export var gravity: float = 20.0

var visual_model: Node3D
var hud: CanvasLayer
var last_look_dir: Vector3 = Vector3.FORWARD

# Cached nodes para evitar get_node_or_null repetidos
var _cached_audio_manager: Node = null

# Abilities timers
var katana_cooldown: float = 0.8


var fireball_cooldown: float = 1.5


var explosion_cooldown: float = 5.0



var has_weapon: bool = false
var weapon_cooldown: float = 0.35


# Styloo weapon data
var _current_styloo_weapon: String = ""
var _current_weapon_data: Dictionary = {}
var _weapon_visual: Node3D = null

# Durability system
var _weapon_uses_left: int = 0
var _max_weapon_uses: int = 5
const WEAPON_USES_DEFAULT: int = 5

var _base_scale: Vector3 = Vector3.ZERO
var _anim_time: float = 0.0
var _anim_player: AnimationPlayer = null

@onready var fireball_scene := preload("res://entities/player/weapons/MagicProjectile.tscn")
@onready var styloo_projectile_scene := preload("res://entities/player/weapons/StylooRangedProjectile.tscn")
@onready var grenade_scene := preload("res://entities/player/weapons/GrenadeProjectile.tscn")

# Grenade system
var _grenade_charge: float = 0.0
var _is_charging_grenade: bool = false
var _grenade_trajectory_points: Array[Node3D] = []
const GRENADE_MAX_CHARGE: float = 2.0
const GRENADE_MIN_THROW_FORCE: float = 10.0
const GRENADE_MAX_THROW_FORCE: float = 25.0

# Material cacheado para efectos visuales (evitar crear nuevos cada vez)
static var _katana_materials: Array[Material] = []
var _shared_styloo_mat: Material = null
static var _slash_material_cache: StandardMaterial3D = null
static var _explosion_material_cache: StandardMaterial3D = null
static var _ring_material_cache: StandardMaterial3D = null

func _enter_tree() -> void:
	var auth_id: int = name.to_int() if name.is_valid_int() else 1
	set_multiplayer_authority(auth_id)
	
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:velocity")
	config.add_property(".:current_health")
	config.add_property(".:last_look_dir")
	config.add_property(".:has_weapon")
	sync.replication_config = config
	add_child(sync)

@onready var _game_manager: Node = get_node_or_null("/root/GameManager")

func _ready() -> void:
	current_health = max_health
	add_to_group("player")
	visual_model = get_node_or_null("VisualModel")
	_find_anim_player()
	
	if _game_manager and _game_manager.has_method("register_player"):
		_game_manager.register_player(self)
	
	var scene = get_tree().current_scene
	if scene:
		hud = scene.get_node_or_null("HUD")
		if hud:
			hud.update_health(current_health, max_health)
	_setup_blade_visual()
	_init_material_cache()
	_fix_numpad_inputs()

func _fix_numpad_inputs() -> void:
	for i in range(5):
		var action = "weapon_" + str(i)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev1 = InputEventKey.new()
		ev1.keycode = KEY_0 + i
		if not InputMap.action_has_event(action, ev1):
			InputMap.action_add_event(action, ev1)
		var ev2 = InputEventKey.new()
		ev2.keycode = KEY_KP_0 + i
		if not InputMap.action_has_event(action, ev2):
			InputMap.action_add_event(action, ev2)

	if not InputMap.has_action("drop_weapon"):
		InputMap.add_action("drop_weapon")
	var ev_q = InputEventKey.new()
	ev_q.keycode = KEY_Q
	if not InputMap.action_has_event("drop_weapon", ev_q):
		InputMap.action_add_event("drop_weapon", ev_q)

func _find_anim_player() -> void:
	if not visual_model: return
	for child in visual_model.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			_load_animations()
			return
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				_anim_player = grandchild
				_load_animations()
				return

func _load_animations(_anim_path := "") -> void:
	# SIMPLIFIED: Las animaciones vienen incluidas en los modelos .glb
	# No intentamos cargar animaciones externas de Rig_Medium para evitar
	# errores de path de skeleton incompatibles
	pass

func _setup_blade_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	var blade_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Blade.gltf"
	if ResourceLoader.exists(blade_path):
		var blade = load(blade_path).instantiate()
		visual.add_child(blade)
		blade.position = Vector3(0.3, 0.7, -0.4)
		blade.rotation_degrees = Vector3(0, 90, 0)

func _physics_process(delta: float) -> void:
	if _base_scale == Vector3.ZERO and visual_model:
		_base_scale = visual_model.scale
		
	if is_multiplayer_authority():
		_update_timers(delta)
		_handle_movement(delta)
		_handle_abilities()
		_check_fall_death(delta)
	
	_animate_visuals(delta)

func _check_fall_death(delta: float) -> void:
	# Check if player fell below the map
	if global_position.y < FALL_THRESHOLD:
		if not _is_falling:
			_is_falling = true
			_fall_timer = 0.0
			# print("Player falling! Starting fall death timer...")
		else:
			_fall_timer += delta
			if hud and hud.has_method("show_fall_warning"):
				hud.show_fall_warning(FALL_DEATH_TIME - _fall_timer)
			
			if _fall_timer >= FALL_DEATH_TIME:
				# print("Player died from falling!")
				_die_from_fall()
	else:
		if _is_falling:
			_is_falling = false
			_fall_timer = 0.0
			if hud and hud.has_method("hide_fall_warning"):
				hud.hide_fall_warning()

func _die_from_fall() -> void:
	_is_falling = false
	_fall_timer = 0.0
	if hud and hud.has_method("hide_fall_warning"):
		hud.hide_fall_warning()
	
	# Reset health and respawn at center
	current_health = max_health
	if hud: hud.update_health(current_health, max_health)
	
	# Respawn at center of map (0, 5, 0) instead of random position
	global_position = Vector3(0, 5, 0)
	velocity = Vector3.ZERO
	
	# Visual effect for respawn
	if visual_model:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(visual_model, "scale", Vector3.ZERO, 0.1)
		tw.chain().tween_property(visual_model, "scale", _base_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_timers(delta: float) -> void:
	pass  # No cooldowns â€” abilities fire every frame they're pressed

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction.length() > 0.1:
		velocity.x = lerp(velocity.x, direction.x * move_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * move_speed, acceleration * delta)
		last_look_dir = direction
	else:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
		
	move_and_slide()
	
	if last_look_dir.length() > 0.1 and visual_model:
		var target_rot := atan2(last_look_dir.x, last_look_dir.z)
		visual_model.rotation.y = lerp_angle(visual_model.rotation.y, target_rot, 15.0 * delta)

func _handle_abilities() -> void:
	# Ability 0: Katana (0 or Numpad 0)
	if Input.is_action_just_pressed("weapon_0") or Input.is_physical_key_pressed(KEY_KP_0) or Input.is_physical_key_pressed(KEY_0):
		_attack_katana()

	# Ability 1: Fireball (1 or Numpad 1)
	if Input.is_action_just_pressed("weapon_1") or Input.is_physical_key_pressed(KEY_KP_1) or Input.is_physical_key_pressed(KEY_1):
		_cast_fireball()

	# Ability 2: AOE Explosion (2 or Numpad 2)
	if Input.is_action_just_pressed("weapon_2") or Input.is_physical_key_pressed(KEY_KP_2) or Input.is_physical_key_pressed(KEY_2):
		_aoe_explosion()

	# Ability 3: Weapon (3 or Numpad 3 if has_weapon)
	if (Input.is_action_just_pressed("weapon_3") or Input.is_physical_key_pressed(KEY_KP_3) or Input.is_physical_key_pressed(KEY_3)) and has_weapon:
		_fire_weapon()
	
	# Ability 4: Grenade (4 or Numpad 4) - Hold to charge, release to throw
	_handle_grenade_input()
	
	if Input.is_action_just_pressed("drop_weapon") or Input.is_physical_key_pressed(KEY_Q):
		if has_weapon:
			_drop_weapon()
	

func _handle_grenade_input() -> void:
	if Input.is_action_just_pressed("weapon_4") or Input.is_physical_key_pressed(KEY_KP_4) or Input.is_physical_key_pressed(KEY_4):
		if not _is_charging_grenade:
			_start_grenade_charge()
	
	if _is_charging_grenade:
		_update_grenade_charge()
		if Input.is_action_just_released("weapon_4") or (not Input.is_physical_key_pressed(KEY_KP_4) and not Input.is_physical_key_pressed(KEY_4) and not Input.is_action_pressed("weapon_4")):
			_throw_grenade()

func _start_grenade_charge() -> void:
	_grenade_charge = 0.0
	_is_charging_grenade = true
	_spawn_trajectory_preview()

func _update_grenade_charge() -> void:
	_grenade_charge += get_physics_process_delta_time()
	_grenade_charge = min(_grenade_charge, GRENADE_MAX_CHARGE)
	_update_trajectory_preview()

func _spawn_trajectory_preview() -> void:
	# Clear existing points
	_clear_trajectory_preview()
	
	# Create pool of trajectory points (red spheres)
	for i in range(20):
		var point = CSGSphere3D.new()
		point.radius = 0.2
		point.radial_segments = 16
		point.rings = 8
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 0.0, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.0, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		point.material = mat
		
		point.visible = false
		get_tree().current_scene.add_child(point)
		_grenade_trajectory_points.append(point)

func _update_trajectory_preview() -> void:
	if _grenade_trajectory_points.is_empty():
		return
	
	var charge_pct: float = _grenade_charge / GRENADE_MAX_CHARGE
	var throw_force: float = lerp(GRENADE_MIN_THROW_FORCE, GRENADE_MAX_THROW_FORCE, charge_pct)
	
	var start_pos: Vector3 = global_position + Vector3(0, 1.5, 0) + last_look_dir * 0.5
	var velocity: Vector3 = last_look_dir * throw_force
	velocity.y = 8.0 * (0.5 + charge_pct * 0.5)  # Higher arc with more charge
	
	var gravity := Vector3(0, -20.0, 0)
	var time_step := 0.05
	
	for i in range(_grenade_trajectory_points.size()):
		var t: float = time_step * i
		var pos: Vector3 = start_pos + velocity * t + 0.5 * gravity * t * t
		
		var point := _grenade_trajectory_points[i]
		point.global_position = pos
		
		# Fade out points further along the trajectory
		var alpha := 0.8 * (1.0 - float(i) / _grenade_trajectory_points.size())
		if point.material:
			point.material.albedo_color.a = alpha
		
		point.visible = pos.y > 0.0  # Hide if below ground

func _clear_trajectory_preview() -> void:
	for point in _grenade_trajectory_points:
		if is_instance_valid(point):
			point.queue_free()
	_grenade_trajectory_points.clear()

func _throw_grenade() -> void:
	_is_charging_grenade = false
	
	var charge_pct: float = clamp(_grenade_charge / GRENADE_MAX_CHARGE, 0.0, 1.0)
	var throw_force: float = lerp(GRENADE_MIN_THROW_FORCE, GRENADE_MAX_THROW_FORCE, charge_pct)
	
	var throw_velocity: Vector3 = last_look_dir * throw_force
	throw_velocity.y = 8.0 * (0.5 + charge_pct * 0.5)
	
	# Spawn grenade
	if multiplayer.is_server():
		rpc_spawn_grenade.rpc(global_position + Vector3(0, 1.5, 0) + last_look_dir * 0.5, throw_velocity)
	else:
		rpc_id(1, "rpc_request_grenade", global_position + Vector3(0, 1.5, 0) + last_look_dir * 0.5, throw_velocity)
	
	# Clear trajectory
	_clear_trajectory_preview()
	
	# Animation
	if visual_model:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(visual_model, "rotation_degrees:x", visual_model.rotation_degrees.x + 45, 0.1)
		tw.chain().tween_property(visual_model, "rotation_degrees:x", visual_model.rotation_degrees.x, 0.2)
	
	_play_shoot_sound()

@rpc("any_peer")
func rpc_request_grenade(pos: Vector3, throw_velocity: Vector3) -> void:
	if multiplayer.is_server():
		rpc_spawn_grenade.rpc(pos, throw_velocity)

@rpc("authority", "call_local")
func rpc_spawn_grenade(pos: Vector3, throw_velocity: Vector3) -> void:
	if grenade_scene:
		var grenade = grenade_scene.instantiate()
		get_tree().current_scene.add_child(grenade)
		grenade.global_position = pos
		grenade.initial_velocity = throw_velocity

func _attack_katana() -> void:
	rpc_execute_katana.rpc(global_position, last_look_dir)

@rpc("any_peer", "call_local")
func rpc_execute_katana(pos: Vector3, l_dir: Vector3) -> void:
	_play_shoot_sound()
	
	if multiplayer.is_server():
		var enemies := get_tree().get_nodes_in_group("enemies")
		# print("DEBUG Katana: checking ", enemies.size(), " enemies")
		for i in range(enemies.size()):
			var e: Node = enemies[i]
			if is_instance_valid(e) and e is Node3D:
				var to_enemy = (e as Node3D).global_position - pos
				var dist = to_enemy.length()
				var angle = to_enemy.normalized().dot(l_dir)
				if dist < 4.5 and angle > 0.4:
					if e.has_method("take_damage"): 
						# print("DEBUG Katana: HIT enemy=", e.name, " dist=", dist, " angle=", angle)
						e.take_damage(25)

	if visual_model:
		var tw = create_tween()
		tw.tween_property(visual_model, "scale", _base_scale * 1.4, 0.05)
		tw.tween_property(visual_model, "scale", _base_scale, 0.1)
		
	# EFECTO VISUAL: Ice Katana Slash (usar material cacheado)
	var slash = CSGBox3D.new()
	slash.size = Vector3(3.0, 0.1, 0.8)
	slash.material = _get_slash_material()
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(slash)
		slash.global_position = pos + Vector3(0, 1.0, 0) + l_dir * 1.5
		slash.look_at(slash.global_position + l_dir, Vector3.UP)
		
		var tw_slash = create_tween().set_parallel(true)
		tw_slash.tween_property(slash, "scale", Vector3(1.5, 0.5, 2.5), 0.2)
		tw_slash.tween_property(slash, "global_position", slash.global_position + l_dir * 2.0, 0.2)
		tw_slash.tween_property(slash.material, "albedo_color:a", 0.0, 0.2)
		tw_slash.chain().tween_callback(slash.queue_free)

func _cast_fireball() -> void:
	if multiplayer.is_server():
		rpc_spawn_fireball.rpc(global_position + Vector3(0, 0.5, 0) + last_look_dir * 1.5, last_look_dir)
	else:
		rpc_id(1, "rpc_request_fireball", global_position + Vector3(0, 0.5, 0) + last_look_dir * 1.5, last_look_dir)

@rpc("any_peer")
func rpc_request_fireball(pos: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server(): rpc_spawn_fireball.rpc(pos, dir)

@rpc("authority", "call_local")
func rpc_spawn_fireball(pos: Vector3, dir: Vector3) -> void:
	var proj = fireball_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = pos
	proj.direction = dir

func _aoe_explosion() -> void:
	rpc_execute_aoe.rpc(global_position)

@rpc("any_peer", "call_local")
func rpc_execute_aoe(pos: Vector3) -> void:
	var scene = get_tree().current_scene
	if not scene: return
	
	# Visual effect for explosion (usar materiales cacheados)
	var sphere = CSGSphere3D.new()
	sphere.radius = 0.5
	sphere.radial_segments = 32
	sphere.rings = 16
	sphere.material = _get_explosion_material()
	scene.add_child(sphere)
	sphere.global_position = pos + Vector3(0, 0.5, 0)
	
	# EFECTO VISUAL: Anillo de impacto secundario
	var ring = CSGTorus3D.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 1.0
	ring.sides = 32
	ring.material = _get_ring_material()
	scene.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.2, 0)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sphere, "radius", 6.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sphere.material, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(sphere.queue_free)
	
	var tw_ring = create_tween().set_parallel(true)
	tw_ring.tween_property(ring, "inner_radius", 6.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(ring, "outer_radius", 7.5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(ring.material, "albedo_color:a", 0.0, 0.5)
	tw_ring.chain().tween_callback(ring.queue_free)
	
	if multiplayer.is_server():
		var enemies := get_tree().get_nodes_in_group("enemies")
		# print("DEBUG AOE: checking ", enemies.size(), " enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is Node3D:
				if enemy.global_position.distance_to(pos) < 4.0:
					if enemy.has_method("take_damage"): 
						# print("DEBUG AOE: HIT enemy=", enemy.name, " dist=", enemy.global_position.distance_to(pos))
						enemy.take_damage(40)

func _fire_weapon() -> void:
	if not has_weapon: return
	
	# print("Weapon used: ", _current_styloo_weapon)
	
	# Verificar si es arma ranged o melee
	var weapon_type_str: String = _current_weapon_data.get("type", "melee")
	
	if weapon_type_str == "ranged" or weapon_type_str == "ranged_lobber":
		# Modo ranged - disparar proyectil
		_fire_ranged_projectile()
	else:
		# Modo melee - ataque cuerpo a cuerpo
		_perform_melee_attack()

func _fire_ranged_projectile() -> void:
	"""Disparar proyectil ranged (shurikens, kunai, hachas)."""
	var spawn_pos = global_position + Vector3(0, 1.0, 0) + last_look_dir * 0.8
	
	if multiplayer.is_server():
		rpc_spawn_styloo_projectile.rpc(spawn_pos, last_look_dir, _current_styloo_weapon, _current_weapon_data)
	else:
		rpc_id(1, "rpc_request_styloo_projectile", spawn_pos, last_look_dir, _current_styloo_weapon, _current_weapon_data)
	
	# AnimaciÃ³n de lanzamiento
	if _anim_player and _anim_player.has_animation("CharacterArmature|Punch"):
		_anim_player.play("CharacterArmature|Punch")
	elif visual_model:
		# AnimaciÃ³n manual de lanzamiento (sin cambiar rotaciÃ³n/postura)
		var tw = create_tween()
		tw.tween_property(visual_model, "scale", _base_scale * 1.3, 0.05)
		tw.tween_property(visual_model, "scale", _base_scale, 0.1)

func _perform_melee_attack() -> void:
	"""Ataque melee con slash effect."""
	var weapon_range: float = _current_weapon_data.get("range", 3.0)
	var weapon_damage: int = _current_weapon_data.get("damage", 40)
	var weapon_color: Color = _current_weapon_data.get("color", Color.CYAN)
	
	if multiplayer.is_server():
		rpc_execute_styloo_attack.rpc(global_position, last_look_dir, weapon_range, weapon_damage, weapon_color)
	else:
		rpc_id(1, "rpc_request_styloo_attack", global_position, last_look_dir, weapon_range, weapon_damage, weapon_color)

func _drop_weapon() -> void:
	"""Drop weapon on the ground when durability runs out."""
	# print("Weapon broken! Dropping: ", _current_styloo_weapon)
	
	# Spawnear pickup en el suelo con usos restantes (siempre 0 en este caso)
	if multiplayer.is_server():
		rpc_drop_weapon_pickup.rpc(global_position, _current_styloo_weapon, _current_weapon_data)
	else:
		rpc_id(1, "rpc_request_weapon_drop", global_position, _current_styloo_weapon, _current_weapon_data)
	
	# Limpiar arma del jugador
	has_weapon = false
	if _weapon_visual:
		_weapon_visual.queue_free()
		_weapon_visual = null
	_current_styloo_weapon = ""
	_current_weapon_data = {}
	_weapon_uses_left = 0

@rpc("any_peer")
func rpc_request_weapon_drop(pos: Vector3, weapon_type: String, weapon_data: Dictionary) -> void:
	if multiplayer.is_server():
		rpc_drop_weapon_pickup.rpc(pos, weapon_type, weapon_data)

@rpc("authority", "call_local")
func rpc_drop_weapon_pickup(pos: Vector3, weapon_type: String, weapon_data: Dictionary) -> void:
	"""Spawn a dropped weapon pickup on the ground."""
	var pickup_scene = load("res://entities/interactables/StylooWeaponPickup.tscn")
	if pickup_scene:
		var pickup = pickup_scene.instantiate()
		pickup.weapon_type = weapon_type
		pickup._weapon_data = weapon_data.duplicate()
		pickup._is_dropped = true  # Marcar como droppeado (desaparecerÃ¡ si no se recoge)
		get_tree().current_scene.add_child(pickup)
		# Droppear adelante del jugador a 3 metros
		pickup.global_position = pos + last_look_dir * 3.0 + Vector3(0, 0.5, 0)

@rpc("any_peer")
func rpc_request_styloo_projectile(pos: Vector3, dir: Vector3, weapon_type: String, weapon_data: Dictionary) -> void:
	if multiplayer.is_server():
		rpc_spawn_styloo_projectile.rpc(pos, dir, weapon_type, weapon_data)

@rpc("authority", "call_local")
func rpc_spawn_styloo_projectile(pos: Vector3, dir: Vector3, weapon_type: String, weapon_data: Dictionary) -> void:
	"""Spawn a ranged projectile for Styloo weapons (shurikens, kunai, axes)."""
	if styloo_projectile_scene:
		var scene = get_tree().current_scene
		if scene:
			var proj = styloo_projectile_scene.instantiate()
			scene.add_child(proj)
			
			# Seteamos la posiciÃ³n DESPUÃ‰S de aÃ±adir al Ã¡rbol para evitar el error de "is_inside_tree"
			proj.global_position = pos
			proj.direction = dir.normalized()
			proj.weapon_type = weapon_type
			proj.damage = weapon_data.get("damage", 25)
			
			# Configurar comportamiento segÃºn tipo
			match weapon_type:
				"shuriken1", "shuriken2", "shuriken3", "shuriken4":
					proj.speed = 35.0
					proj.life_time = 2.5
				"kunai":
					proj.speed = 45.0
					proj.life_time = 2.0
				"doubleAxe", "simpleAxe":
					proj.speed = 18.0
					proj.life_time = 4.0
		
		_play_shoot_sound()

@rpc("any_peer")
func rpc_request_styloo_attack(pos: Vector3, dir: Vector3, weapon_range: float, damage: int, color: Color) -> void:
	if multiplayer.is_server():
		rpc_execute_styloo_attack.rpc(pos, dir, weapon_range, damage, color)

@rpc("any_peer", "call_local")
func rpc_execute_styloo_attack(pos: Vector3, dir: Vector3, weapon_range: float, damage: int, color: Color) -> void:
	_play_shoot_sound()
	
	# DaÃ±o a enemigos
	if multiplayer.is_server():
		var enemies := get_tree().get_nodes_in_group("enemies")
		# print("DEBUG StylooMelee: checking ", enemies.size(), " enemies")
		for i in range(enemies.size()):
			var e: Node = enemies[i]
			if is_instance_valid(e) and e is Node3D:
				var to_enemy = (e as Node3D).global_position - pos
				var dist = to_enemy.length()
				var angle = to_enemy.normalized().dot(dir)
				if dist < weapon_range and angle > 0.3:
					if e.has_method("take_damage"): 
						# print("DEBUG StylooMelee: HIT enemy=", e.name, " dist=", dist, " angle=", angle)
						e.take_damage(damage)
	
	# Efecto visual del ataque con el color del arma
	_spawn_weapon_attack_effect(pos, dir, weapon_range, color)

func _spawn_weapon_attack_effect(pos: Vector3, dir: Vector3, weapon_range: float, color: Color) -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	
	# Slash effect
	var slash = CSGBox3D.new()
	slash.size = Vector3(weapon_range * 0.8, 0.1, 0.8)
	
	var mat_slash = StandardMaterial3D.new()
	mat_slash.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat_slash.emission_enabled = true
	mat_slash.emission = color * 1.5
	mat_slash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.material = mat_slash
	
	get_tree().current_scene.add_child(slash)
	slash.global_position = pos + Vector3(0, 1.0, 0) + dir * (weapon_range * 0.5)
	slash.look_at(slash.global_position + dir, Vector3.UP)
	
	# Trail particles
	var trail = GPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.5
	trail.explosiveness = 0.8
	
	var trail_mat = ParticleProcessMaterial.new()
	trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	trail_mat.emission_box_extents = Vector3(weapon_range * 0.5, 0.2, 0.5)
	trail_mat.initial_velocity_min = 1.0
	trail_mat.initial_velocity_max = 3.0
	trail_mat.color = color
	trail.process_material = trail_mat
	
	var trail_mesh = SphereMesh.new()
	trail_mesh.radius = 0.05
	trail_mesh.height = 0.1
	trail.draw_pass_1 = trail_mesh
	
	if tree and tree.current_scene:
		tree.current_scene.add_child(trail)
		trail.global_position = pos + Vector3(0, 1.0, 0) + dir * (weapon_range * 0.3)
	
	# Animaciones
	var tw_slash = create_tween().set_parallel(true)
	tw_slash.tween_property(slash, "scale", Vector3(1.5, 0.5, 2.5), 0.2)
	tw_slash.tween_property(slash, "global_position", slash.global_position + dir * 1.5, 0.2)
	tw_slash.tween_property(mat_slash, "albedo_color:a", 0.0, 0.2)
	tw_slash.chain().tween_callback(slash.queue_free)
	
	# Cleanup trail
	if tree:
		var timer = tree.create_timer(0.6)
		timer.timeout.connect(trail.queue_free)
	
	# AnimaciÃ³n del personaje
	if visual_model:
		var tw = create_tween()
		tw.tween_property(visual_model, "scale", _base_scale * 1.3, 0.05)
		tw.tween_property(visual_model, "scale", _base_scale, 0.1)
	
	# AnimaciÃ³n del arma
	if _weapon_visual:
		var tw_weapon = create_tween().set_parallel(true)
		tw_weapon.tween_property(_weapon_visual, "rotation_degrees:x", _weapon_visual.rotation_degrees.x + 90, 0.15)
		tw_weapon.chain().tween_property(_weapon_visual, "rotation_degrees:x", _weapon_visual.rotation_degrees.x, 0.15)

@rpc("any_peer")
func rpc_request_projectile(pos: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server(): rpc_spawn_projectile.rpc(pos, dir)

@rpc("authority", "call_local")
func rpc_spawn_projectile(_pos: Vector3, _dir: Vector3) -> void:
	# FunciÃ³n mantenida por compatibilidad pero no usada actualmente
	pass

func _animate_visuals(_delta: float) -> void:
	if not visual_model: return
	var speed_ratio = Vector2(velocity.x, velocity.z).length() / move_speed
	
	if _anim_player:
		var target_anim := ""
		if speed_ratio > 0.1:
			target_anim = "Walk" if _anim_player.has_animation("Walk") else ("Run" if _anim_player.has_animation("Run") else "")
		else:
			target_anim = "Idle" if _anim_player.has_animation("Idle") else ""
		if target_anim and _anim_player.current_animation != target_anim:
			_anim_player.play(target_anim)
	
	# Fallback/Additive procedural animation
	if speed_ratio > 0.1:
		_anim_time += _delta * 18.0
		if not _anim_player:
			visual_model.scale.y = lerp(visual_model.scale.y, _base_scale.y * (1.0 + sin(_anim_time) * 0.15), 15.0 * _delta)
			visual_model.position.y = abs(sin(_anim_time)) * 0.2
	else:
		if not _anim_player:
			visual_model.scale = lerp(visual_model.scale, _base_scale, 10.0 * _delta)
			visual_model.position.y = lerp(visual_model.position.y, 0.0, 10.0 * _delta)

# â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
#  OPTIMIZACIONES: Material Cache & Helper Functions
# â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
func _init_material_cache() -> void:
	# Inicializar materiales cacheados una sola vez
	if _slash_material_cache == null:
		_slash_material_cache = StandardMaterial3D.new()
		_slash_material_cache.albedo_color = Color(0.0, 0.8, 1.0, 0.9)
		_slash_material_cache.emission_enabled = true
		_slash_material_cache.emission = Color(0.0, 0.5, 1.0)
		_slash_material_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
	if _explosion_material_cache == null:
		_explosion_material_cache = StandardMaterial3D.new()
		_explosion_material_cache.albedo_color = Color(0.8, 0.2, 1.0, 0.8)
		_explosion_material_cache.emission_enabled = true
		_explosion_material_cache.emission = Color(0.8, 0.1, 1.0)
		_explosion_material_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
	if _ring_material_cache == null:
		_ring_material_cache = StandardMaterial3D.new()
		_ring_material_cache.albedo_color = Color(1.0, 0.0, 0.5, 0.9)
		_ring_material_cache.emission_enabled = true
		_ring_material_cache.emission = Color(1.0, 0.2, 0.5)
		_ring_material_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _get_slash_material() -> StandardMaterial3D:
	if _slash_material_cache == null:
		_init_material_cache()
	# Crear copia para permitir modificaciÃ³n individual
	var mat = _slash_material_cache.duplicate()
	return mat

func _get_explosion_material() -> StandardMaterial3D:
	if _explosion_material_cache == null:
		_init_material_cache()
	var mat = _explosion_material_cache.duplicate()
	return mat

func _get_ring_material() -> StandardMaterial3D:
	if _ring_material_cache == null:
		_init_material_cache()
	var mat = _ring_material_cache.duplicate()
	return mat

func _play_shoot_sound() -> void:
	# Cachear AudioManager para evitar get_node_or_null repetido
	if _cached_audio_manager == null:
		_cached_audio_manager = get_node_or_null("/root/AudioManager")
	if _cached_audio_manager and _cached_audio_manager.has_method("play_shoot"):
		_cached_audio_manager.play_shoot()

func take_damage(amount: int) -> void:
	if not multiplayer.is_server():
		rpc_id(1, "rpc_take_damage_player", amount)
		return
	rpc_take_damage_player(amount)

@rpc("authority", "call_local")
func rpc_take_damage_player(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	if hud: hud.update_health(current_health, max_health)
	if current_health <= 0:
		current_health = max_health
		if hud: hud.update_health(current_health, max_health)
		_respawn()

func _respawn() -> void:
	global_position = _find_safe_respawn_position()

func _find_safe_respawn_position() -> Vector3:
	const MIN_SAFE_DISTANCE := 20.0  # MÃ­nima distancia segura de enemigos
	const DEFAULT_POS := Vector3(0, 5, 0)
	
	# Obtener todos los enemigos
	var enemies := get_tree().get_nodes_in_group("enemies")
	
	# Obtener todos los puntos de spawn del jugador
	var spawn_markers := get_tree().get_nodes_in_group("player_spawns")
	
	# Si no hay enemigos, usar spawn aleatorio o posiciÃ³n por defecto
	if enemies.size() == 0:
		if spawn_markers.size() > 0:
			var random_marker: Node3D = spawn_markers[randi() % spawn_markers.size()]
			return random_marker.global_position
		return DEFAULT_POS
	
	# Buscar el spawn mÃ¡s alejado de los enemigos
	var best_spawn: Vector3 = DEFAULT_POS
	var best_min_distance := 0.0
	var found_safe := false
	
	# Evaluar cada spawn point
	for marker in spawn_markers:
		var spawn_pos: Vector3 = (marker as Node3D).global_position
		var min_distance_to_enemies := INF
		
		# Calcular distancia mÃ­nima a todos los enemigos desde este spawn
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is Node3D:
				var dist: float = spawn_pos.distance_to((enemy as Node3D).global_position)
				if dist < min_distance_to_enemies:
					min_distance_to_enemies = dist
		
		# Si este spawn estÃ¡ a mÃ¡s de 20 metros de todos los enemigos, es seguro
		if min_distance_to_enemies >= MIN_SAFE_DISTANCE:
			# De los spawn seguros, elegir el que estÃ¡ mÃ¡s lejos
			if min_distance_to_enemies > best_min_distance:
				best_min_distance = min_distance_to_enemies
				best_spawn = spawn_pos
				found_safe = true
		elif not found_safe:
			# Si aÃºn no encontramos uno seguro, guardar el que estÃ¡ mÃ¡s lejos
			if min_distance_to_enemies > best_min_distance:
				best_min_distance = min_distance_to_enemies
				best_spawn = spawn_pos
	
	# Si no hay spawn markers, buscar posiciones alternativas
	if spawn_markers.size() == 0:
		# Intentar posiciones predefinidas alejadas del centro
		var alternative_positions: Array[Vector3] = [
			Vector3(40, 5, 40),
			Vector3(-40, 5, 40),
			Vector3(40, 5, -40),
			Vector3(-40, 5, -40),
			Vector3(0, 5, 48),
			Vector3(0, 5, -48),
			Vector3(48, 5, 0),
			Vector3(-48, 5, 0)
		]
		
		for pos in alternative_positions:
			var min_distance_to_enemies := INF
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy is Node3D:
					var dist: float = pos.distance_to((enemy as Node3D).global_position)
					if dist < min_distance_to_enemies:
						min_distance_to_enemies = dist
			
			if min_distance_to_enemies >= MIN_SAFE_DISTANCE and min_distance_to_enemies > best_min_distance:
				best_min_distance = min_distance_to_enemies
				best_spawn = pos
				found_safe = true
			elif not found_safe and min_distance_to_enemies > best_min_distance:
				best_min_distance = min_distance_to_enemies
				best_spawn = pos
	
	# print("Respawn seguro en: ", best_spawn, " (distancia mÃ­nima a enemigos: ", best_min_distance, ")")
	return best_spawn

func pickup_weapon(_weapon_type: String = "sword") -> void:
	# Legacy weapon pickup - convertir a styloo
	pickup_styloo_weapon("sword1", {})

func pickup_styloo_weapon(weapon_type: String, weapon_data: Dictionary) -> void:
	if has_weapon:
		_drop_weapon()

	has_weapon = true
	_current_styloo_weapon = weapon_type
	
	# Usar datos proporcionados o defaults
	if weapon_data.is_empty():
		_current_weapon_data = {
			"cooldown": 0.35,
			"damage": 40,
			"range": 3.0,
			"color": Color(0.3, 0.8, 1.0, 1.0),
			"scale": Vector3(0.015, 0.015, 0.015),
			"position": Vector3(0.3, 0.7, 0.4),
			"rotation": Vector3(0, 90, 0),
			"uses_left": WEAPON_USES_DEFAULT
		}
	else:
		_current_weapon_data = weapon_data.duplicate()
		# Si no tiene usos definidos, asignar default
		if not _current_weapon_data.has("uses_left"):
			_current_weapon_data["uses_left"] = WEAPON_USES_DEFAULT
	
	_weapon_uses_left = _current_weapon_data.get("uses_left", WEAPON_USES_DEFAULT)
	_max_weapon_uses = WEAPON_USES_DEFAULT
	weapon_cooldown = _current_weapon_data.get("cooldown", 0.35)
	
	# print("Styloo weapon picked up: ", weapon_type, " (damage: ", _current_weapon_data.get("damage", 40), ", uses: ", _weapon_uses_left, "/", _max_weapon_uses, ")")
	
	# Mostrar arma visual en el personaje
	_setup_styloo_weapon_visual()
	
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_level_up"):
		am.play_level_up()

func _setup_styloo_weapon_visual() -> void:
	if not visual_model:
		return
	
	# Remover arma anterior si existe
	if _weapon_visual:
		_weapon_visual.queue_free()
		_weapon_visual = null
	
	# Construir path al modelo
	var weapon_path := "res://assets/models/weapons/weaponsassetspackbyStyloo/ASSETS.fbx_" + _current_styloo_weapon + ".fbx"
	# print("Loading equipped weapon: ", weapon_path)
	
	if ResourceLoader.exists(weapon_path):
		_weapon_visual = load(weapon_path).instantiate()
		# print("Equipped weapon loaded: ", _weapon_visual.name)
		
		# Strip embedded animations
		var anim_players = _weapon_visual.find_children("*", "AnimationPlayer", true)
		for ap in anim_players:
			ap.queue_free()
			
		# Aplicar escala y posiciÃ³n de mano del personaje (corregido factor x300 del importer FBX para que el arma se vea realista y amenazante)
		var hand_scale := Vector3(0.008, 0.008, 0.008) * 300.0  # TamaÃ±o visible real
		_weapon_visual.scale = hand_scale
		_weapon_visual.position = Vector3(0.2, 0.5, 0.3)  # PosiciÃ³n en mano derecha
		_weapon_visual.rotation_degrees = Vector3(0, 90, 0)
		# Aplicar la textura correcta
		_apply_weapon_materials_to_node(_weapon_visual)
		visual_model.add_child(_weapon_visual)
		# print("Weapon equipped successfully")
	else:
		# print("WARNING: Could not load weapon, using fallback")
		# Fallback visual
		_weapon_visual = _create_fallback_weapon_visual()
		visual_model.add_child(_weapon_visual)

func _apply_weapon_materials_to_node(node: Node) -> void:
	if not _shared_styloo_mat:
		var mat_path = "res://assets/models/weapons/weaponsassetspackbyStyloo/textures/Textures.mat"
		if ResourceLoader.exists(mat_path):
			_shared_styloo_mat = load(mat_path)
			
	if node is MeshInstance3D and _shared_styloo_mat:
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, _shared_styloo_mat)
				
	for child in node.get_children():
		_apply_weapon_materials_to_node(child)

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result

func _create_fallback_weapon_visual() -> Node3D:
	var container = Node3D.new()
	container.name = "FallbackWeapon"
	
	# Mesh segÃºn tipo
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var color: Color = _current_weapon_data.get("color", Color.CYAN)
	
	match _current_styloo_weapon:
		"katana", "longsword", "normalsword", "sword1", "bayonet":
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(0.1, 0.6, 0.05)
		"doubleAxe", "simpleAxe", "pickaxe":
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(0.2, 0.5, 0.1)
		"shuriken1", "shuriken2", "shuriken3", "shuriken4":
			mesh.mesh = SphereMesh.new()
			mesh.mesh.radius = 0.15
			mesh.mesh.height = 0.05
		_:
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(0.1, 0.4, 0.08)
	
	mesh.position = Vector3(0.3, 0.7, 0.4)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 2.0
	mat.metallic = 0.6
	mesh.material_override = mat
	
	container.add_child(mesh)
	return container
