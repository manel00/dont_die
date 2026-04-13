# HitEffect.gd
# Efecto de partículas al recibir daño

extends Node3D

@export var hit_color: Color = Color(1.0, 0.0, 0.0, 1.0)

func _ready() -> void:
	_create_particles()

func _create_particles() -> void:
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.5
	particles.amount = 8
	
	# Material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2
	material.direction = Vector3.UP
	material.spread = 90.0
	material.gravity = Vector3(0, -5, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.scale_min = 0.05
	material.scale_max = 0.1
	material.color = hit_color
	
	particles.process_material = material
	
	# Mesh
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh
	
	add_child(particles)
	
	# Destruir rápido
	await get_tree().create_timer(0.6).timeout
	queue_free()
