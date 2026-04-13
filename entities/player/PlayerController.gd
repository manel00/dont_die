class_name PlayerController
extends CharacterBody3D

@export_category("Stats")
@export var max_health: int = 100
var current_health: int = 100

@export_category("Movement Settings")
@export var move_speed: float = 24.0  # 3x faster (was 8.0)
@export var acceleration: float = 36.0  # Scaled up (was 12.0)
@export var gravity: float = 20.0

var visual_model: Node3D
var hud: CanvasLayer
var last_look_dir: Vector3 = Vector3.FORWARD

# Abilities timers
var katana_cooldown: float = 0.0
var _katana_timer: float = 0.0

var fireball_cooldown: float = 0.0
var _fireball_timer: float = 0.0

var explosion_cooldown: float = 0.0
var _explosion_timer: float = 0.0

var has_weapon: bool = false
var weapon_cooldown: float = 0.0
var _weapon_timer: float = 0.0

var _base_scale: Vector3 = Vector3.ZERO
var _anim_time: float = 0.0

@onready var fireball_scene := preload("res://entities/player/weapons/MagicProjectile.tscn")
@onready var projectile_scene := preload("res://entities/player/weapons/Projectile.tscn")

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

var _anim_player: AnimationPlayer = null

func _ready() -> void:
	current_health = max_health
	add_to_group("player")
	visual_model = get_node_or_null("VisualModel")
	_find_anim_player()
	
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("register_player"):
		gm.register_player(self)
		
	hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.update_health(current_health, max_health)
	_setup_blade_visual()

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
	
	_animate_visuals(delta)
	
	if hud:
		# Update HUD with ability statuses
		pass

func _update_timers(delta: float) -> void:
	if _katana_timer > 0: _katana_timer -= delta
	if _fireball_timer > 0: _fireball_timer -= delta
	if _explosion_timer > 0: _explosion_timer -= delta
	if _weapon_timer > 0: _weapon_timer -= delta

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
	# Ability 0: Katana (Q or KEY_0 or KEY_KP_0)
	if (Input.is_action_just_pressed("weapon_0") or Input.is_physical_key_pressed(KEY_0) or Input.is_physical_key_pressed(KEY_KP_0)) and _katana_timer <= 0:
		_attack_katana()
	
	# Ability 1: Fireball (1 or KEY_KP_1)
	if (Input.is_action_just_pressed("weapon_1") or Input.is_physical_key_pressed(KEY_1) or Input.is_physical_key_pressed(KEY_KP_1)) and _fireball_timer <= 0:
		_cast_fireball()
		
	# Ability 2: AOE Explosion (2 or KEY_KP_2)
	if (Input.is_action_just_pressed("weapon_2") or Input.is_physical_key_pressed(KEY_2) or Input.is_physical_key_pressed(KEY_KP_2)) and _explosion_timer <= 0:
		_aoe_explosion()
		
	# Ability 3: Weapon (3 or KEY_KP_3 if has_weapon) - REMOVED mouse click
	var weapon_input = Input.is_physical_key_pressed(KEY_3) or Input.is_physical_key_pressed(KEY_KP_3)
	if weapon_input and has_weapon and _weapon_timer <= 0:
		_fire_weapon()

func _attack_katana() -> void:
	_katana_timer = katana_cooldown
	rpc_execute_katana.rpc(global_position, last_look_dir)

@rpc("any_peer", "call_local")
func rpc_execute_katana(pos: Vector3, l_dir: Vector3) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_shoot"): am.play_shoot()
	
	if multiplayer.is_server():
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e is Node3D:
				var to_enemy = e.global_position - pos
				if to_enemy.length() < 4.5 and to_enemy.normalized().dot(l_dir) > 0.4:
					if e.has_method("take_damage"): e.take_damage(80)
	
	if visual_model:
		var tw = create_tween()
		tw.tween_property(visual_model, "scale", _base_scale * 1.4, 0.05)
		tw.tween_property(visual_model, "scale", _base_scale, 0.1)
		
	# EFECTO VISUAL: Ice Katana Slash
	var slash = CSGBox3D.new()
	slash.size = Vector3(3.0, 0.1, 0.8)
	var mat_slash = StandardMaterial3D.new()
	mat_slash.albedo_color = Color(0.0, 0.8, 1.0, 0.9)
	mat_slash.emission_enabled = true
	mat_slash.emission = Color(0.0, 0.5, 1.0)
	mat_slash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.material = mat_slash
	get_tree().current_scene.add_child(slash)
	slash.global_position = pos + Vector3(0, 1.0, 0) + l_dir * 1.5
	slash.look_at(slash.global_position + l_dir, Vector3.UP)
	
	var tw_slash = create_tween().set_parallel(true)
	tw_slash.tween_property(slash, "scale", Vector3(1.5, 0.5, 2.5), 0.2)
	tw_slash.tween_property(slash, "global_position", slash.global_position + l_dir * 2.0, 0.2)
	tw_slash.tween_property(mat_slash, "albedo_color:a", 0.0, 0.2)
	tw_slash.chain().tween_callback(slash.queue_free)

func _cast_fireball() -> void:
	_fireball_timer = fireball_cooldown
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
	_explosion_timer = explosion_cooldown
	rpc_execute_aoe.rpc(global_position)

@rpc("any_peer", "call_local")
func rpc_execute_aoe(pos: Vector3) -> void:
	# Visual effect for explosion
	var sphere = CSGSphere3D.new()
	sphere.radius = 0.5
	sphere.radial_segments = 32
	sphere.rings = 16
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	get_tree().current_scene.add_child(sphere)
	sphere.global_position = pos + Vector3(0, 0.5, 0)
	
	# EFECTO VISUAL: Anillo de impacto secundario
	var ring = CSGTorus3D.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 1.0
	ring.sides = 32
	var mat_ring = StandardMaterial3D.new()
	mat_ring.albedo_color = Color(1.0, 0.0, 0.5, 0.9)
	mat_ring.emission_enabled = true
	mat_ring.emission = Color(1.0, 0.2, 0.5)
	mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = mat_ring
	get_tree().current_scene.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.2, 0)
	
	var tw = create_tween().set_parallel(true)
	# Animar la esfera
	tw.tween_property(sphere, "radius", 6.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(sphere.queue_free)
	
	var tw_ring = create_tween().set_parallel(true)
	# Animar el anillo
	tw_ring.tween_property(ring, "inner_radius", 6.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(ring, "outer_radius", 7.5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(mat_ring, "albedo_color:a", 0.0, 0.5)
	tw_ring.chain().tween_callback(ring.queue_free)
	
	if multiplayer.is_server():
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(pos) < 4.0:
				if e.has_method("take_damage"): e.take_damage(80)

func _fire_weapon() -> void:
	if not has_weapon: return
	_weapon_timer = weapon_cooldown
	if multiplayer.is_server():
		rpc_spawn_projectile.rpc(global_position + Vector3(0, 0.5, 0) + last_look_dir * 1.2, last_look_dir)
	else:
		rpc_id(1, "rpc_request_projectile", global_position + Vector3(0, 0.5, 0) + last_look_dir * 1.2, last_look_dir)

@rpc("any_peer")
func rpc_request_projectile(pos: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server(): rpc_spawn_projectile.rpc(pos, dir)

@rpc("authority", "call_local")
func rpc_spawn_projectile(pos: Vector3, dir: Vector3) -> void:
	var p = projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.direction = dir

func _animate_visuals(delta: float) -> void:
	if not visual_model: return
	var speed_ratio = Vector2(velocity.x, velocity.z).length() / move_speed
	
	if _anim_player:
		if speed_ratio > 0.1:
			if _anim_player.has_animation("Walk"):
				if _anim_player.current_animation != "Walk": _anim_player.play("Walk")
			elif _anim_player.has_animation("Run"):
				if _anim_player.current_animation != "Run": _anim_player.play("Run")
		else:
			if _anim_player.has_animation("Idle"):
				if _anim_player.current_animation != "Idle": _anim_player.play("Idle")
	
	# Fallback/Additive procedural animation
	if speed_ratio > 0.1:
		_anim_time += delta * 18.0
		if not _anim_player:
			visual_model.scale.y = lerp(visual_model.scale.y, _base_scale.y * (1.0 + sin(_anim_time) * 0.15), 15.0 * delta)
			visual_model.position.y = abs(sin(_anim_time)) * 0.2
	else:
		if not _anim_player:
			visual_model.scale = lerp(visual_model.scale, _base_scale, 10.0 * delta)
			visual_model.position.y = lerp(visual_model.position.y, 0.0, 10.0 * delta)

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
	global_position = Vector3(0, 5, 0) # Fallback simple respawn

func pickup_weapon() -> void:
	has_weapon = true
	print("Weapon picked up!")
	
	# Pickup animation
	if _anim_player and _anim_player.has_animation("Interact"):
		_anim_player.play("Interact")
	elif _anim_player and _anim_player.has_animation("Pickup"):
		_anim_player.play("Pickup")
	elif visual_model:
		# Visual fallback
		var tw = create_tween().set_parallel(true)
		tw.tween_property(visual_model, "position:y", 1.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(visual_model, "rotation_degrees:y", visual_model.rotation_degrees.y + 360, 0.4)
		tw.chain().tween_property(visual_model, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_level_up"):
		am.play_level_up()
