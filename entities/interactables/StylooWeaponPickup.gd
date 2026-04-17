extends Area3D

## StylooWeaponPickup — Sistema completo de pickups para el pack de armas Styloo
## 12 armas únicas: bayonet, coolknife, doubleAxe, katana, kunai, longsword, 
## normalsword, pickaxe, shuriken1-4, simpleAxe, sword1

const WEAPON_PACK_PATH := "res://assets/models/weapons/weaponsassetspackbyStyloo/"

# Definición completa de las 12 armas Styloo
const STYLOO_WEAPONS := {
	"bayonet": {
		"file": "ASSETS.fbx_bayonet.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 0.8, 0),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.3,
		"damage": 35,
		"range": 3.0,
		"color": Color(0.7, 0.7, 0.8, 1.0)  # Plateado
	},
	"coolknife": {
		"file": "ASSETS.fbx_coolknife.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 0.8, 0),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.25,
		"damage": 30,
		"range": 2.5,
		"color": Color(0.2, 0.8, 1.0, 1.0)  # Cyan
	},
	"doubleAxe": {
		"file": "ASSETS.fbx_doubleAxe.fbx",
		"scale": Vector3(0.012, 0.012, 0.012),
		"position": Vector3(0, 1.0, 0),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 1.0,
		"damage": 90,
		"range": 5.0,
		"color": Color(0.8, 0.2, 0.2, 1.0),  # Rojo sangre
		"type": "ranged_lobber"  # Lanzamiento pesado con arco, daño en área masivo
	},
	"katana": {
		"file": "ASSETS.fbx_katana.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 0.9, 0),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.35,
		"damage": 45,
		"range": 3.5,
		"color": Color(1.0, 0.0, 0.5, 1.0)  # Rosa intenso
	},
	"kunai": {
		"file": "ASSETS.fbx_kunai.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"position": Vector3(0, 0.7, 0),
		"rotation": Vector3(0, 45, 45),
		"cooldown": 0.2,
		"damage": 28,
		"range": 2.0,
		"color": Color(0.5, 0.0, 0.8, 1.0),  # Púrpura
		"type": "ranged"  # Proyectil muy rápido que atraviesa enemigos
	},
	"longsword": {
		"file": "ASSETS.fbx_longsword.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 1.0, 0),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.45,
		"damage": 50,
		"range": 4.5,
		"color": Color(0.9, 0.9, 1.0, 1.0)  # Blanco acero
	},
	"normalsword": {
		"file": "ASSETS.fbx_normalsword.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 0.8, 0),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.35,
		"damage": 40,
		"range": 3.0,
		"color": Color(0.6, 0.6, 0.7, 1.0)  # Gris acero
	},
	"pickaxe": {
		"file": "ASSETS.fbx_pickaxe.fbx",
		"scale": Vector3(0.012, 0.012, 0.012),
		"position": Vector3(0, 0.9, 0),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 0.5,
		"damage": 55,
		"range": 3.5,
		"color": Color(0.4, 0.3, 0.2, 1.0)  # Marrón herrumbre
	},
	"shuriken1": {
		"file": "ASSETS.fbx_shuriken1.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"position": Vector3(0, 0.6, 0),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15,
		"damage": 22,
		"range": 2.0,
		"color": Color(1.0, 0.5, 0.0, 1.0),  # Naranja
		"type": "ranged"  # Proyectil rápido que rebota
	},
	"shuriken2": {
		"file": "ASSETS.fbx_shuriken2.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"position": Vector3(0, 0.6, 0),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15,
		"damage": 22,
		"range": 2.0,
		"color": Color(0.0, 1.0, 0.5, 1.0),  # Verde neón
		"type": "ranged"  # Proyectil rápido que rebota
	},
	"shuriken3": {
		"file": "ASSETS.fbx_shuriken3.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"position": Vector3(0, 0.6, 0),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15,
		"damage": 18,
		"range": 2.0,
		"color": Color(1.0, 0.0, 1.0, 1.0),  # Magenta
		"type": "ranged"  # Proyectil rápido que rebota
	},
	"shuriken4": {
		"file": "ASSETS.fbx_shuriken4.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"position": Vector3(0, 0.6, 0),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15,
		"damage": 25,
		"range": 2.0,
		"color": Color(1.0, 0.8, 0.0, 1.0),  # Oro
		"type": "ranged"  # Proyectil rápido que rebota
	},
	"simpleAxe": {
		"file": "ASSETS.fbx_simpleAxe.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 0.8, 0),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 0.8,
		"damage": 70,
		"range": 4.0,
		"color": Color(0.5, 0.5, 0.4, 1.0),  # Gris madera
		"type": "ranged_lobber"  # Lanzamiento pesado con arco, daño en área
	},
	"sword1": {
		"file": "ASSETS.fbx_sword1.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"position": Vector3(0, 0.9, 0),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.35,
		"damage": 42,
		"range": 3.2,
		"color": Color(0.3, 0.8, 1.0, 1.0)  # Azul hielo
	}
}

@export var weapon_type: String = "katana"  # Tipo por defecto

var _weapon_data: Dictionary
var _is_dropped: bool = false  # true = droppeado por jugador, desaparecerá si no se recoge
var _despawn_timer: float = 0.0
const DESPAWN_TIME: float = 10.0  # Segundos antes de desaparecer si es droppeado

func _ready() -> void:
	# Validar weapon_type
	if not STYLOO_WEAPONS.has(weapon_type):
		weapon_type = "katana"  # Fallback
	
	# Si no se asignaron datos externos (vía drop), usar defaults
	if _weapon_data.is_empty():
		_weapon_data = STYLOO_WEAPONS[weapon_type].duplicate()
		_weapon_data["uses_left"] = 5  # Usos por defecto
	else:
		# Es un arma droppeada - asegurar que tenga todos los campos necesarios
		var default_data = STYLOO_WEAPONS[weapon_type]
		for key in default_data.keys():
			if not _weapon_data.has(key):
				_weapon_data[key] = default_data[key]
	
	collision_mask = 1  # Players y bots (ambos en grupo "player")
	body_entered.connect(_on_body_entered)
	
	_setup_visual()
	_setup_collision()
	_start_animation()
	
	# Si es droppeado, iniciar timer de desaparición
	if _is_dropped:
		_start_despawn_timer()
		# Efecto visual de "a punto de desaparecer"
		_start_fading_warning()

func _physics_process(delta: float) -> void:
	if _is_dropped:
		_despawn_timer += delta
		if _despawn_timer >= DESPAWN_TIME:
			_fade_out_and_despawn()

func _start_despawn_timer() -> void:
	_despawn_timer = 0.0
	print("Weapon dropped: ", weapon_type, " (uses left: ", _weapon_data.get("uses_left", 0), ") - Despawn in ", DESPAWN_TIME, "s")

func _start_fading_warning() -> void:
	# Parpadeo más rápido cuando está a punto de desaparecer
	var visual = get_node_or_null("WeaponVisual")
	if visual:
		for child in visual.get_children():
			if child is GeometryInstance3D:
				# Hacer que parpadee durante los últimos 3 segundos
				var tw = create_tween().set_loops()
				tw.tween_property(child, "modulate:a", 0.3, 0.2)
				tw.tween_property(child, "modulate:a", 1.0, 0.2)

func _fade_out_and_despawn() -> void:
	# Fade out y desaparecer
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.5)
	tw.tween_callback(queue_free)

func _create_uses_indicator(uses_left: int) -> void:
	# Crear pequeño indicador de usos restantes
	var label = Label3D.new()
	label.name = "UsesIndicator"
	label.text = str(uses_left) + "/5"
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.003
	
	# Color según usos restantes
	if uses_left >= 4:
		label.modulate = Color(0.2, 1.0, 0.2)  # Verde (mucho uso)
	elif uses_left >= 2:
		label.modulate = Color(1.0, 1.0, 0.2)  # Amarillo (medio)
	else:
		label.modulate = Color(1.0, 0.2, 0.2)  # Rojo (poco uso)
	
	label.outline_modulate = Color.BLACK
	label.position = Vector3(0, 1.5, 0)  # Arriba del arma
	add_child(label)
	
	# Animar para que siempre mire a la cámara y flote
	var tw = create_tween().set_loops()
	tw.tween_property(label, "position:y", 1.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "position:y", 1.4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_visual() -> void:
	# Container para el arma
	var container = Node3D.new()
	container.name = "WeaponVisual"
	add_child(container)
	
	# Mostrar usos restantes si es un arma con durabilidad limitada
	var uses_left = _weapon_data.get("uses_left", 5)
	if uses_left < 5 or _is_dropped:
		_create_uses_indicator(uses_left)
	
	# Intentar cargar modelo 3D
	var weapon_path: String = WEAPON_PACK_PATH + _weapon_data.file
	print("Attempting to load weapon: ", weapon_path)
	
	var weapon_resource = load(weapon_path)
	if weapon_resource:
		print("Weapon file loaded, instantiating...")
		var weapon_model = weapon_resource.instantiate()
		
		# Aplicar escala y transform
		weapon_model.scale = _weapon_data.scale
		weapon_model.position = _weapon_data.position
		weapon_model.rotation_degrees = _weapon_data.rotation
		
		# Aplicar la textura correcta
		_apply_weapon_materials(weapon_model)
		
		container.add_child(weapon_model)
		print("Weapon added to scene successfully")
	else:
		print("WARNING: Weapon file could not be loaded: ", weapon_path)
		# Fallback: Crear representación con formas geométricas
		_create_fallback_visual(container)
	
	# Partículas de brillo con color del arma
	_create_particles()
	
	# Luz omnidireccional con color del arma
	_create_light()
	
	# Halo glow
	_create_halo()

func _apply_weapon_materials(node: Node3D) -> void:
	"""Aplica la textura original del asset pack a las armas en el suelo."""
	var tex_path := "res://assets/models/weapons/weaponsassetspackbyStyloo/3D weapons asset pack.png"
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	
	if tex:
		var meshes := _find_all_mesh_instances(node)
		for mesh in meshes:
			var mat = StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.metallic = 0.3
			mat.roughness = 0.6
			mesh.material_override = mat

func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	"""Encuentra todos los MeshInstance3D recursivamente."""
	var result: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	
	return result

func _create_fallback_visual(container: Node3D) -> void:
	# Crear una forma representativa del tipo de arma
	var mesh: MeshInstance3D
	
	match weapon_type:
		"katana", "longsword", "normalsword", "sword1", "bayonet":
			# Espadas - forma alargada
			mesh = MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(0.1, 0.8, 0.05)
			
		"doubleAxe", "simpleAxe", "pickaxe":
			# Hachas/picos - forma con cabeza
			mesh = MeshInstance3D.new()
			mesh.mesh = CylinderMesh.new()
			mesh.mesh.height = 0.6
			mesh.mesh.radius = 0.15
			
		"shuriken1", "shuriken2", "shuriken3", "shuriken4", "kunai":
			# Armas arrojadizas - forma estrella o puntiaguda
			mesh = MeshInstance3D.new()
			mesh.mesh = SphereMesh.new()
			mesh.mesh.radius = 0.2
			mesh.mesh.height = 0.1
			
		"coolknife":
			# Cuchillo - forma pequeña y afilada
			mesh = MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(0.08, 0.4, 0.03)
		_:
			# Default
			mesh = MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(0.1, 0.5, 0.1)
	
	mesh.position = _weapon_data.position
	
	# Material con color del arma
	var mat = StandardMaterial3D.new()
	mat.albedo_color = _weapon_data.color
	mat.emission_enabled = true
	mat.emission = _weapon_data.color * 2.0
	mat.emission_energy_multiplier = 3.0
	mat.metallic = 0.7
	mat.roughness = 0.3
	mesh.material_override = mat
	
	container.add_child(mesh)

func _create_particles() -> void:
	var particles = GPUParticles3D.new()
	particles.name = "WeaponParticles"
	particles.amount = 30
	particles.lifetime = 1.2
	particles.local_coords = false
	
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.6
	particle_mat.gravity = Vector3(0, 0.3, 0)
	particle_mat.color = _weapon_data.color
	particle_mat.scale_min = 0.03
	particle_mat.scale_max = 0.12
	particle_mat.radial_velocity_min = 0.1
	particle_mat.radial_velocity_max = 0.3
	particles.process_material = particle_mat
	
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.04
	particle_mesh.height = 0.08
	particles.draw_pass_1 = particle_mesh
	particles.position.y = 0.8
	
	add_child(particles)

func _create_light() -> void:
	var light = OmniLight3D.new()
	light.name = "WeaponLight"
	light.light_color = _weapon_data.color
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.shadow_enabled = true
	add_child(light)

func _create_halo() -> void:
	var halo = CSGSphere3D.new()
	halo.name = "WeaponHalo"
	halo.radius = 0.7
	halo.radial_segments = 16
	halo.rings = 8
	
	var halo_mat = StandardMaterial3D.new()
	halo_mat.albedo_color = Color(_weapon_data.color.r, _weapon_data.color.g, _weapon_data.color.b, 0.25)
	halo_mat.emission_enabled = true
	halo_mat.emission = _weapon_data.color * 1.5
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material = halo_mat
	halo.position.y = 0.8
	
	add_child(halo)
	
	# Animación de pulso del halo
	var tw = create_tween().set_loops().set_parallel(true)
	tw.tween_property(halo, "scale", Vector3(1.3, 1.3, 1.3), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(halo, "scale", Vector3(0.8, 0.8, 0.8), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_collision() -> void:
	var shape = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	add_child(shape)
	
	var sphere = SphereShape3D.new()
	sphere.radius = 3.5  # Radio grande para pickup fácil
	shape.shape = sphere

func _start_animation() -> void:
	# Rotación constante
	var tw_rotate = create_tween().set_loops()
	tw_rotate.tween_property(self, "rotation_degrees:y", 360, 4.0).from(0)
	
	# Bobbing vertical
	var tw_bob = create_tween().set_loops().set_parallel(true)
	tw_bob.tween_property(self, "position:y", position.y + 0.4, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_bob.chain().tween_property(self, "position:y", position.y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	
	if body.is_in_group("player") and body.has_method("pickup_styloo_weapon"):
		# Pasar todos los datos del arma al player
		body.pickup_styloo_weapon(weapon_type, _weapon_data)
		rpc_destroy.rpc()

@rpc("authority", "call_local")
func rpc_destroy() -> void:
	# Guardar posición antes de destruir
	var pos = global_position
	# Efecto de recolección
	_spawn_pickup_effect(pos)
	queue_free()

func _spawn_pickup_effect(pos: Vector3) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	
	# Explosión de partículas al recoger
	var effect = GPUParticles3D.new()
	effect.amount = 50
	effect.lifetime = 0.8
	effect.explosiveness = 1.0
	effect.local_coords = false
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.color = _weapon_data.color
	mat.scale_min = 0.05
	mat.scale_max = 0.2
	effect.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	effect.draw_pass_1 = mesh
	
	tree.current_scene.add_child(effect)
	effect.global_position = pos
	
	# Auto-limpiar
	var timer = tree.create_timer(1.0)
	timer.timeout.connect(effect.queue_free)

# Función estática para obtener un tipo de arma aleatorio
static func get_random_weapon_type() -> String:
	var types = STYLOO_WEAPONS.keys()
	return types[randi() % types.size()]

# Función estática para obtener datos de un arma
static func get_weapon_data(weapon_type_name: String) -> Dictionary:
	if STYLOO_WEAPONS.has(weapon_type_name):
		return STYLOO_WEAPONS[weapon_type_name]
	return STYLOO_WEAPONS["katana"]  # Fallback
