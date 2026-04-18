class_name Projectile
extends Area3D

@export var speed: float = 25.0
@export var damage: int = 15
@export var life_time: float = 2.0
@export var hit_group: String = "enemies"

var direction: Vector3 = Vector3.FORWARD
var _has_dealt_damage: bool = false  # Flag para evitar daÃ±o mÃºltiple

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer = get_tree().create_timer(life_time)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# DEBUG: Log todas las colisiones
	# print("DEBUG Projectile collision: proj=", get_instance_id(), " body=", body.name, 
	#	" groups=", body.get_groups(), " has_take_damage=", body.has_method("take_damage"),
	#	" _has_dealt_damage=", _has_dealt_damage)
	
	# Evitar daÃ±o mÃºltiple del mismo proyectil
	if _has_dealt_damage:
		# print("DEBUG Projectile: already dealt damage, ignoring")
		return
	
	# Ignore if body has no group system (static environment like floor/walls)
	# Only damage valid targets in the correct faction group
	if body.is_in_group(hit_group) and body.has_method("take_damage"):
		# print("DEBUG Projectile: DEALING DAMAGE to ", body.name, " damage=", damage)
		_has_dealt_damage = true
		body.take_damage(damage)
		queue_free()
	elif body.is_in_group("enemies") or body.is_in_group("player"):
		# Hit a valid character but wrong faction (e.g. enemy bullet hitting enemy)
		# Just destroy the projectile without dealing damage
		# print("DEBUG Projectile: wrong faction, destroying")
		queue_free()
	# If it hits environment (StaticBody, CSG), ignore it â€” let lifetime handle it
