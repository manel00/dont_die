extends EnemyBase

## Ranger â€” usa Skeleton_Rogue.glb (KayKit Skeletons) + Crossbow

var attack_cooldown: float = 1.8
var _attack_timer: float = 0.0
var projectile_scene := preload("res://entities/player/weapons/Projectile.tscn")

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	attack_range = 18.0  # Mayor rango
	move_speed = 1.4  # 80% mÃ¡s lento
	max_health = 180  # +50% mÃ¡s vida
	current_health = max_health
	attack_damage = 30  # +100% mÃ¡s daÃ±o
	score_value = 60  # +50% mÃ¡s puntos
	attack_cooldown = 0.7  # Alta cadencia — mecha agresivo
	_find_anim_player()
	
	# Attach Crossbow to hand (procedural for now, or just ensure it's in the scene)
	_setup_weapon_visual()

func _setup_weapon_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	
	# Load Crossbow asset
	var weapon_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Crossbow.gltf"
	if ResourceLoader.exists(weapon_path):
		var weapon_scene = load(weapon_path)
		var weapon = weapon_scene.instantiate()
		# Find hand bone or just place it as a child of VisualModel for simplicity in this prototype
		visual.add_child(weapon)
		weapon.position = Vector3(0.3, 0.8, -0.2) # Hardcoded offset for the hand position
		weapon.rotation_degrees = Vector3(0, 90, 0)

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
		_attack_timer = attack_cooldown
		_shoot_electric_bolt(move_dir)

## Dispara un bolt eléctrico amarillo de alta cadencia.
func _shoot_electric_bolt(move_dir: Vector3) -> void:
	var proj := projectile_scene.instantiate()
	proj.hit_group = "player"
	proj.damage = attack_damage
	proj.speed = 40.0  # Muy rápido — mecha agresivo

	# Color eléctrico amarillo brillante
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.95, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.0)
	material.emission_energy_multiplier = 4.0

	var scene := get_tree().current_scene
	if not scene:
		proj.queue_free()
		return

	scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.0, 0) + move_dir * 1.0
	proj.direction = move_dir

	# Aplicar material eléctrico al mesh del proyectil
	var mesh := proj.get_node_or_null("CSGSphere3D") as GeometryInstance3D
	if not mesh:
		for child in proj.get_children():
			if child is GeometryInstance3D:
				mesh = child
				break
	if mesh:
		mesh.material_override = material

	# Luz eléctrica amarilla en el proyectil
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 1.0, 0.2)
	light.light_energy = 3.0
	light.omni_range = 5.0
	proj.add_child(light)

	# Liberar luz cuando el proyectil muera
	proj.tree_exiting.connect(func():
		if is_instance_valid(light):
			light.queue_free()
	)
