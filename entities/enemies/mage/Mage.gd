extends EnemyBase

## Mage â€” usa Skeleton_Mage.glb (KayKit Skeletons)
## MINIBOSS: Ataque a distancia con proyectiles elementales (hielo, fuego, electric)

# El attack_cooldown ahora se hereda de EnemyBase
var projectile_scene := preload("res://entities/player/weapons/Projectile.tscn")

# Elemental projectile types
enum ElementalType { ICE, FIRE, ELECTRIC }

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	attack_range = 45.0  # Triple de rango (15.0 * 3)
	move_speed = 1.6  # 80% mÃ¡s lento
	max_health = 350  # +75% mÃ¡s vida
	current_health = max_health
	attack_damage = 50  # +43% mÃ¡s daÃ±o
	score_value = 75  # +50% mÃ¡s puntos por ser miniboss
	attack_cooldown = 1.0  # Disparar cada segundo sin parar (petición usuario)
	_find_anim_player()
	_setup_staff_visual()
	_setup_glow()
	_apply_random_mecha_texture()  # MINIBOSS: Mantener identidad visual aunque el Base ya limpie doble carga

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
	
	# MINIBOSS: Lanzar 3 proyectiles elementales en abanico
	for i in range(3):
			var element := (ElementalType.ICE + i) % 3 as ElementalType
			_shoot_elemental_projectile(move_dir, element, i - 1)

func _shoot_elemental_projectile(base_dir: Vector3, element: ElementalType, spread_index: int) -> void:
	"""Dispara un proyectil elemental con color y efecto segÃºn el tipo."""
	var proj := projectile_scene.instantiate()
	proj.hit_group = "player"
	proj.damage = attack_damage
	
	# Calcular direcciÃ³n con spread (abanico)
	var spread_angle: float = deg_to_rad(15.0 * spread_index)  # -15Â°, 0Â°, +15Â°
	var rotated_dir := base_dir.rotated(Vector3.UP, spread_angle)
	
	# Configurar color y efecto segÃºn elemento
	var color: Color
	var emission: Color
	var light_color: Color
	match element:
		ElementalType.ICE:
			color = Color(0.2, 0.6, 1.0)  # Azul hielo
			emission = Color(0.1, 0.4, 0.9)
			light_color = Color(0.2, 0.5, 1.0)
			proj.speed = 20.0  # Hielo: mÃ¡s lento pero congelante
		ElementalType.FIRE:
			color = Color(1.0, 0.3, 0.0)  # Rojo fuego
			emission = Color(0.9, 0.2, 0.0)
			light_color = Color(1.0, 0.4, 0.1)
			proj.speed = 30.0  # Fuego: rÃ¡pido y ardiente
		ElementalType.ELECTRIC:
			color = Color(0.9, 0.9, 0.1)  # Amarillo elÃ©ctrico
			emission = Color(0.8, 0.8, 0.0)
			light_color = Color(1.0, 1.0, 0.2)
			proj.speed = 35.0  # ElÃ©ctrico: muy rÃ¡pido
	
	# Material elemental
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 3.0
	
	var scene := get_tree().current_scene
	if not scene:
		proj.queue_free()
		return
	scene.add_child(proj)
	
	# PosiciÃ³n de spawn con offset para cada proyectil
	var spawn_offset := Vector3(0, 0.5 + (spread_index * 0.1), 0)
	proj.global_position = global_position + spawn_offset + rotated_dir * 1.0
	proj.direction = rotated_dir
	
	# Aplicar material al mesh
	var mesh := proj.get_node_or_null("CSGSphere3D") as GeometryInstance3D
	if not mesh:
		for child in proj.get_children():
			if child is GeometryInstance3D:
				mesh = child
				break
	if mesh:
		mesh.material_override = material
	
	# AÃ±adir luz puntual al proyectil para efecto visual
	var light := OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = 2.0
	light.omni_range = 4.0
	proj.add_child(light)
	
	# Auto-destruir luz cuando el proyectil muera
	proj.tree_exiting.connect(func(): 
		if is_instance_valid(light): 
			light.queue_free()
	)
