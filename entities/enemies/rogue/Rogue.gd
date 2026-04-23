extends EnemyBase

## Rogue â€” usa Skeleton_Rogue.glb (KayKit Skeletons)
## Enemigo rÃ¡pido de cuerpo a cuerpo con dagas

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	attack_range = 3.0  # Mayor rango
	move_speed = 6.72  # +20% (5.6 * 1.2)
	attack_damage = 25  # +67% mÃ¡s daÃ±o
	max_health = 180  # +50% mÃ¡s vida
	current_health = 180
	score_value = 30  # +50% mÃ¡s puntos
	# IA mÃ¡s agresiva
	flank_chance = 0.5  # 50% probabilidad de flanquear
	reaction_time = 0.2  # Reacciona mÃ¡s rÃ¡pido
	_find_anim_player()
	_setup_daggers_visual()
	_setup_glow()  # VISUAL: Glow effect for miniboss

func _setup_glow() -> void:
	# Add glow light to make miniboss stand out
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.0, 1.0)  # Orange glow
	light.light_energy = 0.5
	light.omni_range = 8.0
	add_child(light)
	
	# Pulsing animation
	var tween = create_tween().set_loops()
	tween.tween_property(light, "light_energy", 0.8, 1.0)
	tween.tween_property(light, "light_energy", 0.5, 1.0)

func _setup_daggers_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	# AÃ±adir dagas visuales al rogue
	var dagger_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Dagger.gltf"
	if ResourceLoader.exists(dagger_path):
		var dagger_right = load(dagger_path).instantiate()
		visual.add_child(dagger_right)
		dagger_right.position = Vector3(0.3, 0.6, 0.2)
		dagger_right.rotation_degrees = Vector3(0, 0, -90)
		
		var dagger_left = load(dagger_path).instantiate()
		visual.add_child(dagger_left)
		dagger_left.position = Vector3(-0.3, 0.6, 0.2)
		dagger_left.rotation_degrees = Vector3(0, 0, 90)

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
	
	# DaÃ±o en Ã¡rea corto alcance
	if multiplayer.is_server():
		var enemies = get_tree().get_nodes_in_group("player")
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(global_position) < attack_range:
				if e.has_method("take_damage"): 
					e.take_damage(int(attack_damage * damage_multiplier))
					# Efecto visual de sangre/daÃ±o
					_blood_effect(e.global_position)

func _blood_effect(pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	
	var blood = CSGSphere3D.new()
	blood.radius = 0.3
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.0, 0.0)
	blood.material = mat
	scene.add_child(blood)
	blood.global_position = pos + Vector3(0, 0.5, 0)
	
	var tw = create_tween()
	tw.tween_property(blood, "scale", Vector3.ZERO, 0.3)
	tw.chain().tween_callback(blood.queue_free)
