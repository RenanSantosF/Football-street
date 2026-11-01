class_name PlayerAnimationController
extends Node
## Ponte entre a lógica do jogador e o AnimationTree do modelo humanoide.
##
## O AnimationTree (montado pelo AnimationTreeBuilder) tem uma
## AnimationNodeStateMachine na raiz. Os nomes dos estados são o "contrato"
## entre código e animação; estado que ainda não existe é simplesmente ignorado
## (ex.: chutes chegam na Etapa 3).
##
## Locomoção: BlendSpace1D cujas posições são as velocidades naturais das
## passadas (m/s). Passamos a velocidade REAL do corpo, corrigida pelo tamanho
## do personagem, então o pé não desliza. Acima do clipe mais rápido, o
## TimeScale acelera a passada.

const PARAM_PLAYBACK := "parameters/playback"
const LOCOMOTION_STATES_PARAMS: Array[String] = ["parameters/Locomotion", "parameters/LocomotionBall"]

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
	var k := 1.0
	if player.visual.has_method("get_locomotion_scale"):
		k = player.visual.call("get_locomotion_scale")
	var stride_speed := player.get_horizontal_speed() / maxf(k, 0.01)
	var top: float = AnimationCatalog.LOCOMOTION_SPEEDS[&"sprint"]
	var time_scale := stride_speed / top if stride_speed > top else 1.0
	for base in LOCOMOTION_STATES_PARAMS:
		anim_tree.set(base + "/Speed/blend_position", stride_speed)
		anim_tree.set(base + "/Scale/scale", time_scale)
	var current := playback.get_current_node()
	if current in LOCOMOTION_STATES:
		var wanted: StringName = &"LocomotionBall" if player.ball_control.has_ball() else &"Locomotion"
		if current != wanted and _has_state(wanted):
			playback.travel(wanted)


func _on_action_started(kind: StringName) -> void:
	if not is_active() or not ACTION_STATES.has(kind):
		return
	var state_name: StringName = ACTION_STATES[kind]
	if not _has_state(state_name):
		return
	if playback.get_current_node() == state_name:
		playback.start(state_name) # reinicia o clipe
	else:
		playback.travel(state_name)


func _has_state(state_name: StringName) -> bool:
	var root := anim_tree.tree_root as AnimationNodeStateMachine
	return root != null and root.has_node(state_name)
