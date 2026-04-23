class_name StylooRangedProjectile
extends Area3D

## StylooRangedProjectile â€” Sistema de proyectiles para armas ranged del pack Styloo
## Shurikens: RÃ¡pido, rebota en paredes
## Kunai: Muy rÃ¡pido, atraviesa enemigos  
## Hachas: Lento, pesado, gran daÃ±o en Ã¡rea

@export var speed: float = 30.0
@export var damage: int = 25
@export var life_time: float = 3.0
@export var weapon_type: String = "shuriken1":
	set(v):
		weapon_type = v
		if is_node_ready():
			_setup_weapon_behavior()
@export var hit_group: String = "enemies"

var direction: Vector3 = Vector3.FORWARD
var _pierce_count: int = 0  # Para kunai que atraviesa
var _max_pierce: int = 3
var _is_axe: bool = false
var _spin_speed: float = 0.0
var _damaged_enemies: Dictionary = {}  # Track enemigos ya daÃ±ados (para evitar daÃ±o mÃºltiple)
const MAX_DAMAGED_TRACKED: int = 20  # BUG FIX: Limit dictionary size to prevent memory leak
var _is_setup: bool = false # Evitar doble setup

func _ready() -> void:
	_setup_weapon_behavior()
	body_entered.connect(_on_body_entered)
	
	# Auto-destruir despuÃ©s de tiempo de vida
	var timer = get_tree().create_timer(life_time)
	timer.timeout.connect(queue_free)
	
	# Efecto visual inicial
	_spawn_muzzle_flash()

func _setup_weapon_behavior() -> void:
	if _is_setup and Engine.is_editor_hint(): return
	_is_setup = true
	
	# Limpiar visuales previos si existen (caso de cambio en runtime)
	var prev = get_node_or_null("RotationNode")
	if prev: 
		remove_child(prev)
		prev.queue_free()
	
	match weapon_type:
		"shuriken1", "shuriken2", "shuriken3", "shuriken4":
			# Shurikens: Rápido, rebota, rotación de voltereta
			speed = 35.0
			damage = 22
			life_time = 2.5
			_max_pierce = 0
			_spin_speed = 1200.0 # Voltereta rápida
			
		"kunai", "coolknife", "bayonet":
			# Cuchillos: Ahora también con voltereta dinámica
			speed = 45.0
			damage = 28
			life_time = 2.0
			_max_pierce = 3
			_spin_speed = 1000.0 # Efecto de voltereta
			
		"doubleAxe", "simpleAxe":
			# Hachas: Voltereta pesada
			speed = 35.0
			damage = 65
			life_time = 3.5
			_max_pierce = 0
			_spin_speed = 1100.0
			_is_axe = true
	
	# Crear mesh visual usando el modelo real del arma
	_create_visual_mesh()
	
const WEAPON_PACK_PATH := "res://assets/models/weapons/weaponsassetspackbyStyloo/"

func _create_visual_mesh() -> void:
	# 1. Nodo de rotación de vuelo (Mira hacia la dirección del proyectil)
	var rot_node = Node3D.new()
	rot_node.name = "RotationNode"
	add_child(rot_node)
	
	# 2. Contenedor de giro visual (Hace la voltereta)
	var model_container = Node3D.new()
	model_container.name = "ModelContainer"
	rot_node.add_child(model_container)
	
	# Determinar archivo a cargar
	var weapon_file := "ASSETS.fbx_" + weapon_type + ".fbx"
	var weapon_path := WEAPON_PACK_PATH + weapon_file
	
	var loaded_model: Node3D = null
	if ResourceLoader.exists(weapon_path):
		var res = load(weapon_path)
		if res:
			loaded_model = res.instantiate()

	if loaded_model:
		# Centrar y orientar el modelo para proyectiles
		model_container.add_child(loaded_model)
		
		# Escala: Reducida un 50% a petición del usuario
		var is_small := weapon_type.contains("shuriken") or weapon_type == "kunai" or weapon_type.contains("knife") or weapon_type == "bayonet"
		var scale_val := 9.0 if is_small else 6.0 
		loaded_model.scale = Vector3(scale_val, scale_val, scale_val)
		
		# Orientación base FBX -> Dirección proyectil (-Z)
		if weapon_type.contains("shuriken"):
			loaded_model.rotation_degrees = Vector3(90, 0, 0)
		else:
			loaded_model.rotation_degrees = Vector3(0, 90, 0)
			
		_apply_projectile_texture(loaded_model)
		_center_projectile_model(loaded_model)
	else:
		# Fallback mesh
		var fallback = MeshInstance3D.new()
		fallback.mesh = BoxMesh.new()
		fallback.mesh.size = Vector3(0.1, 0.1, 0.6)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_weapon_color()
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 3.0
		fallback.material_override = mat
		model_container.add_child(fallback)

	# Trail de partículas
	_create_trail()

func _center_projectile_model(model: Node3D) -> void:
	# Centrar el modelo para que el hitbox (Area3D) coincida con el centro visual
	var meshes := _find_meshes(model)
	if meshes.is_empty():
		return
	
	var aabb := AABB()
	var first := true
	for mesh in meshes:
		if mesh.mesh:
			var local_aabb := mesh.mesh.get_aabb()
			var transformed_aabb := mesh.transform * local_aabb
			if first:
				aabb = transformed_aabb
				first = false
			else:
				aabb = aabb.merge(transformed_aabb)
	
	# Mover el modelo localmente para centrar el AABB
	# BUG FIX: El desplazamiento debe tener en cuenta la escala y rotación del propio modelo
	var center := aabb.get_center()
	model.position = -(model.quaternion * (model.scale * center))

func _apply_projectile_texture(model: Node3D) -> void:
	var tex_path := WEAPON_PACK_PATH + "3D weapons asset pack.png"
	var tex = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	
	# Crear un único material para compartir
	var mat := StandardMaterial3D.new()
	if tex:
		mat.albedo_texture = tex
	else:
		# Fallback color si no hay textura para evitar errores de material nulo
		mat.albedo_color = _get_weapon_color()
	
	mat.metallic = 0.5
	mat.roughness = 0.4
	
	var meshes = _find_meshes(model)
	for mesh in meshes:
		for i in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(i, mat)

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result

func _get_weapon_color() -> Color:
	match weapon_type:
		"shuriken1": return Color(1.0, 0.5, 0.0)
		"shuriken2": return Color(0.0, 1.0, 0.5)
		"shuriken3": return Color(1.0, 0.0, 1.0)
		"shuriken4": return Color(1.0, 0.8, 0.0)
		"kunai": return Color(0.5, 0.0, 0.8)
		"doubleAxe", "simpleAxe": return Color(0.8, 0.2, 0.2)
	return Color.WHITE

func _create_trail() -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 0.3
	particles.local_coords = false
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 2.0
	mat.color = _get_weapon_color()
	mat.scale_min = 0.02
	mat.scale_max = 0.08
	
	particles.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	particles.draw_pass_1 = mesh
	particles.position = Vector3(0, 0, -0.2)
	
	add_child(particles)

func _spawn_muzzle_flash() -> void:
	var flash = OmniLight3D.new()
	flash.light_color = _get_weapon_color()
	flash.light_energy = 2.0
	flash.omni_range = 1.5
	add_child(flash)
	
	# Fade out rÃ¡pido
	var tw = create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.1)
	tw.tween_callback(flash.queue_free)

func _physics_process(delta: float) -> void:
	# Mover proyectil
	global_position += direction * speed * delta
	
	# 1. Orientar el nodo de rotación hacia donde vuela
	if direction.length() > 0.001:
		var rot_node = get_node_or_null("RotationNode")
		if rot_node:
			rot_node.look_at(global_position + direction, Vector3.UP)
	
	# 2. Rotación visual en el contenedor
	if _spin_speed > 0:
		var model_container = get_node_or_null("RotationNode/ModelContainer")
		if model_container:
			if weapon_type.contains("shuriken"):
				# Shurikens: Giran como un frisbee (Horizontalmente sobre el eje Y local)
				model_container.rotate_object_local(Vector3.UP, deg_to_rad(_spin_speed * delta))
			else:
				# Otros: Giran como una voltereta (Verticalmente sobre el eje X local)
				model_container.rotate_object_local(Vector3.RIGHT, deg_to_rad(_spin_speed * delta))
	
	# Gravedad desactivada para hachas si se lanzan como shurikens (recto)
	# if _is_axe:
	# 	direction.y -= 2.0 * delta
	# 	direction = direction.normalized()

func _on_body_entered(body: Node3D) -> void:
	# DEBUG: Log todas las colisiones
	# print("DEBUG StylooProjectile collision: proj=", get_instance_id(), " weapon=", weapon_type,
	# 	" body=", body.name, " groups=", body.get_groups(), 
	# 	" in_hit_group=", body.is_in_group(hit_group), " has_take_damage=", body.has_method("take_damage"))
	
	# Verificar si es enemigo vÃ¡lido
	if body.is_in_group(hit_group) and body.has_method("take_damage"):
		# Evitar daÃ±ar al mismo enemigo mÃºltiples veces
		var enemy_id = body.get_instance_id()
		if _damaged_enemies.has(enemy_id):
			# print("DEBUG StylooProjectile: already damaged enemy ", body.name, ", ignoring")
			return  # Ya daÃ±amos a este enemigo, ignorar
		
		# Marcar como daÃ±ado
		_damaged_enemies[enemy_id] = true
		
		# BUG FIX: Limit dictionary size to prevent memory leak
		if _damaged_enemies.size() > MAX_DAMAGED_TRACKED:
			var first_key = _damaged_enemies.keys()[0]
			_damaged_enemies.erase(first_key)
		
		# Aplicar daÃ±o
		# print("DEBUG StylooProjectile: DEALING DAMAGE to ", body.name, " damage=", damage, " weapon=", weapon_type)
		body.take_damage(damage)
		
		# Spawnear efecto de impacto
		_spawn_impact_effect(body.global_position)
		
		# Comportamiento según tipo de arma
		var is_piercing := weapon_type == "kunai" or weapon_type == "coolknife" or weapon_type == "bayonet"
		if is_piercing and _pierce_count < _max_pierce:
			# Atraviesa enemigos
			_pierce_count += 1
			return  # No destruir, sigue volando
		else:
			# Shurikens, hachas (estilo shuriken) y otros se destruyen al impactar
			queue_free()
			
	elif body.is_in_group("enemies") or body.is_in_group("player"):
		# GolpeÃ³ personaje pero no es objetivo vÃ¡lido
		queue_free()
		
	else:
		# GolpeÃ³ ambiente (pared, suelo, etc)
		if weapon_type.contains("shuriken") or _is_axe:
			# Shurikens y hachas rebotan en paredes
			_bounce_off_wall(body)
		else:
			# Otros se destruyen
			queue_free()

func _bounce_off_wall(wall: Node3D) -> void:
	# Calcular normal de rebote aproximada
	var bounce_dir = (global_position - wall.global_position).normalized()
	bounce_dir.y = 0  # Mantener en plano horizontal principalmente
	
	if bounce_dir.length() < 0.1:
		bounce_dir = -direction  # Rebote simple si no hay direcciÃ³n clara
	
	# Reducir velocidad en cada rebote
	speed *= 0.7
	if speed < 10.0:
		queue_free()  # Dejar de rebotar si es muy lento
		return
	
	direction = bounce_dir.normalized()
	
	# Efecto visual de rebote
	var particles = GPUParticles3D.new()
	particles.amount = 10
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.color = _get_weapon_color()
	particles.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.04
	particles.draw_pass_1 = mesh
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(particles)
		particles.global_position = global_position
	
	var timer = get_tree().create_timer(0.3)
	timer.timeout.connect(particles.queue_free)

func _aoe_damage(center: Vector3) -> void:
	# DaÃ±o en Ã¡rea para hachas
	var radius: float = 4.0
	var enemies = get_tree().get_nodes_in_group(hit_group)
	
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node3D:
			var dist = enemy.global_position.distance_to(center)
			if dist < radius:
				# DaÃ±o decreciente con distancia
				var damage_mult = 1.0 - (dist / radius)
				var aoe_damage = int(damage * damage_mult)
				if enemy.has_method("take_damage"):
					enemy.take_damage(aoe_damage)
	
	# Efecto visual de explosiÃ³n
	var explosion = CSGSphere3D.new()
	explosion.radius = 0.5
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.material = mat
	
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(explosion)
		explosion.global_position = center
	
	# Efecto visual de explosión (FIX: usar tween del propio nodo explosion o del tree)
	var tw = explosion.create_tween().set_parallel(true)
	tw.tween_property(explosion, "radius", radius, 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(explosion.queue_free)

func _spawn_impact_effect(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.4
	particles.explosiveness = 0.8
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.color = _get_weapon_color()
	particles.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	particles.draw_pass_1 = mesh
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(particles)
		particles.global_position = pos
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)
