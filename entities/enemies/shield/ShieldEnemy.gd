extends EnemyBase

## ShieldEnemy â€” usa Skeleton_Warrior.glb (KayKit Skeletons) + Shield

var attack_cooldown: float = 1.2
var _attack_timer: float = 0.0

var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	max_health = 400 # +60% mÃ¡s tanky
	super._ready()
	move_speed = 0.96  # +20% (0.8 * 1.2)
	attack_damage = 35  # +75% mÃ¡s daÃ±o
	score_value = 80  # +60% mÃ¡s puntos
	attack_cooldown = 1.0  # Ataques mÃ¡s frecuentes
	_find_anim_player()
	_setup_shield_visual()

func _setup_shield_visual() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	
	var shield_path := "res://assets/models/characters/KayKit_Skeletons_1.1_FREE/assets/gltf/Skeleton_Shield_Large_A.gltf"
	if ResourceLoader.exists(shield_path):
		var shield_scene = load(shield_path)
		var shield = shield_scene.instantiate()
		visual.add_child(shield)
		shield.position = Vector3(-0.4, 0.8, -0.3)
		shield.rotation_degrees = Vector3(0, -90, 0)

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
