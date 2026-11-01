class_name PlayerAnimationController
extends Node
## Ponte entre a lógica do jogador e o AnimationTree do modelo humanoide.
##
## Etapa 1: o manequim provisório não tem esqueleto, então este nó fica inativo.
## Etapa 2: o modelo real terá um AnimationTree com uma AnimationNodeStateMachine
## na raiz contendo os estados abaixo. Os nomes são o "contrato" entre código e
## animação: basta o AnimationTree ter estados com esses nomes.
##
## Locomoção usa BlendSpace1D (parado→andando→trotando→correndo) dirigido pela
## velocidade REAL do corpo, evitando o efeito de "deslizar".

const PARAM_PLAYBACK := "parameters/playback"
const PARAM_LOCOMOTION := "parameters/Locomotion/blend_position"
const PARAM_LOCOMOTION_BALL := "parameters/LocomotionBall/blend_position"

const LOCOMOTION_STATES: Array[StringName] = [&"Locomotion", &"LocomotionBall"]

## tipo de ação do Player -> estado do AnimationTree
const ACTION_STATES := {
	&"pass": &"PassShort",
	&"long_pass": &"PassLong",
	&"shoot": &"Shoot",
	&"shoot_power": &"ShootPower",
	&"dribble": &"Dribble",
	&"tackle": &"Tackle",
	&"stumble": &"Stumble",
}

var player: Player
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback


func setup(p: Player) -> void:
	player = p
	if not player.action_started.is_connected(_on_action_started):
		player.action_started.connect(_on_action_started)
	refresh_model()


## Procura o AnimationTree dentro do modelo visual (chamar após trocar o modelo).
func refresh_model() -> void:
	anim_tree = null
	playback = null
	if player == null or player.visual == null:
		return
	anim_tree = player.visual.find_child("AnimationTree", true, false) as AnimationTree
	if anim_tree != null:
		anim_tree.active = true
		playback = anim_tree.get(PARAM_PLAYBACK) as AnimationNodeStateMachinePlayback


func is_active() -> bool:
	return anim_tree != null and playback != null


func physics_update(_delta: float) -> void:
	if not is_active():
		return
	var speed01 := clampf(player.get_horizontal_speed() / player.sprint_speed, 0.0, 1.0)
	anim_tree.set(PARAM_LOCOMOTION, speed01)
	anim_tree.set(PARAM_LOCOMOTION_BALL, speed01)
	var current := playback.get_current_node()
	if current in LOCOMOTION_STATES:
		var wanted: StringName = &"LocomotionBall" if player.ball_control.has_ball() else &"Locomotion"
		if current != wanted and _has_state(wanted):
			playback.travel(wanted)


func _on_action_started(kind: StringName) -> void:
	if not is_active() or not ACTION_STATES.has(kind):
		return
	var state_name: StringName = ACTION_STATES[kind]
	if _has_state(state_name):
		playback.travel(state_name)


func _has_state(state_name: StringName) -> bool:
	var root := anim_tree.tree_root as AnimationNodeStateMachine
	return root != null and root.has_node(state_name)
