extends EnemyBase

## ShieldEnemy — ahora es ranged (arquero con escudo)

var projectile_scene := preload("res://entities/player/weapons/Projectile.tscn")
var attack_cooldown: float = 1.2
var _attack_timer: float = 0.0

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	max_health = 350  # +50% más vida
	move_speed = 1.2  # Más lento por ser ranged
	attack_damage = 40  # +100% más daño
	attack_range = 40.0  # Rango triple
	score_value = 70  # +50% más puntos
	attack_cooldown = 1.0  # Disparar cada segundo
	_find_anim_player()

func _shoot_energy_ball(move_dir: Vector3) -> void:
	var proj := projectile_scene.instantiate()
	proj.scale = Vector3(2.0, 2.0, 2.0)
	proj.hit_group = "player"
	proj.damage = int(attack_damage * damage_multiplier)
	proj.speed = 35.0
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 1.0)  # Azul hielo
	material.emission_enabled = true
	material.emission = Color(0.3, 0.5, 1.0)
	material.emission_energy_multiplier = 3.0
	
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(proj)
		proj.global_position = global_position + Vector3(0, 1.5, 0)
		proj.global_position += move_dir * 1.5
		proj.velocity = move_dir * proj.speed
		proj.set_surface_override_material(0, material)

func _find_anim_player() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	for child in visual.get_children():
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

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if current_state == State.ATTACK:
		_attack_timer -= delta
	
	_update_animation()

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
			if _anim_player.has_animation(ANIM_ATTACK) and _anim_player.current_animation != ANIM_ATTACK:
				_anim_player.play(ANIM_ATTACK)
		State.DEAD:
			_anim_player.stop()


func _perform_attack() -> void:
	if target == null: return
	
	var dir := global_position.direction_to(target.global_position)
	var move_dir := Vector3(dir.x, 0, dir.z).normalized()
	rotation.y = atan2(move_dir.x, move_dir.z)
	
	if _attack_timer <= 0.0:
		_shoot_energy_ball(move_dir)
		_attack_timer = attack_cooldown
