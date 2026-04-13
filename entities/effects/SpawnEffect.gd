# SpawnEffect.gd
# Efecto de partículas al aparecer un enemigo

extends Node3D

@export var is_miniboss: bool = false

func _ready() -> void:
	_create_particles()
	_play_effect()

func _create_particles() -> void:
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 1.0
	particles.amount = 30 if is_miniboss else 15
	
	# Material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3.UP
	material.spread = 180.0
	material.gravity = Vector3(0, -9.8, 0)
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 6.0
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	# Color: azul para minibosses, rojo para normales
	var color = Color(0.3, 0.5, 1.0, 1.0) if is_miniboss else Color(1.0, 0.2, 0.1, 1.0)
	material.color = color
	
	particles.process_material = material
	
	# Mesh
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	particles.draw_pass_1 = mesh
	
	add_child(particles)
	
	# Luz temporal
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 5.0
	add_child(light)
	
	# Animar fade out de la luz
	var tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.5)
	tween.tween_callback(light.queue_free)
	
	# Destruir después de la animación
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _play_effect() -> void:
	# Flash inicial
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.2, 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
