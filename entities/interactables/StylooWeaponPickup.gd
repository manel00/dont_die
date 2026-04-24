extends Area3D

## StylooWeaponPickup — Arma recogible en el suelo
## El nodo raíz (Area3D) NUNCA se mueve.
## Solo el hijo WeaponVisual rota y flota.

const WEAPON_PACK_PATH := "res://assets/models/weapons/weaponsassetspackbyStyloo/"

const STYLOO_WEAPONS := {
	"bayonet": {
		"file": "ASSETS.fbx_bayonet.fbx",
		"scale": Vector3(0.03, 0.03, 0.03),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.3, "damage": 35, "range": 3.0,
		"color": Color(0.7, 0.7, 0.8, 1.0),
		"type": "ranged"
	},
	"coolknife": {
		"file": "ASSETS.fbx_coolknife.fbx",
		"scale": Vector3(0.03, 0.03, 0.03),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.25, "damage": 30, "range": 2.5,
		"color": Color(0.2, 0.8, 1.0, 1.0),
		"type": "ranged"
	},
	"doubleAxe": {
		"file": "ASSETS.fbx_doubleAxe.fbx",
		"scale": Vector3(0.024, 0.024, 0.024),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 1.0, "damage": 90, "range": 5.0,
		"color": Color(0.8, 0.2, 0.2, 1.0),
		"type": "ranged_lobber"
	},
	"katana": {
		"file": "ASSETS.fbx_katana.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.35, "damage": 45, "range": 3.5,
		"color": Color(1.0, 0.0, 0.5, 1.0)
	},
	"kunai": {
		"file": "ASSETS.fbx_kunai.fbx",
		"scale": Vector3(0.04, 0.04, 0.04),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.2, "damage": 28, "range": 2.0,
		"color": Color(0.5, 0.0, 0.8, 1.0),
		"type": "ranged"
	},
	"longsword": {
		"file": "ASSETS.fbx_longsword.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.45, "damage": 50, "range": 4.5,
		"color": Color(0.9, 0.9, 1.0, 1.0)
	},
	"normalsword": {
		"file": "ASSETS.fbx_normalsword.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.35, "damage": 40, "range": 3.0,
		"color": Color(0.6, 0.6, 0.7, 1.0)
	},
	"pickaxe": {
		"file": "ASSETS.fbx_pickaxe.fbx",
		"scale": Vector3(0.024, 0.024, 0.024),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 0.5, "damage": 55, "range": 3.5,
		"color": Color(0.4, 0.3, 0.2, 1.0)
	},
	"shuriken1": {
		"file": "ASSETS.fbx_shuriken1.fbx",
		"scale": Vector3(0.04, 0.04, 0.04),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 22, "range": 2.0,
		"color": Color(1.0, 0.5, 0.0, 1.0),
		"type": "ranged"
	},
	"shuriken2": {
		"file": "ASSETS.fbx_shuriken2.fbx",
		"scale": Vector3(0.04, 0.04, 0.04),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 22, "range": 2.0,
		"color": Color(0.0, 1.0, 0.5, 1.0),
		"type": "ranged"
	},
	"shuriken3": {
		"file": "ASSETS.fbx_shuriken3.fbx",
		"scale": Vector3(0.04, 0.04, 0.04),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 18, "range": 2.0,
		"color": Color(1.0, 0.0, 1.0, 1.0),
		"type": "ranged"
	},
	"shuriken4": {
		"file": "ASSETS.fbx_shuriken4.fbx",
		"scale": Vector3(0.04, 0.04, 0.04),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 25, "range": 2.0,
		"color": Color(1.0, 0.8, 0.0, 1.0),
		"type": "ranged"
	},
	"simpleAxe": {
		"file": "ASSETS.fbx_simpleAxe.fbx",
		"scale": Vector3(0.03, 0.03, 0.03),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 0.8, "damage": 70, "range": 4.0,
		"color": Color(0.5, 0.5, 0.4, 1.0),
		"type": "ranged_lobber"
	},
	"sword1": {
		"file": "ASSETS.fbx_sword1.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.35, "damage": 42, "range": 3.2,
		"color": Color(0.3, 0.8, 1.0, 1.0)
	}
}

@export var weapon_type: String = "katana"

var _weapon_data: Dictionary = {}
var _is_dropped: bool = false
var _despawn_timer: float = 0.0
const DESPAWN_TIME: float = 15.0

func _ready() -> void:
	# Asegurar multiplayer peer en modo offline/standalone
	if not multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	# Validar y cargar datos del arma
	if not STYLOO_WEAPONS.has(weapon_type):
		weapon_type = "katana"
	_weapon_data = STYLOO_WEAPONS[weapon_type]

	add_to_group("styloo_pickups")

	# Configurar collision — capa 2 para pickupeables, detecta capa 1 (jugadores)
	collision_layer = 2  # Capa de pickupeables
	collision_mask = 1   # Detecta jugadores (capa 1 por defecto)
	monitoring = true
	call_deferred("set", "monitorable", true)  # Usar call_deferred como indica el error

	# Añadir collision shape - MISMA ALTURA QUE EL ARMA VISUAL
	var col := CollisionShape3D.new()
	col.name = "PickupCollision"
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	col.shape = sphere
	col.position = Vector3(0, 0.3, 0)  # Misma altura que WeaponVisual
	add_child(col)
	
	# Conectar señal de pickup
	body_entered.connect(_on_body_entered)

	# Construir visual y animación en el siguiente frame
	# para que el nodo esté completamente en el árbol antes
	call_deferred("_build_visual")

	# Timer de despawn REMOVIDO de _ready para evitar que armas naturales desaparezcan.
	# Solo se gestionará en _process si _is_dropped == true.

func _build_visual() -> void:
	# ─── CONTENEDOR VISUAL ────────────────────────────────────────────
	# Este es el único nodo que se mueve (rota + bob).
	var visual := Node3D.new()
	visual.name = "WeaponVisual"
	visual.position = Vector3(0.0, 0.7, 0.0)  # elevado sobre el suelo (0.7m)
	add_child(visual)

	# ─── MODELO 3D ────────────────────────────────────────────────────
	var weapon_path: String = WEAPON_PACK_PATH + str(_weapon_data.get("file", ""))
	var loaded_model: Node3D = null

	if ResourceLoader.exists(weapon_path):
		var res := load(weapon_path)
		if res:
			loaded_model = res.instantiate()

	if loaded_model:
		var is_small_weapon := weapon_type.contains("shuriken") or weapon_type == "kunai" or weapon_type.contains("knife") or weapon_type == "bayonet" or weapon_type.contains("Axe") or weapon_type == "pickaxe"
		var scale_multiplier := 450.0 if is_small_weapon else 300.0
		
		loaded_model.scale = _weapon_data.scale * scale_multiplier * 0.5
		loaded_model.rotation_degrees = _weapon_data.rotation
		_apply_texture(loaded_model)
		_center_model(loaded_model)
		visual.add_child(loaded_model)
	else:
		visual.add_child(_make_fallback_mesh())

	# ─── LUZ ──────────────────────────────────────────────────────────
	var light := OmniLight3D.new()
	light.light_color = _weapon_data.get("color", Color.WHITE) as Color
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position = Vector3(0, 0.5, 0)
	add_child(light)

	# ─── ANIMACIÓN ────────────────────────────────────────────────────
	# Hacer que el arma flote y rote para que se vea premium y NUNCA toque el suelo
	var tw = visual.create_tween().set_loops()
	tw.tween_property(visual, "position:y", 0.9, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "position:y", 0.7, 1.2).set_trans(Tween.TRANS_SINE)
	
	var tw_rot = visual.create_tween().set_loops()
	tw_rot.tween_property(visual, "rotation:y", TAU, 3.0).as_relative()

func _apply_texture(model: Node3D) -> void:
	var tex_path := WEAPON_PACK_PATH + "3D weapons asset pack.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
		
	# Crear un único material para compartir entre mallas
	var mat := StandardMaterial3D.new()
	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = _weapon_data.get("color", Color.WHITE)
		
	mat.metallic = 0.4
	mat.roughness = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	
	for mesh in _find_meshes(model):
		if mesh.mesh == null:
			continue
		# Usar surface_override_material es más robusto para archivos FBX
		for i in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(i, mat)

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result

func _center_model(model: Node3D) -> void:
	# Calcular bounding box de todos los meshes PARA EL MODELO ENTERO
	var meshes := _find_meshes(model)
	if meshes.is_empty():
		return
	
	var aabb := AABB()
	var first := true
	for mesh in meshes:
		if mesh.mesh:
			# IMPORTANTE: Obtener AABB local y transformarlo al espacio del 'model'
			# Esto maneja casos donde el mesh está desplazado dentro del FBX
			var local_aabb := mesh.mesh.get_aabb()
			var mesh_transform := mesh.transform
			var transformed_aabb := mesh_transform * local_aabb
			
			if first:
				aabb = transformed_aabb
				first = false
			else:
				aabb = aabb.merge(transformed_aabb)
	
	# Centrar el modelo: moverlo para que el centro del bounding box esté en (0,0,0) relativo a 'visual'
	# BUG FIX: El desplazamiento debe tener en cuenta la escala y rotación del propio modelo (multiplicando por ellas)
	var center := aabb.get_center()
	model.position = -(model.quaternion * (model.scale * center))

func _make_fallback_mesh() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.6, 0.06)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	var col: Color = _weapon_data.get("color", Color.YELLOW) as Color
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.7
	mesh.material_override = mat
	return mesh

func _process(delta: float) -> void:
	if _is_dropped:
		_despawn_timer += delta
		if _despawn_timer >= DESPAWN_TIME:
			_fade_and_die()

func _on_body_entered(body: Node3D) -> void:
	# Pickup automático al tocar un jugador
	# Solo funciona en servidor o modo offline
	var is_authority = multiplayer.is_server() or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if not is_authority:
		return
	
	# Cooldown para armas recién droppeadas (evitar recoger inmediatamente)
	if _is_dropped and _despawn_timer < 0.5:
		return
	
	if body.is_in_group("player"):
		if body.has_method("pickup_styloo_weapon"):
			var success: bool = body.pickup_styloo_weapon(weapon_type, _weapon_data)
			
			if success:
				# ÚNICO DEBUG PERMITIDO: Informar del arma recogida
				print("WEAPON PICKED UP: ", weapon_type)
				
				# Destruir pickup — FIX: authority check before RPC
				if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
					if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
						rpc_destroy.rpc()
					else:
						queue_free()
				else:
					rpc_destroy.rpc_id(1)

@rpc("authority", "call_local")
func rpc_destroy() -> void:
	queue_free()

func _fade_and_die() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	# BUG FIX: Nunca escalar exactamente a ZERO para evitar errores de matriz no invertible (det == 0)
	tw.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.4)
	tw.tween_callback(queue_free)

static func get_random_weapon_type() -> String:
	var keys := STYLOO_WEAPONS.keys()
	return keys[randi() % keys.size()]

static func get_weapon_data(wtype: String) -> Dictionary:
	if STYLOO_WEAPONS.has(wtype):
		return STYLOO_WEAPONS[wtype]
	return STYLOO_WEAPONS["katana"]
