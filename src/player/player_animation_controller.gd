class_name PlayerAnimationController
extends Node
## Ponte entre a lógica do jogador e o AnimationTree do modelo humanoide.
##
## O AnimationTree (montado pelo AnimationTreeBuilder) tem uma
## AnimationNodeStateMachine na raiz. Os nomes dos estados são o "contrato"
## entre código e animação; estado que não existe é simplesmente ignorado.
##
## Locomoção: BlendSpace1D cujas posições são as velocidades naturais das
## passadas (m/s). Passamos a velocidade REAL do corpo corrigida pelo tamanho
## do personagem, então o pé não desliza.
##
## Ações com bola (Etapa 3): a física decide QUANDO o pé encosta na bola
## (Player._action_contact). Ao iniciar a ação, pulamos (TimeSeek) para o
## ponto do clipe em que faltam exatamente esse tempo até o contato do pé.
## Resultado: a bola sai no quadro em que o pé da animação toca nela.

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
	&"receive": &"Receive",
}
## tipo de ação -> nome lógico do clipe (para tempo de contato e pé)
const ACTION_LOGICAL := {
	&"pass": &"pass_short",
	&"long_pass": &"pass_long",
	&"shoot": &"shoot",
	&"shoot_power": &"shoot_power",
	&"receive": &"receive",
}
## Velocidade de reprodução das ações (um pouco mais rápido = mais responsivo).
const ACTION_SPEED := 1.1
## Depois do contato, se o jogador já está correndo, a animação volta para a
## locomoção em vez de terminar o follow-through parado.
const RELEASE_AFTER_CONTACT := 0.18
const RELEASE_SPEED := 1.8

var player: Player
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var _action_state: StringName = &""
var _time_since_contact := INF


func setup(p: Player) -> void:
	player = p
	if not player.action_started.is_connected(_on_action_started):
		player.action_started.connect(_on_action_started)
	if not player.ball_touched.is_connected(_on_ball_touched):
		player.ball_touched.connect(_on_ball_touched)
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


## Lado do pé que chuta naquela ação: +1 direito, -1 esquerdo.
func kick_foot(kind: StringName) -> float:
	if not is_active() or not ACTION_LOGICAL.has(kind):
		return 0.0
	var logical: StringName = ACTION_LOGICAL[kind]
	return AnimationCatalog.contact_foot(logical) if AnimationCatalog.has_clip(logical) else 0.0


func physics_update(delta: float) -> void:
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
	var wanted: StringName = &"LocomotionBall" if player.ball_control.has_ball() else &"Locomotion"
	_time_since_contact += delta
	if current in LOCOMOTION_STATES:
		_action_state = &""
		if current != wanted and _has_state(wanted):
			playback.travel(wanted)
	elif current == _action_state and player.state == Player.State.MOVE \
			and _time_since_contact > RELEASE_AFTER_CONTACT and player.get_horizontal_speed() > RELEASE_SPEED:
		playback.travel(wanted)
		_action_state = &""


func _on_action_started(kind: StringName) -> void:
	if not is_active() or not ACTION_STATES.has(kind):
		return
	var state_name: StringName = ACTION_STATES[kind]
	if not _has_state(state_name):
		return
	if ACTION_LOGICAL.has(kind):
		var logical: StringName = ACTION_LOGICAL[kind]
		var lead := player.time_to_contact() * ACTION_SPEED
		_play_action(state_name, maxf(AnimationCatalog.contact_time(logical) - lead, 0.0))
		_time_since_contact = -player.time_to_contact()
	else:
		_play(state_name)


func _on_ball_touched(kind: StringName) -> void:
	# Domínio: o pé pisa na bola logo em seguida ao contato.
	if kind != &"receive" or not is_active() or not _has_state(&"Receive"):
		return
	if playback.get_current_node() in LOCOMOTION_STATES and player.get_horizontal_speed() < 3.5:
		_play_action(&"Receive", maxf(AnimationCatalog.contact_time(&"receive") - 0.08, 0.0))
		_time_since_contact = -0.08


func _play_action(state_name: StringName, seek: float) -> void:
	anim_tree.set("parameters/%s/Seek/seek_request" % state_name, seek)
	anim_tree.set("parameters/%s/Scale/scale" % state_name, ACTION_SPEED)
	_action_state = state_name
	_play(state_name)


func _play(state_name: StringName) -> void:
	if playback.get_current_node() == state_name:
		playback.start(state_name) # reinicia o clipe
	else:
		playback.travel(state_name)


func _has_state(state_name: StringName) -> bool:
	var root := anim_tree.tree_root as AnimationNodeStateMachine
	return root != null and root.has_node(state_name)
