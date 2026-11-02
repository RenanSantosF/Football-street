class_name PlayerAnimationController
extends Node
## Ponte entre a lógica do jogador e o AnimationTree do modelo humanoide.
##
## Estado-base escolhido continuamente:
##   Mark            sem a bola, marcando quem conduz (encara o adversário e
##                   anda de lado/de costas) — e o goleiro, sempre
##   Locomotion      o resto
## Os BlendSpaces recebem a velocidade REAL do corpo corrigida pelo tamanho do
## personagem, então o pé não desliza.
##
## Ações com bola: a física decide QUANDO o pé encosta na bola; ao iniciar a
## ação, pulamos (TimeSeek) para o ponto do clipe em que falta exatamente esse
## tempo até o contato do pé.

const PARAM_PLAYBACK := "parameters/playback"
const BASE_STATES: Array[StringName] = [&"Locomotion", &"Mark"]

## tipo de ação/reação do Player -> estado do AnimationTree
const ACTION_STATES := {
	&"pass": &"PassShort",
	&"chip": &"PassShort",
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
	&"turn180": &"Turn180",
	&"turn_l": &"TurnLeft",
	&"turn_r": &"TurnRight",
	&"run_stop": &"RunStop",
	&"cut_r": &"Cut",
	&"cut_l": &"CutL",
	&"walk_turn180_r": &"WalkTurn180",
	&"walk_turn180_l": &"WalkTurn180L",
	&"stand_turn_r": &"StandTurn",
	&"stand_turn_l": &"StandTurnL",
	&"walk_stop": &"WalkStop",
	&"recv_chest": &"RecvChest",
	&"recv_knee": &"RecvKnee",
	&"header": &"Header",
	&"head_control": &"HeadControl",
	&"header_jump": &"HeaderJump",
	&"tackle": &"PassLong",
	&"celebrate": &"Celebrate",
	&"samba": &"Samba",
	&"defeated": &"Defeated",
}
## tipo de ação -> nome lógico do clipe (tempo de contato e pé)
const ACTION_LOGICAL := {
	&"pass": &"pass_short",
	&"chip": &"pass_short",
	&"long_pass": &"pass_long",
	&"shoot": &"shoot",
	&"shoot_power": &"shoot_power",
	&"receive": &"receive",
	&"spin": &"spin",
	&"slide": &"tackle",
	&"gk_pass": &"gk_pass",
	&"trip": &"trip",
	&"jump": &"jump",
	&"tackle": &"pass_long",
	&"turn180": &"turn180",
	&"turn_l": &"turn_l",
	&"turn_r": &"turn_r",
	&"run_stop": &"run_stop",
	&"cut_r": &"cut_r",
	&"cut_l": &"cut_r_m",
	&"walk_turn180_r": &"walk_turn180",
	&"walk_turn180_l": &"walk_turn180_m",
	&"stand_turn_r": &"stand_turn_r",
	&"stand_turn_l": &"stand_turn_r_m",
	&"walk_stop": &"walk_stop",
	&"recv_chest": &"recv_chest",
	&"recv_knee": &"recv_knee",
	&"header": &"header",
	&"head_control": &"head_control",
	&"header_jump": &"header_jump",
}
## Estados que voltam sozinhos para a locomoção no fim do clipe.
const AUTO_RETURN: Array[StringName] = [
	&"PassShort", &"PassLong", &"Shoot", &"ShootPower", &"PassShortL", &"PassLongL", &"ShootL",
	&"ShootPowerL", &"Receive", &"Spin", &"GKPass", &"GKCatch", &"Jump", &"Turn180", &"TurnLeft",
	&"TurnRight", &"RunStop", &"Cut", &"CutL", &"WalkTurn180", &"WalkTurn180L", &"StandTurn",
	&"StandTurnL", &"WalkStop", &"RecvChest", &"Header", &"HeadControl", &"HeaderJump", &"Burst",
	&"Stumble", &"GetUpFront", &"GetUpBack",
]
## Domínios no ar: depois do contato voltam para a locomoção (o joelho é um
## clipe em ciclo, então não acaba sozinho).
const AERIAL_STATES: Array[StringName] = [&"RecvChest", &"RecvKnee", &"Header", &"HeadControl", &"HeaderJump"]
## Velocidade de reprodução por tipo (as viradas casam com a física do Player).
const KIND_SPEED := {
	&"turn180": Player.TURN_SPEED_UP, &"turn_l": Player.TURN_SPEED_UP,
	&"turn_r": Player.TURN_SPEED_UP, &"run_stop": 1.0,
	&"cut_r": 1.0, &"cut_l": 1.0, &"walk_turn180_r": 1.45, &"walk_turn180_l": 1.45,
	&"stand_turn_r": 1.2, &"stand_turn_l": 1.2, &"walk_stop": 1.0,
}
## Gesto de espera -> estado.
const GESTURE_STATES := {
	&"argue": &"Argue", &"warmup": &"Warmup", &"talk": &"Talk", &"kick_up": &"KickUp",
}
const GESTURE_CLIPS := {
	&"argue": &"argue", &"warmup": &"warmup", &"talk": &"talk", &"kick_up": &"kick_up",
}
## Ações que ficam no chão no fim (carrinho, tropeço): levantam depois.
const DOWN_ACTIONS: Array[StringName] = [&"slide", &"trip"]
## Velocidade de reprodução das ações (um pouco mais rápido = mais responsivo).
const ACTION_SPEED := 1.0
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
var _prev_facing := Vector3.FORWARD
var _turn_rate := 0.0
var _gesture_state: StringName = &""
var _ball_blend := 0.0
var _stride := 0.0
var _blend_pos := 0.0
var _time_scale := 1.0
## Velocidade natural da caminhada (m/s, catálogo).
const WALK_STRIDE := 1.64
var _rng := RandomNumberGenerator.new()


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
		# Cada jogador começa num ponto diferente do ciclo (ninguém sincronizado).
		_rng.randomize()
		anim_tree.advance(_rng.randf_range(0.0, 3.0))


func is_active() -> bool:
	return anim_tree != null and playback != null


## Lado do pé que chuta naquela ação: +1 direito, -1 esquerdo.
func kick_foot(kind: StringName) -> float:
	if not is_active() or not ACTION_LOGICAL.has(kind):
		return 0.0
	var logical: StringName = ACTION_LOGICAL[kind]
	if player.kick_mirrored() and AnimationCatalog.has_clip(AnimationCatalog.mirrored_name(logical)):
		logical = AnimationCatalog.mirrored_name(logical)
	return AnimationCatalog.contact_foot(logical) if AnimationCatalog.has_clip(logical) else 0.0


func physics_update(delta: float) -> void:
	if not is_active():
		return
	var k := 1.0
	if player.visual.has_method("get_locomotion_scale"):
		k = player.visual.call("get_locomotion_scale")
	k = maxf(k, 0.01)
	var v := player.get_flat_velocity()
	# Girando parado: dá passinhos (a velocidade de giro alimenta a passada),
	# em vez de rodar com os pés deslizando.
	var ang := absf(_prev_facing.signed_angle_to(player.facing, Vector3.UP)) / maxf(delta, 0.001)
	_prev_facing = player.facing
	_turn_rate = lerpf(_turn_rate, ang, 1.0 - exp(-10.0 * delta))
	var raw := maxf(v.length(), minf(_turn_rate * 0.3, 1.0)) / k
	# Passada suave: a velocidade que alimenta a animação muda devagar (sem
	# pé "teleportando" quando o corpo freia/acelera um pouco).
	_stride = lerpf(_stride, raw, 1.0 - exp(-7.0 * delta))
	# Devagar NÃO mistura "parado" com "andando" (isso dava passo arrastado,
	# "tentando andar"): usa a caminhada inteira, mais lenta (TimeScale).
	var walk := WALK_STRIDE
	var pos := _stride
	var time_scale := 1.0
	if _stride < 0.22:
		pos = 0.0
	elif _stride < walk:
		pos = walk
		time_scale = clampf(_stride / walk, 0.45, 1.0)
	elif _stride > AnimationCatalog.TOP_SPEED:
		time_scale = _stride / AnimationCatalog.TOP_SPEED
	# troca parado ↔ andando com mistura de ~0,2 s
	_blend_pos = move_toward(_blend_pos, pos, delta * 8.0)
	_time_scale = lerpf(_time_scale, time_scale, 1.0 - exp(-8.0 * delta))
	var ball_target := 1.0 if player.ball_control.has_ball() else 0.0
	_ball_blend = move_toward(_ball_blend, ball_target, delta * 3.0)
	anim_tree.set("parameters/Locomotion/Speed/blend_position", Vector2(_blend_pos, _ball_blend))
	anim_tree.set("parameters/Locomotion/Scale/scale", _time_scale)
	# Marcação: velocidade no referencial do corpo (x = direita, y = frente).
	var right := player.facing.cross(Vector3.UP)
	anim_tree.set("parameters/Mark/Dir/blend_position", Vector2(v.dot(right), v.dot(player.facing)) / k)

	var current := playback.get_current_node()
	_time_since_contact += delta

	if player.current_reaction() != &"":
		_prev_speed = v.length()
		return # comemoração/lamento: fica até a próxima saída de bola

	var wanted := _wanted_base()
	# Ação já terminou na lógica e o jogador está correndo: volta para a
	# corrida na hora (nada de deslizar com o pé esticado de um clipe parado).
	if not (current in BASE_STATES) and current != &"Burst" and current != _gesture_state \
			and not (_action_kind in DOWN_ACTIONS) and not (current in [&"Fallen", &"GetUpFront", &"GetUpBack", &"Trip", &"Tackle"]) \
			and player.state == Player.State.MOVE and v.length() > 1.2 \
			and not (current in [&"Celebrate", &"CelebrateIdle", &"Samba", &"Defeated"]):
		playback.travel(wanted)
		_action_state = &""
		_action_kind = &""
		_prev_speed = v.length()
		return
	# Gestos de espera (parado): reclamar, aquecer, conversar, embaixadinha.
	if player.gesture != &"" and current in BASE_STATES and v.length() < 0.3 \
			and GESTURE_STATES.has(player.gesture) and _has_state(GESTURE_STATES[player.gesture]):
		var gs: StringName = GESTURE_STATES[player.gesture]
		var clip_len := AnimationCatalog.clip_length(GESTURE_CLIPS[player.gesture])
		anim_tree.set("parameters/%s/Seek/seek_request" % gs, _rng.randf_range(0.0, maxf(clip_len - 3.0, 0.0)))
		anim_tree.set("parameters/%s/Scale/scale" % gs, _rng.randf_range(0.9, 1.1))
		_gesture_state = gs
		playback.travel(gs)
		_prev_speed = v.length()
		return
	if current == _gesture_state and _gesture_state != &"":
		if player.gesture == &"" or v.length() > 0.3:
			_gesture_state = &""
			playback.travel(wanted)
		_prev_speed = v.length()
		return
	if current in BASE_STATES:
		_action_state = &""
		_action_kind = &""
		_getting_up = false
		if current != wanted and _has_state(wanted):
			playback.travel(wanted)
		# Arrancada: parado → correndo forte.
		elif current == &"Locomotion" and _prev_speed < 0.6 and player.intent.sprint \
				and player.intent.move.length() > 0.7 and _has_state(&"Burst") \
				and not player.ball_control.has_ball():
			playback.travel(&"Burst")
	elif _action_kind in DOWN_ACTIONS:
		_update_down()
	elif current == &"Burst":
		# Arrancada: sai no fim do clipe (antes congelava no último quadro e o
		# jogador "desfilava" deslizando nessa pose), ao parar ou com a bola.
		if player.state != Player.State.MOVE or player.intent.move.length() < 0.3 \
				or player.ball_control.has_ball() \
				or playback.get_current_play_position() >= playback.get_current_length() - 0.3:
			playback.travel(wanted)
	elif current in [&"Fallen", &"GetUpFront", &"GetUpBack"]:
		if player.state == Player.State.MOVE:
			playback.travel(wanted)
	elif current == &"Receive" and (player.get_horizontal_speed() > 0.6 or _time_since_contact > 0.6):
		# Domínio: sola na bola só parado; voltou a andar → sai na hora
		# (antes ficava com o pé levantado deslizando).
		playback.travel(wanted)
		_action_state = &""
	elif current in AERIAL_STATES and player.state == Player.State.MOVE and _time_since_contact > 0.35:
		playback.travel(wanted)
		_action_state = &""
	elif current == _action_state and player.state == Player.State.MOVE \
			and _time_since_contact > RELEASE_AFTER_CONTACT and player.get_horizontal_speed() > RELEASE_SPEED:
		playback.travel(wanted)
		_action_state = &""
	elif current in [&"Celebrate", &"CelebrateIdle", &"Samba", &"Defeated"]:
		playback.travel(wanted)
	elif current in AUTO_RETURN and player.state != Player.State.ACTION \
			and playback.get_current_play_position() >= playback.get_current_length() - 0.2:
		# Fim do clipe: volta para a locomoção (mistura de 0,22 s).
		playback.travel(wanted)
		_action_state = &""
	_prev_speed = v.length()


func _wanted_base() -> StringName:
	if player.is_marking() and _has_state(&"Mark"):
		return &"Mark"
	return &"Locomotion"


## Carrinho / tropeço: no chão até faltar o tempo de levantar. O tropeço
## termina de bruços (levanta com "Standing Up"); o carrinho, de costas ("Stand Up").
func _update_down() -> void:
	if player.state != Player.State.ACTION:
		if not _getting_up:
			playback.travel(_wanted_base())
		_action_kind = &""
		return
	var logical: StringName = &"getup" if _action_kind == &"trip" else &"getup_b"
	var state_name: StringName = &"GetUpFront" if _action_kind == &"trip" else &"GetUpBack"
	var getup_len := AnimationCatalog.getup_duration(logical)
	var remaining := player.action_time_left()
	if not _getting_up and remaining <= maxf(getup_len, 0.35):
		_getting_up = true
		if getup_len > 0.0 and _has_state(state_name):
			var seg: Array = AnimationCatalog.GETUP_SEGMENTS[logical]
			anim_tree.set("parameters/%s/Seek/seek_request" % state_name, seg[0])
			anim_tree.set("parameters/%s/Scale/scale" % state_name, AnimationCatalog.GETUP_SPEED)
			_action_state = state_name
			_play(state_name)
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
	var mirrored := player.kick_mirrored() and kind in [&"pass", &"long_pass", &"shoot", &"shoot_power", &"chip"] \
		and _has_state(StringName(String(state_name) + "L"))
	if mirrored:
		state_name = StringName(String(state_name) + "L")
	if not _has_state(state_name):
		return
	_action_kind = kind
	_getting_up = false
	if ACTION_LOGICAL.has(kind):
		var logical: StringName = ACTION_LOGICAL[kind]
		if mirrored:
			logical = AnimationCatalog.mirrored_name(logical)
		var seek := 0.0
		if AnimationCatalog.has_contact(logical):
			seek = maxf(AnimationCatalog.contact_time(logical) - player.time_to_contact() * ACTION_SPEED, 0.0)
		_play_action(state_name, seek, KIND_SPEED.get(kind, ACTION_SPEED))
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
	# Domínio: o pé pisa na bola — só quase parado (correndo, a passada segue).
	if kind != &"receive" or not _has_state(&"Receive"):
		return
	if playback.get_current_node() in BASE_STATES and player.get_horizontal_speed() < 1.0:
		_action_kind = kind
		_play_action(&"Receive", maxf(AnimationCatalog.contact_time(&"receive") - 0.08, 0.0))
		_time_since_contact = -0.08


func _play_action(state_name: StringName, seek: float, speed := ACTION_SPEED) -> void:
	anim_tree.set("parameters/%s/Seek/seek_request" % state_name, seek)
	anim_tree.set("parameters/%s/Scale/scale" % state_name, speed)
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
