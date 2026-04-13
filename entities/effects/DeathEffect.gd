# DeathEffect.gd
# Efecto de partículas al morir un enemigo - explosión de huesos

extends Node3D

@export var enemy_type: String = "minion"  # minion, mage, rogue

func _ready() -> void:
	_create_particles()
	_play_effect()

func _create_particles() -> void:
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 2.0
	particles.amount = 20
	
	# Material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	material.direction = Vector3.UP
	material.spread = 180.0
	material.gravity = Vector3(0, -15, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 10.0
	material.scale_min = 0.15
	material.scale_max = 0.25
	
	# Color por tipo
	var color: Color
	match enemy_type:
		"mage":
			color = Color(0.8, 0.2, 1.0, 1.0)  # Púrpura
		"rogue":
			color = Color(1.0, 0.5, 0.0, 1.0)  # Naranja
		_:
			color = Color(0.9, 0.9, 0.7, 1.0)  # Hueso
	
	material.color = color
	particles.process_material = material
	
	# Mesh - pequeños huesos/cubos
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.08, 0.25, 0.08)
	particles.draw_pass_1 = mesh
	
	add_child(particles)
	
	# Destruir después
	await get_tree().create_timer(2.5).timeout
	queue_free()

func _play_effect() -> void:
	# Flash de muerte
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
