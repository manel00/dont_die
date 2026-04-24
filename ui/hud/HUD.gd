extends CanvasLayer

@onready var score_label: Label = $MarginContainer/UILayout/TopBar/ScoreLabel
@onready var wave_label: Label = $MarginContainer/UILayout/TopBar/WaveLabel
@onready var ammo_label: Label = $MarginContainer/UILayout/BottomUI/AmmoContainer/AmmoLabel
@onready var health_bar: ProgressBar = $MarginContainer/UILayout/BottomUI/HealthContainer/HealthBar
@onready var health_value: Label = $MarginContainer/UILayout/BottomUI/HealthContainer/HealthValue
@onready var heart_icon: Label = $MarginContainer/UILayout/BottomUI/HealthContainer/HeartIcon
@onready var reload_progress: ProgressBar = $MarginContainer/UILayout/BottomUI/ReloadProgressBar
@onready var game_over_overlay: ColorRect = $GameOverOverlay
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var final_score_label: Label = $GameOverOverlay/CenterContainer/VBoxContainer/FinalScoreLabel
@onready var radar_container: Control = $RadarContainer
@onready var radar_circle: ColorRect = $RadarContainer/RadarCircle
@onready var enemy_markers: Control = $RadarContainer/RadarCircle/EnemyMarkers

# Labels de estado de bots aliados (opcional — se crean dinámicamente si no existen en la escena)
var bot_labels: Array[Label] = []
var _enemy_count_label: Label = null

# Radar settings - OPTIMIZED
const RADAR_RANGE: float = 50.0  # Distance in world units
const MAX_RADAR_ENEMIES: int = 15  # Limit to prevent lag with 100+ enemies
const RADAR_UPDATE_INTERVAL: float = 0.1  # Update every 0.1s instead of every frame
var _radar_dots: Array[ColorRect] = []
var _player: Node3D = null
var _radar_update_timer: float = 0.0
@warning_ignore("unused_variable")
var _cached_enemies: Array = []

# Ability cooldown tracking
var _ability_cooldowns: Dictionary = {
	"katana": {"current": 0.0, "max": 0.5, "node": null},
	"fireball": {"current": 0.0, "max": 2.0, "node": null},
	"explosion": {"current": 0.0, "max": 5.0, "node": null},
	"heal": {"current": 0.0, "max": 15.0, "node": null}
}

# Kill feed
var _kill_feed_entries: Array[Label] = []
const MAX_KILL_FEED_ENTRIES: int = 5

# Stats tracking
var _player_kills: int = 0
var _bot_kills: int = 0
var _survival_time: float = 0.0
var _game_start_time: float = 0.0

func _ready() -> void:
	# Conectar señales del GameManager y WaveManager
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.score_changed.connect(_on_score_changed)
		gm.game_over.connect(_on_game_over)
	
	var wm := get_node_or_null("/root/WaveManager")
	if wm:
		wm.wave_started.connect(_on_wave_started)

	reload_progress.visible = false
	game_over_overlay.visible = false
	
	# Crear label de conteo de enemigos dinámicamente
	_create_enemy_counter()
	
	# Crear labels de bots
	_setup_bot_labels()
	
	# Setup radar
	_setup_radar()
	
	# Setup ability cooldowns
	_setup_ability_cooldowns()
	
	# Setup kill feed
	_setup_kill_feed()
	
	# Start survival timer
	_game_start_time = Time.get_unix_time_from_system()

func _create_enemy_counter() -> void:
	_enemy_count_label = Label.new()
	_enemy_count_label.name = "EnemyCountLabel"
	_enemy_count_label.text = "ENEMIES: 0"
	_enemy_count_label.add_theme_font_size_override("font_size", 14)
	_enemy_count_label.modulate = Color(1.0, 0.4, 0.2)
	# Añadir en la barra superior si existe
	var top_bar := get_node_or_null("MarginContainer/UILayout/TopBar")
	if top_bar:
		top_bar.add_child(_enemy_count_label)

func _setup_bot_labels() -> void:
	# Crear mini-labels de estado de bots si se usa modo solo
	# Se actualizan desde _process
	pass

func _process(_delta: float) -> void:
	# Actualizar conteo de enemigos activo
	if _enemy_count_label:
		var enemies := get_tree().get_nodes_in_group("enemies")
		_enemy_count_label.text = "👾 " + str(enemies.size())
	
	# Sincronizar labels de bots (crear si faltan)
	var bots := get_tree().get_nodes_in_group("bots")
	
	# Ajustar cantidad de labels si no coincide con cantidad de bots
	if bots.size() != bot_labels.size():
		# Limpiar y regenerar (simple) o añadir faltantes
		if bots.size() > bot_labels.size():
			for i in range(bot_labels.size(), bots.size()):
				add_bot_label(i)
	
	# Actualizar labels existentes
	for i in range(bots.size()):
		if i < bot_labels.size():
			var bot := bots[i] as Node
			if is_instance_valid(bot) and bot.get("current_health") != null:
				var hp: int = bot.get("current_health")
				var max_hp: int = bot.get("max_health") if bot.get("max_health") != null else 100
				bot_labels[i].text = "🤖 BOT%d: %d/%d" % [i + 1, hp, max_hp]
				var ratio: float = float(hp) / max(max_hp, 1)
				bot_labels[i].modulate = Color(1.0, ratio, ratio * 0.5)
			else:
				# Si el bot murió, el label se queda pero podemos marcarlo
				bot_labels[i].text = "🤖 BOT%d: DEAD" % (i + 1)
				bot_labels[i].modulate = Color.GRAY
	
	# Update radar (optimized - only every 0.1s, max 15 enemies)
	_update_radar(_delta)
	
	# Update ability cooldowns
	_update_ability_cooldowns(_delta)
	
	# Update kill feed (fade out)
	_update_kill_feed(_delta)
	
	# Update survival time
	_update_survival_time()

func _on_score_changed(new_score: int) -> void:
	score_label.text = "SCORE: " + str(new_score)

func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE " + str(wave_number)
	var tween := create_tween()
	wave_label.pivot_offset = wave_label.size / 2
	wave_label.scale = Vector2(1.5, 1.5)
	tween.tween_property(wave_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func update_health(current: int, maximum: int) -> void:
	if not health_bar: health_bar = get_node_or_null("MarginContainer/UILayout/BottomUI/HealthContainer/HealthBar")
	if not health_value: health_value = get_node_or_null("MarginContainer/UILayout/BottomUI/HealthContainer/HealthValue")
	if not heart_icon: heart_icon = get_node_or_null("MarginContainer/UILayout/BottomUI/HealthContainer/HeartIcon")
	if not damage_overlay: damage_overlay = get_node_or_null("DamageOverlay")
	if not health_bar: return
	
	health_bar.max_value = maximum
	health_bar.value = current
	if health_value:
		health_value.text = "%d / %d" % [current, maximum]
	
	var ratio := float(current) / maximum
	
	# Color del corazón según la vida
	if is_instance_valid(heart_icon):
		if ratio < 0.3:
			heart_icon.text = "💔"
			heart_icon.modulate = Color(1, 0, 0)
			var pulse_tween = create_tween().set_loops()
			pulse_tween.tween_property(heart_icon, "scale", Vector2(1.3, 1.3), 0.4)
			pulse_tween.tween_property(heart_icon, "scale", Vector2(1.0, 1.0), 0.4)
		elif ratio < 0.6:
			heart_icon.text = "❤️"
			heart_icon.modulate = Color(1, 0.5, 0)
			heart_icon.scale = Vector2(1.0, 1.0)
		else:
			heart_icon.text = "❤️"
			heart_icon.modulate = Color(1, 0.2, 0.2)
			heart_icon.scale = Vector2(1.0, 1.0)
	
	# Color de la barra según vida
	var fill_style = health_bar.get_theme_stylebox("fill")
	if fill_style:
		var target_color: Color
		if ratio < 0.3:
			target_color = Color(0.9, 0.1, 0.1)
		elif ratio < 0.6:
			target_color = Color(0.9, 0.7, 0.1)
		else:
			target_color = Color(0.2, 0.8, 0.2)
		
		var tween := create_tween()
		tween.tween_method(func(c): fill_style.bg_color = c, fill_style.bg_color, target_color, 0.3)
	
	# Color del texto según vida
	if is_instance_valid(health_value):
		if ratio < 0.3:
			health_value.modulate = Color(1, 0.3, 0.3)
		else:
			health_value.modulate = Color.WHITE
	
	# Overlay de daño cuando vida < 25%
	if ratio < 0.25:
		damage_overlay.visible = true
		var pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(damage_overlay, "color:a", 0.3, 0.5)
		pulse_tween.tween_property(damage_overlay, "color:a", 0.1, 0.5)
	else:
		damage_overlay.visible = false

func update_weapon_hud(current_ammo: int, max_ammo: int, is_reloading: bool, reload_timer: float, normal_reload_time: float) -> void:
	if not ammo_label: ammo_label = $MarginContainer/UILayout/BottomUI/AmmoContainer/AmmoLabel
	if not reload_progress: reload_progress = $MarginContainer/UILayout/BottomUI/ReloadProgressBar
	if not ammo_label: return
	
	if current_ammo >= 999:
		ammo_label.text = "AMMO: ∞"
	else:
		ammo_label.text = "AMMO: %d / %d" % [current_ammo, max_ammo]
	
	if is_reloading and reload_progress:
		reload_progress.visible = true
		reload_progress.max_value = normal_reload_time
		reload_progress.value = reload_timer
		# Color del active reload window
		var progress_pct := reload_timer / normal_reload_time
		if progress_pct >= 0.55 and progress_pct <= 0.8:
			reload_progress.modulate = Color(0.2, 1.0, 0.3)  # Verde = zona active reload
		else:
			reload_progress.modulate = Color(1.0, 0.8, 0.2)  # Amarillo = normal
	elif reload_progress:
		reload_progress.visible = false

func _on_game_over() -> void:
	game_over_overlay.visible = true
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		final_score_label.text = "PUNTAJE FINAL: " + str(gm.current_score)
	
	# Tween de entrada del game over
	game_over_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.5)

func update_weapon_name(weapon_name: String) -> void:
	if not ammo_label: return
	var icons := {"Weapon": "🔫", "Shotgun": "💥", "AssaultRifle": "⚡", "Assault Rifle": "⚡"}
	var icon: String = icons.get(weapon_name, "🔫")
	ammo_label.text = icon + " " + weapon_name.to_upper() + "  |  ∞"
	# Flash effect
	var tween := create_tween()
	ammo_label.modulate = Color(1.0, 0.9, 0.2, 1)
	tween.tween_property(ammo_label, "modulate", Color.WHITE, 0.4)

func add_bot_label(bot_index: int) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.text = "🤖 BOT%d: 100/100" % (bot_index + 1)
	lbl.modulate = Color(0.5, 1.0, 0.6)
	bot_labels.append(lbl)
	# Añadir al layout si existe un contenedor de bots
	var bot_container := get_node_or_null("MarginContainer/UILayout/BotContainer")
	if bot_container:
		bot_container.add_child(lbl)
	else:
		# Añadir directamente a la capa del canvas
		add_child(lbl)
		lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		lbl.position = Vector2(10, 100 + bot_index * 20)

# ═══════════════════════════════════════════════════════════════════
#  RADAR SYSTEM
# ═══════════════════════════════════════════════════════════════════
func _setup_radar() -> void:
	# Find the player
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if not p.is_in_group("bots"):
			_player = p as Node3D
			break
	
	# Create initial pool of radar dots
	for i in range(20):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.color = Color(1, 0, 0, 1)  # Red for enemies
		dot.visible = false
		enemy_markers.add_child(dot)
		_radar_dots.append(dot)

func _update_radar(delta: float) -> void:
	_radar_update_timer += delta
	if _radar_update_timer < RADAR_UPDATE_INTERVAL:
		return  # Skip this frame, update only every 0.1s
	_radar_update_timer = 0.0
	
	if not _player or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if not p.is_in_group("bots"):
				_player = p as Node3D
				break
		if not _player:
			return
	
	# Get enemies and sort by distance (closest first) - OPTIMIZED
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	var nearby_enemies = []
	
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy is Node3D:
			var diff = enemy.global_position - _player.global_position
			var dist = Vector2(diff.x, diff.z).length()
			if dist <= RADAR_RANGE:
				nearby_enemies.append({"enemy": enemy, "dist": dist})
	
	# Sort by distance and take only closest 15
	nearby_enemies.sort_custom(func(a, b): return a.dist < b.dist)
	var enemies_to_show = nearby_enemies.slice(0, min(MAX_RADAR_ENEMIES, nearby_enemies.size()))
	
	var radar_radius := radar_circle.size.x / 2.0
	
	# Update dots - hide unused ones first
	for i in range(_radar_dots.size()):
		var dot := _radar_dots[i]
		if i < enemies_to_show.size():
			var enemy_data: Dictionary = enemies_to_show[i]
			var enemy: Node3D = enemy_data.enemy
			var distance: float = enemy_data.dist
			var diff: Vector3 = enemy.global_position - _player.global_position
			
			var angle := atan2(diff.x, diff.z) - _player.rotation.y
			var normalized_dist := distance / RADAR_RANGE
			
			var radar_x := radar_radius + sin(angle) * normalized_dist * radar_radius - 3
			var radar_y := radar_radius - cos(angle) * normalized_dist * radar_radius - 3
			
			dot.position = Vector2(radar_x, radar_y)
			dot.visible = true
			
			# Simplified color check - check name only once
			var enemy_name = enemy.name
			if enemy_name.contains("Mage") or enemy_name.contains("Rogue"):
				dot.color = Color(1, 0.5, 0, 1)  # Orange for mini-bosses
			else:
				dot.color = Color(1, 0, 0, 1)  # Red for normal
		else:
			dot.visible = false

func _setup_ability_cooldowns() -> void:
	var container = get_node_or_null("MarginContainer/UILayout/BottomUI/AbilitiesContainer")
	if not container: return
	
	# Assign cooldown nodes
	var katana = container.get_node_or_null("AbilityKatana/CooldownOverlay")
	var fireball = container.get_node_or_null("AbilityFireball/CooldownOverlay")
	var explosion = container.get_node_or_null("AbilityExplosion/CooldownOverlay")
	var heal = container.get_node_or_null("AbilityHeal/CooldownOverlay")
	
	if katana: _ability_cooldowns["katana"]["node"] = katana
	if fireball: _ability_cooldowns["fireball"]["node"] = fireball
	if explosion: _ability_cooldowns["explosion"]["node"] = explosion
	if heal: _ability_cooldowns["heal"]["node"] = heal
	
	# Style cooldown overlays
	for ability in _ability_cooldowns:
		var data = _ability_cooldowns[ability]
		var node = data["node"] as ProgressBar
		if node:
			node.max_value = data["max"]
			node.value = data["max"]
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0.7)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_right = 4
			style.corner_radius_bottom_left = 4
			node.add_theme_stylebox_override("background", style)

func _update_ability_cooldowns(delta: float) -> void:
	for ability in _ability_cooldowns:
		var data = _ability_cooldowns[ability]
		var node = data["node"] as ProgressBar
		if node and data["current"] > 0:
			data["current"] = max(0, data["current"] - delta)
			node.value = data["current"]
			# Visual: show cooldown as overlay
			if data["current"] <= 0:
				node.modulate = Color(1, 1, 1, 0.3)  # Ready - dimmed
			else:
				node.modulate = Color(1, 1, 1, 1)  # On cooldown

func update_ability_cooldown(ability_name: String, cooldown_time: float) -> void:
	if _ability_cooldowns.has(ability_name):
		_ability_cooldowns[ability_name]["current"] = cooldown_time
		_ability_cooldowns[ability_name]["max"] = cooldown_time

func _setup_kill_feed() -> void:
	var top_bar = get_node_or_null("MarginContainer/UILayout/TopBar")
	if not top_bar: return
	
	# Create container for kill feed on the right side
	for i in range(MAX_KILL_FEED_ENTRIES):
		var label = Label.new()
		label.name = "KillFeed_" + str(i)
		label.add_theme_font_size_override("font_size", 14)
		label.modulate = Color(1, 1, 1, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_bar.add_child(label)
		_kill_feed_entries.append(label)

func _update_kill_feed(delta: float) -> void:
	# Fade out kill feed entries
	for i in range(_kill_feed_entries.size()):
		var label = _kill_feed_entries[i]
		if label.modulate.a > 0:
			label.modulate.a = max(0, label.modulate.a - delta * 0.5)

func add_kill_feed_entry(killer_name: String, enemy_type: String, points: int) -> void:
	# Shift entries down
	for i in range(_kill_feed_entries.size() - 1, 0, -1):
		_kill_feed_entries[i].text = _kill_feed_entries[i - 1].text
		_kill_feed_entries[i].modulate.a = _kill_feed_entries[i - 1].modulate.a
	
	# Add new entry at top
	_kill_feed_entries[0].text = "%s killed %s +%d" % [killer_name, enemy_type, points]
	_kill_feed_entries[0].modulate.a = 1.0

func _update_survival_time() -> void:
	if _game_start_time > 0:
		_survival_time = Time.get_unix_time_from_system() - _game_start_time
		var minutes = int(_survival_time / 60.0)
		var seconds = int(_survival_time) % 60
		# Update or create survival time label
		var top_bar = get_node_or_null("MarginContainer/UILayout/TopBar")
		if top_bar:
			var time_label = top_bar.get_node_or_null("TimeLabel")
			if not time_label:
				time_label = Label.new()
				time_label.name = "TimeLabel"
				time_label.add_theme_font_size_override("font_size", 18)
				top_bar.add_child(time_label)
			time_label.text = "TIME: %02d:%02d" % [minutes, seconds]

func record_kill(is_player: bool) -> void:
	if is_player:
		_player_kills += 1
	else:
		_bot_kills += 1
	
	# Update kill stats display
	var top_bar = get_node_or_null("MarginContainer/UILayout/TopBar")
	if top_bar:
		var stats_label = top_bar.get_node_or_null("KillStatsLabel")
		if not stats_label:
			stats_label = Label.new()
			stats_label.name = "KillStatsLabel"
			stats_label.add_theme_font_size_override("font_size", 14)
			stats_label.modulate = Color(0.7, 0.7, 1.0)
			top_bar.add_child(stats_label)
		stats_label.text = "KILLS: P%d | B%d" % [_player_kills, _bot_kills]

# ═══════════════════════════════════════════════════════════════════
#  FALL WARNING SYSTEM
# ═══════════════════════════════════════════════════════════════════
var _fall_warning_label: Label = null

func show_fall_warning(time_remaining: float) -> void:
	if not _fall_warning_label:
		_fall_warning_label = Label.new()
		_fall_warning_label.name = "FallWarningLabel"
		_fall_warning_label.add_theme_font_size_override("font_size", 32)
		_fall_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fall_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fall_warning_label.set_anchors_preset(Control.PRESET_CENTER)
		add_child(_fall_warning_label)
	
	_fall_warning_label.visible = true
	var seconds = max(0, ceil(time_remaining))
	_fall_warning_label.text = "⚠️ RETURN TO MAP! %ds" % seconds
	_fall_warning_label.modulate = Color(1.0, 0.3, 0.3) if time_remaining < 1.0 else Color(1.0, 0.8, 0.2)

func hide_fall_warning() -> void:
	if _fall_warning_label:
		_fall_warning_label.visible = false
