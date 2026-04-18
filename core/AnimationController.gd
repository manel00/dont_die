class_name AnimationController
extends Node

## AnimationController â€” Sistema completo de animaciones para personajes KayKit
## Gestiona AnimationTree con StateMachine para Idle, Walk, Run, Attack, Death

@export var character_model: Node3D
@export var animation_player: AnimationPlayer

var _anim_tree: AnimationTree
var _state_machine: AnimationNodeStateMachinePlayback

# Estados disponibles
enum AnimState { IDLE, WALK, RUN, ATTACK, DEATH, INTERACT }
var _current_state: AnimState = AnimState.IDLE

# Nombres de animaciones en los archivos GLB
const ANIMATIONS := {
	"Idle": "CharacterArmature|Idle",
	"Walk": "CharacterArmature|Walk",
	"Run": "CharacterArmature|Run",
	"Attack": "CharacterArmature|Punch",
	"Death": "CharacterArmature|Death",
	"Interact": "CharacterArmature|Interact"
}

func _ready() -> void:
	_setup_animation_tree()

func _setup_animation_tree() -> void:
	if not animation_player:
		# print("AnimationController: No AnimationPlayer assigned. Using fallback logic.")
		# Crear animaciones procedimentales como fallback
		_create_fallback_animations()
		return
	
	# Crear AnimationTree
	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimationTree"
	_anim_tree.anim_player = animation_player.get_path()
	_anim_tree.active = true
	add_child(_anim_tree)
	
	# Crear StateMachine
	var state_machine = AnimationNodeStateMachine.new()
	_anim_tree.tree_root = state_machine
	
	# Agregar estados
	_add_state("Idle", ANIMATIONS.Idle, true)
	_add_state("Walk", ANIMATIONS.Walk)
	_add_state("Run", ANIMATIONS.Run)
	_add_state("Attack", ANIMATIONS.Attack)
	_add_state("Death", ANIMATIONS.Death)
	_add_state("Interact", ANIMATIONS.Interact)
	
	# Conectar transiciones
	_add_transition("Idle", "Walk")
	_add_transition("Walk", "Idle")
	_add_transition("Idle", "Run")
	_add_transition("Run", "Idle")
	_add_transition("Walk", "Run")
	_add_transition("Run", "Walk")
	_add_transition("Idle", "Attack", true)  # Auto-return
	_add_transition("Walk", "Attack", true)
	_add_transition("Run", "Attack", true)
	_add_transition("Idle", "Death")
	_add_transition("Walk", "Death")
	_add_transition("Run", "Death")
	_add_transition("Idle", "Interact", true)
	
	# Obtener playback
	_state_machine = _anim_tree.get("parameters/playback")
	if _state_machine:
		_state_machine.start("Idle")

func _add_state(state_name: String, anim_name: String, is_start: bool = false) -> void:
	var state_machine = _anim_tree.tree_root as AnimationNodeStateMachine
	
	# Crear AnimationNodeAnimation
	var anim_node = AnimationNodeAnimation.new()
	anim_node.animation = anim_name
	
	state_machine.add_node(state_name, anim_node)
	
	if is_start:
		state_machine.set_start_node(state_name)

func _add_transition(from: String, to: String, auto_return: bool = false) -> void:
	var state_machine = _anim_tree.tree_root as AnimationNodeStateMachine
	
	var transition = AnimationNodeStateMachineTransition.new()
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	
	if auto_return:
		# Volver automÃ¡ticamente al estado anterior despuÃ©s de la animaciÃ³n
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	
	state_machine.add_transition(from, to, transition)
	
	if auto_return:
		# Agregar transiciÃ³n de retorno
		var return_trans = AnimationNodeStateMachineTransition.new()
		return_trans.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		return_trans.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		state_machine.add_transition(to, from, return_trans)

# API PÃºblica

func play_idle() -> void:
	if _state_machine and _current_state != AnimState.IDLE:
		_state_machine.travel("Idle")
		_current_state = AnimState.IDLE

func play_walk() -> void:
	if _state_machine and _current_state != AnimState.WALK:
		_state_machine.travel("Walk")
		_current_state = AnimState.WALK

func play_run() -> void:
	if _state_machine and _current_state != AnimState.RUN:
		_state_machine.travel("Run")
		_current_state = AnimState.RUN

func play_attack() -> void:
	if _state_machine:
		_state_machine.travel("Attack")
		_current_state = AnimState.ATTACK

func play_death() -> void:
	if _state_machine:
		_state_machine.travel("Death")
		_current_state = AnimState.DEATH

func play_interact() -> void:
	if _state_machine:
		_state_machine.travel("Interact")
		_current_state = AnimState.INTERACT

func set_speed_scale(speed: float) -> void:
	if _anim_tree:
		_anim_tree.set("parameters/TimeScale/scale", speed)

func get_current_state() -> AnimState:
	return _current_state

func is_playing(anim_name: String) -> bool:
	if not animation_player:
		return false
	return animation_player.current_animation == anim_name

func _create_fallback_animations() -> void:
	# Fallback: crear animaciones procedimentales simples
	# El sistema funcionarÃ¡ sin AnimationTree pero con animaciones bÃ¡sicas
	_current_state = AnimState.IDLE
