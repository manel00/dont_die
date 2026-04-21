## BotPlayer.gd
## AI-controlled ally that follows the human player(s) and auto-shoots enemies.
## Uses the same weapons system as PlayerController.

class_name BotPlayer
extends CharacterBody3D

@export_category("Bot Stats")
@export var max_health: int = 150  # +50% mÃ¡s vida
@export var move_speed: float = 2.34  # +30%
@export var attack_range: float = 15.0  # Mayor rango
@export var fire_rate: float = 0.28  # +25% mÃ¡s rÃ¡pido
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
@export var kite_speed: float = 2.86  # +30%
@export var retreat_health_pct: float = 0.25  # Retirarse al 25% vida
@export var optimal_distance: float = 10.0  # Distancia Ã³ptima del enemigo
@export var dodge_enabled: bool = true
@export var support_ally: bool = true  # Ayudar a aliados en peligro

var current_health: int = 150
var _fire_timer: float = 0.0
var _target_enemy: Node3D = null
var _follow_target: Node3D = null  # The human player to follow
var nav_agent: NavigationAgent3D
var visual_model: Node3D
var active_weapon: Node3D

@onready var bot_projectile_scene := preload("res://entities/player/weapons/StylooRangedProjectile.tscn")

# IA avanzada
enum BotState { IDLE, FOLLOW, CHASE, KITE, RETREAT, SUPPORT }
var _bot_state: BotState = BotState.IDLE
var _dodge_direction: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
var _support_target: Node3D = null
var _last_melee_target: Node3D = null

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
	
	# Initialize cooldowns
	_attack_cooldown = 0.0
	_melee_cooldown = 0.0
	_fireball_cooldown = 0.0
	_mode_switch_timer = 2.0  # Switch combat mode every 2 seconds
	
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
		
		# Ocultar todos los mesh de los esqueletos originales
		for child in visual.find_children("*", "MeshInstance3D", true, false):
			child.hide()
			
		var mecha_node: Node3D = null
		if obj_mesh is PackedScene:
			mecha_node = obj_mesh.instantiate()
		elif obj_mesh is Mesh:
			mecha_node = MeshInstance3D.new()
			mecha_node.mesh = obj_mesh
			
		if mecha_node:
			visual.add_child(mecha_node)
			if mecha_node is MeshInstance3D:
				mecha_node.set_surface_override_material(0, mat)
			else:
				for mi in mecha_node.find_children("*", "MeshInstance3D", true, false):
					mi.set_surface_override_material(0, mat)
			
			mecha_node.scale = Vector3(1.0, 1.0, 1.0)
			mecha_node.position = Vector3(0, 0, 0)
			mecha_node.rotation_degrees = Vector3(0, 180, 0)
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
		
		# Calcular puntuaciÃ³n de prioridad (menor = mejor)
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
	
	# Find human player to follow - prioritize staying close to ANY player
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
	
	# If no human found, stay close to any nearby bot
	if _follow_target == null:
		var bots := get_tree().get_nodes_in_group("bots")
		for b in bots:
			if b == self or not (b is Node3D): continue
			var d: float = global_position.distance_to((b as Node3D).global_position)
			if d < 8.0 and d < nearest_human_dist:
				nearest_human_dist = d
				_follow_target = b as Node3D
	
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

func _evaluate_bot_state() -> void:
	# Evaluar estado del bot
	var health_pct = float(current_health) / max_health
	
	# Pick up weapon if nearby
	if _nearby_weapon:
		_bot_state = BotState.FOLLOW  # Will move toward weapon
		return
	
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
	
	# Update combat mode based on distance
	_update_combat_mode()
	
	# Kiting: mantener distancia Ã³ptima
	if _target_enemy:
		var dist_to_enemy = global_position.distance_to(_target_enemy.global_position)
		if _current_combat_mode == CombatMode.MELEE:
			# For melee, get close
			if dist_to_enemy > 3.0:
				_bot_state = BotState.CHASE
			else:
				_bot_state = BotState.CHASE  # Stay close for melee
		elif dist_to_enemy < optimal_distance * 0.5 and _current_combat_mode == CombatMode.RANGED:
			# Muy cerca for ranged - kite back
			_bot_state = BotState.KITE
			return
		elif dist_to_enemy > attack_range * 1.2:
			# Lejos - chase
			_bot_state = BotState.CHASE
			return
		else:
			# En rango Ã³ptimo - mantener posiciÃ³n
			_bot_state = BotState.CHASE
	else:
		_bot_state = BotState.FOLLOW

func _update_combat_mode() -> void:
	# Switch combat mode periodically
	if _mode_switch_timer <= 0.0 and _target_enemy:
		_mode_switch_timer = 2.0 + randf() * 2.0  # 2-4 seconds
		var dist = global_position.distance_to(_target_enemy.global_position)
		
		# Choose mode based on distance
		if dist < 4.0:
			# Close range - prefer melee
			_current_combat_mode = CombatMode.MELEE if randf() > 0.3 else CombatMode.FIREBALL
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
	
	var move_to_node: Node3D = null
	var actual_speed = move_speed
	
	# Actualizar timers de dodge
	if _dodge_timer > 0:
		_dodge_timer -= delta
	
	# Handle weapon pickup
	if _nearby_weapon and _bot_state == BotState.FOLLOW:
		var dist_to_weapon = global_position.distance_to(_nearby_weapon.global_position)
		if dist_to_weapon < 1.5:
			# Pick up the weapon
			if _nearby_weapon.has_method("pickup"):
				_nearby_weapon.pickup(self)
			_nearby_weapon = null
		else:
			move_to_node = _nearby_weapon
			actual_speed = kite_speed
	
	match _bot_state:
		BotState.KITE:
			# Hacer kiting - alejarse del enemigo mientras disparas
			if _target_enemy:
				var to_enemy = _target_enemy.global_position - global_position
				var retreat_dir = -Vector3(to_enemy.x, 0, to_enemy.z).normalized()
				
				# AÃ±adir movimiento lateral para evitar ser alcanzado
				var strafe = retreat_dir.cross(Vector3.UP) * (1 if randf() > 0.5 else -1)
				var move_dir = (retreat_dir * 0.7 + strafe * 0.3).normalized()
				
				actual_speed = kite_speed
				velocity.x = move_dir.x * actual_speed
				velocity.z = move_dir.z * actual_speed
			
		BotState.RETREAT:
			# Ir hacia el jugador para protegerse
			if _follow_target:
				move_to_node = _follow_target
				actual_speed = kite_speed  # MÃ¡s rÃ¡pido al retirarse
			
		BotState.SUPPORT:
			# Ir hacia el aliado que necesita ayuda
			if _support_target:
				move_to_node = _support_target
				actual_speed = kite_speed
			
		BotState.CHASE:
			# Perseguir enemigo - adjust distance based on combat mode
			if _target_enemy:
				var dist_to_enemy = global_position.distance_to(_target_enemy.global_position)
				var target_dist = optimal_distance
				if _current_combat_mode == CombatMode.MELEE:
					target_dist = 2.5  # Get very close for melee
				elif _current_combat_mode == CombatMode.FIREBALL:
					target_dist = 8.0
				
				if dist_to_enemy > target_dist:
					move_to_node = _target_enemy
				elif dist_to_enemy < target_dist * 0.7 and _current_combat_mode != CombatMode.MELEE:
					# Too close for ranged, back up
					var to_enemy = _target_enemy.global_position - global_position
					var retreat_dir = -Vector3(to_enemy.x, 0, to_enemy.z).normalized()
					velocity.x = retreat_dir.x * kite_speed * 0.5
					velocity.z = retreat_dir.z * kite_speed * 0.5
					return
			
		BotState.FOLLOW:
			# Follow player - stay close
			if _follow_target:
				var dist_to_player = global_position.distance_to(_follow_target.global_position)
				if dist_to_player > 4.0:  # Stay within 4 units
					move_to_node = _follow_target
			elif _target_enemy == null:
				# No target, patrol near player
				if _follow_target:
					var patrol_offset = Vector3(randf() - 0.5, 0, randf() - 0.5) * 3.0
					var patrol_target = _follow_target.global_position + patrol_offset
					var to_patrol = (patrol_target - global_position).normalized()
					velocity.x = to_patrol.x * move_speed * 0.3
					velocity.z = to_patrol.z * move_speed * 0.3
					return
	
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
	
	# EvasiÃ³n: detectar proyectiles entrantes
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
	
	# Create melee slash effect
	if multiplayer.is_server():
		var slash_pos = (global_position + _target_enemy.global_position) / 2.0
		slash_pos.y = global_position.y + 1.0
		_rpc_spawn_melee_slash.rpc(slash_pos, _target_enemy.global_position - global_position)
	
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
func pickup_styloo_weapon(_weapon_name: String, _data: Dictionary) -> void:
	# El bot se hace más poderoso en lugar de cambiar de modelo complejo
	max_health += 50
	current_health = max_health
	fire_rate = max(0.1, fire_rate - 0.05)

func pickup_weapon(weapon_type: String) -> void:
	pickup_styloo_weapon(weapon_type, {})

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
