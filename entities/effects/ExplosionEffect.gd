# ExplosionEffect.gd
# Efecto visual de explosión autónomo. Se añade a la escena raíz y
# se destruye solo. NO depende del proyectil que lo creó.

class_name ExplosionEffect
extends Node3D

# Radio final de la onda expansiva visible
@export var blast_radius: float = 6.0
# Duración total del efecto
@export var duration: float = 0.7

func _ready() -> void:
	_spawn_shockwave()
	_spawn_fireball()
	_spawn_particles()
	# Auto-destrucción garantizada
	await get_tree().create_timer(duration + 1.5).timeout
	if is_instance_valid(self):
		queue_free()

# --- Onda expansiva (esfera que se expande hasta el radio real) ---
func _spawn_shockwave() -> void:
	var shock := MeshInstance3D.new()
	shock.name = "Shockwave"
	add_child(shock)

	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh.radial_segments = 24
	mesh.rings = 12
	shock.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 4.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shock.material_override = mat

	# Animar escala (radius efectivo = 0.3 * scale = blast_radius → scale = blast_radius / 0.3)
	var target_scale: float = blast_radius / 0.3
	var tween := create_tween().set_parallel(true)
	tween.tween_property(shock, "scale", Vector3.ONE * target_scale, duration * 0.8)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.6)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(shock.queue_free)

# --- Bola de fuego central (núcleo naranja brillante) ---
func _spawn_fireball() -> void:
	var fire := MeshInstance3D.new()
	fire.name = "Fireball"
	add_child(fire)

	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.6
	mesh.radial_segments = 16
	mesh.rings = 8
	fire.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 8.0
	fire.material_override = mat

	# Luz central deslumbrante
	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.4, 0.0)
	omni.light_energy = 20.0
	omni.omni_range = blast_radius * 1.5
	add_child(omni)

	# Tween A: secuencia de escala (expansión → contracción)
	var tween_scale := create_tween()
	tween_scale.tween_property(fire, "scale", Vector3.ONE * 2.5, 0.12)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween_scale.tween_property(fire, "scale", Vector3(0.001, 0.001, 0.001), 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_scale.tween_callback(fire.queue_free)

	# Tween B: fade de alpha y luz (en paralelo, independiente)
	var tween_fade := create_tween().set_parallel(true)
	tween_fade.tween_property(mat, "albedo_color:a", 0.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD)
	tween_fade.tween_property(omni, "light_energy", 0.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD)

# --- Partículas de escombros ---
func _spawn_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ExplosionParticles"
	particles.amount = 150
	particles.lifetime = 1.8
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.one_shot = true
	add_child(particles)

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.5
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = blast_radius * 1.2
	pmat.gravity = Vector3(0, -15.0, 0)
	pmat.scale_min = 0.06
	pmat.scale_max = 0.25
	# Gradiente naranja → negro
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.6, 0.0, 1.0), Color(0.2, 0.05, 0.0, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	pmat.color_ramp = grad_tex
	particles.process_material = pmat

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.08
	pmesh.height = 0.16
	particles.draw_pass_1 = pmesh

	# Empezar a emitir inmediatamente
	particles.emitting = true
