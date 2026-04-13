class_name Barricade
extends StaticBody3D

@export var max_health: int = 80
var current_health: int

var _label_3d: Node3D  # Barra de vida 3D procedural

func _ready() -> void:
	current_health = max_health
	_create_health_display()

func _create_health_display() -> void:
	# Crear un Label3D flotante como barra de vida visual
	var label := Label3D.new()
	label.name = "HealthLabel"
	label.text = _get_health_text()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.modulate = Color(0.2, 1.0, 0.3)
	label.position = Vector3(0, 1.8, 0)
	label.no_depth_test = true
	add_child(label)
	_label_3d = label

func _get_health_text() -> String:
	var pct: int = int(float(current_health) / max_health * 100.0)
	var bar := ""
	var filled: int = int(float(pct) / 10.0)
	for i in range(10):
		bar += "█" if i < filled else "░"
	return bar

func take_damage(amount: int) -> void:
	current_health = clamp(current_health - amount, 0, max_health)
	
	# Actualizar label de vida
	if _label_3d:
		_label_3d.text = _get_health_text()
		var ratio: float = float(current_health) / max_health
		if ratio < 0.3:
			_label_3d.modulate = Color(1.0, 0.2, 0.2)
		elif ratio < 0.6:
			_label_3d.modulate = Color(1.0, 0.8, 0.2)
	
	# Flash de impacto
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var orig_mat := mesh.get_active_material(0)
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1, 0.3, 0.3)
		mesh.set_surface_override_material(0, flash_mat)
		await get_tree().create_timer(0.1).timeout
		mesh.set_surface_override_material(0, orig_mat)
	
	if current_health <= 0:
		_destroy()

func _destroy() -> void:
	# Pequeña explosión visual al destruirse
	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.color = Color(0.6, 0.4, 0.2)
	particles.process_material = mat
	particles.amount = 20
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 1.0
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 1, 0)
	particles.emitting = true
	
	# Auto-limpiar partículas tras el lifetime
	var t := get_tree().create_timer(particles.lifetime + 0.5)
	t.timeout.connect(particles.queue_free)
	
	queue_free()
