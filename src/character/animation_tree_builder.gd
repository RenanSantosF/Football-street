class_name AnimationTreeBuilder
extends RefCounted
## Monta por código o AnimationTree do jogador (evita montar nós à mão no
## editor do celular). Estrutura:
##
##   StateMachine (raiz)
##   ├── Locomotion      BlendTree: BlendSpace1D "Speed" → TimeScale "Scale"
##   ├── LocomotionBall  idem (Etapa 3 troca pelos clipes de condução)
##   ├── Stumble         desequilíbrio (volta sozinho para Locomotion)
##   └── Fall            queda
##
## O BlendSpace1D usa a velocidade natural de cada clipe como posição, então
## a passada casa com o deslocamento. O TimeScale cobre o que passar do clipe
## mais rápido e a diferença de tamanho entre personagens.
## Novos estados da Etapa 3 (passe, chute, domínio...) entram aqui, com os
## nomes que o PlayerAnimationController já espera.

const XFADE_LOCOMOTION := 0.2
const XFADE_ACTION := 0.12


static func build(tree: AnimationTree) -> void:
	for prefix: StringName in AnimationCatalog.get_libraries():
		if not tree.has_animation_library(prefix):
			tree.add_animation_library(prefix, AnimationCatalog.get_libraries()[prefix])

	var sm := AnimationNodeStateMachine.new()
	sm.add_node(&"Locomotion", _locomotion(), Vector2(300, 100))
	sm.add_node(&"LocomotionBall", _locomotion(), Vector2(300, 250))
	_add_transition(sm, &"Start", &"Locomotion", 0.0, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
	_add_transition(sm, &"Locomotion", &"LocomotionBall", XFADE_LOCOMOTION)
	_add_transition(sm, &"LocomotionBall", &"Locomotion", XFADE_LOCOMOTION)

	_add_one_shot(sm, &"Stumble", &"stumble", Vector2(600, 100))
	_add_one_shot(sm, &"Fall", &"fall", Vector2(600, 250), false)

	tree.tree_root = sm


static func _locomotion() -> AnimationNodeBlendTree:
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 8.0
	bs.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	for logical: StringName in AnimationCatalog.LOCOMOTION_SPEEDS:
		if not AnimationCatalog.has_clip(logical):
			continue
		var anim := AnimationNodeAnimation.new()
		anim.animation = AnimationCatalog.clip(logical)
		bs.add_blend_point(anim, AnimationCatalog.LOCOMOTION_SPEEDS[logical])
	var bt := AnimationNodeBlendTree.new()
	bt.add_node(&"Speed", bs, Vector2(0, 0))
	bt.add_node(&"Scale", AnimationNodeTimeScale.new(), Vector2(250, 0))
	bt.connect_node(&"Scale", 0, &"Speed")
	bt.connect_node(&"output", 0, &"Scale")
	return bt


static func _add_one_shot(sm: AnimationNodeStateMachine, state: StringName, logical: StringName,
		pos: Vector2, auto_return := true) -> void:
	if not AnimationCatalog.has_clip(logical):
		return
	var anim := AnimationNodeAnimation.new()
	anim.animation = AnimationCatalog.clip(logical)
	sm.add_node(state, anim, pos)
	for from in [&"Locomotion", &"LocomotionBall"]:
		_add_transition(sm, from, state, XFADE_ACTION)
	if auto_return:
		var back := _add_transition(sm, state, &"Locomotion", 0.25, AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO)
		back.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	else:
		_add_transition(sm, state, &"Locomotion", 0.4)


static func _add_transition(sm: AnimationNodeStateMachine, from: StringName, to: StringName, xfade: float,
		advance := AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	t.advance_mode = advance
	sm.add_transition(from, to, t)
	return t
