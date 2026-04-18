extends Area3D

## StylooWeaponPickup â€” Sistema completo de pickups para el pack de armas Styloo
## 12 armas Ãºnicas: bayonet, coolknife, doubleAxe, katana, kunai, longsword, 
## normalsword, pickaxe, shuriken1-4, simpleAxe, sword1

const WEAPON_PACK_PATH := "res://assets/models/weapons/weaponsassetspackbyStyloo/"

# DefiniciÃ³n completa de las 12 armas Styloo
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
		"type": "ranged_lobber"  # Lanzamiento pesado con arco, daÃ±o en Ã¡rea masivo
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
		"color": Color(0.5, 0.0, 0.8, 1.0),  # PÃºrpura
		"type": "ranged"  # Proyectil muy rÃ¡pido que atraviesa enemigos
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
		"color": Color(0.4, 0.3, 0.2, 1.0)  # MarrÃ³n herrumbre
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
		"type": "ranged"  # Proyectil rÃ¡pido que rebota
	},
	"shuriken2": {
		"file": "ASSETS.fbx_shuriken2.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"position": Vector3(0, 0.6, 0),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15,
		"damage": 22,
		"range": 2.0,
		"color": Color(0.0, 1.0, 0.5, 1.0),  # Verde neÃ³n
		"type": "ranged"  # Proyectil rÃ¡pido que rebota
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
		"type": "ranged"  # Proyectil rÃ¡pido que rebota
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
		"type": "ranged"  # Proyectil rÃ¡pido que rebota
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
		"type": "ranged_lobber"  # Lanzamiento pesado con arco, daÃ±o en Ã¡rea
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
var _is_dropped: bool = false  # true = droppeado por jugador, desaparecerÃ¡ si no se recoge
var _despawn_timer: float = 0.0
const DESPAWN_TIME: float = 5.0  # Segundos antes de desaparecer si es droppeado

func _ready() -> void:
	# Validar weapon_type
	if not STYLOO_WEAPONS.has(weapon_type):
		weapon_type = "katana"  # Fallback
	
	# Si no se asignaron datos externos (vÃ­a drop), usar defaults
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
	
	# Si es droppeado, iniciar timer de desapariciÃ³n
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
	# print("Weapon dropped: ", weapon_type, " - Despawn in ", DESPAWN_TIME, "s")

func _start_fading_warning() -> void:
	# Parpadeo mÃ¡s rÃ¡pido cuando estÃ¡ a punto de desaparecer
	var visual = get_node_or_null("WeaponVisual")
	if visual:
		for child in visual.get_children():
			if child is GeometryInstance3D:
				# Hacer que parpadee durante los Ãºltimos 3 segundos
				var tw = create_tween().set_loops()
				tw.tween_property(child, "modulate:a", 0.3, 0.2)
				tw.tween_property(child, "modulate:a", 1.0, 0.2)

func _fade_out_and_despawn() -> void:
	# Fade out y desaparecer
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.5)
	tw.tween_callback(queue_free)

func _create_uses_indicator(uses_left: int) -> void:
	# Sistema de municion infinita, ya no mostramos indicador de usos
	pass

func _setup_visual() -> void:
	# Container para el arma
	var container = Node3D.new()
	container.name = "WeaponVisual"
	add_child(container)
	
	# Mostrar usos restantes si es un arma con durabilidad limitada
	pass
	
	# Intentar cargar modelo 3D
	var weapon_path: String = WEAPON_PACK_PATH + _weapon_data.file
	# print("Attempting to load weapon: ", weapon_path)
	
	var weapon_resource = load(weapon_path)
	if weapon_resource:
		# print("Weapon file loaded, instantiating...")
		var weapon_model = weapon_resource.instantiate()
		# Aplicar escala (se multiplica por 300 para hacerlo 3 veces mÃ¡s grande de lo orginal 100x y contrarrestar el importe de Godot)
		weapon_model.scale = _weapon_data.scale * 300.0
		weapon_model.position = _weapon_data.position
		weapon_model.rotation_degrees = _weapon_data.rotation
		
		# Aplicar la textura correcta
		_apply_weapon_materials(weapon_model)
		
		container.add_child(weapon_model)
		# print("Weapon added to scene successfully")
	else:
		# print("WARNING: Weapon file could not be loaded: ", weapon_path)
		# Fallback: Crear representaciÃ³n con formas geomÃ©tricas
		_create_fallback_visual(container)
	
	# PartÃ­culas de brillo con color del arma (pero reducidas para no tapar)
	_create_particles()
	
	# Luz omnidireccional con color del arma
	_create_light()
	
	# Eliminado el "Halo glow" para que el arma se pueda ver perfectamente

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
			# Cuchillo - forma pequeÃ±a y afilada
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
	pass

func _create_light() -> void:
	var light = OmniLight3D.new()
	light.name = "WeaponLight"
	light.light_color = _weapon_data.color
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.shadow_enabled = true
	add_child(light)

func _setup_collision() -> void:
	var shape = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	add_child(shape)
	
	var sphere = SphereShape3D.new()
	sphere.radius = 1.0  # Radio más ajustado para no atraparlas a kilómetros
	shape.shape = sphere

func _start_animation() -> void:
	# RotaciÃ³n constante
	var tw_rotate = create_tween().set_loops()
	tw_rotate.tween_property(self, "rotation_degrees:y", 360, 4.0).from(0)
	
	# Bobbing vertical
	var tw_bob = create_tween().set_loops().set_parallel(true)
	tw_bob.tween_property(self, "position:y", position.y + 0.4, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_bob.chain().tween_property(self, "position:y", position.y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
		
	# Evitar recoger el arma en la misma décima de segundo que acabamos de dropearla (impide el bug de no poder soltar con Q)
	if _is_dropped and _despawn_timer < 0.5:
		return
	
	if body.is_in_group("player") and body.has_method("pickup_styloo_weapon"):
		# Pasar todos los datos del arma al player
		body.pickup_styloo_weapon(weapon_type, _weapon_data)
		rpc_destroy.rpc()

@rpc("authority", "call_local")
func rpc_destroy() -> void:
	# Guardar posiciÃ³n antes de destruir
	var pos = global_position
	# Efecto de recolecciÃ³n
	_spawn_pickup_effect(pos)
	queue_free()

func _spawn_pickup_effect(pos: Vector3) -> void:
	pass

# FunciÃ³n estÃ¡tica para obtener un tipo de arma aleatorio
static func get_random_weapon_type() -> String:
	var types = STYLOO_WEAPONS.keys()
	return types[randi() % types.size()]

# FunciÃ³n estÃ¡tica para obtener datos de un arma
static func get_weapon_data(weapon_type_name: String) -> Dictionary:
	if STYLOO_WEAPONS.has(weapon_type_name):
		return STYLOO_WEAPONS[weapon_type_name]
	return STYLOO_WEAPONS["katana"]  # Fallback
