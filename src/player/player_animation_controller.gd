class_name PlayerAnimationController
extends Node
## Ponte entre a lógica do jogador e o AnimationTree do modelo humanoide.
##
## Estado-base escolhido continuamente:
##   Mark            sem a bola, marcando quem conduz (encara o adversário e
##                   anda de lado/de costas) — e o goleiro, sempre
##   LocomotionBall  com a bola (condução)
##   Locomotion      o resto
## Os BlendSpaces recebem a velocidade REAL do corpo corrigida pelo tamanho do
## personagem, então o pé não desliza.
##
## Ações com bola: a física decide QUANDO o pé encosta na bola; ao iniciar a
## ação, pulamos (TimeSeek) para o ponto do clipe em que falta exatamente esse
## tempo até o contato do pé.

const PARAM_PLAYBACK := "parameters/playback"
const BASE_STATES: Array[StringName] = [&"Locomotion", &"LocomotionBall", &"Mark"]

## tipo de ação/reação do Player -> estado do AnimationTree
const ACTION_STATES := {
	&"pass": &"PassShort",
	&"long_pass": &"PassLong",
	&"shoot": &"Shoot",
	&"shoot_power": &"ShootPower",
	&"receive": &"Receive",
	&"spin": &"Spin",
	&"slide": &"Tackle",
	&"trip": &"Trip",
	&"jump": &"Jump",
	&"stumble": &"Stumble",
	&"gk_pass": &"GKPass",
	&"gk_catch": &"GKCatch",
	&"celebrate": &"Celebrate",
	&"samba": &"Samba",
	&"defeated": &"Defeated",
}
## tipo de ação -> nome lógico do clipe (tempo de contato e pé)
const ACTION_LOGICAL := {
	&"pass": &"pass_short",
	&"long_pass": &"pass_long",
	&"shoot": &"shoot",
	&"shoot_power": &"shoot_power",
	&"receive": &"receive",
	&"spin": &"spin",
	&"slide": &"tackle",
	&"gk_pass": &"gk_pass",
	&"trip": &"trip",
	&"jump": &"jump",
}
## Ações que ficam no chão no fim (carrinho, tropeço): levantam depois.
const DOWN_ACTIONS: Array[StringName] = [&"slide", &"trip"]
## Velocidade de reprodução das ações (um pouco mais rápido = mais responsivo).
const ACTION_SPEED := 1.1
const RELEASE_AFTER_CONTACT := 0.18
const RELEASE_SPEED := 1.8

var player: Player
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var _action_state: StringName = &""
var _action_kind: StringName = &""
var _time_since_contact := INF
var _prev_speed := 0.0
var _getting_up := false


func setup(p: Player) -> void:
	player = p
	if not player.action_started.is_connected(_on_action_started):
		player.action_started.connect(_on_action_started)
	if not player.ball_touched.is_connected(_on_ball_touched):
		player.ball_touched.connect(_on_ball_touched)
	refresh_model()


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
	k = maxf(k, 0.01)
	var v := player.get_flat_velocity()
	var stride_speed := v.length() / k
	var time_scale := stride_speed / AnimationCatalog.TOP_SPEED if stride_speed > AnimationCatalog.TOP_SPEED else 1.0
	for base in [&"Locomotion", &"LocomotionBall"]:
		anim_tree.set("parameters/%s/Speed/blend_position" % base, stride_speed)
		anim_tree.set("parameters/%s/Scale/scale" % base, time_scale)
	# Marcação: velocidade no referencial do corpo (x = direita, y = frente).
	var right := player.facing.cross(Vector3.UP)
	anim_tree.set("parameters/Mark/Dir/blend_position", Vector2(v.dot(right), v.dot(player.facing)) / k)

	var current := playback.get_current_node()
	_time_since_contact += delta

	if player.current_reaction() != &"":
		_prev_speed = v.length()
		return # comemoração/lamento: fica até a próxima saída de bola

	var wanted := _wanted_base()
	if current in BASE_STATES:
		_action_state = &""
		_action_kind = &""
		_getting_up = false
		if current != wanted and _has_state(wanted):
			playback.travel(wanted)
		# Arrancada: parado → correndo forte.
		elif current == &"Locomotion" and _prev_speed < 0.6 and player.intent.sprint \
				and player.intent.move.length() > 0.7 and _has_state(&"Burst"):
			playback.travel(&"Burst")
	elif _action_kind in DOWN_ACTIONS:
		_update_down()
	elif current == &"Burst":
		if player.state != Player.State.MOVE or player.intent.move.length() < 0.3:
			playback.travel(wanted)
	elif current == &"Fallen" or current == &"GetUp":
		if player.state == Player.State.MOVE and current == &"Fallen":
			playback.travel(wanted)
	elif current == _action_state and player.state == Player.State.MOVE \
			and _time_since_contact > RELEASE_AFTER_CONTACT and player.get_horizontal_speed() > RELEASE_SPEED:
		playback.travel(wanted)
		_action_state = &""
	elif current in [&"Celebrate", &"CelebrateIdle", &"Samba", &"Defeated"]:
		playback.travel(wanted)
	_prev_speed = v.length()


func _wanted_base() -> StringName:
	if player.is_marking() and _has_state(&"Mark"):
		return &"Mark"
	return &"LocomotionBall" if player.ball_control.has_ball() else &"Locomotion"


## Carrinho / tropeço: no chão até faltar o tempo de levantar.
func _update_down() -> void:
	if player.state != Player.State.ACTION:
		if not _getting_up:
			playback.travel(_wanted_base())
		_action_kind = &""
		return
	var getup_len := AnimationCatalog.clip_length(&"getup") / ACTION_SPEED
	var remaining := player.action_time_left()
	if not _getting_up and remaining <= maxf(getup_len, 0.35):
		_getting_up = true
		if _has_state(&"GetUp"):
			_play_action(&"GetUp", 0.0)
		else:
			playback.travel(_wanted_base())


func _on_action_started(kind: StringName) -> void:
	if not is_active():
		return
	if kind == &"pass" and player.is_goalkeeper() and _has_state(&"GKPass"):
		kind = &"gk_pass"
	if not ACTION_STATES.has(kind):
		return
	var state_name: StringName = ACTION_STATES[kind]
	if not _has_state(state_name):
		return
	_action_kind = kind
	_getting_up = false
	if ACTION_LOGICAL.has(kind):
		var logical: StringName = ACTION_LOGICAL[kind]
		var seek := 0.0
		if AnimationCatalog.CONTACTS.has(logical):
			seek = maxf(AnimationCatalog.contact_time(logical) - player.time_to_contact() * ACTION_SPEED, 0.0)
		_play_action(state_name, seek)
		_time_since_contact = -player.time_to_contact()
	else:
		_play(state_name)


func _on_ball_touched(kind: StringName) -> void:
	if not is_active():
		return
	if kind == &"gk_catch" and _has_state(&"GKCatch"):
		_action_kind = kind
		_play_action(&"GKCatch", 0.3)
		_time_since_contact = 0.0
		return
	# Domínio: o pé pisa na bola logo em seguida ao contato.
	if kind != &"receive" or not _has_state(&"Receive"):
		return
	if playback.get_current_node() in BASE_STATES and player.get_horizontal_speed() < 3.5:
		_action_kind = kind
		_play_action(&"Receive", maxf(AnimationCatalog.contact_time(&"receive") - 0.08, 0.0))
		_time_since_contact = -0.08


func _play_action(state_name: StringName, seek: float) -> void:
	anim_tree.set("parameters/%s/Seek/seek_request" % state_name, seek)
	anim_tree.set("parameters/%s/Scale/scale" % state_name, ACTION_SPEED)
	_action_state = state_name
	_play(state_name)


func _play(state_name: StringName) -> void:
	if playback.get_current_node() == state_name:
		playback.start(state_name)
	else:
		playback.travel(state_name)


func _has_state(state_name: StringName) -> bool:
	var root := anim_tree.tree_root as AnimationNodeStateMachine
	return root != null and root.has_node(state_name)
