class_name StylooRangedProjectile
extends Area3D

## StylooRangedProjectile â€” Sistema de proyectiles para armas ranged del pack Styloo
## Shurikens: RÃ¡pido, rebota en paredes
## Kunai: Muy rÃ¡pido, atraviesa enemigos  
## Hachas: Lento, pesado, gran daÃ±o en Ã¡rea

@export var speed: float = 30.0
@export var damage: int = 25
@export var life_time: float = 3.0
@export var weapon_type: String = "shuriken1"  # shuriken1-4, kunai, doubleAxe, simpleAxe
@export var hit_group: String = "enemies"

var direction: Vector3 = Vector3.FORWARD
var _pierce_count: int = 0  # Para kunai que atraviesa
var _max_pierce: int = 3
var _is_axe: bool = false
var _spin_speed: float = 0.0
var _damaged_enemies: Dictionary = {}  # Track enemigos ya daÃ±ados (para evitar daÃ±o mÃºltiple)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Configurar segÃºn tipo de arma
	_setup_weapon_behavior()
	
	# Auto-destruir despuÃ©s de tiempo de vida
	var timer = get_tree().create_timer(life_time)
	timer.timeout.connect(queue_free)
	
	# Efecto visual inicial
	_spawn_muzzle_flash()

func _setup_weapon_behavior() -> void:
	match weapon_type:
		"shuriken1", "shuriken2", "shuriken3", "shuriken4":
			# Shurikens: RÃ¡pido, rebota, daÃ±o medio
			speed = 35.0
			damage = 22
			life_time = 2.5
			_max_pierce = 0  # No atraviesa, rebota
			_spin_speed = 720.0  # RPM de rotaciÃ³n
			
		"kunai":
			# Kunai: Muy rÃ¡pido, atraviesa 3 enemigos
			speed = 45.0
			damage = 28
			life_time = 2.0
			_max_pierce = 3
			_spin_speed = 0  # No rota, vuela recto
			
		"doubleAxe", "simpleAxe":
			# Hachas: Lento pero devastador, daÃ±o en Ã¡rea
			speed = 18.0
			damage = 70
			life_time = 4.0
			_max_pierce = 0
			_spin_speed = 360.0  # Gira lentamente
			_is_axe = true
	
	# Crear mesh visual
	_create_visual_mesh()

func _create_visual_mesh() -> void:
	var mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var mat = StandardMaterial3D.new()
	
	match weapon_type:
		"shuriken1", "shuriken2", "shuriken3", "shuriken4":
			# Shuriken - estrella plana
			mesh_instance.mesh = CylinderMesh.new()
			mesh_instance.mesh.top_radius = 0.15
			mesh_instance.mesh.bottom_radius = 0.0
			mesh_instance.mesh.height = 0.05
			mesh_instance.rotation_degrees.x = 90
			
			mat.albedo_color = _get_weapon_color()
			mat.emission_enabled = true
			mat.emission = mat.albedo_color * 2.0
			
		"kunai":
			# Kunai - forma de cuchillo alargado
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = Vector3(0.08, 0.08, 0.5)
			
			mat.albedo_color = Color(0.5, 0.0, 0.8)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.0, 1.0)
			
		"doubleAxe", "simpleAxe":
			# Hacha - forma de doble hoja
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = Vector3(0.3, 0.1, 0.4)
			
			mat.albedo_color = Color(0.8, 0.2, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.3, 0.3)
			
			# Agregar mango
			var handle = MeshInstance3D.new()
			handle.mesh = CylinderMesh.new()
			handle.mesh.radius = 0.04
			handle.mesh.height = 0.4
			handle.position = Vector3(0, 0, 0.3)
			handle.rotation_degrees.x = 90
			handle.material_override = mat
			add_child(handle)
	
	mesh_instance.material_override = mat
	
	# Trail de partÃ­culas
	_create_trail()

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
	
	# Rotar segÃºn tipo
	if _spin_speed > 0:
		rotate_z(deg_to_rad(_spin_speed * delta))
	
	# Gravedad para hachas (lanzamiento pesado)
	if _is_axe:
		direction.y -= 2.0 * delta  # CaÃ­da lenta
		direction = direction.normalized()

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
		
		# Aplicar daÃ±o
		# print("DEBUG StylooProjectile: DEALING DAMAGE to ", body.name, " damage=", damage, " weapon=", weapon_type)
		body.take_damage(damage)
		
		# Spawnear efecto de impacto
		_spawn_impact_effect(body.global_position)
		
		# Comportamiento segÃºn tipo de arma
		if weapon_type == "kunai" and _pierce_count < _max_pierce:
			# Kunai atraviesa enemigos
			_pierce_count += 1
			# print("DEBUG StylooProjectile: kunai pierce continues, count=", _pierce_count)
			return  # No destruir, sigue volando
		elif _is_axe:
			# Hacha causa daÃ±o en Ã¡rea
			_aoe_damage(body.global_position)
			queue_free()
		else:
			# Shurikens y otros se destruyen al impactar
			queue_free()
			
	elif body.is_in_group("enemies") or body.is_in_group("player"):
		# GolpeÃ³ personaje pero no es objetivo vÃ¡lido
		queue_free()
		
	else:
		# GolpeÃ³ ambiente (pared, suelo, etc)
		if weapon_type.begins_with("shuriken"):
			# Shurikens rebotan en paredes
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
	get_tree().current_scene.add_child(particles)
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
	
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = center
	
	var tw = create_tween().set_parallel(true)
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
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)
