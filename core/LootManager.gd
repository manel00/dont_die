extends Node

## LootManager (Autoload)
## Handles serverside loot drop spawning when enemies die.

const DROP_CHANCE = 0.5 # 50% chance per enemy

var loot_item_scene = preload("res://entities/interactables/LootItem.tscn")
var weapon_pickup_scene = preload("res://entities/interactables/StylooWeaponPickup.tscn")

func _ready() -> void:
	if multiplayer.is_server():
		# Spawn some initial weapons around the center
		for i in range(5): # Increased to 5
			var pos = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
			_spawn_weapon_pickup.call_deferred(pos)
		
		# Periodic weapon supply timer
		var timer = Timer.new()
		timer.wait_time = 25.0 # Every 25 seconds
		timer.timeout.connect(_on_supply_timer_timeout)
		add_child(timer)
		timer.start()

func _on_supply_timer_timeout() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	
	var p = players.pick_random()
	var angle = randf() * TAU
	var dist = randf_range(5, 12)
	var pos = p.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	rpc("_spawn_weapon_pickup", pos)

func try_drop_loot(position: Vector3) -> void:
	if not multiplayer.is_server(): return
	
	var r = randf()
	if r <= 0.10: # Health orb (10%)
		rpc("_spawn_loot", position)
	elif r <= 0.20: # Weapon pickup (10%)
		rpc("_spawn_weapon_pickup", position)

@rpc("authority", "call_local")
func _spawn_weapon_pickup(position: Vector3) -> void:
	if not weapon_pickup_scene: return
	var tree := get_tree()
	if not tree or not tree.current_scene: return
	var instance = weapon_pickup_scene.instantiate()
	# Random weapon type from Styloo 
	var weapon_types = [
		"bayonet", "coolknife", "doubleAxe", "katana", "kunai", "longsword",
		"normalsword", "pickaxe", "shuriken1", "shuriken2", "shuriken3", "shuriken4",
		"simpleAxe", "sword1"
	]
	instance.weapon_type = weapon_types[randi() % weapon_types.size()]
	tree.current_scene.add_child(instance)
	instance.global_position = position + Vector3(0, 1.0, 0)

@rpc("authority", "call_local")
func _spawn_loot(position: Vector3) -> void:
	if not loot_item_scene: return
	var tree := get_tree()
	if not tree or not tree.current_scene: return
	var loot = loot_item_scene.instantiate()
	tree.current_scene.add_child(loot)
	loot.global_position = position + Vector3(0, 0.5, 0)
