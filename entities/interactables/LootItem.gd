extends Area3D

class_name LootItem

@export var heal_value: int = 25

func _ready() -> void:
	# FIX: Asegurar collision layers correctas para detectar CharacterBody3D del jugador
	# Layer 1 = entorno/jugador, configurar monitoreo
	collision_layer = 0   # El loot no forma parte de ninguna capa fÃ­sica
	collision_mask = 1    # Detectar layer 1 (jugadores/personajes)
	monitoring = true
	set_deferred("monitorable", false)
	body_entered.connect(_on_body_entered)
	
	# Visual representation (Green glowing sphere)
	var sphere := CSGSphere3D.new()
	sphere.radius = 0.4
	sphere.radial_segments = 16
	sphere.rings = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 1.0, 0.2, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.8, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	add_child(sphere)
	
	# Hover animation
	var tw = create_tween().set_loops()
	tw.tween_property(sphere, "position:y", 0.3, 1.0).from(0.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sphere, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	# Auto-destruir tras 30 segundos si nadie lo recoge
	var lifetime := get_tree().create_timer(30.0)
	lifetime.timeout.connect(_on_lifetime_timeout)

func _on_lifetime_timeout() -> void:
	# Safety: ensure we're not inside tree operations when freeing
	if is_inside_tree():
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	# Server-authoritative heal (en solo mode, is_server() = true siempre)
	if not multiplayer.is_server():
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(-heal_value)  # Negativo = curaciÃ³n
	queue_free()
