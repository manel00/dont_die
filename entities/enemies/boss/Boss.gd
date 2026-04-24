extends EnemyBase

## BOSS FINAL - Mecha inteligente con ataques ranged y melee
## Persigue jugadores Y bots, nunca se queda quieto

var _attack_timer: float = 0.0
var _strafe_dir: int = 1
var projectile_scene: PackedScene

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

const BOSS_MECHA_INDEX: int = 4

# Distancias de ataque
const MELEE_RANGE: float = 5.0
const RANGED_MIN_RANGE: float = 15.0

func _ready() -> void:
	max_health = 3000
	super._ready()
	move_speed = 3.0
	attack_damage = 100
	score_value = 500
	attack_cooldown = 1.2
	attack_range = 50.0
	
	# IA muy agresiva
	flank_chance = 0.7
	reaction_time = 0.1
	
	# Cargar escena de proyectil
	projectile_scene = preload("res://entities/player/weapons/Projectile.tscn")
	
	_find_anim_player()
	_apply_mecha_texture_by_index(BOSS_MECHA_INDEX)
	_setup_boss_glow()
	
	# Escala grande para el boss
	var boss_visual := get_node_or_null("VisualModel") as Node3D
	if boss_visual:
		boss_visual.scale *= 2.0
		_base_scale = boss_visual.scale
		_scale_initialized = true

func _setup_boss_glow() -> void:
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.4, 1.0)  # Verde esmeralda
	light.light_energy = 1.0
	light.omni_range = 15.0
	add_child(light)
	
	var tween = create_tween().set_loops()
	tween.tween_property(light, "light_energy", 1.5, 1.0)
	tween.tween_property(light, "light_energy", 1.0, 1.0)

func _find_anim_player() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	for child in visual.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			return
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				_anim_player = grandchild
				return

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if current_state == State.ATTACK:
		# BOSS NUNCA SE QUEDA QUIETO: movimiento lento mientras ataca
		_move_while_attacking(delta)
		_attack_timer -= delta
	
	_update_animation()

func _move_while_attacking(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	# Strafe lateral mientras ataca
	_strafe_dir = _strafe_dir if randf() > 0.02 else -_strafe_dir
	var to_target = target.global_position - global_position
	var move_dir = Vector3(to_target.x, 0, to_target.z).normalized()
	var strafe = move_dir.cross(Vector3.UP) * _strafe_dir
	
	# Mantiene distancia óptima para atacar
	var dist = global_position.distance_to(target.global_position)
	var speed_mult = 0.4
	
	if dist > attack_range * 0.8:
		# Acércate si estás muy lejos
		velocity = move_dir * move_speed * speed_mult
	elif dist < MELEE_RANGE:
		# Aléjate un poco si estás muy cerca
		velocity = -move_dir * move_speed * speed_mult * 0.5
	else:
		# Strafe lateral en rango de ataque
		velocity = strafe * move_speed * speed_mult * 0.7

func _update_animation() -> void:
	if not _anim_player:
		return
	match current_state:
		State.IDLE:
			if _anim_player.has_animation(ANIM_IDLE) and _anim_player.current_animation != ANIM_IDLE:
				_anim_player.play(ANIM_IDLE)
		State.CHASE:
			if _anim_player.has_animation(ANIM_WALK) and _anim_player.current_animation != ANIM_WALK:
				_anim_player.play(ANIM_WALK)
		State.ATTACK:
			if _anim_player.has_animation(ANIM_WALK) and _anim_player.current_animation != ANIM_WALK:
				_anim_player.play(ANIM_WALK)  # Usa walk incluso en ataque
		State.STRAFE:
			if _anim_player.has_animation(ANIM_WALK) and _anim_player.current_animation != ANIM_WALK:
				_anim_player.play(ANIM_WALK)
		State.DEAD:
			_anim_player.stop()

func _perform_attack() -> void:
	if target == null: return
	
	var dir := global_position.direction_to(target.global_position)
	var move_dir := Vector3(dir.x, 0, dir.z).normalized()
	rotation.y = atan2(move_dir.x, move_dir.z)
	
	var dist = global_position.distance_to(target.global_position)
	
	if dist <= MELEE_RANGE:
		# ATAQUE MELEE: Onda expansiva
		_perform_melee_attack(move_dir)
	elif dist <= attack_range:
		# ATAQUE RANGED: Bola de energía
		_perform_ranged_attack(move_dir)
	else:
		pass  # Demasiado lejos

func _perform_ranged_attack(dir: Vector3) -> void:
	# Bola de energía verde esmeralda
	var proj = projectile_scene.instantiate()
	proj.scale = Vector3(3.0, 3.0, 3.0)
	proj.hit_group = "player"
	proj.damage = int(attack_damage * damage_multiplier)
	proj.speed = 25.0
	
	var scene = get_tree().current_scene
	if not scene:
		proj.queue_free()
		return
	scene.add_child(proj)
	
	proj.global_position = global_position + Vector3(0, 1.5, 0) + dir * 1.5
	proj.direction = dir
	
	# Material verde esmeralda con glow
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.9, 0.4)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.8, 0.3)
	material.emission_energy_multiplier = 4.0
	
	var mesh = proj.get_node_or_null("CSGSphere3D") as GeometryInstance3D
	if not mesh:
		for child in proj.get_children():
			if child is GeometryInstance3D:
				mesh = child
				break
	if mesh:
		mesh.material_override = material
	
	# Luz verde
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.5)
	light.light_energy = 3.0
	light.omni_range = 6.0
	proj.add_child(light)

func _perform_melee_attack(_dir: Vector3 = Vector3.ZERO) -> void:
	# Onda expansiva melee con daño en área
	var targets = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("bots")
	
	for t in targets:
		if is_instance_valid(t) and t.has_method("take_damage"):
			var dist = global_position.distance_to(t.global_position)
			if dist <= MELEE_RANGE * 2:
				t.take_damage(int(attack_damage * 1.2 * damage_multiplier))
	
	# Efecto visual de onda expansiva
	_create_shockwave_effect()
	
	# Screen shake pequeño
	var ss = get_node_or_null("/root/ScreenShake")
	if ss:
		ss.shake(0.3, 0.4)

func _create_shockwave_effect() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	# Anillo expansivo
	var shockwave = CSGSphere3D.new()
	shockwave.radius = 0.5
	shockwave.radial_segments = 16
	shockwave.rings = 4
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.5, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.4)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material = mat
	
	scene.add_child(shockwave)
	shockwave.global_position = global_position + Vector3(0, 0.5, 0)
	
	# Animación de expansión
	var tw = scene.create_tween().set_parallel(true)
	tw.tween_property(shockwave, "scale", Vector3(8.0, 1.0, 8.0), 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(shockwave.queue_free)
