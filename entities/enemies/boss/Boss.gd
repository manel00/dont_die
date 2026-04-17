extends EnemyBase

## Boss — usa Skeleton_Rogue.glb (KayKit Skeletons)
## BOSS FINAL: Usa textura MechaGolem para diferenciarse

var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

# Índice de textura mecha para el boss (MechaGolem = 4)
const BOSS_MECHA_INDEX: int = 4

func _ready() -> void:
	max_health = 2000  # +100% más vida
	super._ready()  # llama a la base que establece current_health = max_health
	move_speed = 2.8  # 80% más lento
	attack_damage = 80  # +60% más daño
	score_value = 200  # +100% más puntos
	attack_cooldown = 0.8  # Ataques más frecuentes
	# IA más agresiva para boss
	flank_chance = 0.6  # 60% probabilidad de flanquear
	reaction_time = 0.15  # Reacciona muy rápido
	_find_anim_player()
	_setup_axe_visual()
	_apply_mecha_texture_by_index(BOSS_MECHA_INDEX)  # BOSS: Textura MechaGolem fija

func _setup_axe_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	var axe_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Axe.gltf"
	if ResourceLoader.exists(axe_path):
		var axe = load(axe_path).instantiate()
		visual.add_child(axe)
		axe.position = Vector3(0.4, 0.8, -0.2)
		axe.rotation_degrees = Vector3(0, 90, 0)
		axe.scale = Vector3(1.2, 1.2, 1.2)
	
	# El Boss tiene escala extra para parecer más intimidante
	var boss_visual := get_node_or_null("VisualModel") as Node3D
	if boss_visual:
		boss_visual.scale *= 1.5
		_base_scale = boss_visual.scale
		_scale_initialized = true

func _find_anim_player() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	for child in visual.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
			return
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				_anim_player = grandchild
				_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
				return

func _load_animations(_anim_path := "") -> void:
	# SIMPLIFIED: Las animaciones vienen incluidas en los modelos .glb
	pass

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if current_state == State.ATTACK:
		_attack_timer -= delta
	
	_update_animation()

func _update_animation() -> void:
	if not _anim_player:
		return
	match current_state:
		State.IDLE:
			if _anim_player.has_animation(ANIM_IDLE) and _anim_player.current_animation != ANIM_IDLE:
				_anim_player.play(ANIM_IDLE)
		State.CHASE:
			if _anim_player.has_animation(ANIM_WALK) and _anim_player.current_animation != ANIM_WALK:
				_anim_player.play(ANIM_WALK)
		State.ATTACK:
			if _anim_player.has_animation(ANIM_ATTACK) and _anim_player.current_animation != ANIM_ATTACK:
				_anim_player.play(ANIM_ATTACK)
		State.DEAD:
			_anim_player.stop()

func _perform_attack() -> void:
	if target == null: return
	
	var dir := global_position.direction_to(target.global_position)
	rotation.y = atan2(dir.x, dir.z)
	
	if _attack_timer <= 0.0:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
			_attack_timer = attack_cooldown
			
			# Golpe de boss: pequeño shake de cámara (via shockwave visual)
			var shockwave := CSGSphere3D.new()
			shockwave.radius = 0.1
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.0, 0.0, 0.5)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.0, 0.0)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shockwave.material = mat
			get_tree().current_scene.add_child(shockwave)
			shockwave.global_position = global_position + Vector3(0, 0.5, 0)
			var tw := get_tree().current_scene.create_tween().set_parallel(true)
			tw.tween_property(shockwave, "radius", 3.0, 0.3)
			tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
			tw.chain().tween_callback(shockwave.queue_free)
