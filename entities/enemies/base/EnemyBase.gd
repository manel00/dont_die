class_name EnemyBase
extends CharacterBody3D

@export_category("Enemy Stats")
@export var max_health: int = 450  # +50% mÃ¡s vida
@export var move_speed: float = 7.5  # +20% (6.24 * 1.2)
@export var attack_damage: int = 30  # +50% mÃ¡s daÃ±o
@export var attack_range: float = 2.5  # Mayor rango de ataque
@export var score_value: int = 15  # +50% mÃ¡s puntos
@export var attack_cooldown: float = 0.8  # Cooldown entre ataques

# IA mejorada
@export_category("AI Behavior")
@export var reaction_time: float = 0.3  # Tiempo de reacciÃ³n
@export var strafe_enabled: bool = true  # Movimiento lateral inteligente
@export var flank_chance: float = 0.3  # 30% probabilidad de flanquear
@export var max_distance_from_player: float = 60.0  # Aumentado para soportar rangos triples

var current_health: int
var target: Node3D = null
var nav_agent: NavigationAgent3D
var damage_multiplier: float = 1.0
var _health_bar_fill: Sprite3D
var _health_bar_bg: Sprite3D  # Fondo negro para mejor contraste

enum State { IDLE, CHASE, ATTACK, DEAD, STRAFE }
var current_state: State = State.IDLE
var _is_mecha_active: bool = false

@onready var _visual_model: Node3D = get_node_or_null("VisualModel")
var _base_scale: Vector3 = Vector3.ONE
var _anim_time: float = 0.0
var _scale_initialized: bool = false

# IA avanzada
var _reaction_timer: float = 0.0
var _strafe_direction: int = 1
var _attack_cooldown: float = 0.0
var _is_flanking: bool = false

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  MECHA TEXTURES SYSTEM
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
const MECHA_TEXTURES: Array[String] = [
	"res://assets/models/characters/Enemies_mecha/Arachnoid.png",
	"res://assets/models/characters/Enemies_mecha/Companion-bot.png",
	"res://assets/models/characters/Enemies_mecha/FieldFighter.png",
	"res://assets/models/characters/Enemies_mecha/Mecha01.png",
	"res://assets/models/characters/Enemies_mecha/MechaGolem.png",
	"res://assets/models/characters/Enemies_mecha/MechaTrooper.png",
	"res://assets/models/characters/Enemies_mecha/MobileStorageBot.png",
	"res://assets/models/characters/Enemies_mecha/QuadrupedTank.png",
	"res://assets/models/characters/Enemies_mecha/ReconBot.png"
]

# â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
#  PERFORMANCE OPTIMIZATION
# â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
const MECHA_MODELS: Array[String] = [
	"res://assets/models/characters/Enemies_mecha/Arachnoid.obj",
	"res://assets/models/characters/Enemies_mecha/Companion-bot.obj",
	"res://assets/models/characters/Enemies_mecha/FieldFighter.obj",
	"res://assets/models/characters/Enemies_mecha/Mecha01.obj",
	"res://assets/models/characters/Enemies_mecha/MechaGolem.obj",
	"res://assets/models/characters/Enemies_mecha/MechaTrooper.obj",
	"res://assets/models/characters/Enemies_mecha/MobileStorageBot.obj",
	"res://assets/models/characters/Enemies_mecha/QuadrupedTank.obj",
	"res://assets/models/characters/Enemies_mecha/ReconBot.obj"
]

const DISTANCE_CULLING_THRESHOLD: float = 100.0  # Aumentado para permitir combate a larga distancia
const ANIMATION_UPDATE_INTERVAL: float = 0.2    # Update animation every 0.2s
const SHADOW_CULLING_DISTANCE: float = 80.0   # Aumentado para mechas grandes
var _ai_update_timer: float = 0.0
var _is_ai_frozen: bool = false
var _player_ref: Node3D = null

# Cache de jugadores para evitar get_nodes_in_group repetido
static var _player_cache: Array[Node] = []
static var _player_cache_timer: float = 0.0
static var _player_cache_interval: float = 0.5

# â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
#  MATERIAL CACHE - Reutilizar materiales para evitar lag
# â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
static var _mecha_materials: Array[StandardMaterial3D] = []
static var _mecha_textures: Array[Texture2D] = []
static var _mecha_model_assets: Array = []
static var _materials_loaded: bool = false

func _ready() -> void:
	current_health = max_health
	_setup_health_bar()
	# Asegurar que la barra de vida se actualice al spawnear
	call_deferred("_update_health_bar")
	
	# NavegaciÃ³n
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	add_child(nav_agent)
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = attack_range
	nav_agent.path_max_distance = 100.0  # Aumentar distancia mÃ¡xima de path
	nav_agent.navigation_layers = 1  # Asegurar que use la capa de navegaciÃ³n correcta
	
	# ReplicaciÃ³n - solo posiciÃ³n y rotaciÃ³n para evitar desincronizaciÃ³n de salud
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property(".:velocity")
	# NOTA: current_health y current_state NO se replican para evitar bugs de desincronizaciÃ³n
	# El servidor controla el daÃ±o y la muerte, los clientes reciben actualizaciones visuales
	sync.replication_config = config
	add_child(sync)
	
	add_to_group("enemies")
	
	# DEBUG: Verificar inicializaciÃ³n correcta
	# print("DEBUG Enemy _ready: name=", name, " health=", current_health, "/", max_health, 
	# 	" in_group_enemies=", is_in_group("enemies"), " has_take_damage=", has_method("take_damage"))
	
	# Capturar escala del modelo visual
	var visual := _visual_model
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
	
	# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
	#  VISUAL EFFECT: Spawn Effect
	# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
	call_deferred("_spawn_effect")
	
	# Initialize player cache before finding target (BUG FIX: cache was empty on first use)
	if _player_cache.is_empty():
		var all_players := get_tree().get_nodes_in_group("player")
		_player_cache = all_players.filter(func(p): return is_instance_valid(p))
	
	# Buscar target inmediatamente despuÃ©s de spawnear
	call_deferred("_find_nearest_target")

func _spawn_effect() -> void:
	var spawn_effect = load("res://entities/effects/SpawnEffect.gd")
	if spawn_effect:
		var effect = Node3D.new()
		effect.set_script(spawn_effect)
		effect.is_miniboss = (max_health > 100)
		add_child(effect)

func _setup_health_bar() -> void:
	# Determinar si es miniboss/boss para escalar la barra
	var is_miniboss := max_health > 100
	var bar_width := 6.0 if is_miniboss else 5.0  # Mitad de larga
	var bar_height := 9.0 if is_miniboss else 7.5  # 5x mÃ¡s gruesa
	var y_offset := 4.2 if is_miniboss else 3.5
	var pixel_size := 0.004 if is_miniboss else 0.0035
	
	# Barra de fondo eliminada por petición del usuario para más limpieza visual
	
	# Barra de vida actual - creamos textura BLANCA para que el modulate funcione
	_health_bar_fill = Sprite3D.new()
	_health_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_fill.pixel_size = pixel_size
	_health_bar_fill.texture = _create_bar_texture(Color.WHITE)
	_health_bar_fill.scale = Vector3(bar_width, bar_height, 1)
	_health_bar_fill.position = Vector3(0, y_offset, 0.01)
	_health_bar_fill.render_priority = 1
	add_child(_health_bar_fill)
	_update_health_bar()

func _create_bar_texture(color: Color) -> ImageTexture:
	var img = Image.create(64, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _update_health_bar() -> void:
	if not _health_bar_fill: return
	
	var is_miniboss := max_health > 100
	var bar_width := 6.0 if is_miniboss else 5.0  # Escala base
	var bar_height := 9.0 if is_miniboss else 7.5
	
	# Si es un mecha, aplicamos el multiplicador de tamaño
	if _is_mecha_active:
		bar_width *= 2.0
		bar_height *= 2.0
	
	var pct = clamp(float(current_health) / max_health, 0.001, 1.0)
	
	# Escalar ancho según vida (la barra de color se reduce)
	# BUG FIX: Nunca usar escala 0 para evitar errores de determinante 0 en el renderizador
	_health_bar_fill.scale.x = bar_width * pct
	_health_bar_fill.scale.y = bar_height
	
	# Alinear a la izquierda (empezar desde el borde izquierdo del fondo)
	var tex_width: float = 64.0
	var total_w = tex_width * _health_bar_fill.pixel_size * bar_width
	var current_w = tex_width * _health_bar_fill.pixel_size * (bar_width * pct)
	var shift = (total_w - current_w) / 2.0
	_health_bar_fill.position.x = -shift
	
	# Colores según vida (unificado a VERDE por petición del usuario)
	var target_color: Color
	if pct > 0.5:
		target_color = Color(0.3, 1.0, 0.3)  # Verde brillante (igual que el jugador)
	elif pct > 0.25:
		target_color = Color(1.0, 1.0, 0.3)  # Amarillo
	else:
		target_color = Color(1.0, 0.3, 0.3)  # Rojo
		
	_health_bar_fill.modulate = target_color
	
	# Ocultar barra si estÃ¡ muerto (vida <= 0)
	_health_bar_fill.visible = current_health > 0
	
	# Forzar ocultaciÃ³n si la vida es <= 0
	if current_health <= 0:
		_health_bar_fill.visible = false

func _fix_zero_scales() -> void:
	# Solo asegurar que el VisualModel tenga escala vÃ¡lida
	var visual := _visual_model
	if visual:
		# Asegurar que la escala base se capture correctamente
		_base_scale = visual.scale
		# Resetear a escala base si hay valores invÃ¡lidos
		if _base_scale.x == 0 or _base_scale.y == 0 or _base_scale.z == 0:
			_base_scale = Vector3(1.32, 1.32, 1.32)
			visual.scale = _base_scale
		_scale_initialized = true

## Fix para que las barras de vida se vean por encima de los modelos mecha
func _fix_health_bar_for_mecha() -> void:
	if not _health_bar_fill:
		return
	
	# Elevación estratégica: los mechas son muy altos y anchos
	# Aumentamos a 10.5 para asegurar que esté por encima de la cabeza
	var mecha_y_offset := 10.5
	_health_bar_fill.position.y = mecha_y_offset
	
	# "SIEMPRE VISIBLE": Activamos no_depth_test y prioridad alta
	# Esto cumple con la petición de que esté "siempre visible" y "encima de la textura"
	_health_bar_fill.no_depth_test = true
	_health_bar_fill.render_priority = 10
	_health_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Hacer la barra de los mechas el doble de grande que la de los minions para que destaque
	var mecha_bar_scale_mult := 2.0
	_health_bar_fill.scale = Vector3(
		(6.0 if max_health > 100 else 5.0) * mecha_bar_scale_mult,
		(9.0 if max_health > 100 else 7.5) * mecha_bar_scale_mult,
		1.0
	)
	_is_mecha_active = true
	
	# Forzar actualización inicial
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		visible = false
		return

	# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
	#  PERFORMANCE: Distance Culling & Batch Updates
	# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
	# Actualizar cache de jugadores periÃ³dicamente
	_player_cache_timer += delta
	if _player_cache_timer >= _player_cache_interval:
		_player_cache_timer = 0.0
		var all_players := get_tree().get_nodes_in_group("player")
		_player_cache = all_players.filter(func(p): return is_instance_valid(p))
	
	# Usar cache de jugadores para encontrar referencia
	if not _player_ref or not is_instance_valid(_player_ref):
		var valid_players := _player_cache.filter(func(p): return is_instance_valid(p))
		if valid_players.size() > 0:
			_player_ref = valid_players[0]
	
	var distance_to_player: float = INF
	if _player_ref and is_instance_valid(_player_ref):
		distance_to_player = global_position.distance_to(_player_ref.global_position)
		
		# Distance culling: freeze AI for far enemies
		if distance_to_player > DISTANCE_CULLING_THRESHOLD:
			_is_ai_frozen = true
			if not is_on_floor():
				velocity += get_gravity() * delta
			move_and_slide()
			return
		else:
			_is_ai_frozen = false
	
	# En modo offline/solo, tambiÃ©n somos el servidor
	var is_authority = multiplayer.is_server() or not multiplayer.has_multiplayer_peer()
	if is_authority:
		if not is_on_floor(): velocity += get_gravity() * delta
		
		# Actualizar cooldown de ataque cada frame (independiente de la cadencia de IA)
		if _attack_cooldown > 0:
			_attack_cooldown -= delta
			
		# ATAQUE FRAME-PERFECT: Disparar inmediatamente cuando el cooldown llegue a 0 si está en estado ATTACK
		if current_state == State.ATTACK and _attack_cooldown <= 0:
			if target and is_instance_valid(target):
				# Mirar al target antes de atacar (para que los proyectiles salgan rectos)
				var look_dir = (target.global_position - global_position).normalized()
				rotation.y = atan2(look_dir.x, look_dir.z)
				velocity = Vector3.ZERO
				_perform_attack()
				_attack_cooldown = attack_cooldown
			
		# Batch AI updates: only update every few frames for far enemies
		_ai_update_timer += delta
		var update_interval = 0.1 if distance_to_player < 15.0 else 0.3
		if _ai_update_timer >= update_interval:
			_handle_state_machine(_ai_update_timer)
			_ai_update_timer = 0.0
		
		move_and_slide()
	
	# Animation updates less frequently for performance
	_anim_time += delta
	if _anim_time >= ANIMATION_UPDATE_INTERVAL:
		_animate_visuals(delta)
		_anim_time = 0.0
	
	# Mantener escala y posición del modelo visual (evitar drift por animaciones ocultas)
	if _visual_model and _scale_initialized:
		_visual_model.scale = _base_scale
		_visual_model.position = Vector3.ZERO

func _handle_state_machine(delta: float) -> void:
	# VerificaciÃ³n de seguridad: si ya estÃ¡ muerto, no procesar
	if current_state == State.DEAD or current_health <= 0:
		return
	
	if target != null and not is_instance_valid(target): target = null
	
	# Siempre buscar el jugador mÃ¡s cercano si no tenemos target
	if target == null:
		_find_nearest_target()
	
	# Actualizar cooldown de ataque (ahora se hace en _physics_process)
	
	# IA mejorada: evaluar estado cada reaction_time
	_reaction_timer += delta
	if _reaction_timer >= reaction_time:
		_reaction_timer = 0.0
		_evaluate_state()
	
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta)
			velocity.z = move_toward(velocity.z, 0, move_speed * delta)
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
			
			# IA avanzada: flanquear o perseguir
			var to_target = target.global_position - global_position
			var move_direction = Vector3(to_target.x, 0, to_target.z).normalized()
			
			# Probabilidad de flanquear
			if _is_flanking:
				var flank_offset = move_direction.cross(Vector3.UP) * _strafe_direction * 3.0
				move_direction = (move_direction + flank_offset * 0.5).normalized()
			
			velocity.x = move_direction.x * move_speed
			velocity.z = move_direction.z * move_speed
			
			if move_direction.length() > 0.01:
				var target_rotation = atan2(move_direction.x, move_direction.z)
				rotation.y = lerp_angle(rotation.y, target_rotation, 12.0 * delta)
				
		State.STRAFE:
			if target == null:
				current_state = State.IDLE
				return
			
			# Movimiento lateral para evitar ataques
			var to_target = target.global_position - global_position
			var move_direction = Vector3(to_target.x, 0, to_target.z).normalized()
			var strafe_dir = move_direction.cross(Vector3.UP) * _strafe_direction
			
			# Mantener distancia mientras se mueve lateralmente
			var dist = global_position.distance_to(target.global_position)
			if dist < attack_range * 1.5:
				# Acercarse un poco mientras strafea
				velocity = (move_direction * 0.3 + strafe_dir * 0.7) * move_speed * 0.8
			else:
				velocity = strafe_dir * move_speed * 0.6
			
			if move_direction.length() > 0.01:
				var target_rotation = atan2(move_direction.x, move_direction.z)
				rotation.y = lerp_angle(rotation.y, target_rotation, 12.0 * delta)
			
			# Volver a chase despuÃs de strafear un poco
			if randf() < 0.02:  # 2% chance por frame de salir de strafe
				current_state = State.CHASE

		State.ATTACK:
			if target == null or not is_instance_valid(target):
				current_state = State.IDLE
				return
				
			var dist = global_position.distance_to(target.global_position)
			if dist > attack_range + 0.5:
				current_state = State.CHASE
			else:
				# El ataque ahora se gestiona en _physics_process para precisión frame-perfect
				velocity = Vector3.ZERO

func _evaluate_state() -> void:
	# Evaluar si cambiar de estado basado en situación
	if current_state == State.DEAD or target == null:
		return
	
	var health_pct = float(current_health) / max_health
	var dist = global_position.distance_to(target.global_position)
	
	# PRIORIDAD: Si está a más de max_distance, siempre chase aunque esté en otro estado
	if dist > max_distance_from_player and current_state != State.CHASE and current_state != State.ATTACK:
		current_state = State.CHASE
		_is_flanking = false
		return
	
	# Daño aumentado al 20% de vida (sin huir)
	if health_pct < 0.2:
		damage_multiplier = 1.2
	else:
		damage_multiplier = 1.0
	
	# Strafe si está muy cerca y no puede atacar (solo si no está muy lejos)
	if dist < attack_range * 0.8 and current_state == State.CHASE and strafe_enabled and dist <= max_distance_from_player:
		_strafe_direction = 1 if randf() > 0.5 else -1
		current_state = State.STRAFE
		return
	
	# Decidir si flanquear
	if current_state == State.CHASE and randf() < flank_chance:
		_is_flanking = !_is_flanking
		_strafe_direction = 1 if randf() > 0.5 else -1

func _find_nearest_target() -> void:
	# Usar cache de jugadores en lugar de llamar get_nodes_in_group
	if _player_cache.size() == 0:
		target = null
		return
	
	var nearest_dist := INF
	var nearest_player: Node3D = null
	
	for p in _player_cache:
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

@rpc("authority", "call_local")
func rpc_sync_health(new_hp: int, damage_taken: int) -> void:
	if current_state == State.DEAD:
		return

	# Aseguramos de que nunca sobrepase los lÃ­mites de forma imprevista
	current_health = clamp(new_hp, 0, max_health)
	
	_update_health_bar()
	
	if damage_taken > 0:
		_hit_flash()
		_hit_effect()
		_show_damage_number(damage_taken)

	if current_health <= 0:
		die()

@rpc("any_peer")
func rpc_request_damage(amount: int) -> void:
	if multiplayer.is_server():
		take_damage(amount)

func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
		
	# RediseÃ±ado de 0: Servidor gestiona todo el cÃ¡lculo blindado
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		var actual_damage = max(0, amount) # ProhÃ­be totalmente healing por daÃ±o negativo
		var new_hp = current_health - actual_damage
		rpc_sync_health.rpc(new_hp, actual_damage)
	else:
		rpc_request_damage.rpc_id(1, amount)

func _hit_flash() -> void:
	var visual := _visual_model
	if not visual:
		return
	
	var meshes: Array[GeometryInstance3D] = []
	for child in visual.get_children():
		if child is GeometryInstance3D:
			meshes.append(child)
			for grandchild in child.get_children():
				if grandchild is GeometryInstance3D:
					meshes.append(grandchild)
	
	if meshes.is_empty():
		return
	
	for mesh in meshes:
		var original_mat: Material = mesh.get_surface_override_material(0)
		if not original_mat:
			original_mat = mesh.material_override
		
		if not original_mat:
			continue
		
		var hit_mat := original_mat.duplicate() as StandardMaterial3D
		mesh.material_override = hit_mat
		
		var tw := create_tween()
		tw.tween_property(hit_mat, "albedo_color", Color(2.0, 0.5, 0.5), 0.05)
		tw.tween_property(hit_mat, "albedo_color", Color.WHITE, 0.15)
		tw.chain().tween_callback(func():
			# BUG FIX: Restore original material - duplicated material will be auto-freed
			mesh.material_override = original_mat
			# Note: hit_mat is a local duplicate that auto-releases when out of scope
		)

func _hit_effect() -> void:
	var hit_effect = load("res://entities/effects/HitEffect.gd")
	if hit_effect:
		var effect = Node3D.new()
		effect.set_script(hit_effect)
		add_child(effect)
		effect.position = Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3))

func _show_damage_number(amount: int) -> void:
	# Crear label flotante de daÃ±o
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

func die() -> void:
	current_state = State.DEAD
	
	# Ocultar barra de vida inmediatamente al morir
	if _health_bar_bg:
		_health_bar_bg.visible = false
	if _health_bar_fill:
		_health_bar_fill.visible = false
	
	# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
	#  VISUAL EFFECT: Death Effect
	# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
	
	# Death animation mÃ¡s rÃ¡pida y con fade
	visible = false  # Hide main mesh, show particles instead
	
	# Delay destroy to let particles play
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _death_effect() -> void:
	# FIX: Use the existing GDScript approach (effects are .gd files, not .tscn)
	var death_effect = load("res://entities/effects/DeathEffect.gd")
	if death_effect:
		var effect = Node3D.new()
		effect.set_script(death_effect)
		if max_health > 150:
			effect.enemy_type = "mage"
		elif max_health > 100:
			effect.enemy_type = "rogue"
		else:
			effect.enemy_type = "minion"
		var tree := get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(effect)
			effect.global_position = global_position
		else:
			if get_parent():
				get_parent().add_child(effect)
				effect.global_position = global_position

func _ensure_materials_loaded() -> void:
	if _materials_loaded:
		return
	
	# Pre-cargar todas las texturas, modelos y materiales una sola vez
	for i in range(MECHA_TEXTURES.size()):
		var tex = load(MECHA_TEXTURES[i]) as Texture2D
		var model = load(MECHA_MODELS[i])
		if tex and model:
			_mecha_textures.append(tex)
			_mecha_model_assets.append(model)
			# Crear material compartido TOTALMENTE SÓLIDO
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.emission_enabled = false # Sin brillos raros que parezcan hologramas
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			_mecha_materials.append(mat)
	
	_materials_loaded = true
	
	# CRITICAL FIX: Ensure all surfaces in pre-loaded models have their materials assigned correctly
	# This prevents "Parameter 'material' is null" errors during shadow passes
	for i in range(_mecha_model_assets.size()):
		var model = _mecha_model_assets[i]
		var mat = _mecha_materials[i]
		if model is Mesh:
			pass # Meshes themselves don't store surface overrides here
		elif model is PackedScene:
			# We can't easily modify the PackedScene surfaces without instantiating,
			# but we ensure they are applied during _apply_mecha_texture_by_index
			pass

func _apply_random_mecha_texture() -> void:
	"""Aplica modelo mecha aleatorio ocultando el hueso/skeleton antiguo."""
	_ensure_materials_loaded()
	
	if _mecha_materials.is_empty():
		return
		
	var idx := randi() % _mecha_materials.size()
	_apply_mecha_texture_by_index(idx)

func _apply_mecha_texture_by_index(index: int) -> void:
	"""Aplica un modelo mecha específico por índice."""
	_ensure_materials_loaded()
	
	var visual := _visual_model
	if not visual:
		return
		
	if index < 0 or index >= _mecha_materials.size():
		_apply_random_mecha_texture()
		return
	
	# 1. Limpieza total: eliminar CUALQUIER modelo mecha previo para evitar Z-fighting (textura que aparece/desaparece)
	var old_mecha = visual.get_node_or_null("MechaModel")
	if old_mecha:
		old_mecha.queue_free()
		visual.remove_child(old_mecha)
	
	# 2. Ocultar meshes y DETENER animaciones de los esqueletos originales para evitar que muevan el pivot
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		child.hide()
	for child in visual.find_children("*", "AnimationPlayer", true, false):
		child.stop()
	
	var res = _mecha_model_assets[index]
	var mecha_node: Node3D = null
	
	if res is PackedScene:
		mecha_node = res.instantiate()
	elif res is Mesh:
		mecha_node = MeshInstance3D.new()
		mecha_node.mesh = res
		
	if mecha_node:
		mecha_node.name = "MechaModel"
		visual.add_child(mecha_node)
		
		# 3. Aplicar material SÓLIDO y OPACO (sentido común: los robots no son fantasmas)
		var material = _mecha_materials[index]
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		
		if mecha_node is MeshInstance3D:
			if mecha_node.mesh:
				for i in range(mecha_node.mesh.get_surface_count()):
					mecha_node.set_surface_override_material(i, material)
		else:
			for mi in mecha_node.find_children("*", "MeshInstance3D", true, false):
				if mi.mesh:
					for i in range(mi.mesh.get_surface_count()):
						mi.set_surface_override_material(i, material)
				else:
					# Si no hay mesh pero es un MeshInstance, asignar un fallback pequeño
					# para evitar que el renderer se queje de materiales nulos en superficies inexistentes
					pass
				
		# 4. Ajustar escala, rotación y CENTRADO CRÍTICO
		mecha_node.scale = Vector3(1.0, 1.0, 1.0)
		mecha_node.rotation_degrees = Vector3(0, 180, 0)
		_center_mecha_model(mecha_node)
		
		# Fix: Asegurar que la barra de vida se vea por encima del modelo mecha
		_fix_health_bar_for_mecha()

func _animate_visuals(_delta: float) -> void:
	# Escala fija - no permitir cambios dinÃ¡micos de tamaÃ±o
	if _visual_model and _scale_initialized:
		# Mantener siempre la escala base sin animaciones
		_visual_model.scale = _base_scale
		_visual_model.position = Vector3.ZERO

func _center_mecha_model(model: Node3D) -> void:
	# Centrado geométrico para evitar "orbiting"
	var meshes: Array[MeshInstance3D] = []
	if model is MeshInstance3D:
		meshes.append(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child)
	
	if meshes.is_empty():
		model.position = Vector3.ZERO
		return
	
	var aabb := AABB()
	var first := true
	for mesh in meshes:
		if mesh.mesh:
			var local_aabb := mesh.mesh.get_aabb()
			var mesh_transform := mesh.transform
			var transformed_aabb := mesh_transform * local_aabb
			if first:
				aabb = transformed_aabb
				first = false
			else:
				aabb = aabb.merge(transformed_aabb)
	
	# Aplicar offset negativo del centro para que coincida con el origen (0,0,0)
	# IMPORTANTE: No aplicar model.quaternion porque el AABB ya está transformado
	# por la rotación del modelo. El centro ya está en coordenadas del mundo.
	# Simplemente negamos el centro directamente.
	var center := aabb.get_center()
	model.position = -center
	model.position.y = 0
