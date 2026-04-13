extends EnemyBase

## Zombie — usa Skeleton_Minion.glb (KayKit Skeletons)

var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0

# Animaciones del Skeleton_Minion
var _anim_player: AnimationPlayer = null
const ANIM_WALK := "Walk"
const ANIM_IDLE := "Idle"
const ANIM_ATTACK := "Attack"

func _ready() -> void:
	super._ready()
	_find_anim_player()

func _find_anim_player() -> void:
	var visual := get_node_or_null("VisualModel")
	if not visual: return
	for child in visual.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb")
			return
		for grandchild in child.get_children():
			if grandchild is AnimationPlayer:
				_anim_player = grandchild
				_load_animations("res://assets/models/characters/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb")
				return

func _load_animations(anim_path: String) -> void:
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
			if not _anim_player.current_animation == ANIM_IDLE:
				if _anim_player.has_animation(ANIM_IDLE):
					_anim_player.play(ANIM_IDLE)
		State.CHASE:
			if not _anim_player.current_animation == ANIM_WALK:
				if _anim_player.has_animation(ANIM_WALK):
					_anim_player.play(ANIM_WALK)
		State.ATTACK:
			if not _anim_player.current_animation == ANIM_ATTACK:
				if _anim_player.has_animation(ANIM_ATTACK):
					_anim_player.play(ANIM_ATTACK)
		State.DEAD:
			_anim_player.stop()

func _perform_attack() -> void:
	if target == null: return
	
	# Mirar al jugador agresivamente
	var dir := global_position.direction_to(target.global_position)
	rotation.y = atan2(dir.x, dir.z)
	
	if _attack_timer <= 0.0:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
			print("¡Zombi muerde al jugador por ", attack_damage, "!")
			_attack_timer = attack_cooldown
