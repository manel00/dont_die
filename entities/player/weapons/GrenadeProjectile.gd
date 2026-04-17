class_name GrenadeProjectile
extends Area3D

@export var speed: float = 15.0
@export var damage: int = 60
@export var explosion_radius: float = 6.0
@export var life_time: float = 4.0
@export var hit_group: String = "enemies"

var direction: Vector3 = Vector3.FORWARD
var _velocity: Vector3 = Vector3.ZERO
var _has_exploded: bool = false
var _spin_speed: float = 360.0  # RPM

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("projectiles")
	
	# Auto-destruir después de tiempo de vida
	var timer = get_tree().create_timer(life_time)
	timer.timeout.connect(_explode)
	
	# Crear mesh visual
	_create_visual()
	
	# Inicializar velocidad con arco
	_velocity = direction * speed
	_velocity.y = 8.0  # Arco inicial

func _create_visual() -> void:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "GrenadeMesh"
	add_child(mesh_instance)
	
	# Mesh esférico para granada
	mesh_instance.mesh = SphereMesh.new()
	mesh_instance.mesh.radius = 0.25
	mesh_instance.mesh.height = 0.5
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)  # Gris metálico
	mat.metallic = 0.8
	mat.roughness = 0.4
	
	# Emisión roja pulsante
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 0.2)
	mat.emission_energy_multiplier = 2.0
	
	mesh_instance.material_override = mat
	
	# Luz roja pulsante
	var light = OmniLight3D.new()
	light.name = "GrenadeLight"
	light.light_color = Color(1.0, 0.0, 0.1)
	light.light_energy = 3.0
	light.omni_range = 4.0
	add_child(light)
	
	# Animación de pulso
	var tw = create_tween().set_loops().set_parallel(true)
	tw.tween_property(light, "light_energy", 5.0, 0.3)
	tw.chain().tween_property(light, "light_energy", 2.0, 0.3)

func _physics_process(delta: float) -> void:
	# Gravedad
	_velocity.y -= 20.0 * delta
	
	# Mover
	global_position += _velocity * delta
	
	# Rotar
	rotate_z(deg_to_rad(_spin_speed * delta))
	
	# Detectar suelo
	if global_position.y <= 0.25:
		global_position.y = 0.25
		_explode()

func _on_body_entered(body: Node3D) -> void:
	if _has_exploded:
		return
	
	# Explosión al tocar enemigo
	if body.is_in_group(hit_group) and body.has_method("take_damage"):
		_explode()
	elif body is StaticBody3D or body is CSGShape3D:
		# Explosión al tocar suelo/escenario
		_explode()

func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	
	# Daño en área
	var targets := get_tree().get_nodes_in_group(hit_group)
	for t in targets:
		if is_instance_valid(t) and t is Node3D:
			var dist = t.global_position.distance_to(global_position)
			if dist <= explosion_radius:
				if t.has_method("take_damage"):
					var damage_mult = 1.0 - (dist / explosion_radius)
					var final_damage = int(damage * damage_mult)
					t.take_damage(final_damage)
	
	# Efecto visual de explosión
	_spawn_explosion_effect()
	
	# Ocultar mesh
	var mesh = get_node_or_null("GrenadeMesh")
	if mesh:
		mesh.visible = false
	
	# Destruir después de efecto
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _spawn_explosion_effect() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	
	# Esfera de explosión
	var explosion = CSGSphere3D.new()
	explosion.radius = 0.5
	explosion.radial_segments = 32
	explosion.rings = 16
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.material = mat
	
	scene.add_child(explosion)
	explosion.global_position = global_position
	
	# Animación de expansión
	var tw = create_tween().set_parallel(true)
	tw.tween_property(explosion, "radius", explosion_radius, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(explosion.queue_free)
	
	# Partículas de explosión
	var particles = GPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.local_coords = false
	
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.5
	pmat.initial_velocity_min = 5.0
	pmat.initial_velocity_max = 15.0
	pmat.gravity = Vector3(0, -9.8, 0)
	pmat.color = Color(1.0, 0.2, 0.0)
	pmat.scale_min = 0.05
	pmat.scale_max = 0.2
	particles.process_material = pmat
	
	var pmesh = SphereMesh.new()
	pmesh.radius = 0.08
	pmesh.height = 0.16
	particles.draw_pass_1 = pmesh
	
	scene.add_child(particles)
	particles.global_position = global_position
	
	# Auto-limpiar partículas
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(particles.queue_free)
