extends EnemyBase

## Minion â€” usa Skeleton_Minion.glb (KayKit Skeletons)
## Enemigo dÃ©bil pero numeroso, ataca en grupo

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	attack_range = 2.0
	move_speed = 3.2  # 80% mÃ¡s lento
	attack_damage = 15  # +87% mÃ¡s daÃ±o
	max_health = 120   # +50% mÃ¡s resistente
	current_health = 120
	score_value = 10   # +100% mÃ¡s puntos
	_find_anim_player()
	_setup_visual()

func _setup_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	# El minion es mÃ¡s pequeÃ±o
	visual.scale = Vector3(0.35, 0.35, 0.35)

func _find_anim_player() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	for child in visual.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb")
			return
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				_anim_player = grandchild
				_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb")
				return

func _load_animations(_anim_path := "") -> void:
	# SIMPLIFIED: Las animaciones vienen incluidas en los modelos .glb
	pass

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
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
				# AnimaciÃ³n mÃ¡s rÃ¡pida para el minion
				_anim_player.speed_scale = 1.5
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
	
	# DaÃ±o en Ã¡rea muy corto alcance
	if multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if p.is_in_group("bots"):
				continue
			if is_instance_valid(p) and p.global_position.distance_to(global_position) < attack_range:
				if p.has_method("take_damage"): 
					p.take_damage(attack_damage)

func die() -> void:
	# Override para aÃ±adir efecto de muerte de minion (explosiÃ³n pequeÃ±a)
	_death_effect()
	super.die()

func _death_effect() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	
	var burst = CSGSphere3D.new()
	burst.radius = 0.2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.2, 0.0)
	burst.material = mat
	scene.add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.3, 0)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(burst, "scale", Vector3(3, 3, 3), 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(burst.queue_free)
