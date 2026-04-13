class_name MagicProjectile
extends Area3D

@export var speed: float = 30.0
@export var impact_damage: float = 100.0
@export var explosion_radius: float = 4.0
@export var hit_group: String = "enemies"

var direction: Vector3 = Vector3.FORWARD
var _grace_timer: float = 0.15  # FIX: timer de gracia para evitar explosión al spawnear

func _ready() -> void:
	# FIX: Iniciar monitoreo desactivado, activarlo tras el timer de gracia
	monitoring = false
	body_entered.connect(_on_body_entered)
	var lifetime_timer := get_tree().create_timer(3.0)
	lifetime_timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# FIX: Timer de gracia antes de activar colisiones
	if _grace_timer > 0.0:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			monitoring = true
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# FIX: Solo explotar si golpea un CharacterBody3D (jugadores/enemigos/barrels), no entorno
	if not (body is CharacterBody3D or body is StaticBody3D and body.has_method("take_damage")):
		# Si es entorno estático sin take_damage, ignorar y continuar
		if body is StaticBody3D and not body.has_method("take_damage"):
			return
	
	print("MAGIC EXPLOSION!")
	
	# Daño en área a todos los targets del grupo correcto en radio
	var targets := get_tree().get_nodes_in_group(hit_group)
	for t in targets:
		if is_instance_valid(t) and t.global_position.distance_to(global_position) <= explosion_radius:
			if t.has_method("take_damage"):
				t.take_damage(int(impact_damage))
				
	# Efecto visual de explosión
	var explosion := CSGSphere3D.new()
	explosion.radius = explosion_radius
	explosion.radial_segments = 32
	explosion.rings = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.material = mat
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	var tw := get_tree().current_scene.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_property(explosion, "scale", Vector3(1.3, 1.3, 1.3), 0.5)
	tw.chain().tween_callback(explosion.queue_free)
	
	queue_free()
