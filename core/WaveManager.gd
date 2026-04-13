extends Node

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal wave_enemy_spawned(wave_number: int, current_count: int, total_count: int)

# ═══════════════════════════════════════════════════════════════════
#  SCENES - Solo usamos Minion (normal) y Mage/Rogue (mini-bosses)
# ═══════════════════════════════════════════════════════════════════
var minion_scene: PackedScene = preload("res://entities/enemies/minion/Minion.tscn")
var mage_scene: PackedScene = preload("res://entities/enemies/mage/Mage.tscn")
var rogue_scene: PackedScene = preload("res://entities/enemies/rogue/Rogue.tscn")

# ═══════════════════════════════════════════════════════════════════
#  WAVE CONFIGURATION - BALANCED: 1 miniboss cada 8 minions
# ═══════════════════════════════════════════════════════════════════
const WAVE_CONFIG = {
	1: {"total": 50, "minions": 44, "minibosses": 6},   # 44 + 6 = 50 (ratio 1:7.3)
	2: {"total": 100, "minions": 89, "minibosses": 11}, # 89 + 11 = 100 (ratio 1:8.1)
	3: {"total": 150, "minions": 133, "minibosses": 17} # 133 + 17 = 150 (ratio 1:7.8)
}
# Ratio: ~1 mini-boss por cada 8 minions (menos caótico, minibosses más especiales)

# ═══════════════════════════════════════════════════════════════════
#  STATE
# ═══════════════════════════════════════════════════════════════════
var current_wave: int = 1
var is_spawning: bool = false
var spawn_points: Array[Node] = []
var active_enemies: int = 0
var _wave_in_progress: bool = false
var _enemies_spawned_this_wave: int = 0
var _wave_start_time: float = 0.0

# Spawn tracking
var _minions_to_spawn: int = 0
var _minibosses_to_spawn: int = 0
var _total_wave_enemies: int = 0

var spawn_timer: Timer
var _spawn_batch_timer: Timer

# ═══════════════════════════════════════════════════════════════════
#  INITIALIZATION
# ═══════════════════════════════════════════════════════════════════
func _ready() -> void:
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║           WAVE MANAGER - SKELETON HORDE SYSTEM               ║")
	print("╠══════════════════════════════════════════════════════════════╣")
	print("║  Wave 1: 25 enemies  (21 Minions + 4 Mini-bosses)             ║")
	print("║  Wave 2: 50 enemies (42 Minions + 8 Mini-bosses)             ║")
	print("║  Wave 3: 75 enemies (63 Minions + 12 Mini-bosses)            ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	
	# Main spawn timer - OPTIMIZED: slower spawn to prevent lag
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.5  # Spawn 2 enemies per second max
	spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(spawn_timer)
	
	# Batch spawn timer for initial wave burst
	_spawn_batch_timer = Timer.new()
	_spawn_batch_timer.wait_time = 0.2  # Slower batch spawn
	_spawn_batch_timer.timeout.connect(_on_batch_spawn)
	add_child(_spawn_batch_timer)
	
	# Start first wave after short delay
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(_start_wave_1)

# ═══════════════════════════════════════════════════════════════════
#  WAVE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════
func _start_wave_1() -> void:
	_start_wave(1)

func _start_wave(wave_number: int) -> void:
	if wave_number > 3:
		print("WaveManager: ALL WAVES COMPLETED!")
		return
	
	current_wave = wave_number
	_wave_in_progress = true
	_enemies_spawned_this_wave = 0
	_wave_start_time = Time.get_time_dict_from_system()["second"]
	
	var config = WAVE_CONFIG[wave_number]
	_minions_to_spawn = config["minions"]
	_minibosses_to_spawn = config["minibosses"]
	_total_wave_enemies = config["total"]
	
	spawn_points = get_tree().get_nodes_in_group("spawners")
	if spawn_points.is_empty():
		print("WaveManager: ERROR - No spawners found! Creating fallback...")
		_create_fallback_spawners()
	
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║  WAVE ", wave_number, " STARTED!                              ")
	print("║  Minions to spawn: ", _minions_to_spawn, "                      ")
	print("║  Mini-bosses to spawn: ", _minibosses_to_spawn, "                ")
	print("╚══════════════════════════════════════════════════════════════╝")
	
	is_spawning = true
	_wave_in_progress = true
	
	# Spawn initial batch immediately
	_spawn_batch(10)
	
	# Start continuous spawning
	spawn_timer.start()
	
	wave_started.emit(current_wave)
	_play_wave_sfx()

func _create_fallback_spawners() -> void:
	# Create spawn points around the arena if none exist
	var arena = get_tree().current_scene
	if not arena:
		return
		
	var spawn_positions = [
		Vector3(-30, 0, -30), Vector3(30, 0, -30),
		Vector3(-30, 0, 30), Vector3(30, 0, 30),
		Vector3(0, 0, -35), Vector3(0, 0, 35),
		Vector3(-35, 0, 0), Vector3(35, 0, 0)
	]
	
	for pos in spawn_positions:
		var marker = Marker3D.new()
		marker.position = pos  # Use position, not global_position (not in tree yet)
		marker.add_to_group("spawners")
		arena.add_child(marker)
		spawn_points.append(marker)

# ═══════════════════════════════════════════════════════════════════
#  SPAWNING LOGIC
# ═══════════════════════════════════════════════════════════════════
func _on_spawn_tick() -> void:
	if not _can_spawn():
		return
	
	# Spawn 1 enemy per tick for smooth flow
	_spawn_single_enemy()
	
	# Check wave completion
	if _enemies_spawned_this_wave >= _total_wave_enemies and active_enemies == 0:
		_complete_wave()

func _on_batch_spawn() -> void:
	if not _can_spawn():
		return
	_spawn_single_enemy()

func _spawn_batch(count: int) -> void:
	for i in range(count):
		if _can_spawn():
			_spawn_single_enemy()

func _can_spawn() -> bool:
	var is_authority = multiplayer.is_server() or not multiplayer.has_multiplayer_peer()
	if not is_authority:
		return false
	if not is_spawning:
		return false
	if _enemies_spawned_this_wave >= _total_wave_enemies:
		return false
	return true

func _spawn_single_enemy() -> void:
	# Determine what to spawn based on remaining counts
	var scene_to_spawn: PackedScene = null
	var is_miniboss = false
	
	# Ratio-based spawning: for every 5 minions, spawn 1 miniboss
	var total_remaining = _minions_to_spawn + _minibosses_to_spawn
	if total_remaining <= 0:
		return
	
	# Calculate current ratio in spawned enemies
	var spawned_minions = WAVE_CONFIG[current_wave]["minions"] - _minions_to_spawn
	var spawned_minibosses = WAVE_CONFIG[current_wave]["minibosses"] - _minibosses_to_spawn
	var total_spawned = spawned_minions + spawned_minibosses
	
	var target_miniboss_ratio = float(WAVE_CONFIG[current_wave]["minibosses"]) / float(WAVE_CONFIG[current_wave]["total"])
	var current_miniboss_ratio = float(spawned_minibosses) / float(total_spawned + 1) if total_spawned > 0 else 0.0
	
	# Decision: spawn miniboss if we're behind on miniboss ratio
	if _minibosses_to_spawn > 0 and (current_miniboss_ratio < target_miniboss_ratio or _minions_to_spawn <= 0):
		# Spawn mini-boss (Mage or Rogue randomly)
		scene_to_spawn = mage_scene if randf() < 0.5 else rogue_scene
		_minibosses_to_spawn -= 1
		is_miniboss = true
	elif _minions_to_spawn > 0:
		# Spawn normal minion
		scene_to_spawn = minion_scene
		_minions_to_spawn -= 1
	else:
		return  # Nothing to spawn
	
	# Spawn near player for engagement
	_spawn_enemy_near_player(scene_to_spawn, is_miniboss)
	
	_enemies_spawned_this_wave += 1
	
	# Emit progress signal every 10 enemies
	if _enemies_spawned_this_wave % 10 == 0:
		wave_enemy_spawned.emit(current_wave, _enemies_spawned_this_wave, _total_wave_enemies)
		print("Wave ", current_wave, " Progress: ", _enemies_spawned_this_wave, "/", _total_wave_enemies, " (Active: ", active_enemies, ")")

func _spawn_enemy_near_player(scene: PackedScene, is_miniboss: bool = false) -> void:
	var players = get_tree().get_nodes_in_group("player")
	var human_players = []
	for p in players:
		if not p.is_in_group("bots"):
			human_players.append(p)
	
	var spawn_pos: Vector3
	
	if human_players.size() > 0:
		var target_player = human_players[randi() % human_players.size()]
		var angle = randf() * TAU
		# Minibosses spawn slightly farther away
		var min_dist = 8.0 if is_miniboss else 4.0
		var max_dist = 20.0 if is_miniboss else 12.0
		var dist = lerp(min_dist, max_dist, randf())
		spawn_pos = target_player.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	else:
		# Fallback spawn positions
		spawn_pos = Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
	
	_spawn_at_pos(scene, spawn_pos)

func _spawn_at_pos(scene: PackedScene, pos: Vector3) -> void:
	if not scene:
		return
	
	var enemy = scene.instantiate()
	var enemies_node = get_tree().current_scene.get_node_or_null("Enemies")
	
	if enemies_node:
		enemies_node.add_child(enemy, true)
		enemy.global_position = pos + Vector3(0, 1.0, 0)
		enemy.tree_exited.connect(_on_enemy_killed)
		active_enemies += 1
	else:
		# Create enemies node if missing
		enemies_node = Node3D.new()
		enemies_node.name = "Enemies"
		get_tree().current_scene.add_child(enemies_node)
		enemies_node.add_child(enemy, true)
		enemy.global_position = pos + Vector3(0, 1.0, 0)
		enemy.tree_exited.connect(_on_enemy_killed)
		active_enemies += 1

# ═══════════════════════════════════════════════════════════════════
#  WAVE COMPLETION & PROGRESSION
# ═══════════════════════════════════════════════════════════════════
func _on_enemy_killed() -> void:
	active_enemies = max(0, active_enemies - 1)
	
	# Check if wave is complete (all spawned and all dead)
	if _wave_in_progress and _enemies_spawned_this_wave >= _total_wave_enemies and active_enemies == 0:
		_complete_wave()

func _complete_wave() -> void:
	_wave_in_progress = false
	is_spawning = false
	spawn_timer.stop()
	
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║  WAVE ", current_wave, " CLEARED!                               ")
	print("╚══════════════════════════════════════════════════════════════╝")
	
	wave_cleared.emit(current_wave)
	
	# Start next wave after delay
	var next_wave = current_wave + 1
	if next_wave <= 3:
		print("WaveManager: Starting Wave ", next_wave, " in 5 seconds...")
		var t := get_tree().create_timer(5.0)
		t.timeout.connect(func(): _start_wave(next_wave))
	else:
		print("WaveManager: 🎉 ALL WAVES COMPLETED! VICTORY! 🎉")

# ═══════════════════════════════════════════════════════════════════
#  UTILITY
# ═══════════════════════════════════════════════════════════════════
func _play_wave_sfx() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_level_up"):
		am.play_level_up()

func get_wave_progress() -> Dictionary:
	return {
		"wave": current_wave,
		"spawned": _enemies_spawned_this_wave,
		"total": _total_wave_enemies if _wave_in_progress else 0,
		"active": active_enemies,
		"in_progress": _wave_in_progress
	}
