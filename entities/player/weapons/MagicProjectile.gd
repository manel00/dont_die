class_name MagicProjectile
extends Area3D

@export var speed: float = 30.0
@export var impact_damage: float = 15.0
@export var explosion_radius: float = 4.0
@export var hit_group: String = "enemies"

var direction: Vector3 = Vector3.FORWARD
var _grace_timer: float = 0.15  # FIX: timer de gracia para evitar explosiÃ³n al spawnear

func _ready() -> void:
	# FIX: Iniciar monitoreo desactivado, activarlo tras el timer de gracia
	monitoring = false
	body_entered.connect(_on_body_entered)
	var lifetime_timer := get_tree().create_timer(3.0)
	lifetime_timer.timeout.connect(queue_free)
	
	# Cambiar color a ROJO
	_setup_visuals()

func _setup_visuals() -> void:
	# Cambiar color de la esfera principal
	var sphere = get_node_or_null("CSGSphere3D")
	if sphere:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0) # Rojo puro
		mat.emission_enabled = true
		mat.emission = Color(2, 0, 0) # Brillo rojo intenso
		sphere.material = mat
	
	# Añadir luz roja
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.1, 0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)

	# Crear estela de partículas ROJAS
	_create_red_trail()

func _create_red_trail() -> void:
	var trail = GPUParticles3D.new()
	trail.amount = 30
	trail.lifetime = 0.5
	trail.local_coords = false
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.gravity = Vector3(0, 1.0, 0) # Humo/fuego que sube un poco
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 1.0
	mat.color = Color(1, 0.1, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.2
	
	# Curva de escala para que se desvanezcan
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	
	trail.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = Color(1, 0.2, 0)
	mesh.material = mesh_mat
	
	trail.draw_pass_1 = mesh
	add_child(trail)

func _physics_process(delta: float) -> void:
	# FIX: Timer de gracia antes de activar colisiones
	if _grace_timer > 0.0:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			monitoring = true
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D or (body is StaticBody3D and body.has_method("take_damage"))):
		return
	
	# Daño en área a todos los targets del grupo correcto en radio
	var targets := get_tree().get_nodes_in_group(hit_group)
	for t in targets:
		if is_instance_valid(t) and t.global_position.distance_to(global_position) <= explosion_radius:
			if t.has_method("take_damage"):
				t.take_damage(int(impact_damage))
				
	# Efecto visual de explosión ROJO
	var scene := get_tree().current_scene
	if not scene:
		queue_free()
		return
	
	var explosion := CSGSphere3D.new()
	explosion.radius = explosion_radius
	explosion.radial_segments = 32
	explosion.rings = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.6) # Rojo
	mat.emission_enabled = true
	mat.emission = Color(2, 0, 0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.material = mat
	scene.add_child(explosion)
	explosion.global_position = global_position
	
	var tw := scene.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_property(explosion, "scale", Vector3(1.3, 1.3, 1.3), 0.5)
	tw.chain().tween_callback(explosion.queue_free)
	
	queue_free()
