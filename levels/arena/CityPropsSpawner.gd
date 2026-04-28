extends Node3D

## CityPropsSpawner — Premium Urban District
## Construye mapa urbano estilo Barcelona/La Sagrera con:
## - Calles principales y secundarias
## - Edificios de perímetro
## - Cobertura táctica (coches, contenedores)
## - Alumbrado público y decoración
## - Parque/área central

const CITY_PACK := "res://assets/models/environment/city_free_pack/"

func _ready() -> void:
	if multiplayer.is_server():
		await get_tree().create_timer(0.5).timeout
		_build_city()

func _build_city() -> void:
	print("CityPropsSpawner: Building La Sagrera urban district...")

	_build_city_blocks()
	_build_roads_network()
	_build_strategic_cover()
	_build_lighting_and_decoration()
	_build_central_park()

	if multiplayer.is_server():
		_place_starting_weapons()

	_bake_navmesh()
	print("CityPropsSpawner: City layout complete.")

func _place_starting_weapons() -> void:
	var weapon_pts = [
		Vector3(5, 0.5, 5), Vector3(-5, 0.5, 5), Vector3(5, 0.5, -5), Vector3(-5, 0.5, -5),
		Vector3(20, 0.5, 20), Vector3(-20, 0.5, 20), Vector3(20, 0.5, -20), Vector3(-20, 0.5, -20),
		Vector3(35, 0.5, 5), Vector3(-35, 0.5, -5), Vector3(15, 0.5, -30), Vector3(-15, 0.5, 30)
	]
	var styloo_types = [
		"bayonet", "coolknife", "doubleAxe", "katana", "kunai", "longsword",
		"normalsword", "pickaxe", "shuriken1", "shuriken2", "shuriken3", "shuriken4"
	]
	for i in range(weapon_pts.size()):
		rpc("_spawn_styloo_weapon_at", weapon_pts[i], styloo_types[i % styloo_types.size()])

@rpc("authority", "call_local")
func _spawn_styloo_weapon_at(pos: Vector3, weapon_type: String) -> void:
	var pickup_scene = load("res://entities/interactables/StylooWeaponPickup.tscn")
	if pickup_scene:
		var w = pickup_scene.instantiate()
		w.weapon_type = weapon_type
		get_tree().current_scene.add_child(w)
		w.global_position = pos

func _bake_navmesh() -> void:
	var nav_region = get_parent() as NavigationRegion3D
	if nav_region and nav_region.has_method("bake_navigation_mesh"):
		print("CityPropsSpawner: Baking NavMesh...")
		nav_region.call_deferred("bake_navigation_mesh")

# ═══════════════════════════════════════════════════════════════════
#  CITY BLOCKS — Cuadras de edificios
# ═══════════════════════════════════════════════════════════════════
func _build_city_blocks() -> void:
	print("CityPropsSpawner: Building city blocks...")

	# Cuadras NW (nord-oest)
	_place_solid("block2.glb", Vector3(-35, 0, -35), 0)
	_place_solid("building3.glb", Vector3(-25, 0, -35), 0)
	_place_solid("block2.glb", Vector3(-35, 0, -25), 90)

	# Cuadras NE
	_place_solid("building3.glb", Vector3(25, 0, -35), 0)
	_place_solid("block2.glb", Vector3(35, 0, -35), 0)
	_place_solid("building3.glb", Vector3(35, 0, -25), 90)

	# Cuadras SW
	_place_solid("block2.glb", Vector3(-35, 0, 25), 90)
	_place_solid("building3.glb", Vector3(-35, 0, 35), 0)
	_place_solid("block2.glb", Vector3(-25, 0, 35), 0)

	# Cuadras SE
	_place_solid("building3.glb", Vector3(25, 0, 35), 0)
	_place_solid("block2.glb", Vector3(35, 0, 25), 90)
	_place_solid("building3.glb", Vector3(35, 0, 35), 0)

	# Bloques adicionales para densidad urbana
	_place_solid("building3.glb", Vector3(-15, 0, -40), 180)
	_place_solid("block2.glb", Vector3(15, 0, -40), 180)
	_place_solid("building3.glb", Vector3(-15, 0, 40), 0)
	_place_solid("block2.glb", Vector3(15, 0, 40), 0)
	_place_solid("building3.glb", Vector3(-40, 0, 15), 90)
	_place_solid("block2.glb", Vector3(40, 0, 15), 270)
	_place_solid("building3.glb", Vector3(-40, 0, -15), 90)
	_place_solid("block2.glb", Vector3(40, 0, -15), 270)

# ═══════════════════════════════════════════════════════════════════
#  ROADS —calles y conexiones (sin colisión para fluidez)
#  NOTE: Roads are now static in .tscn, this adds decals only
# ═══════════════════════════════════════════════════════════════════
func _build_roads_network() -> void:
	print("CityPropsSpawner: Road network is static in .tscn, skipping decoration...")

# ═══════════════════════════════════════════════════════════════════
#  STRATEGIC COVER — 8 Coches para cobertura táctica
# ═══════════════════════════════════════════════════════════════════
func _build_strategic_cover() -> void:
	print("CityPropsSpawner: Building tactical cover...")

	# Zona norte
	_place_solid("redCar.glb", Vector3(10, 0.05, -12), 15)
	_place_solid("redCar.glb", Vector3(-10, 0.05, -12), 195)

	# Zona sur
	_place_solid("redCar.glb", Vector3(10, 0.05, 12), 15)
	_place_solid("redCar.glb", Vector3(-10, 0.05, 12), 195)

	# Zona este
	_place_solid("redCar.glb", Vector3(12, 0.05, 10), 105)
	_place_solid("redCar.glb", Vector3(12, 0.05, -10), 285)

	# Zona oeste
	_place_solid("redCar.glb", Vector3(-12, 0.05, 10), 105)
	_place_solid("redCar.glb", Vector3(-12, 0.05, -10), 285)

	# Corner coverage
	_place_solid("redCar.glb", Vector3(30, 0.05, 30), 45)
	_place_solid("redCar.glb", Vector3(-30, 0.05, -30), 225)

# ═══════════════════════════════════════════════════════════════════
#  LIGHTING & DECORATION — Solo objetos sobre calles/aceras transitables
# ═══════════════════════════════════════════════════════════════════
func _build_lighting_and_decoration() -> void:
	print("CityPropsSpawner: Building street props only...")

	# Alumbrado público en aceras (dentro del área transitable)
	var light_pts = [
		Vector3(-15, 0, -26), Vector3(15, 0, -26),
		Vector3(-15, 0, 26), Vector3(15, 0, 26),
		Vector3(-26, 0, -15), Vector3(-26, 0, 15),
		Vector3(26, 0, -15), Vector3(26, 0, 15)
	]
	for p in light_pts:
		_place_solid("streetLight.glb", p, 0)

	# Contenedores de basura en aceras
	var container_pts = [
		Vector3(8, 0, -26), Vector3(-8, 0, 26),
		Vector3(26, 0, 8), Vector3(-26, 0, -8)
	]
	for p in container_pts:
		_place_solid("garbageBin.glb", p, randf() * 360)

	# Fire hydrants en aceras
	_place_solid("fireHydrant.glb", Vector3(8, 0, 26), 0)
	_place_solid("fireHydrant.glb", Vector3(-8, 0, -26), 0)

	# Señales de tráfico
	_place_solid("stopSign.glb", Vector3(26, 0, 0), 90)
	_place_solid("stopSign.glb", Vector3(-26, 0, 0), 270)
	_place_solid("trafficLight.glb", Vector3(0, 0, 26), 180)

	# Benches en aceras
	_place_solid("bench2.glb", Vector3(8, 0, 0), 0)
	_place_solid("bench2.glb", Vector3(-8, 0, 0), 90)

# ═══════════════════════════════════════════════════════════════════
#  CENTRAL PARK — Solo decoración baja (no bloquea navegación)
# ═══════════════════════════════════════════════════════════════════
func _build_central_park() -> void:
	# Solo jardín bajo y árboles pequeños en el centro (intersección)
	_place_decoration("garden1.glb", Vector3(0, 0, 0), 0)
	_place_decoration("tree2.glb", Vector3(3, 0, 3), 0)
	_place_decoration("tree6.glb", Vector3(-3, 0, -3), 0)

# ═══════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════
func _place_solid(asset: String, pos: Vector3, rot_y: float) -> void:
	var inst = _instantiate_asset(asset)
	if inst:
		add_child(inst)
		inst.global_position = pos
		inst.rotation_degrees.y = rot_y
		_ensure_collision(inst)

func _place_decoration(asset: String, pos: Vector3, rot_y: float) -> void:
	var inst = _instantiate_asset(asset)
	if inst:
		add_child(inst)
		inst.global_position = pos
		inst.rotation_degrees.y = rot_y

func _instantiate_asset(asset_name: String) -> Node3D:
	var path: String = CITY_PACK + asset_name
	if not ResourceLoader.exists(path):
		print("CityPropsSpawner: Asset not found: " + path)
		return null
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		print("CityPropsSpawner: Failed to load scene: " + path)
		return null
	return scene.instantiate() as Node3D

func _ensure_collision(node: Node3D) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			return
	_add_collisions_recursive(node)

func _add_collisions_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).create_trimesh_collision()
	for child in node.get_children():
		_add_collisions_recursive(child)