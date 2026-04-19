extends Area3D

## StylooWeaponPickup — Arma recogible en el suelo
## El nodo raíz (Area3D) NUNCA se mueve.
## Solo el hijo WeaponVisual rota y flota.

const WEAPON_PACK_PATH := "res://assets/models/weapons/weaponsassetspackbyStyloo/"

const STYLOO_WEAPONS := {
	"bayonet": {
		"file": "ASSETS.fbx_bayonet.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 90),
		"cooldown": 0.3, "damage": 35, "range": 3.0,
		"color": Color(0.7, 0.7, 0.8, 1.0)
	},
	"coolknife": {
		"file": "ASSETS.fbx_coolknife.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.25, "damage": 30, "range": 2.5,
		"color": Color(0.2, 0.8, 1.0, 1.0)
	},
	"doubleAxe": {
		"file": "ASSETS.fbx_doubleAxe.fbx",
		"scale": Vector3(0.012, 0.012, 0.012),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 1.0, "damage": 90, "range": 5.0,
		"color": Color(0.8, 0.2, 0.2, 1.0),
		"type": "ranged_lobber"
	},
	"katana": {
		"file": "ASSETS.fbx_katana.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.35, "damage": 45, "range": 3.5,
		"color": Color(1.0, 0.0, 0.5, 1.0)
	},
	"kunai": {
		"file": "ASSETS.fbx_kunai.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"rotation": Vector3(0, 45, 45),
		"cooldown": 0.2, "damage": 28, "range": 2.0,
		"color": Color(0.5, 0.0, 0.8, 1.0),
		"type": "ranged"
	},
	"longsword": {
		"file": "ASSETS.fbx_longsword.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.45, "damage": 50, "range": 4.5,
		"color": Color(0.9, 0.9, 1.0, 1.0)
	},
	"normalsword": {
		"file": "ASSETS.fbx_normalsword.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 0),
		"cooldown": 0.35, "damage": 40, "range": 3.0,
		"color": Color(0.6, 0.6, 0.7, 1.0)
	},
	"pickaxe": {
		"file": "ASSETS.fbx_pickaxe.fbx",
		"scale": Vector3(0.012, 0.012, 0.012),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 0.5, "damage": 55, "range": 3.5,
		"color": Color(0.4, 0.3, 0.2, 1.0)
	},
	"shuriken1": {
		"file": "ASSETS.fbx_shuriken1.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 22, "range": 2.0,
		"color": Color(1.0, 0.5, 0.0, 1.0),
		"type": "ranged"
	},
	"shuriken2": {
		"file": "ASSETS.fbx_shuriken2.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 22, "range": 2.0,
		"color": Color(0.0, 1.0, 0.5, 1.0),
		"type": "ranged"
	},
	"shuriken3": {
		"file": "ASSETS.fbx_shuriken3.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 18, "range": 2.0,
		"color": Color(1.0, 0.0, 1.0, 1.0),
		"type": "ranged"
	},
	"shuriken4": {
		"file": "ASSETS.fbx_shuriken4.fbx",
		"scale": Vector3(0.02, 0.02, 0.02),
		"rotation": Vector3(90, 0, 0),
		"cooldown": 0.15, "damage": 25, "range": 2.0,
		"color": Color(1.0, 0.8, 0.0, 1.0),
		"type": "ranged"
	},
	"simpleAxe": {
		"file": "ASSETS.fbx_simpleAxe.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 0, 0),
		"cooldown": 0.8, "damage": 70, "range": 4.0,
		"color": Color(0.5, 0.5, 0.4, 1.0),
		"type": "ranged_lobber"
	},
	"sword1": {
		"file": "ASSETS.fbx_sword1.fbx",
		"scale": Vector3(0.015, 0.015, 0.015),
		"rotation": Vector3(0, 90, 0),
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

	# Configurar collision — capa 1 para detectar jugadores en esa capa
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true

	# Añadir collision shape
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	col.shape = sphere
	add_child(col)

	# Conectar señal de pickup
	body_entered.connect(_on_body_entered)

	# Construir visual y animación en el siguiente frame
	# para que el nodo esté completamente en el árbol antes
	call_deferred("_build_visual")

	# Timer de despawn si fue dropeada
	if _is_dropped and multiplayer.is_server():
		var t := get_tree().create_timer(DESPAWN_TIME)
		t.timeout.connect(_fade_and_die)

func _build_visual() -> void:
	# ─── CONTENEDOR VISUAL ────────────────────────────────────────────
	# Este es el único nodo que se mueve (rota + bob).
	# El nodo raíz (Area3D) NUNCA se mueve — su posición es la del pickup.
	var visual := Node3D.new()
	visual.name = "WeaponVisual"
	visual.position = Vector3(0.0, 0.8, 0.0)  # elevado sobre el suelo
	add_child(visual)

	# ─── MODELO 3D ────────────────────────────────────────────────────
	var weapon_path: String = WEAPON_PACK_PATH + str(_weapon_data.get("file", ""))
	var loaded_model: Node3D = null

	if ResourceLoader.exists(weapon_path):
		var res := load(weapon_path)
		if res:
			loaded_model = res.instantiate()

	if loaded_model:
		# Escala + rotación definidas por datos del arma
		loaded_model.scale = _weapon_data.scale * 300.0
		loaded_model.rotation_degrees = _weapon_data.rotation
		# SIEMPRE en el origen del contenedor — evita órbita al rotar
		loaded_model.position = Vector3.ZERO
		_apply_texture(loaded_model)
		visual.add_child(loaded_model)
	else:
		# Fallback geométrico si no hay .fbx disponible
		visual.add_child(_make_fallback_mesh())

	# ─── LUZ ──────────────────────────────────────────────────────────
	var light := OmniLight3D.new()
	light.light_color = _weapon_data.get("color", Color.WHITE) as Color
	light.light_energy = 4.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)

	# ─── ANIMACIÓN ────────────────────────────────────────────────────
	# Armas estáticas en el suelo (sin animación)

func _apply_texture(model: Node3D) -> void:
	var tex_path := WEAPON_PACK_PATH + "3D weapons asset pack.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	if not tex:
		return
	for mesh in _find_meshes(model):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.metallic = 0.3
		mat.roughness = 0.5
		mesh.material_override = mat

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result

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

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if _is_dropped and _despawn_timer < 0.5:
		return
	if body.is_in_group("player") and body.has_method("pickup_styloo_weapon"):
		body.pickup_styloo_weapon(weapon_type, _weapon_data)
		rpc_destroy.rpc()

@rpc("authority", "call_local")
func rpc_destroy() -> void:
	queue_free()

func _fade_and_die() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(queue_free)

static func get_random_weapon_type() -> String:
	var keys := STYLOO_WEAPONS.keys()
	return keys[randi() % keys.size()]

static func get_weapon_data(wtype: String) -> Dictionary:
	if STYLOO_WEAPONS.has(wtype):
		return STYLOO_WEAPONS[wtype]
	return STYLOO_WEAPONS["katana"]
