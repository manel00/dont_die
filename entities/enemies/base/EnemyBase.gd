class_name EnemyBase
extends CharacterBody3D

@export_category("Enemy Stats")
@export var max_health: int = 100
@export var move_speed: float = 5.5  # Aumentado para enemigos más amenazantes
@export var attack_damage: int = 20
@export var attack_range: float = 2.0
@export var score_value: int = 10

var current_health: int
var target: Node3D = null
var nav_agent: NavigationAgent3D
var _health_bar_bg: Sprite3D
var _health_bar_fill: Sprite3D
var _health_bar_container: Node3D

enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var _base_scale: Vector3 = Vector3.ONE
var _anim_time: float = 0.0
var _scale_initialized: bool = false

# ═══════════════════════════════════════════════════════════════════
#  PERFORMANCE OPTIMIZATION
# ═══════════════════════════════════════════════════════════════════
const DISTANCE_CULLING_THRESHOLD: float = 50.0  # No AI updates beyond this
const ANIMATION_UPDATE_INTERVAL: float = 0.2    # Update animation every 0.2s
const SHADOW_CULLING_DISTANCE: float = 40.0   # Disable shadows beyond this
var _ai_update_timer: float = 0.0
var _is_ai_frozen: bool = false
var _player_ref: Node3D = null

func _ready() -> void:
	current_health = max_health
	_setup_health_bar()
	# Asegurar que la barra de vida se actualice al spawnear
	call_deferred("_update_health_bar")
	
	# Navegación
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	add_child(nav_agent)
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = attack_range
	nav_agent.path_max_distance = 100.0  # Aumentar distancia máxima de path
	nav_agent.navigation_layers = 1  # Asegurar que use la capa de navegación correcta
	
	# Replicación
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property(".:velocity")
	config.add_property(".:current_health")
	sync.replication_config = config
	add_child(sync)
	
	add_to_group("enemies")
	
	# Capturar escala del modelo visual
	var visual := get_node_or_null("VisualModel") as Node3D
	if visual:
		_base_scale = visual.scale
		if _base_scale.x == 0 or _base_scale.y == 0 or _base_scale.z == 0:
			_base_scale = Vector3(1.32, 1.32, 1.32)  # Escala por defecto para enemigos
			visual.scale = _base_scale
		_scale_initialized = true
	else:
		# Fallback si no hay VisualModel
		_base_scale = Vector3(1.32, 1.32, 1.32)
		_scale_initialized = true
	
	# ═══════════════════════════════════════════════════════════════════
	#  VISUAL EFFECT: Spawn Effect
	# ═══════════════════════════════════════════════════════════════════
	call_deferred("_spawn_effect")
	
	# Buscar target inmediatamente después de spawnear
	call_deferred("_find_nearest_target")

func _spawn_effect() -> void:
	var spawn_effect = load("res://entities/effects/SpawnEffect.gd")
	if spawn_effect:
		var effect = Node3D.new()
		effect.set_script(spawn_effect)
		effect.is_miniboss = (max_health > 100)  # Detectar miniboss por vida
		add_child(effect)

func _setup_health_bar() -> void:
	# Contenedor para la barra de vida - posicionado más arriba para enemigos más grandes
	_health_bar_container = Node3D.new()
	_health_bar_container.position = Vector3(0, 2.0, 0)
	add_child(_health_bar_container)
	
	# Border/Outline (negro para contraste)
	var border = Sprite3D.new()
	border.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	border.pixel_size = 0.005
	border.texture = _create_bar_texture(Color(0, 0, 0, 1.0))
	border.scale = Vector3(25, 4, 1)
	border.position = Vector3(0, 0, -0.02)
	_health_bar_container.add_child(border)
	
	# Fondo de la barra (gris oscuro)
	_health_bar_bg = Sprite3D.new()
	_health_bar_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_bg.pixel_size = 0.005
	_health_bar_bg.texture = _create_bar_texture(Color(0.15, 0.15, 0.15, 1.0))
	_health_bar_bg.scale = Vector3(24, 3, 1)
	_health_bar_container.add_child(_health_bar_bg)
	
	# Barra de vida verde
	_health_bar_fill = Sprite3D.new()
	_health_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_fill.pixel_size = 0.005
	_health_bar_fill.texture = _create_bar_texture(Color(0.1, 0.9, 0.1, 1.0))
	_health_bar_fill.scale = Vector3(24, 2.5, 1)
	_health_bar_fill.position = Vector3(0, 0, 0.01)
	_health_bar_container.add_child(_health_bar_fill)
	
	_update_health_bar()

func _create_bar_texture(color: Color) -> ImageTexture:
	var img = Image.create(64, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _update_health_bar() -> void:
	if not _health_bar_fill: return
	var pct = float(current_health) / max_health
	pct = clamp(pct, 0.0, 1.0)
	# Escalar la barra verde según el porcentaje de vida
	_health_bar_fill.scale.x = 24 * pct
	# Centrar la barra para que se achique desde la derecha
	_health_bar_fill.position.x = -0.06 * (1 - pct)
	# Cambiar color según la vida (verde -> amarillo -> rojo)
	if pct > 0.6:
		_health_bar_fill.texture = _create_bar_texture(Color(0.1, 0.9, 0.1, 1.0))  # Verde brillante
	elif pct > 0.3:
		_health_bar_fill.texture = _create_bar_texture(Color(0.9, 0.9, 0.1, 1.0))  # Amarillo
	else:
		_health_bar_fill.texture = _create_bar_texture(Color(0.9, 0.1, 0.1, 1.0))  # Rojo

func _fix_zero_scales() -> void:
	# Solo asegurar que el VisualModel tenga escala válida
	var visual = get_node_or_null("VisualModel") as Node3D
	if visual:
		# Asegurar que la escala base se capture correctamente
		_base_scale = visual.scale
		# Resetear a escala base si hay valores inválidos
		if _base_scale.x == 0 or _base_scale.y == 0 or _base_scale.z == 0:
			_base_scale = Vector3(1.32, 1.32, 1.32)
			visual.scale = _base_scale
		_scale_initialized = true

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	# ═══════════════════════════════════════════════════════════════════
	#  PERFORMANCE: Distance Culling & Batch Updates
	# ═══════════════════════════════════════════════════════════════════
	# Find nearest player for distance check (includes bots)
	if not _player_ref or not is_instance_valid(_player_ref):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player_ref = players[0]
	
	var distance_to_player: float = INF
	if _player_ref:
		distance_to_player = global_position.distance_to(_player_ref.global_position)
		
		# Distance culling: freeze AI for far enemies
		if distance_to_player > DISTANCE_CULLING_THRESHOLD:
			_is_ai_frozen = true
			# Move minimal anyway to avoid stuck feeling
			if not is_on_floor():
				velocity += get_gravity() * delta
			move_and_slide()
			return  # Skip expensive AI
		else:
			_is_ai_frozen = false
	
	# FIX: En modo offline/solo, también somos el servidor
	var is_authority = multiplayer.is_server() or not multiplayer.has_multiplayer_peer()
	if is_authority:
		if not is_on_floor(): velocity += get_gravity() * delta
		
		# Batch AI updates: only update every few frames for far enemies
		_ai_update_timer += delta
		var update_interval = 0.1 if distance_to_player < 15.0 else 0.3  # Closer = more responsive
		if _ai_update_timer >= update_interval:
			_ai_update_timer = 0.0
			_handle_state_machine(delta)
		
		move_and_slide()
	
	# Animation updates less frequently for performance
	_anim_time += delta
	if _anim_time >= ANIMATION_UPDATE_INTERVAL:
		_animate_visuals(delta)
		_anim_time = 0.0
	
	# FIX: Asegurar que la escala del modelo visual nunca cambie
	var visual = get_node_or_null("VisualModel") as Node3D
	if visual and _scale_initialized:
		visual.scale = _base_scale

func _handle_state_machine(delta: float) -> void:
	if target != null and not is_instance_valid(target): target = null
	
	# Siempre buscar el jugador más cercano si no tenemos target
	if target == null:
		_find_nearest_target()
	
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta)
			velocity.z = move_toward(velocity.z, 0, move_speed * delta)
			# Buscar target si estamos idle
			if target == null:
				_find_nearest_target()
			if target != null:
				current_state = State.CHASE
			
		State.CHASE:
			if target == null:
				current_state = State.IDLE
				return
				
			var dist = global_position.distance_to(target.global_position)
			if dist <= attack_range:
				current_state = State.ATTACK
				return
			
			# Persecución directa simple (más confiable que navegación)
			var to_target = target.global_position - global_position
			var move_direction = Vector3(to_target.x, 0, to_target.z).normalized()
			
			velocity.x = move_direction.x * move_speed
			velocity.z = move_direction.z * move_speed
			
			# Rotar hacia el target
			if move_direction.length() > 0.01:
				var target_rotation = atan2(move_direction.x, move_direction.z)
				rotation.y = lerp_angle(rotation.y, target_rotation, 12.0 * delta)
				
		State.ATTACK:
			if target == null or not is_instance_valid(target):
				current_state = State.IDLE
				return
				
			var dist = global_position.distance_to(target.global_position)
			if dist > attack_range + 0.5:
				current_state = State.CHASE
			else:
				# Mirar al target mientras ataca
				var look_dir = (target.global_position - global_position).normalized()
				rotation.y = atan2(look_dir.x, look_dir.z)
				velocity = Vector3.ZERO
				_perform_attack()

func _find_nearest_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		target = null
		return
	
	var nearest_dist := INF
	var nearest_player: Node3D = null
	
	for p in players:
		if not is_instance_valid(p):
			continue
		var d = global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_player = p
	
	if nearest_player != null:
		target = nearest_player
		current_state = State.CHASE

func _perform_attack() -> void:
	pass

@rpc("any_peer", "call_local")
func rpc_take_damage(amount: int) -> void:
	if not multiplayer.is_server(): return
	if current_state == State.DEAD: return
	current_health -= amount
	_update_health_bar()
	_hit_flash()
	_hit_effect()
	
	# ═══════════════════════════════════════════════════════════════════
	#  VISUAL FEEDBACK: Show floating damage number
	# ═══════════════════════════════════════════════════════════════════
	_show_damage_number(amount)
	
	if current_health <= 0: die()

func _hit_flash() -> void:
	var visual = get_node_or_null("VisualModel")
	if visual:
		# Buscar meshes dentro del VisualModel (GeometryInstance3D tienen modulate)
		var meshes: Array[GeometryInstance3D] = []
		for child in visual.get_children():
			if child is GeometryInstance3D:
				meshes.append(child)
				# Buscar recursivamente
				for grandchild in child.get_children():
					if grandchild is GeometryInstance3D:
						meshes.append(grandchild)
		
		for mesh in meshes:
			var tw = create_tween()
			tw.tween_property(mesh, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.05)
			tw.tween_property(mesh, "modulate", Color.WHITE, 0.15)

func _hit_effect() -> void:
	# Partículas de impacto
	var hit_effect = load("res://entities/effects/HitEffect.gd")
	if hit_effect:
		var effect = Node3D.new()
		effect.set_script(hit_effect)
		add_child(effect)
		effect.position = Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3))

func _show_damage_number(amount: int) -> void:
	# Crear label flotante de daño
	var label = Label3D.new()
	label.text = "-" + str(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.modulate = Color(1.0, 0.8, 0.2, 1.0)  # Amarillo-naranja
	label.outline_modulate = Color.BLACK
	label.position = Vector3(randf_range(-0.5, 0.5), 2.5, randf_range(-0.5, 0.5))
	add_child(label)
	
	# Animar subida y fade
	var tw = create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.5, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	tw.chain().tween_callback(label.queue_free)

func take_damage(amount: int) -> void:
	if multiplayer.is_server(): rpc_take_damage(amount)
	else: rpc_id(1, "rpc_take_damage", amount)

func die() -> void:
	current_state = State.DEAD
	
	# ═══════════════════════════════════════════════════════════════════
	#  VISUAL EFFECT: Death Effect
	# ═══════════════════════════════════════════════════════════════════
	_death_effect()
	
	# Screen shake for miniboss deaths
	if max_health > 100:
		var ss = get_node_or_null("/root/ScreenShake")
		if ss: ss.shake(0.8, 0.5)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm: gm.add_score(score_value)
	
	# Try dropping loot via LootManager
	var lm = get_node_or_null("/root/LootManager")
	if lm: lm.try_drop_loot(global_position)
	
	# Death animation más rápida y con fade
	visible = false  # Hide main mesh, show particles instead
	
	# Delay destroy to let particles play
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _death_effect() -> void:
	var death_effect = load("res://entities/effects/DeathEffect.gd")
	if death_effect:
		var effect = Node3D.new()
		effect.set_script(death_effect)
		# Detectar tipo por nombre o vida
		if max_health > 150:
			effect.enemy_type = "mage"
		elif max_health > 100:
			effect.enemy_type = "rogue"
		else:
			effect.enemy_type = "minion"
		# Safety: get_tree() or current_scene might be null during scene changes
		var tree := get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(effect)
			effect.global_position = global_position
		else:
			# Fallback: add to this enemy's parent temporarily
			if get_parent():
				get_parent().add_child(effect)
				effect.global_position = global_position

func _animate_visuals(delta: float) -> void:
	# Escala fija - no permitir cambios dinámicos de tamaño
	var visual = get_node_or_null("VisualModel")
	if visual and _scale_initialized:
		# Mantener siempre la escala base sin animaciones
		visual.scale = _base_scale
