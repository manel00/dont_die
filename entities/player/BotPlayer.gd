## BotPlayer.gd
## AI-controlled ally that follows the human player(s) and auto-shoots enemies.
## Uses the same weapons system as PlayerController.

extends CharacterBody3D

@export_category("Bot Stats")
@export var max_health: int = 150  # +50% mÃ¡s vida
@export var move_speed: float = 3.2  # +60% - más movimiento
@export var attack_range: float = 20.0  # Mayor rango - más acción
@export var fire_rate: float = 0.2  # +50% más rápido - más acción
@export var gravity: float = 20.0

# Combat modes
enum CombatMode { RANGED, MELEE, FIREBALL }
var _current_combat_mode: CombatMode = CombatMode.RANGED
var _attack_cooldown: float = 0.0
var _melee_cooldown: float = 0.0
var _fireball_cooldown: float = 0.0
var _mode_switch_timer: float = 0.0

# Weapon pickup
var _nearby_weapon: Node3D = null
@onready var fireball_scene := preload("res://entities/player/weapons/MagicProjectile.tscn")

# IA mejorada
@export_category("Bot AI")
@export var kite_speed: float = 3.5  # +60% - más rápido para escapar
@export var retreat_health_pct: float = 0.25  # Retirarse al 25% vida
@export var optimal_distance: float = 12.0  # Distancia óptima del enemigo
@export var dodge_enabled: bool = true
@export var support_ally: bool = true  # Ayudar a aliados en peligro
@export var reaction_time: float = 0.15  # Tiempo de reacción rápido
@export var erratic_movement: bool = true  # Movimiento errático para parecer humano

var current_health: int = 150
var _fire_timer: float = 0.0
var _target_enemy: Node3D = null
var _follow_target: Node3D = null  # The human player to follow
var nav_agent: NavigationAgent3D
var visual_model: Node3D
var active_weapon: Node3D

@onready var bot_projectile_scene := preload("res://entities/player/weapons/StylooRangedProjectile.tscn")

# IA avanzada
enum BotState { IDLE, FOLLOW, CHASE, KITE, RETREAT, SUPPORT, EVADE, FLANK, SEEK_HEALTH }
var _bot_state: BotState = BotState.IDLE
var _dodge_direction: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
var _support_target: Node3D = null
var _health_orb_target: Node3D = null
var _last_melee_target: Node3D = null
var _attack_anim_timer: float = 0.0
var _combat_side: int = 1
var _last_state_change: float = 0.0  # Para variabilidad
var _idle_wander_timer: float = 0.0  # Movimiento cuando no hay enemigo
var _facing_direction: Vector3 = Vector3.FORWARD  # Dirección actual de mirada
var _strafe_timer: float = 0.0  # Timer para cambio de strafe

signal bot_died

# Animation system
var _anim_player: AnimationPlayer = null
const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walk"
const ANIM_RUN := "Run"
const ANIM_ATTACK := "Attack"
const ATTACK_ANIM_DURATION: float = 0.22
const ALLY_PROTECTION_RADIUS: float = 8.0
const COMBAT_REPOSITION_RADIUS: float = 4.5
const PERSONAL_SPACE_RADIUS: float = 2.2
const TARGET_STICKINESS_BONUS: float = 6.0

func _ready() -> void:
	current_health = max_health
	add_to_group("player")  # Same group so enemies target bots too
	add_to_group("bots")
	# Inicializar estado
	current_health = max_health
	
	visual_model = get_node_or_null("VisualModel")
	
	# Initialize cooldowns
	_attack_cooldown = 0.0
	_melee_cooldown = 0.0
	_fireball_cooldown = 0.0
	_mode_switch_timer = 2.0  # Switch combat mode every 2 seconds
	_combat_side = 1 if randi() % 2 == 0 else -1
	
	# Find weapon (legacy)
	for child in get_children():
		if child.name == "Weapon":
			active_weapon = child
			break
	
	if GameManager.enemy_mode == "mechas":
		_apply_companion_bot_texture()
	
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 2.0
	add_child(nav_agent)
	_setup_bot_weapon_visual()
	_find_anim_player()

func _setup_bot_weapon_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	var blade_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Blade.gltf"
	if ResourceLoader.exists(blade_path):
		var blade = load(blade_path).instantiate()
		visual.add_child(blade)
		blade.position = Vector3(0.3, 0.7, -0.4)
		blade.rotation_degrees = Vector3(0, 90, 0)

func _apply_companion_bot_texture() -> void:
	var tex = load("res://assets/models/characters/Enemies_mecha/Companion-bot.png") as Texture2D
	var obj_mesh = load("res://assets/models/characters/Enemies_mecha/Companion-bot.obj")
	
	if tex and obj_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.8, 1.0)
		mat.emission_energy_multiplier = 0.8
		
		var visual := get_node_or_null("VisualModel")
		if not visual: return
		
		# 2. Ocultar meshes y DETENER animaciones de los esqueletos originales
		for child in visual.find_children("*", "MeshInstance3D", true, false):
			child.hide()
		for child in visual.find_children("*", "AnimationPlayer", true, false):
			child.stop()
			
		var mecha_node: Node3D = null
		if obj_mesh is PackedScene:
			mecha_node = obj_mesh.instantiate()
		elif obj_mesh is Mesh:
			mecha_node = MeshInstance3D.new()
			mecha_node.mesh = obj_mesh
			
		if mecha_node:
			visual.add_child(mecha_node)
			if mecha_node is MeshInstance3D:
				if mecha_node.mesh:
					mecha_node.set_surface_override_material(0, mat)
			else:
				for mi in mecha_node.find_children("*", "MeshInstance3D", true, false):
					if mi.mesh:
						mi.set_surface_override_material(0, mat)
			
			mecha_node.scale = Vector3(1.0, 1.0, 1.0)
			mecha_node.rotation_degrees = Vector3(0, 180, 0)
			_center_mecha_model(mecha_node)

func _center_mecha_model(model: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	if model is MeshInstance3D: meshes.append(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child)
	if meshes.is_empty(): return
	var aabb := AABB()
	var first := true
	for mesh in meshes:
		if mesh.mesh:
			var transformed_aabb := mesh.transform * mesh.mesh.get_aabb()
			if first: aabb = transformed_aabb; first = false
			else: aabb = aabb.merge(transformed_aabb)
	var center := aabb.get_center()
	model.position = -(model.quaternion * (model.scale * center))
	model.position.y = 0
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	_update_fire_timer(delta)
	_update_targets()
	_move(delta)
	_try_shoot()
	move_and_slide()

func _update_fire_timer(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _melee_cooldown > 0.0:
		_melee_cooldown -= delta
	if _fireball_cooldown > 0.0:
		_fireball_cooldown -= delta
	if _mode_switch_timer > 0.0:
		_mode_switch_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer = max(_attack_anim_timer - delta, 0.0)

func _update_targets() -> void:
	# Find enemies with priority (Mage > Rogue > Base > Minion)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_score: float = INF
	_support_target = null
	
	for e in enemies:
		if not _is_alive_actor(e):
			continue
		var enemy = e as Node3D
		var d: float = global_position.distance_to(enemy.global_position)
		if d > 50.0:  # Detectar enemigos más lejos - más reacción
			continue
		
		# Calcular puntuaciÃ³n de prioridad (menor = mejor)
		var score = _score_enemy(enemy)
		if score < best_score:
			best_score = score
			best_target = enemy
	
	_target_enemy = best_target
	
	# Find human player to follow - prioritize staying close to ANY player
	var humans := get_tree().get_nodes_in_group("player")
	var nearest_human_dist: float = INF
	_follow_target = null
	for h in humans:
		if not _is_alive_actor(h) or h == self or h.is_in_group("bots"):
			continue
		var d: float = global_position.distance_to((h as Node3D).global_position)
		if d < nearest_human_dist:
			nearest_human_dist = d
			_follow_target = h as Node3D
	
	# If no human found, stay close to any nearby bot
	if _follow_target == null:
		var bots := get_tree().get_nodes_in_group("bots")
		for b in bots:
			if not _is_alive_actor(b) or b == self: continue
			var d: float = global_position.distance_to((b as Node3D).global_position)
			if d < 8.0 and d < nearest_human_dist:
				nearest_human_dist = d
				_follow_target = b as Node3D
	
	# Buscar aliado que necesite ayuda
	if support_ally:
		var bots := get_tree().get_nodes_in_group("bots")
		var lowest_health_pct: float = 1.0
		for b in bots:
			if not _is_alive_actor(b) or b == self: continue
			var bot = b as Node3D
			var bot_hp = bot.get("current_health")
			if bot_hp == null:
				bot_hp = 150
			var bot_max_hp = bot.get("max_health")
			if bot_max_hp == null:
				bot_max_hp = 150
			var hp_pct = float(bot_hp) / bot_max_hp
			if hp_pct < lowest_health_pct and global_position.distance_to(bot.global_position) < 15.0:
				lowest_health_pct = hp_pct
				_support_target = bot
	
	# Check for nearby weapons to pick up
	_nearby_weapon = _find_nearest_weapon()

func _is_targeting_ally(enemy: Node3D) -> bool:
	# Verificar si el enemigo estÃ¡ atacando a un aliado
	var enemy_target = enemy.get("target")
	if enemy_target and enemy_target is Node3D:
		if enemy_target.is_in_group("bots"):
			return true
	return false

func _find_nearest_weapon() -> Node3D:
	# Find weapon pickups in the world
	var weapon_pickups = get_tree().get_nodes_in_group("weapon_pickup")
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for wp in weapon_pickups:
		if wp is Node3D:
			var d = global_position.distance_to(wp.global_position)
			if d < 5.0 and d < nearest_dist:  # Only pick up if close
				nearest_dist = d
				nearest = wp as Node3D
	return nearest

func _is_alive_actor(node: Node) -> bool:
	if not (node is Node3D) or not is_instance_valid(node):
		return false
	var hp = node.get("current_health")
	if hp != null and int(hp) <= 0:
		return false
	return true

func _score_enemy(enemy: Node3D) -> float:
	var score := global_position.distance_to(enemy.global_position)
	var enemy_max_hp = enemy.get("max_health")
	if enemy_max_hp == null:
		enemy_max_hp = 100
	if enemy_max_hp > 1000:
		score -= 18.0
	elif enemy_max_hp > 250:
		score -= 12.0
	elif enemy_max_hp > 150:
		score -= 7.0
	elif enemy_max_hp > 100:
		score -= 3.0
	if enemy == _target_enemy:
		score -= TARGET_STICKINESS_BONUS
	var enemy_target = enemy.get("target")
	if enemy_target != null and enemy_target is Node3D:
		if enemy_target == _follow_target:
			score -= 12.0
		elif enemy_target.is_in_group("bots"):
			score -= 8.0
	if _follow_target and global_position.distance_to(_follow_target.global_position) <= ALLY_PROTECTION_RADIUS:
		var pressure_dist = enemy.global_position.distance_to(_follow_target.global_position)
		if pressure_dist < ALLY_PROTECTION_RADIUS:
			score -= (ALLY_PROTECTION_RADIUS - pressure_dist) * 1.6
	return score

func _get_follow_slot(anchor: Node3D) -> Vector3:
	var base_offset := Vector3(_combat_side * PERSONAL_SPACE_RADIUS, 0, -2.5)
	if _target_enemy and is_instance_valid(_target_enemy):
		var to_enemy = _target_enemy.global_position - anchor.global_position
		to_enemy.y = 0.0
		if to_enemy.length() > 0.1:
			var forward = to_enemy.normalized()
			var side = forward.cross(Vector3.UP).normalized() * _combat_side
			return anchor.global_position - forward * 2.4 + side * PERSONAL_SPACE_RADIUS
	return anchor.global_position + base_offset

func _get_combat_position(enemy: Node3D, desired_distance: float) -> Vector3:
	var to_enemy = enemy.global_position - global_position
	to_enemy.y = 0.0
	if to_enemy.length() < 0.1:
		to_enemy = Vector3.FORWARD
	var forward = to_enemy.normalized()
	var side = forward.cross(Vector3.UP).normalized() * _combat_side
	var anchor = enemy.global_position - forward * desired_distance + side * COMBAT_REPOSITION_RADIUS
	if _follow_target and is_instance_valid(_follow_target):
		anchor = anchor.lerp(_get_follow_slot(_follow_target), 0.18)
	return anchor

func _evaluate_bot_state() -> void:
	# Evaluar estado del bot con más variabilidad humana
	var health_pct = float(current_health) / max_health
	var time_since_change = Time.get_ticks_msec() / 1000.0 - _last_state_change
	
	# Pick up weapon if nearby
	if _nearby_weapon and (_target_enemy == null or global_position.distance_to(_target_enemy.global_position) > optimal_distance):
		_bot_state = BotState.FOLLOW
		return
	
	# Buscar health orb si vida <= 20
	if current_health <= 20:
		var loot_items = get_tree().get_nodes_in_group("loot")
		var closest_orb: Node3D = null
		var closest_dist: float = 50.0  # Radio de 50 metros
		for item in loot_items:
			if item is Node3D and is_instance_valid(item):
				var dist = global_position.distance_to(item.global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest_orb = item
		if closest_orb:
			_health_orb_target = closest_orb
			_bot_state = BotState.SEEK_HEALTH
			return
	
	# Retirarse si vida baja - pero a veces arriesgar
	if health_pct < retreat_health_pct:
		if randf() > 0.15:  # 15% de chance de arriesgar aunque tenga poca vida
			_bot_state = BotState.RETREAT
			return
	
	# Apoyar aliado en peligro - más sensible
	if support_ally and _support_target and _support_target != self:
		var ally_hp = _support_target.get("current_health")
		if ally_hp == null:
			ally_hp = 150
		var ally_max_hp = _support_target.get("max_health")
		if ally_max_hp == null:
			ally_max_hp = 150
		# Apoyar si aliado tiene menos del 50%
		if float(ally_hp) / ally_max_hp < 0.5:
			_bot_state = BotState.SUPPORT
			return
	
	# Update combat mode based on distance
	_update_combat_mode()
	
	# Kiting: mantener distancia óptima - con variabilidad
	if _target_enemy:
		var dist_to_enemy = global_position.distance_to(_target_enemy.global_position)
		
		# Chance aleatoria de flanquear si está en rango
		if dist_to_enemy < optimal_distance * 1.5 and dist_to_enemy > 3.0 and erratic_movement:
			if randf() < 0.08:  # 8% chance por frame
				_combat_side = -_combat_side  # Cambiar lado de combate
				_strafe_timer = 1.5 + randf()  # Strafe durante 1.5-2.5 segundos
				_bot_state = BotState.FLANK
				_last_state_change = Time.get_ticks_msec() / 1000.0
				return
		
		if _current_combat_mode == CombatMode.MELEE:
			# For melee, get close
			_bot_state = BotState.CHASE
		elif dist_to_enemy < optimal_distance * 0.4:
			# Muito perto - kite back com chance de evasion
			if randf() < 0.1:
				_bot_state = BotState.EVADE  # Evasión agresiva
			else:
				_bot_state = BotState.KITE
			return
		elif dist_to_enemy > attack_range * 0.9:
			# Lejos - chase
			_bot_state = BotState.CHASE
			return
		else:
			# En rango óptimo - con variabilidad
			if erratic_movement and randf() < 0.05:
				# Ocasionalmente cambiar a strafe
				_bot_state = BotState.FLANK
				_strafe_timer = 0.8 + randf() * 1.2
			else:
				_bot_state = BotState.CHASE
	else:
		# Sin enemigo - comportamiento idle con movimiento
		_bot_state = BotState.FOLLOW

func _update_combat_mode() -> void:
	# Switch combat mode periodically
	if _mode_switch_timer <= 0.0 and _target_enemy:
		_mode_switch_timer = 2.0 + randf() * 2.0  # 2-4 seconds
		var dist = global_position.distance_to(_target_enemy.global_position)
		
		# Choose mode based on distance
		if current_health < int(max_health * 0.4):
			if dist < 8.0:
				_current_combat_mode = CombatMode.FIREBALL if randf() > 0.35 else CombatMode.RANGED
			else:
				_current_combat_mode = CombatMode.RANGED
		elif dist < 4.0:
			_current_combat_mode = CombatMode.MELEE if randf() > 0.2 else CombatMode.FIREBALL
		elif dist < 10.0:
			# Medium range - mix of all
			var r = randf()
			if r < 0.4:
				_current_combat_mode = CombatMode.RANGED
			elif r < 0.7:
				_current_combat_mode = CombatMode.FIREBALL
			else:
				_current_combat_mode = CombatMode.MELEE
		else:
			# Long range - prefer ranged and fireball
			_current_combat_mode = CombatMode.RANGED if randf() > 0.4 else CombatMode.FIREBALL

func _move(delta: float) -> void:
	_evaluate_bot_state()
	
	var has_move_target := false
	var move_target_position := Vector3.ZERO
	var actual_speed = move_speed
	
	if _dodge_timer > 0:
		_dodge_timer -= delta
	
	if _nearby_weapon and _bot_state == BotState.FOLLOW:
		var dist_to_weapon = global_position.distance_to(_nearby_weapon.global_position)
		if dist_to_weapon < 1.5:
			if _nearby_weapon.has_method("pickup"):
				_nearby_weapon.pickup(self)
			_nearby_weapon = null
		else:
			has_move_target = true
			move_target_position = _nearby_weapon.global_position
			actual_speed = kite_speed
	
	match _bot_state:
		BotState.KITE:
			if _target_enemy:
				var to_enemy = _target_enemy.global_position - global_position
				var retreat_dir = -Vector3(to_enemy.x, 0, to_enemy.z).normalized()
				var strafe = retreat_dir.cross(Vector3.UP) * (1 if randf() > 0.5 else -1)
				var move_dir = (retreat_dir * 0.7 + strafe * 0.3).normalized()
				actual_speed = kite_speed
				velocity.x = move_dir.x * actual_speed
				velocity.z = move_dir.z * actual_speed
		
		BotState.EVADE:
			# Evasión agresiva - movimiento rápido en dirección aleatoria
			if _target_enemy:
				var to_enemy = _target_enemy.global_position - global_position
				var retreat_dir = -Vector3(to_enemy.x, 0, to_enemy.z).normalized()
				# Evasión en ángulo de 45-90 grados
				var strafe = retreat_dir.cross(Vector3.UP) * (1.0 if randf() > 0.5 else -1.0)
				var move_dir = (retreat_dir * 0.5 + strafe * 0.8).normalized()
				actual_speed = kite_speed * 1.3  # Más rápido al evadir
				velocity.x = move_dir.x * actual_speed
				velocity.z = move_dir.z * actual_speed
		
		BotState.FLANK:
			# Flanquear al enemigo por los lados
			_strafe_timer -= delta
			if _target_enemy and _strafe_timer > 0:
				var to_enemy = _target_enemy.global_position - global_position
				var move_dir = Vector3(to_enemy.x, 0, to_enemy.z).normalized()
				var strafe_dir = move_dir.cross(Vector3.UP).normalized() * _combat_side
				# Moverse lateralmente mientras se acerca un poco
				var flank_dir = (strafe_dir * 0.7 + move_dir * 0.3).normalized()
				actual_speed = move_speed * 0.85
				velocity.x = flank_dir.x * actual_speed
				velocity.z = flank_dir.z * actual_speed
			else:
				# Terminar flanqueo
				_bot_state = BotState.CHASE
		
		BotState.RETREAT:
			if _follow_target:
				has_move_target = true
				move_target_position = _get_follow_slot(_follow_target)
				actual_speed = kite_speed
		
		BotState.SUPPORT:
			if _support_target:
				has_move_target = true
				move_target_position = _get_follow_slot(_support_target)
				actual_speed = kite_speed
		
		BotState.SEEK_HEALTH:
			if _health_orb_target and is_instance_valid(_health_orb_target):
				has_move_target = true
				move_target_position = _health_orb_target.global_position
				actual_speed = kite_speed * 1.2  # Moverse más rápido hacia el health orb
		
		BotState.CHASE:
			if _target_enemy:
				var dist_to_enemy = global_position.distance_to(_target_enemy.global_position)
				var target_dist = optimal_distance
				if _current_combat_mode == CombatMode.MELEE:
					target_dist = 2.5
				elif _current_combat_mode == CombatMode.FIREBALL:
					target_dist = 8.0
				
				if dist_to_enemy > target_dist:
					has_move_target = true
					move_target_position = _target_enemy.global_position
				elif dist_to_enemy < target_dist * 0.7 and _current_combat_mode != CombatMode.MELEE:
					var retreat_to_enemy = _target_enemy.global_position - global_position
					var retreat_dir = -Vector3(retreat_to_enemy.x, 0, retreat_to_enemy.z).normalized()
					velocity.x = retreat_dir.x * kite_speed * 0.5
					velocity.z = retreat_dir.z * kite_speed * 0.5
					return
		
		BotState.FOLLOW:
			if _follow_target:
				var dist_to_player = global_position.distance_to(_follow_target.global_position)
				# Movimiento idle más activo - patrulla alrededor del jugador
				if dist_to_player > 4.0:
					has_move_target = true
					move_target_position = _get_follow_slot(_follow_target)
				elif _target_enemy == null:
					# Movimiento de patrulla cuando no hay enemigo
					_idle_wander_timer += delta
					if _idle_wander_timer > 2.0:
						_idle_wander_timer = 0.0
						# Nuevo punto de patrulla aleatorio
						var patrol_offset = Vector3(randf() - 0.5, 0, randf() - 0.5) * 5.0
						var patrol_target = _follow_target.global_position + patrol_offset
						var to_patrol = (patrol_target - global_position).normalized()
						velocity.x = to_patrol.x * move_speed * 0.4
						velocity.z = to_patrol.z * move_speed * 0.4
						return
	
	if has_move_target:
		nav_agent.target_position = move_target_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * actual_speed
		velocity.z = dir.z * actual_speed
		if visual_model and dir.length() > 0.1:
			var rot := atan2(dir.x, dir.z)
			visual_model.rotation.y = lerp_angle(visual_model.rotation.y, rot, 15.0 * delta)
			visual_model.position = Vector3.ZERO
	else:
		velocity.x = move_toward(velocity.x, 0.0, actual_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, actual_speed * delta * 5.0)
	
	if dodge_enabled:
		_try_dodge(delta)
	
	_update_animation()
func _try_dodge(delta: float) -> void:
	# Buscar proyectiles cercanos del enemigo (en grupo 'projectiles')
	var projectiles := get_tree().get_nodes_in_group("projectiles")
	for p in projectiles:
		if not (p is Node3D):
			continue
		var proj := p as Node3D
		var proj_pos := proj.global_position
		var dist := global_position.distance_to(proj_pos)
		if dist < 6.0:  # Proyectil muy cerca (aumentado para esquivar mejor)
			var proj_dir: Vector3 = proj.get("direction") if proj.get("direction") != null else Vector3.FORWARD
			# Calcular direcciÃ³n de evasiÃ³n perpendicular
			var dodge_dir := proj_dir.cross(Vector3.UP).normalized()
			if dodge_dir == Vector3.ZERO:
				dodge_dir = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
			
			_dodge_direction = dodge_dir
			_dodge_timer = 0.8  # Esquiva durante mÃ¡s tiempo
			break
	
	# Aplicar dodge si estÃ¡ activo
	if _dodge_timer > 0:
		velocity.x += _dodge_direction.x * 18.0 * delta
		velocity.z += _dodge_direction.z * 18.0 * delta

func _try_shoot() -> void:
	if not _target_enemy:
		return
	
	# Execute attack based on combat mode
	match _current_combat_mode:
		CombatMode.MELEE:
			_try_melee_attack()
		CombatMode.FIREBALL:
			_try_fireball_attack()
		CombatMode.RANGED:
			_try_ranged_attack()

func _try_ranged_attack() -> void:
	if _fire_timer > 0.0 or not _target_enemy:
		return
	
	var dist: float = global_position.distance_to(_target_enemy.global_position)
	if dist > attack_range:
		return
	
	_fire_timer = fire_rate
	var shoot_dir := ((_target_enemy.global_position + Vector3(0, 1.0, 0)) - (global_position + Vector3(0, 1.0, 0))).normalized()
	shoot_dir = shoot_dir.normalized()
	var muzzle_pos := global_position + shoot_dir * 1.5 + Vector3(0, 1.0, 0)
	
	if multiplayer.is_server():
		rpc_spawn_bot_projectile.rpc(muzzle_pos, shoot_dir)
	else:
		rpc_id(1, "rpc_request_bot_projectile", muzzle_pos, shoot_dir)
		
	# Play sound
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_shoot"):
		am.play_shoot()

func _try_melee_attack() -> void:
	if _melee_cooldown > 0.0 or not _target_enemy:
		return
	
	var dist: float = global_position.distance_to(_target_enemy.global_position)
	if dist > 3.5:  # Melee range
		return
	
	_melee_cooldown = 0.8  # Melee cooldown
	var attack_dir := (_target_enemy.global_position - global_position).normalized()
	if visual_model:
		var flat_dir := Vector3(attack_dir.x, 0, attack_dir.z).normalized()
		if flat_dir.length() > 0.01:
			visual_model.rotation.y = atan2(flat_dir.x, flat_dir.z)
	_play_attack_animation()
	
	# Create melee slash effect
	if multiplayer.is_server():
		var slash_pos = (global_position + _target_enemy.global_position) / 2.0
		slash_pos.y = global_position.y + 1.0
		_rpc_spawn_melee_slash.rpc(slash_pos, attack_dir)
	
	# Deal damage directly
	var enemy = _target_enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(50)  # High melee damage
	elif enemy.has_method("damage"):
		enemy.damage(50)
	_last_melee_target = enemy

@rpc("authority", "call_local")
func _rpc_spawn_melee_slash(pos: Vector3, dir: Vector3) -> void:
	# Create visual slash effect
	var slash = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	slash.mesh = plane
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.3, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 2.0
	slash.material_override = mat
	
	var scene := get_tree().current_scene
	if not scene:
		return
	scene.add_child(slash)
	slash.global_position = pos
	
	# Face the direction
	if dir.length() > 0.1:
		slash.look_at(slash.global_position + dir.normalized(), Vector3.UP)
	
	# Animate and remove
	var tween = create_tween()
	# start_scale unused - using direct tween instead
	slash.scale = Vector3.ZERO
	var mat_color: Color = mat.albedo_color
	tween.tween_property(slash, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
	tween.tween_method(func(a): mat.albedo_color = Color(mat_color.r, mat_color.g, mat_color.b, a), mat_color.a, 0.0, 0.1)
	tween.tween_callback(slash.queue_free)

func _try_fireball_attack() -> void:
	if _fireball_cooldown > 0.0 or not _target_enemy:
		return
	
	var dist: float = global_position.distance_to(_target_enemy.global_position)
	if dist > 20.0:  # Fireball range
		return
	
	_fireball_cooldown = 2.0  # Fireball cooldown
	
	var shoot_dir := ((_target_enemy.global_position + Vector3(0, 0.5, 0)) - (global_position + Vector3(0, 1.0, 0))).normalized()
	var muzzle_pos := global_position + shoot_dir * 1.5 + Vector3(0, 1.0, 0)
	
	if multiplayer.is_server():
		rpc_spawn_fireball.rpc(muzzle_pos, shoot_dir)
	else:
		rpc_id(1, "rpc_request_fireball", muzzle_pos, shoot_dir)

@rpc("any_peer")
func rpc_request_fireball(pos: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		rpc_spawn_fireball.rpc(pos, dir)

@rpc("authority", "call_local")
func rpc_spawn_fireball(pos: Vector3, dir: Vector3) -> void:
	if fireball_scene:
		var scene = get_tree().current_scene
		if scene:
			var proj = fireball_scene.instantiate()
			scene.add_child(proj)
			proj.global_position = pos
			proj.direction = dir
			proj.speed = 15.0
			proj.impact_damage = 40

@rpc("any_peer")
func rpc_request_bot_projectile(pos: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		rpc_spawn_bot_projectile.rpc(pos, dir)

@rpc("authority", "call_local")
func rpc_spawn_bot_projectile(pos: Vector3, dir: Vector3) -> void:
	if bot_projectile_scene:
		var scene = get_tree().current_scene
		if scene:
			var proj = bot_projectile_scene.instantiate()
			scene.add_child(proj)
			proj.global_position = pos
			proj.direction = dir
			proj.weapon_type = "shuriken4" # Use cool shuriken
			proj.damage = int(max_health / 5.0) # Escala con su vida (float division)
			proj.speed = 30.0
			proj.life_time = 2.0

# INTELIGENCIA AUTÃ“NOMA: Los bots recogen botÃ­n para hacerse mÃ¡s fuertes
@warning_ignore("unused_parameter")
func pickup_styloo_weapon(_weapon_name: String, _data: Dictionary) -> bool:
	# El bot se hace más poderoso en lugar de cambiar de modelo complejo
	max_health += 50
	current_health = max_health
	fire_rate = max(0.1, fire_rate - 0.05)
	return true

func pickup_weapon(weapon_type: String) -> void:
	# FIX: Registrar el arma recogida y mejorar stats del bot
	var weapon_data := {}
	match weapon_type:
		"shuriken1", "shuriken2", "shuriken3", "shuriken4":
			weapon_data = {"type": "ranged", "damage": 25, "color": Color.CYAN}
		"kunai":
			weapon_data = {"type": "ranged", "damage": 30, "color": Color.PURPLE}
		"doubleAxe", "simpleAxe":
			weapon_data = {"type": "ranged_lobber", "damage": 35, "color": Color.ORANGE}
	
	# Aplicar mejoras del arma
	pickup_styloo_weapon(weapon_type, weapon_data)
	
	# Reproducir sonido de pickup si existe
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_level_up"):
		am.play_level_up()

func _find_anim_player() -> void:
	if not visual_model: return
	for child in visual_model.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
			return
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				_anim_player = grandchild
				_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
				return

func _load_animations(_anim_path := "") -> void:
	# SIMPLIFIED: Las animaciones vienen incluidas en los modelos .glb
	pass

func _update_animation() -> void:
	if not _anim_player:
		return
	
	var speed = Vector2(velocity.x, velocity.z).length()
	var is_moving = speed > 0.5
	
	if _attack_anim_timer > 0.0:
		if _anim_player.has_animation(ANIM_ATTACK) and _anim_player.current_animation != ANIM_ATTACK:
			_anim_player.play(ANIM_ATTACK)
		return
	
	if is_moving:
		if _anim_player.has_animation(ANIM_RUN):
			if _anim_player.current_animation != ANIM_RUN:
				_anim_player.play(ANIM_RUN)
		elif _anim_player.has_animation(ANIM_WALK):
			if _anim_player.current_animation != ANIM_WALK:
				_anim_player.play(ANIM_WALK)
	else:
		if _anim_player.has_animation(ANIM_IDLE) and _anim_player.current_animation != ANIM_IDLE:
			_anim_player.play(ANIM_IDLE)

func _play_attack_animation() -> void:
	_attack_anim_timer = ATTACK_ANIM_DURATION
	if _anim_player and _anim_player.has_animation(ANIM_ATTACK):
		_anim_player.play(ANIM_ATTACK)
	if visual_model:
		var initial_scale := visual_model.scale
		var tween := create_tween()
		tween.tween_property(visual_model, "scale", initial_scale * 1.12, 0.05)
		tween.tween_property(visual_model, "scale", initial_scale, 0.14)

func take_damage(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	if current_health <= 0:
		bot_died.emit()
		queue_free()
