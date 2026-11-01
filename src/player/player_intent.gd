class_name PlayerIntent
extends RefCounted
## Intenção de controle de um jogador no frame atual.
##
## É produzida pelo HumanInput (toque/teclado/controle) OU pelo AIController
## e consumida pelo Player. Humano e IA usam exatamente a mesma interface,
## então os dois obedecem às mesmas regras de movimento, física e animação.

enum Action { NONE, PASS, SHOOT, DRIBBLE }

## Direção desejada no mundo (plano XZ). Comprimento 0..1 = intensidade.
var move := Vector3.ZERO
var sprint := false
var action: Action = Action.NONE
## Força da ação, 0..1 (tempo segurando o botão).
var power := 0.0
## Direção de mira opcional (ZERO = usar a direção do corpo).
var aim := Vector3.ZERO
## Alvo opcional (ex.: companheiro escolhido pela IA para o passe).
var target: Node3D = null
## Chute mirado pelo jogador humano: a bola vai EXATAMENTE para [member aim]
## (sem mira automática no gol).
var precise := false


func set_action(a: Action, p := 0.0, aim_dir := Vector3.ZERO, tgt: Node3D = null) -> void:
	action = a
	power = clampf(p, 0.0, 1.0)
	aim = aim_dir
	target = tgt
	precise = false


func clear_action() -> void:
	action = Action.NONE
	power = 0.0
	aim = Vector3.ZERO
	target = null
	precise = false
