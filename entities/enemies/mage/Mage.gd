extends EnemyBase

## Mage — usa Skeleton_Mage.glb (KayKit Skeletons)

var attack_cooldown: float = 2.0
var _attack_timer: float = 0.0
var projectile_scene := preload("res://entities/player/weapons/Projectile.tscn")

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	attack_range = 10.0
	move_speed = 2.0
	score_value = 25
	_find_anim_player()
	_setup_staff_visual()
	_setup_glow()  # VISUAL: Glow effect for miniboss

func _setup_glow() -> void:
	# Add glow light to make miniboss stand out
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.5, 1.0, 1.0)  # Blue-ish glow
	light.light_energy = 0.5
	light.omni_range = 8.0
	add_child(light)
	
	# Pulsing animation
	var tween = create_tween().set_loops()
	tween.tween_property(light, "light_energy", 0.8, 1.0)
	tween.tween_property(light, "light_energy", 0.5, 1.0)

func _setup_staff_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	var staff_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Staff.gltf"
	if ResourceLoader.exists(staff_path):
		var staff = load(staff_path).instantiate()
		visual.add_child(staff)
		staff.position = Vector3(0.4, 0.8, -0.2)
		staff.rotation_degrees = Vector3(0, 90, 0)

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

func _load_animations(anim_path: String) -> void:
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
		_attack_timer = attack_cooldown
		
		# Disparar proyectil verde
		var proj := projectile_scene.instantiate()
		proj.hit_group = "player"
		proj.damage = attack_damage
		
		# Material verde neón para el proyectil del mago
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 1.0, 0.3)
		material.emission_enabled = true
		material.emission = Color(0.0, 0.8, 0.2)
		material.emission_energy_multiplier = 2.0
		
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position + Vector3(0, 0.5, 0) + move_dir * 1.0
		proj.direction = move_dir
		
		# Aplicar material al mesh del proyectil
		var mesh := proj.get_node_or_null("CSGSphere3D") as GeometryInstance3D
		if not mesh:
			# Buscar cualquier MeshInstance3D o CSG
			for child in proj.get_children():
				if child is GeometryInstance3D:
					mesh = child
					break
		if mesh:
			mesh.material_override = material
