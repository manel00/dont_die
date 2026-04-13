## BotPlayer.gd
## AI-controlled ally that follows the human player(s) and auto-shoots enemies.
## Uses the same weapons system as PlayerController.

class_name BotPlayer
extends CharacterBody3D

@export_category("Bot Stats")
@export var max_health: int = 100
@export var move_speed: float = 7.0
@export var attack_range: float = 12.0
@export var fire_rate: float = 0.35
@export var gravity: float = 20.0

var current_health: int = 100
var _fire_timer: float = 0.0
var _target_enemy: Node3D = null
var _follow_target: Node3D = null  # The human player to follow
var nav_agent: NavigationAgent3D
var visual_model: Node3D
var active_weapon: Weapon

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
	# Find nearest enemy
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	_target_enemy = null
	for e in enemies:
		if not e is Node3D:
			continue
		var d: float = global_position.distance_to((e as Node3D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			_target_enemy = e as Node3D
	
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

func _move(delta: float) -> void:
	var move_to_node: Node3D = null
	
	# Chase enemy if in range, otherwise follow the human player
	if _target_enemy and global_position.distance_to(_target_enemy.global_position) < attack_range:
		move_to_node = _target_enemy
	elif _follow_target:
		# Follow human player - stay within 5 meters max
		var dist_to_player = global_position.distance_to(_follow_target.global_position)
		if dist_to_player > 3.0:  # Start following at 3m, stay close
			move_to_node = _follow_target
		elif dist_to_player > 5.0:  # Force follow if > 5m
			move_to_node = _follow_target
	
	if move_to_node:
		nav_agent.target_position = move_to_node.global_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		if visual_model and dir.length() > 0.1:
			var rot := atan2(dir.x, dir.z)
			visual_model.rotation.y = lerp_angle(visual_model.rotation.y, rot, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
	
	_update_animation()

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

func _load_animations(anim_path: String) -> void:
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
