class_name ExplosiveBarrel
extends StaticBody3D

@export var max_health: int = 30
@export var explosion_damage: int = 50
@export var explosion_radius: float = 4.0
@export var fuse_time: float = 0.5

var current_health: int
var is_triggered: bool = false

var blast_radius_area: Area3D

func _ready() -> void:
	current_health = max_health
	
	# Crear Ã¡rea de explosiÃ³n dinÃ¡micamente
	blast_radius_area = Area3D.new()
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	col_shape.shape = sphere
	blast_radius_area.add_child(col_shape)
	blast_radius_area.monitoring = false  # Solo activar al explotar
	add_child(blast_radius_area)

func take_damage(amount: int) -> void:
	if is_triggered: return
	
	current_health -= amount
	
	# Flash visual de daño
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh and mesh.mesh:
		var flash_mat := StandardMaterial3D.new()
		var pct: float = float(current_health) / max_health
		flash_mat.albedo_color = Color(1.0, pct * 0.5, 0.0)
		flash_mat.emission_enabled = true
		flash_mat.emission = flash_mat.albedo_color * 0.5
		mesh.set_surface_override_material(0, flash_mat)
	
	if current_health <= 0:
		_trigger_explosion()

func _trigger_explosion() -> void:
	is_triggered = true
	# print("Â¡Barril activado! Explotando en ", fuse_time, "s...")
	
	# Efecto de parpadeo antes de explotar
	_blink_effect()
	
	var timer := get_tree().create_timer(fuse_time)
	timer.timeout.connect(_explode)

func _blink_effect() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh or not mesh.mesh: return
	var tween := create_tween().set_loops(int(fuse_time / 0.1))
	var blink_mat := StandardMaterial3D.new()
	blink_mat.albedo_color = Color(1, 0.1, 0)
	blink_mat.emission_enabled = true
	blink_mat.emission = Color(1.5, 0.2, 0)
	tween.tween_callback(func(): mesh.set_surface_override_material(0, blink_mat))
	tween.tween_interval(0.05)
	tween.tween_callback(func(): mesh.set_surface_override_material(0, null))
	tween.tween_interval(0.05)

func _explode() -> void:
	# print("Â¡KABOOM!")
	
	# Activar Ã¡rea y aplicar daÃ±o
	blast_radius_area.monitoring = true
	await get_tree().process_frame  # Esperar un frame para que el Area3D detecte
	
	var bodies := blast_radius_area.get_overlapping_bodies()
	for body in bodies:
		if body != self and body.has_method("take_damage"):
			var dist: float = global_position.distance_to(body.global_position)
			var falloff: float = clamp(1.0 - (dist / explosion_radius), 0.1, 1.0)
			body.take_damage(int(explosion_damage * falloff))
	
	# Efecto GPUParticles3D de explosiÃ³n
	_spawn_explosion_vfx()
	
	queue_free()

func _spawn_explosion_vfx() -> void:
	# BUG FIX: Add null check for current_scene
	var scene := get_tree().current_scene
	if not scene:
		return
	
	# Bola de fuego expandiÃ©ndose
	var fireball := CSGSphere3D.new()
	fireball.radius = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(2.0, 0.8, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fireball.material = mat
	scene.add_child(fireball)
	fireball.global_position = global_position + Vector3(0, 0.5, 0)
	
	var tw := scene.create_tween().set_parallel(true)
	tw.tween_property(fireball, "radius", explosion_radius * 0.8, 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(fireball.queue_free)
	
	# PartÃ­culas de escombros
	var particles := GPUParticles3D.new()
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 80.0
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 10.0
	pmat.gravity = Vector3(0, -9.8, 0)
	pmat.color = Color(0.8, 0.4, 0.1)
	pmat.scale_min = 0.1
	pmat.scale_max = 0.3
	particles.process_material = pmat
	particles.amount = 30
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 1.5
	scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.5, 0)
	particles.emitting = true
	
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(particles.queue_free)
