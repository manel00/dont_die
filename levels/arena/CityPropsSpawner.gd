extends Node3D

## CityPropsSpawner — Premium Urban District
## Creates a clean, performance-friendly city layout with wide paths.
## - Invisible floor (uses parent's collision)
## - Perimeter buildings for atmosphere
## - Strategic cover with 6 vehicles
## - No roads (eliminates Z-fighting/flickering)

const CITY_PACK := "res://assets/models/environment/glb or gltf city free  pack/"

func _ready() -> void:
	if multiplayer.is_server():
		# Small delay to ensure scene is ready
		await get_tree().create_timer(0.5).timeout
		_build_city()

func _build_city() -> void:
	print("CityPropsSpawner: Building optimized urban district...")
	
	_build_perimeter_buildings()
	_build_strategic_cover()
	_build_lighting_and_decoration()
	
	if multiplayer.is_server():
		_place_starting_weapons()
	
	# Bake navigation now that all geometry is present
	_bake_navmesh()
	
	print("CityPropsSpawner: City layout complete.")

func _place_starting_weapons() -> void:
	# Spawnear armas Styloo aleatorias (12 tipos diferentes)
	var weapon_pts = [
		Vector3(0, 0.5, 5), Vector3(10, 0.5, 0), Vector3(-10, 0.5, 5), 
		Vector3(0, 0.5, -10), Vector3(12, 0.5, 12), Vector3(-12, 0.5, -12),
		Vector3(20, 0.5, 20), Vector3(-20, 0.5, -20), Vector3(25, 0.5, -15),
		Vector3(-25, 0.5, 15), Vector3(15, 0.5, -25), Vector3(-15, 0.5, 25)
	]
	
	# Styloo weapon types
	var styloo_types = [
		"bayonet", "coolknife", "doubleAxe", "katana", "kunai", "longsword",
		"normalsword", "pickaxe", "shuriken1", "shuriken2", "shuriken3", "shuriken4",
		"simpleAxe", "sword1"
	]
	
	for i in range(weapon_pts.size()):
		var weapon_type = styloo_types[i % styloo_types.size()]
		rpc("_spawn_styloo_weapon_at", weapon_pts[i], weapon_type)

@rpc("authority", "call_local")
func _spawn_styloo_weapon_at(pos: Vector3, weapon_type: String) -> void:
	var pickup_scene = load("res://entities/interactables/StylooWeaponPickup.tscn")
	if pickup_scene:
		var w = pickup_scene.instantiate()
		w.weapon_type = weapon_type
		get_tree().current_scene.add_child(w)
		w.global_position = pos

@rpc("authority", "call_local")
func _spawn_weapon_pickup_at(p: Vector3) -> void:
	var pickup_scene = load("res://entities/interactables/WeaponPickup.tscn")
	if pickup_scene:
		var w = pickup_scene.instantiate()
		get_tree().current_scene.add_child(w)
		w.global_position = p

func _bake_navmesh() -> void:
	var nav_region = get_parent() as NavigationRegion3D
	if nav_region and nav_region.has_method("bake_navigation_mesh"):
		print("CityPropsSpawner: Baking NavMesh...")
		nav_region.call_deferred("bake_navigation_mesh")

# ═══════════════════════════════════════════════════════════════════
#  BUILDINGS — Perimeter "Walls" (with collision)
# ═══════════════════════════════════════════════════════════════════
func _build_containers_as_obstacles() -> void:
	## Contenedores y obstáculos urbanos repartidos por el mapa
	print("CityPropsSpawner: Building containers as obstacles...")
	
	# Contenedores de basura como cobertura/obstáculos
	var container_pts = [
		Vector3(10, 0, 10), Vector3(-10, 0, -10),
		Vector3(15, 0, -15), Vector3(-15, 0, 15),
		Vector3(25, 0, 5), Vector3(-25, 0, -5)
	]
	for p in container_pts:
		_place_solid("garbageBin.glb", p, randf() * 360)
	
	# Papelera grande y banco adicional
	_place_solid("garbageBin.glb", Vector3(5, 0, 18), 30)
	_place_solid("fireHydrant.glb", Vector3(-5, 0, -18), 0)
	_place_solid("stopSign.glb", Vector3(12, 0, 12), 45)
	_place_solid("stopSign.glb", Vector3(-12, 0, -12), 225)

func _build_perimeter_buildings() -> void:
	# North Wall
	_place_solid("building3.glb", Vector3(-25, 0, -45), 180)
	_place_solid("block2.glb", Vector3(-10, 0, -48), 180)
	_place_solid("building3.glb", Vector3(10, 0, -48), 180)
	_place_solid("block2.glb", Vector3(25, 0, -45), 180)
	
	# South Wall
	_place_solid("building3.glb", Vector3(-25, 0, 45), 0)
	_place_solid("block2.glb", Vector3(-10, 0, 48), 0)
	_place_solid("building3.glb", Vector3(10, 0, 48), 0)
	_place_solid("block2.glb", Vector3(25, 0, 45), 0)
	
	# East Wall
	_place_solid("building3.glb", Vector3(45, 0, -25), 270)
	_place_solid("block2.glb", Vector3(48, 0, -10), 270)
	_place_solid("building3.glb", Vector3(48, 0, 10), 270)
	_place_solid("block2.glb", Vector3(45, 0, 25), 270)
	
	# West Wall
	_place_solid("building3.glb", Vector3(-45, 0, -25), 90)
	_place_solid("block2.glb", Vector3(-48, 0, -10), 90)
	_place_solid("building3.glb", Vector3(-48, 0, 10), 90)
	_place_solid("block2.glb", Vector3(-45, 0, 25), 90)

# ═══════════════════════════════════════════════════════════════════
#  STRATEGIC COVER — 6 Cars (with collision)
# ═══════════════════════════════════════════════════════════════════
func _build_strategic_cover() -> void:
	# Distributed for tactical advantage
	_place_solid("redCar.glb", Vector3(18, 0.05, -3), 15)
	_place_solid("redCar.glb", Vector3(-18, 0.05, 3), 195)
	_place_solid("redCar.glb", Vector3(3, 0.05, 18), 105)
	_place_solid("redCar.glb", Vector3(-3, 0.05, -18), 285)
	_place_solid("redCar.glb", Vector3(30, 0.05, 15), 45)
	_place_solid("redCar.glb", Vector3(-30, 0.05, -15), 225)

# ═══════════════════════════════════════════════════════════════════
#  DECORATION — Subtle details (NO collision for fluid movement)
# ═══════════════════════════════════════════════════════════════════
func _build_lighting_and_decoration() -> void:
	# Contenedores y obstáculos sólidos
	_build_containers_as_obstacles()
	
	# Street Lights - AHORA SON OBSTÁCULOS CON COLISIÓN
	var light_pts = [
		Vector3(-20, 0, -20), Vector3(0, 0, -25), Vector3(20, 0, -20),
		Vector3(25, 0, 0), Vector3(20, 0, 20), Vector3(0, 0, 25),
		Vector3(-20, 0, 20), Vector3(-25, 0, 0)
	]
	for p in light_pts:
		_place_solid("streetLight.glb", p, 0)
	
	# Benches near the center - AHORA SON OBSTÁCULOS
	_place_solid("bench2.glb", Vector3(8, 0, 8), 45)
	_place_solid("bench2.glb", Vector3(-8, 0, -8), 225)
	
	# Signage and other props
	_place_decoration("trafficLight.glb", Vector3(22, 0, -3), 0)
	_place_decoration("trafficLight.glb", Vector3(-22, 0, 3), 180)
	_place_decoration("stopSign.glb", Vector3(35, 0, -3), 0)
	_place_decoration("stopSign.glb", Vector3(-35, 0, 3), 180)
	
	# Smaller debris/details
	_place_decoration("garbageBin.glb", Vector3(15, 0, -22), 0)
	_place_decoration("fireHydrant.glb", Vector3(-15, 0, 22), 0)
	_place_decoration("trashBag1.glb", Vector3(16, 0, -21), 30)
	_place_decoration("trashBag2.glb", Vector3(-16, 0, 23), 15)
	
	# Nature (trees)
	_place_decoration("tree2.glb", Vector3(35, 0, 35), 0)
	_place_decoration("tree6.glb", Vector3(-35, 0, -35), 0)
	_place_decoration("tree2.glb", Vector3(40, 0, 0), 0)
	_place_decoration("tree6.glb", Vector3(-40, 0, 0), 0)

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
		# Decorations have NO collision to keep movement 100% fluid

func _instantiate_asset(asset_name: String) -> Node3D:
	var path: String = CITY_PACK + asset_name
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		return null
	return scene.instantiate() as Node3D

func _ensure_collision(node: Node3D) -> void:
	# Verify if it already has collision
	for child in node.get_children():
		if child is StaticBody3D:
			return
	
	# If not, generate it
	_add_collisions_recursive(node)

func _add_collisions_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).create_trimesh_collision()
	for child in node.get_children():
		_add_collisions_recursive(child)
