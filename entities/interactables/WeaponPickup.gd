extends Area3D

## WeaponPickup Proxy
## Converts any old/statically placed WeaponPickups into the new StylooWeaponPickup.

@export var weapon_type: String = "katana"  # sword, shotgun, rifle se convertirÃ¡n

func _ready() -> void:
	if not multiplayer.is_server(): return
	
	call_deferred("_replace_with_styloo")

func _replace_with_styloo() -> void:
	var styloo_scene = load("res://entities/interactables/StylooWeaponPickup.tscn")
	if styloo_scene:
		var styloo = styloo_scene.instantiate()
		
		# Map old weapon types to new ones if necessary
		if weapon_type == "sword" or weapon_type == "normalsword":
			styloo.weapon_type = "katana"
		elif weapon_type == "shotgun":
			styloo.weapon_type = "doubleAxe"
		elif weapon_type == "rifle":
			styloo.weapon_type = "shuriken1"
		else:
			styloo.weapon_type = "katana"
			
		get_parent().add_child(styloo)
		styloo.global_position = global_position
		
	queue_free()
