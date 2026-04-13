extends Area3D

## WeaponPickup
## Gives the player the "Weapon" ability (Ability 3).
##
## Added support for weapon type, larger collision radius, and improved visuals.
##
@export var weapon_type: String = "sword"  # Type of weapon this pickup provides

func _ready() -> void:
	collision_mask = 1 # Players
	body_entered.connect(_on_body_entered)
	
	# Rotate and bob for visual effect
	var tw = create_tween().set_loops().set_parallel(true)
	tw.tween_property(self, "rotation_degrees:y", 360, 3.0).from(0)
	tw.tween_property(self, "position:y", position.y + 0.3, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(self, "position:y", position.y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Visual representation (MEJORADO - Floating Glowy Weapon con modelo 3D)
	var container = Node3D.new()
	container.name = "WeaponVisual"
	add_child(container)
	
	# Intentar cargar modelo de espada si existe
	var sword_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Blade.gltf"
	if ResourceLoader.exists(sword_path):
		var sword = load(sword_path).instantiate()
		sword.scale = Vector3(0.8, 0.8, 0.8)
		sword.position = Vector3(0, 0.8, 0)
		sword.rotation_degrees = Vector3(0, 90, 0)
		container.add_child(sword)
	else:
		# Fallback: CSG mejorado
		var mesh = CSGBox3D.new()
		mesh.size = Vector3(0.15, 0.6, 0.15)
		mesh.position.y = 0.8
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.CYAN
		mat.emission_enabled = true
		mat.emission = Color.CYAN * 3.0
		mat.emission_energy_multiplier = 4.0
		mat.metallic = 0.8
		mat.roughness = 0.2
		mesh.material = mat
		container.add_child(mesh)
		
		# Hoja de la espada
		var blade = CSGBox3D.new()
		blade.size = Vector3(0.08, 0.4, 0.4)
		blade.position = Vector3(0, 1.2, 0.15)
		blade.material = mat
		container.add_child(blade)

	# Partículas de brillo
	var particles = GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 1.0
	particles.local_coords = false
	
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.5
	particle_mat.gravity = Vector3(0, 0.5, 0)
	particle_mat.color = Color.CYAN
	particle_mat.scale_min = 0.05
	particle_mat.scale_max = 0.15
	particles.process_material = particle_mat
	
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	particles.draw_pass_1 = particle_mesh
	particles.position.y = 0.8
	add_child(particles)

	# Glow effect under it - INTENSIFICADO
	var light = OmniLight3D.new()
	light.light_color = Color.CYAN
	light.light_energy = 5.0
	light.omni_range = 5.0
	light.shadow_enabled = true
	add_child(light)
	
	# Halo glow sprite (opcional visual)
	var halo = CSGSphere3D.new()
	halo.radius = 0.6
	halo.radial_segments = 16
	halo.rings = 8
	var halo_mat = StandardMaterial3D.new()
	halo_mat.albedo_color = Color(0, 0.8, 1, 0.3)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color.CYAN * 2.0
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material = halo_mat
	halo.position.y = 0.8
	add_child(halo)
	
	# Animación de pulso del halo
	var tw_halo = create_tween().set_loops().set_parallel(true)
	tw_halo.tween_property(halo, "scale", Vector3(1.3, 1.3, 1.3), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_halo.chain().tween_property(halo, "scale", Vector3(0.8, 0.8, 0.8), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Ensure we have a large enough collision area
	_setup_collision()

func _setup_collision() -> void:
	# Try to find existing collision shape or create one
	var shape = get_node_or_null("CollisionShape3D")
	if not shape:
		shape = CollisionShape3D.new()
		add_child(shape)
	
	var sphere = SphereShape3D.new()
	sphere.radius = 3.0 # Larger radius for easier pickup
	shape.shape = sphere

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if body.is_in_group("player") and body.has_method("pickup_weapon"):
		body.pickup_weapon()
		rpc_destroy.rpc()

@rpc("authority", "call_local")
func rpc_destroy() -> void:
	queue_free()
