class_name AnimationTreeBuilder
extends RefCounted
## Monta por código o AnimationTree do jogador (sem montar nós à mão no
## editor do celular). Estrutura (StateMachine na raiz):
##
##   Estados-base (escolhidos continuamente pelo PlayerAnimationController):
##     Locomotion      BlendSpace2D: velocidade × com bola (parado/andar/trote ou
##                     condução/corrida/sprint)
##     Mark            BlendSpace2D pela velocidade local: postura de marcação,
##                     andar/correr de lado, de costas e nas diagonais
##   Ações (BlendTree: Clip → TimeSeek "Seek" → TimeScale "Scale"):
##     PassShort PassLong Shoot ShootPower Receive Spin Tackle GKPass GKCatch
##   Reações: Burst (arrancada), Stumble, Trip → Fallen, Jump,
##            Celebrate → CelebrateIdle, Samba, Defeated
##
## Posições dos BlendSpaces = velocidades naturais das passadas (m/s,
## AnimationCatalog), então a passada casa com o deslocamento real.

const XFADE_LOCOMOTION := 0.2
const XFADE_ACTION := 0.12
const XFADE_ACTION_OUT := 0.22

const BASE_STATES: Array[StringName] = [&"Locomotion", &"Mark"]

## estado -> nome lógico (ações com contato na bola, com Seek/Scale)
const ACTION_CLIPS := {
	&"PassShort": &"pass_short",
	&"PassLong": &"pass_long",
	&"Shoot": &"shoot",
	&"ShootPower": &"shoot_power",
	&"Receive": &"receive",
	&"Spin": &"spin",
	&"Tackle": &"tackle",
	&"GKPass": &"gk_pass",
	&"GKCatch": &"gk_catch",
	&"Jump": &"jump",
	&"Trip": &"trip",
	&"Turn180": &"turn180",
	&"TurnLeft": &"turn_l",
	&"TurnRight": &"turn_r",
	&"RunStop": &"run_stop",
	&"PassShortL": &"pass_short_m",
	&"PassLongL": &"pass_long_m",
	&"ShootL": &"shoot_m",
	&"ShootPowerL": &"shoot_power_m",
	&"RecvChest": &"recv_chest",
	&"RecvKnee": &"recv_knee",
	&"Header": &"header",
	&"HeadControl": &"head_control",
	&"HeaderJump": &"header_jump",
}
## estado -> [nome lógico, volta sozinho para a locomoção no fim?]
const REACTION_CLIPS := {
	&"Burst": [&"idle_to_sprint", true],
	&"Stumble": [&"stumble", true],
	&"Fallen": [&"fallen", false],
	&"Celebrate": [&"victory", false],
	&"CelebrateIdle": [&"victory_idle", false],
	&"Samba": [&"samba", false],
	&"Defeated": [&"defeated", false],
	&"Argue": [&"argue", false],
	&"Warmup": [&"warmup", false],
	&"Talk": [&"talk", false],
	&"KickUp": [&"kick_up", false],
	&"GetUpFront": [&"getup", true],
	&"GetUpBack": [&"getup_b", true],
}


static func build(tree: AnimationTree) -> void:
	for prefix: StringName in AnimationCatalog.get_libraries():
		if not tree.has_animation_library(prefix):
			tree.add_animation_library(prefix, AnimationCatalog.get_libraries()[prefix])

	var sm := AnimationNodeStateMachine.new()
	# Com e sem bola no MESMO BlendSpace2D (x = velocidade, y = com bola 0..1),
	# sincronizado: ganhar/perder a bola mistura as passadas sem trocar de
	# estado (antes a pose "pulava" a cada passe/domínio).
	sm.add_node(&"Locomotion", _blend_locomotion(), Vector2(300, 100))
	sm.add_node(&"Mark", _blend_2d(AnimationCatalog.MARK_POINTS), Vector2(300, 400))
	_add_transition(sm, &"Start", &"Locomotion", 0.0, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	for a in BASE_STATES:
		for b in BASE_STATES:
			if a != b:
				_add_transition(sm, a, b, XFADE_LOCOMOTION)

	var y := 100.0
	for state: StringName in ACTION_CLIPS:
		if _add_clip_state(sm, state, ACTION_CLIPS[state], Vector2(650, y), true):
			# Tropeço e carrinho terminam no chão (seguem para Fallen); o resto volta sozinho.
			_connect_from_bases(sm, state, not (state in [&"Trip", &"Tackle"]))
		y += 110.0
	y = 100.0
	for state: StringName in REACTION_CLIPS:
		var spec: Array = REACTION_CLIPS[state]
		if _add_clip_state(sm, state, spec[0], Vector2(950, y), false):
			_connect_from_bases(sm, state, spec[1])
		y += 110.0

	# Encadeamentos naturais.
	for down in [&"Trip", &"Tackle"]:
		if sm.has_node(down) and sm.has_node(&"Fallen"):
			var t := _add_transition(sm, down, &"Fallen", 0.3, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
			t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	for gu in [&"GetUpFront", &"GetUpBack"]:
		if sm.has_node(gu):
			for from in [&"Fallen", &"Tackle", &"Trip"]:
				if sm.has_node(from):
					_add_transition(sm, from, gu, 0.35)
	if sm.has_node(&"Celebrate") and sm.has_node(&"CelebrateIdle"):
		var c := _add_transition(sm, &"Celebrate", &"CelebrateIdle", 0.3, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
		c.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	# Ações podem emendar umas nas outras (domínio → passe, etc.).
	for a: StringName in ACTION_CLIPS:
		for b: StringName in ACTION_CLIPS:
			if a != b and sm.has_node(a) and sm.has_node(b):
				_add_transition(sm, a, b, XFADE_ACTION)

	tree.tree_root = sm


static func _blend_locomotion() -> AnimationNodeBlendTree:
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(0.0, 0.0)
	bs.max_space = Vector2(8.0, 1.0)
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	bs.sync = true
	for row in [[AnimationCatalog.LOCOMOTION_POINTS, 0.0], [AnimationCatalog.LOCOMOTION_BALL_POINTS, 1.0]]:
		for p in row[0]:
			if AnimationCatalog.has_clip(p[0]):
				var anim := AnimationNodeAnimation.new()
				anim.animation = AnimationCatalog.clip(p[0])
				bs.add_blend_point(anim, Vector2(p[1], row[1]))
	return _with_scale(bs, &"Speed")


static func _blend_1d(points: Array) -> AnimationNodeBlendTree:
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 8.0
	bs.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	for p in points:
		if AnimationCatalog.has_clip(p[0]):
			var anim := AnimationNodeAnimation.new()
			anim.animation = AnimationCatalog.clip(p[0])
			bs.add_blend_point(anim, p[1])
	return _with_scale(bs, &"Speed")


static func _blend_2d(points: Array) -> AnimationNodeBlendTree:
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-6.0, -6.0)
	bs.max_space = Vector2(6.0, 6.0)
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	for p in points:
		if AnimationCatalog.has_clip(p[0]):
			var anim := AnimationNodeAnimation.new()
			anim.animation = AnimationCatalog.clip(p[0])
			bs.add_blend_point(anim, p[1])
	return _with_scale(bs, &"Dir")


static func _with_scale(node: AnimationRootNode, node_name: StringName) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node(node_name, node, Vector2(0, 0))
	bt.add_node(&"Scale", AnimationNodeTimeScale.new(), Vector2(250, 0))
	bt.connect_node(&"Scale", 0, node_name)
	bt.connect_node(&"output", 0, &"Scale")
	return bt


## Estado de um clipe só, com TimeSeek (pular para um ponto) e TimeScale.
static func _add_clip_state(sm: AnimationNodeStateMachine, state: StringName, logical: StringName,
		pos: Vector2, _with_seek: bool) -> bool:
	if not AnimationCatalog.has_clip(logical):
		return false
	var anim := AnimationNodeAnimation.new()
	anim.animation = AnimationCatalog.clip(logical)
	var bt := AnimationNodeBlendTree.new()
	bt.add_node(&"Clip", anim, Vector2(0, 0))
	bt.add_node(&"Seek", AnimationNodeTimeSeek.new(), Vector2(200, 0))
	bt.add_node(&"Scale", AnimationNodeTimeScale.new(), Vector2(400, 0))
	bt.connect_node(&"Seek", 0, &"Clip")
	bt.connect_node(&"Scale", 0, &"Seek")
	bt.connect_node(&"output", 0, &"Scale")
	sm.add_node(state, bt, pos)
	return true


## A volta para a locomoção é sempre por travel() (o PlayerAnimationController
## volta no fim do clipe ou antes, se o jogador sair andando).
static func _connect_from_bases(sm: AnimationNodeStateMachine, state: StringName, _auto_return: bool) -> void:
	for b in BASE_STATES:
		_add_transition(sm, b, state, XFADE_ACTION)
		_add_transition(sm, state, b, XFADE_ACTION_OUT)


static func _add_transition(sm: AnimationNodeStateMachine, from: StringName, to: StringName, xfade: float,
		advance := AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	t.advance_mode = advance
	if not sm.has_transition(from, to):
		sm.add_transition(from, to, t)
	return t
