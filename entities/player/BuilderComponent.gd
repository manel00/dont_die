class_name BuilderComponent
extends Node3D

@export var barricade_scene: PackedScene
@export var grid_size: float = 2.0
@export var build_range: float = 4.0
@export var max_barricades: int = 10

var barricades_placed: int = 0

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("build_barricade"):
		_attempt_build()

func _attempt_build() -> void:
	if barricades_placed >= max_barricades:
		print("Límite de barricadas alcanzado.")
		return
		
	if not barricade_scene:
		print("No se ha asignado la escena Barricade al BuilderComponent!")
		return
	
	# FIX: Server-authoritative — sólo el servidor instancia barricadas
	if multiplayer.is_server():
		_do_build()
	else:
		# Clientes envían petición al servidor
		rpc_id(1, "rpc_request_build")

@rpc("any_peer")
func rpc_request_build() -> void:
	if multiplayer.is_server():
		_do_build()

func _do_build() -> void:
	var player := get_parent() as Node3D
	if not player: return
	
	var visual := player.get_node_or_null("VisualModel") as Node3D
	var forward_dir := Vector3.FORWARD
	
	if visual:
		forward_dir = -visual.global_transform.basis.z
	
	var place_position: Vector3 = player.global_position + (forward_dir * build_range)
	
	# Grid Snap
	place_position.x = round(place_position.x / grid_size) * grid_size
	place_position.z = round(place_position.z / grid_size) * grid_size
	place_position.y = 0.0
	
	var barricade := barricade_scene.instantiate()
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(barricade, true)  # true = asigna nombre único (network-friendly)
		barricade.global_position = place_position
	else:
		get_tree().root.add_child(barricade, true)
		barricade.global_position = place_position
	barricades_placed += 1
	
	print("Barricada construida en ", place_position)
