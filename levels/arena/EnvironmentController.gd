extends Node3D

## Controlador del Entorno Visual (Dual Style)
## Transita desde Low-Poly "Friendly" hacia Dark "Terrorific" basado en la oleada activa

@export var environment_node: WorldEnvironment
@export var sun_light: DirectionalLight3D

@export_category("Themes")
@export var bright_sky_color: Color = Color(0.4, 0.7, 1.0)
@export var bright_sun_color: Color = Color(1.0, 0.95, 0.9)
@export var bright_sun_energy: float = 1.5

@export var dark_sky_color: Color = Color(0.05, 0.05, 0.1)
@export var dark_sun_color: Color = Color(0.1, 0.1, 0.2)
@export var dark_sun_energy: float = 0.2

@export var transition_duration: float = 3.0

@onready var _wave_manager: Node = get_node_or_null("/root/WaveManager")
var current_tween: Tween

func _ready() -> void:
	# FIX: Buscar nodos automáticamente si los exports no están asignados
	if not environment_node:
		environment_node = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not sun_light:
		sun_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if not sun_light:
			# Buscar en toda la escena si no está como hermano directo
			var lights := get_tree().get_nodes_in_group("sun_light")
			if lights.size() > 0:
				sun_light = lights[0] as DirectionalLight3D
	
	if _wave_manager:
		_wave_manager.wave_started.connect(_on_wave_started)

func _on_wave_started(wave_number: int) -> void:
	var is_boss_wave: bool = (wave_number % 3 == 0)
	var is_high_wave: bool = (wave_number > 5)
	
	if is_boss_wave or is_high_wave:
		transition_to_dark_style()
	else:
		transition_to_bright_style()

func transition_to_dark_style() -> void:
	print("Transicionando a ambiente Terrorífico...")
	_apply_transition(dark_sky_color, dark_sun_color, dark_sun_energy)

func transition_to_bright_style() -> void:
	print("Transicionando a ambiente Amigable...")
	_apply_transition(bright_sky_color, bright_sun_color, bright_sun_energy)

func _apply_transition(target_sky: Color, target_sun: Color, target_energy: float) -> void:
	if current_tween:
		current_tween.kill()

	current_tween = create_tween().set_parallel(true)
	
	if sun_light:
		current_tween.tween_property(sun_light, "light_color", target_sun, transition_duration)
		current_tween.tween_property(sun_light, "light_energy", target_energy, transition_duration)
		
	if environment_node and environment_node.environment:
		var sky = environment_node.environment.sky
		if sky and sky.sky_material and sky.sky_material is ProceduralSkyMaterial:
			current_tween.tween_property(sky.sky_material, "sky_top_color", target_sky, transition_duration)
