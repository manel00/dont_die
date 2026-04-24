extends Control

@onready var ip_line_edit: LineEdit = $MenuContainer/Card/VBoxContainer/IPSection/IpLineEdit
@onready var host_button: Button = $MenuContainer/Card/VBoxContainer/ButtonSection/HostButton
@onready var join_button: Button = $MenuContainer/Card/VBoxContainer/ButtonSection/JoinButton
@onready var solo_button: Button = $MenuContainer/Card/VBoxContainer/SoloButton
@onready var map_arena_button: Button = $MenuContainer/Card/VBoxContainer/MapSection/ArenaButton
@onready var map_sagrera_button: Button = $MenuContainer/Card/VBoxContainer/MapSection/SagreraButton
@onready var enemy_skeletons_button: Button = $MenuContainer/Card/VBoxContainer/EnemyModeSection/SkeletonsButton
@onready var enemy_mechas_button: Button = $MenuContainer/Card/VBoxContainer/EnemyModeSection/MechasButton
@onready var status_label: Label = $MenuContainer/Card/VBoxContainer/StatusLabel
@onready var host_ip_label: Label = $HostIPLabel
@onready var find_games_button: Button = $FindGamesButton
@onready var scanlines: ColorRect = $Scanlines
@onready var grid_overlay: ColorRect = $GridOverlay
@onready var menu_card: PanelContainer = $MenuContainer/Card
@onready var title_label: Label = $MenuContainer/Card/VBoxContainer/TitleSection/Title

var scanline_offset: float = 0.0
var grid_time: float = 0.0
var title_glow_phase: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	solo_button.pressed.connect(_on_solo_pressed)
	map_arena_button.pressed.connect(_on_arena_selected)
	map_sagrera_button.pressed.connect(_on_sagrera_selected)
	enemy_skeletons_button.pressed.connect(_on_skeletons_selected)
	enemy_mechas_button.pressed.connect(_on_mechas_selected)
	find_games_button.pressed.connect(_on_find_games_pressed)
	
	_connect_hover_signals(host_button)
	_connect_hover_signals(join_button)
	_connect_hover_signals(solo_button)
	_connect_hover_signals(map_arena_button)
	_connect_hover_signals(map_sagrera_button)
	_connect_hover_signals(enemy_skeletons_button)
	_connect_hover_signals(enemy_mechas_button)
	_connect_hover_signals(find_games_button)
	
	# Show local IP for reference
	_update_local_ip_display()
	# Default selection visual
	_update_map_selection_visual()
	_update_enemy_selection_visual()
	
	if NetworkManager:
		NetworkManager.connected_to_server.connect(_on_connected_ok)
		NetworkManager.connection_failed.connect(_on_connected_fail)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	GameManager.solo_mode = false
	_set_status("SELECT GAME MODE", Color(0.224, 1.0, 0.078))

func _connect_hover_signals(button: Button) -> void:
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))

func _on_solo_pressed() -> void:
	_set_status("LOADING ARENA — SOLO MODE...", Color(0.224, 1.0, 0.078))
	_set_all_buttons_disabled(true)
	
	# Use OfflineMultiplayerPeer so multiplayer.is_server() returns true
	# without requiring actual network sockets
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	GameManager.solo_mode = true
	
	await get_tree().create_timer(0.3).timeout
	_start_game()

func _on_host_pressed() -> void:
	_set_status("STARTING SERVER...", Color(0.835, 0.502, 1.0))
	_set_all_buttons_disabled(true)
	GameManager.solo_mode = false
	
	if NetworkManager.create_server() == OK:
		_set_status("SERVER ONLINE — LOADING ARENA...", Color(0.224, 1.0, 0.078))
		await get_tree().create_timer(0.4).timeout
		_start_game()
	else:
		_set_status("FAILED TO START SERVER", Color(1.0, 0.3, 0.3))
		_set_all_buttons_disabled(false)

func _on_join_pressed() -> void:
	var ip: String = ip_line_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	_set_status("CONNECTING TO " + ip + "...", Color(0.835, 0.502, 1.0))
	_set_all_buttons_disabled(true)
	GameManager.solo_mode = false
	NetworkManager.join_game(ip)

func _on_connected_ok() -> void:
	_set_status("CONNECTED — ENTERING ARENA...", Color(0.224, 1.0, 0.078))
	await get_tree().create_timer(0.4).timeout
	_start_game()

func _on_connected_fail() -> void:
	_set_status("CONNECTION FAILED — CHECK IP", Color(1.0, 0.2, 0.2))
	_set_all_buttons_disabled(false)

func _on_server_disconnected() -> void:
	_set_status("SERVER DISCONNECTED", Color(1.0, 0.2, 0.2))
	_set_all_buttons_disabled(false)

func _set_status(msg: String, color: Color) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = color

func _set_all_buttons_disabled(disabled: bool) -> void:
	host_button.disabled = disabled
	join_button.disabled = disabled
	solo_button.disabled = disabled
	map_arena_button.disabled = disabled
	map_sagrera_button.disabled = disabled
	find_games_button.disabled = disabled

func _on_arena_selected() -> void:
	GameManager.selected_map_path = GameManager.MAP_ARENA
	_update_map_selection_visual()

func _on_sagrera_selected() -> void:
	GameManager.selected_map_path = GameManager.MAP_SAGRERA
	_update_map_selection_visual()

func _on_skeletons_selected() -> void:
	GameManager.enemy_mode = "skeletons"
	_update_enemy_selection_visual()

func _on_mechas_selected() -> void:
	GameManager.enemy_mode = "mechas"
	_update_enemy_selection_visual()

func _on_find_games_pressed() -> void:
	_set_status("SEARCHING FOR GAMES...", Color(0.835, 0.502, 1.0))
	_set_all_buttons_disabled(true)
	NetworkManager.discover_servers()
	await get_tree().create_timer(3.0).timeout
	var servers := NetworkManager.get_discovered_servers()
	if servers.size() > 0:
		var first_ip: String = servers.keys()[0]
		ip_line_edit.text = first_ip
		_set_status("FOUND: " + first_ip, Color(0.224, 1.0, 0.078))
	else:
		_set_status("NO GAMES FOUND", Color(1.0, 0.2, 0.2))
	_set_all_buttons_disabled(false)

func _update_local_ip_display() -> void:
	var local_ips: Array = IP.get_local_addresses()
	var valid_ip: String = ""
	for ip: String in local_ips:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			valid_ip = ip
			break
	if valid_ip.is_empty() and local_ips.size() > 0:
		valid_ip = local_ips[0]
	if not valid_ip.is_empty():
		host_ip_label.text = "HOST IP: " + valid_ip
	else:
		host_ip_label.text = "HOST IP: ---.---.---.---"

func _update_map_selection_visual() -> void:
	var is_arena = GameManager.selected_map_path == GameManager.MAP_ARENA
	map_arena_button.modulate = Color(0.224, 1.0, 0.078, 1) if is_arena else Color(0.42, 0.0, 0.75, 0.6)
	map_sagrera_button.modulate = Color(0.224, 1.0, 0.078, 1) if !is_arena else Color(0.42, 0.0, 0.75, 0.6)
	
	map_arena_button.text = "● ARENA CLÁSICA" if is_arena else "○ ARENA CLÁSICA"
	map_sagrera_button.text = "● LA SAGRERA" if !is_arena else "○ LA SAGRERA"

func _update_enemy_selection_visual() -> void:
	var is_skeletons = GameManager.enemy_mode == "skeletons"
	enemy_skeletons_button.modulate = Color(0.224, 1.0, 0.078, 1) if is_skeletons else Color(0.42, 0.0, 0.75, 0.6)
	enemy_mechas_button.modulate = Color(0.224, 1.0, 0.078, 1) if !is_skeletons else Color(0.42, 0.0, 0.75, 0.6)
	
	enemy_skeletons_button.text = "● MODO ESQUELETOS" if is_skeletons else "○ MODO ESQUELETOS"
	enemy_mechas_button.text = "● MODO MECHAS" if !is_skeletons else "○ MODO MECHAS"

func _start_game() -> void:
	get_tree().change_scene_to_file(GameManager.selected_map_path)

func _process(delta: float) -> void:
	scanline_offset += delta * 30.0
	if scanline_offset > 4.0:
		scanline_offset = 0.0
	scanlines.position.y = fmod(scanline_offset, 4.0) - 4.0
	
	grid_time += delta
	var grid_alpha = 0.015 + sin(grid_time * 0.5) * 0.01
	grid_overlay.color = Color(0.224, 1.0, 0.078, grid_alpha)
	
	title_glow_phase += delta * 2.0
	var glow_intensity = 0.7 + sin(title_glow_phase) * 0.3
	if title_label:
		title_label.modulate = Color(1.0, 1.0, 1.0, glow_intensity)

func _on_button_mouse_entered(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.02, 1.02), 0.1)
	button.modulate = Color(0.224, 1.0, 0.078, 1.0)

func _on_button_mouse_exited(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	var is_selected = _is_button_selected(button)
	button.modulate = Color(0.224, 1.0, 0.078, 1) if is_selected else Color(0.42, 0.0, 0.75, 0.6)

func _is_button_selected(button: Button) -> bool:
	if button == map_arena_button:
		return GameManager.selected_map_path == GameManager.MAP_ARENA
	if button == map_sagrera_button:
		return GameManager.selected_map_path == GameManager.MAP_SAGRERA
	if button == enemy_skeletons_button:
		return GameManager.enemy_mode == "skeletons"
	if button == enemy_mechas_button:
		return GameManager.enemy_mode == "mechas"
	return true
