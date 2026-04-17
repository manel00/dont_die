## BotPlayer.gd
## AI-controlled ally that follows the human player(s) and auto-shoots enemies.
## Uses the same weapons system as PlayerController.

class_name BotPlayer
extends CharacterBody3D

@export_category("Bot Stats")
@export var max_health: int = 150  # +50% más vida
@export var move_speed: float = 2.34  # +30%
@export var attack_range: float = 15.0  # Mayor rango
@export var fire_rate: float = 0.28  # +25% más rápido
@export var gravity: float = 20.0

# IA mejorada
@export_category("Bot AI")
@export var kite_speed: float = 2.86  # +30%
@export var retreat_health_pct: float = 0.25  # Retirarse al 25% vida
@export var optimal_distance: float = 10.0  # Distancia óptima del enemigo
@export var dodge_enabled: bool = true
@export var support_ally: bool = true  # Ayudar a aliados en peligro

var current_health: int = 150
var _fire_timer: float = 0.0
var _target_enemy: Node3D = null
var _follow_target: Node3D = null  # The human player to follow
var nav_agent: NavigationAgent3D
var visual_model: Node3D
var active_weapon: Weapon

# IA avanzada
enum BotState { IDLE, FOLLOW, CHASE, KITE, RETREAT, SUPPORT }
var _bot_state: BotState = BotState.IDLE
var _dodge_direction: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
var _support_target: Node3D = null

signal bot_died

# Animation system
var _anim_player: AnimationPlayer = null
const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walk"
const ANIM_RUN := "Run"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	current_health = max_health
	add_to_group("player")  # Same group so enemies target bots too
	add_to_group("bots")
	# Inicializar estado
	current_health = max_health
	
	visual_model = get_node_or_null("VisualModel")
	
	# Find weapon
	for child in get_children():
		if child is Weapon:
			active_weapon = child
			break
	
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

func _update_targets() -> void:
	# Find enemies with priority (Mage > Rogue > Base > Minion)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_score: float = INF
	
	for e in enemies:
		if not e is Node3D:
			continue
		var enemy = e as Node3D
		var d: float = global_position.distance_to(enemy.global_position)
		if d > 30.0:  # Ignorar enemigos muy lejanos
			continue
		
		# Calcular puntuación de prioridad (menor = mejor)
		var score = d
		# Priorizar enemigos peligrosos
		if enemy.has_method("get_max_health"):
			var enemy_max_hp = enemy.get("max_health")
			if enemy_max_hp == null:
				enemy_max_hp = 100
			if enemy_max_hp > 200:  # Mage/Boss
				score -= 15.0
			elif enemy_max_hp > 150:  # Rogue
				score -= 8.0
			elif enemy_max_hp > 100:  # Base
				score -= 3.0
		# Priorizar enemigos que atacan a aliados cercanos
		if _is_targeting_ally(enemy):
			score -= 10.0
		
		if score < best_score:
			best_score = score
			best_target = enemy
	
	_target_enemy = best_target
	
	# Find human player to follow
	var humans := get_tree().get_nodes_in_group("player")
	var nearest_human_dist: float = INF
	_follow_target = null
	for h in humans:
		if h == self or h.is_in_group("bots"):
			continue
		var d: float = global_position.distance_to((h as Node3D).global_position)
		if d < nearest_human_dist:
			nearest_human_dist = d
			_follow_target = h as Node3D
	
	# Buscar aliado que necesite ayuda
	if support_ally:
		var bots := get_tree().get_nodes_in_group("bots")
		var lowest_health_pct: float = 1.0
		for b in bots:
			if b == self or not (b is Node3D): continue
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

func _is_targeting_ally(enemy: Node3D) -> bool:
	# Verificar si el enemigo está atacando a un aliado
	var enemy_target = enemy.get("target")
	if enemy_target and enemy_target is Node3D:
		if enemy_target.is_in_group("bots"):
			return true
	return false

func _evaluate_bot_state() -> void:
	# Evaluar estado del bot
	var health_pct = float(current_health) / max_health
	
	# Retirarse si vida baja
	if health_pct < retreat_health_pct:
		_bot_state = BotState.RETREAT
		return
	
	# Apoyar aliado en peligro
	if support_ally and _support_target and _support_target != self:
		var ally_hp = _support_target.get("current_health")
		if ally_hp == null:
			ally_hp = 150
		var ally_max_hp = _support_target.get("max_health")
		if ally_max_hp == null:
			ally_max_hp = 150
		if float(ally_hp) / ally_max_hp < 0.4:
			_bot_state = BotState.SUPPORT
			return
	
	# Kiting: mantener distancia óptima
	if _target_enemy:
		var dist_to_enemy = global_position.distance_to(_target_enemy.global_position)
		if dist_to_enemy < optimal_distance * 0.6:
			# Muy cerca - hacer kiting hacia atrás
			_bot_state = BotState.KITE
			return
		elif dist_to_enemy > attack_range * 1.2:
			# Lejos - chase
			_bot_state = BotState.CHASE
			return
		else:
			# En rango óptimo - mantener posición
			_bot_state = BotState.CHASE
	else:
		_bot_state = BotState.FOLLOW

func _move(delta: float) -> void:
	_evaluate_bot_state()
	
	var move_to_node: Node3D = null
	var actual_speed = move_speed
	
	# Actualizar timers de dodge
	if _dodge_timer > 0:
		_dodge_timer -= delta
	
	match _bot_state:
		BotState.KITE:
			# Hacer kiting - alejarse del enemigo mientras disparas
			if _target_enemy:
				var to_enemy = _target_enemy.global_position - global_position
				var retreat_dir = -Vector3(to_enemy.x, 0, to_enemy.z).normalized()
				
				# Añadir movimiento lateral para evitar ser alcanzado
				var strafe = retreat_dir.cross(Vector3.UP) * (1 if randf() > 0.5 else -1)
				var move_dir = (retreat_dir * 0.7 + strafe * 0.3).normalized()
				
				actual_speed = kite_speed
				velocity.x = move_dir.x * actual_speed
				velocity.z = move_dir.z * actual_speed
			
		BotState.RETREAT:
			# Ir hacia el jugador para protegerse
			if _follow_target:
				move_to_node = _follow_target
				actual_speed = kite_speed  # Más rápido al retirarse
			
		BotState.SUPPORT:
			# Ir hacia el aliado que necesita ayuda
			if _support_target:
				move_to_node = _support_target
				actual_speed = kite_speed
			
		BotState.CHASE:
			# Perseguir enemigo
			if _target_enemy and global_position.distance_to(_target_enemy.global_position) > optimal_distance * 0.8:
				move_to_node = _target_enemy
			
		BotState.FOLLOW:
			# Seguir al jugador
			if _follow_target:
				var dist_to_player = global_position.distance_to(_follow_target.global_position)
				if dist_to_player > 3.0:
					move_to_node = _follow_target
	
	# Aplicar movimiento
	if move_to_node:
		nav_agent.target_position = move_to_node.global_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * actual_speed
		velocity.z = dir.z * actual_speed
		
		if visual_model and dir.length() > 0.1:
			var rot := atan2(dir.x, dir.z)
			visual_model.rotation.y = lerp_angle(visual_model.rotation.y, rot, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, actual_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, actual_speed * delta * 5.0)
	
	# Evasión: detectar proyectiles entrantes
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
		if dist < 5.0:  # Proyectil muy cerca
			var proj_dir: Vector3 = proj.get("direction") if proj.get("direction") != null else Vector3.FORWARD
			# Calcular dirección de evasión perpendicular
			var dodge_dir := proj_dir.cross(Vector3.UP).normalized()
			if dodge_dir == Vector3.ZERO:
				dodge_dir = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
			
			_dodge_direction = dodge_dir
			_dodge_timer = 0.5
			break
	
	# Aplicar dodge si está activo
	if _dodge_timer > 0:
		velocity.x += _dodge_direction.x * 15.0 * delta
		velocity.z += _dodge_direction.z * 15.0 * delta

func _try_shoot() -> void:
	if _fire_timer > 0.0 or not _target_enemy or not active_weapon:
		return
	var dist: float = global_position.distance_to(_target_enemy.global_position)
	if dist > attack_range:
		return
	
	_fire_timer = fire_rate
	var shoot_dir := ((_target_enemy.global_position + Vector3(0, 1.0, 0)) - (global_position + Vector3(0, 1.0, 0))).normalized()
	shoot_dir.y = 0.0
	shoot_dir = shoot_dir.normalized()
	var muzzle_pos := global_position + shoot_dir * 1.5 + Vector3(0, 1.0, 0)
	active_weapon.shoot(muzzle_pos, shoot_dir)

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
	
	if is_moving:
		if _target_enemy and global_position.distance_to(_target_enemy.global_position) < attack_range:
			# In attack range - play attack
			if _anim_player.has_animation(ANIM_ATTACK) and _anim_player.current_animation != ANIM_ATTACK:
				_anim_player.play(ANIM_ATTACK)
		elif _anim_player.has_animation(ANIM_RUN):
			if _anim_player.current_animation != ANIM_RUN:
				_anim_player.play(ANIM_RUN)
		elif _anim_player.has_animation(ANIM_WALK):
			if _anim_player.current_animation != ANIM_WALK:
				_anim_player.play(ANIM_WALK)
	else:
		if _anim_player.has_animation(ANIM_IDLE) and _anim_player.current_animation != ANIM_IDLE:
			_anim_player.play(ANIM_IDLE)

func take_damage(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	if current_health <= 0:
		bot_died.emit()
		queue_free()
