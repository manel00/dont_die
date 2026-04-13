# ScreenShake.gd
# Sistema de vibración de pantalla para impacto

extends Node

var _camera: Camera3D = null
var _original_position: Vector3 = Vector3.ZERO
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _is_shaking: bool = false

func _ready() -> void:
	# Encontrar la cámara del jugador
	_find_camera()

func _find_camera() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not p.is_in_group("bots"):
			var cam = p.get_node_or_null("Camera3D")
			if cam:
				_camera = cam
				_original_position = cam.position
				break

func shake(intensity: float = 0.5, duration: float = 0.3) -> void:
	if not _camera:
		_find_camera()
		if not _camera:
			return
	
	_shake_intensity = intensity
	_shake_duration = duration
	_is_shaking = true
	
	# Tween para el fade out del shake
	var tween = create_tween()
	tween.tween_property(self, "_shake_intensity", 0.0, duration)
	tween.tween_callback(func(): 
		_is_shaking = false
		if _camera:
			_camera.position = _original_position
	)

func _process(_delta: float) -> void:
	if _is_shaking and _camera:
		var shake_offset = Vector3(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_camera.position = _original_position + shake_offset
