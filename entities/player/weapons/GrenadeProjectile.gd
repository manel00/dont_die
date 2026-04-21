class_name GrenadeProjectile
extends RigidBody3D

@export var damage: int = 60
@export var explosion_radius: float = 6.0
@export var life_time: float = 4.0
@export var hit_group: String = "enemies"

var initial_velocity: Vector3 = Vector3.ZERO
var _has_exploded: bool = false
var _armed: bool = false



func _ready() -> void:
	add_to_group("projectiles")

	# Propiedades físicas — gravedad manual para coincidir con la preview
	mass = 1.0
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 0.5

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Timer de vida
	var timer := get_tree().create_timer(life_time)
	timer.timeout.connect(_explode)

	_create_visual()

	if initial_velocity != Vector3.ZERO:
		linear_velocity = initial_velocity
		_armed = true
	else:
		call_deferred("_apply_initial_velocity")

func _apply_initial_velocity() -> void:
	if initial_velocity != Vector3.ZERO and not _armed:
		linear_velocity = initial_velocity
		_armed = true

func _create_visual() -> void:
	if has_node("GrenadeMesh"):
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GrenadeMesh"
	add_child(mesh_instance)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.25
	sphere_mesh.height = 0.5
	mesh_instance.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	mat.metallic = 0.8
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 0.2)
	mat.emission_energy_multiplier = 2.0
	mesh_instance.material_override = mat

	var light := OmniLight3D.new()
	light.name = "GrenadeLight"
	light.light_color = Color(1.0, 0.0, 0.1)
	light.light_energy = 3.0
	light.omni_range = 4.0
	add_child(light)

	# Pulso de la luz (usando set_loops correctamente)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(light, "light_energy", 5.0, 0.3)
	tw.tween_property(light, "light_energy", 1.5, 0.3)

const GRAVITY: float = -20.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.linear_velocity.y += GRAVITY * state.step
	if global_position.y < -20:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if _has_exploded:
		return
	if body.is_in_group(hit_group) and body.has_method("take_damage"):
		_explode()
	elif body.is_in_group("world") or body is StaticBody3D or body is CSGShape3D:
		_explode()

func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	freeze = true

	# Guardar posición antes de destruir el nodo
	var explosion_pos: Vector3 = global_position
	var scene: Node = get_tree().current_scene

	# 1) Lanzar efecto ANTES de queue_free (el efecto es autónomo)
	_spawn_explosion_effect(explosion_pos, scene)

	# 2) Daño en área + flash visual en enemigos afectados
	_apply_area_damage(explosion_pos, scene)

	# 3) Destruir el proyectil
	queue_free()

# ---------------------------------------------------------------------------
# Instancia ExplosionEffect como nodo autónomo en la escena raíz
# ---------------------------------------------------------------------------
func _spawn_explosion_effect(pos: Vector3, scene: Node) -> void:
	if not scene:
		return

	var effect: ExplosionEffect = ExplosionEffect.new()
	effect.blast_radius = explosion_radius
	scene.add_child(effect)
	effect.global_position = pos

# ---------------------------------------------------------------------------
# Daño con falloff de distancia + flash naranja en cada enemigo golpeado
# ---------------------------------------------------------------------------
func _apply_area_damage(pos: Vector3, scene: Node) -> void:
	var targets := get_tree().get_nodes_in_group(hit_group)
	for i in range(targets.size()):
		var t: Node = targets[i]
		if not is_instance_valid(t):
			continue
		if not t is Node3D:
			continue
		var target_3d := t as Node3D
		var dist: float = target_3d.global_position.distance_to(pos)
		if dist <= explosion_radius:
			# Daño con falloff lineal (mínimo 10% del daño base)
			var falloff: float = 1.0 - (dist / explosion_radius)
			falloff = clampf(falloff, 0.1, 1.0)
			var final_damage: int = int(float(damage) * falloff)
			if target_3d.has_method("take_damage"):
				target_3d.call("take_damage", final_damage)
			# Flash amarillo/naranja visual en el enemigo afectado
			_flash_enemy_hit(target_3d, scene)

# ---------------------------------------------------------------------------
# Flash naranja en el enemigo afectado por la explosión
# ---------------------------------------------------------------------------
func _flash_enemy_hit(enemy: Node3D, scene: Node) -> void:
	if not scene:
		return

	# Flash en el enemigo: un quad naranja translúcido que aparece y desaparece
	var flash := MeshInstance3D.new()
	flash.name = "EnemyHitFlash"

	var quad := SphereMesh.new()
	quad.radius = 0.6
	quad.height = 1.2
	quad.radial_segments = 8
	quad.rings = 4
	flash.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.0)
	mat.emission_energy_multiplier = 5.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = mat

	scene.add_child(flash)
	flash.global_position = enemy.global_position + Vector3(0, 0.8, 0)

	# Tween propio del flash (sobrevive sin depender del grenade)
	var tw := flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.1)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(flash.queue_free)
