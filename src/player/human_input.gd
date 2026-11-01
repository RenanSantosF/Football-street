class_name HumanInput
extends Node
## Lê toque/teclado/controle e transforma em PlayerIntent para o jogador
## controlado. Botões de passe e chute carregam força enquanto pressionados.
##
## Passe: toque rápido = passe curto rasteiro; segurar = passe longo/alto.
## Chute: segurar = mais força. Sem a bola, o botão de chute faz o desarme.

signal switch_requested
## Carga atual do botão (0..1) para a barra de força. kind = &"" quando solto.
signal charge_changed(value: float, kind: StringName)
## Mira do chute: ativa enquanto o botão de chute está segurado.
signal aim_changed(active: bool, direction: Vector3, power: float)

const MAX_CHARGE_TIME := 0.9

@export var camera: Camera3D

var current_player: Player = null

var _move := Vector3.ZERO
var _sprint := false
var _pass_hold := -1.0
var _shoot_hold := -1.0
var _queued: PlayerIntent.Action = PlayerIntent.Action.NONE
var _queued_power := 0.0
var _last_charge := -1.0
var _aim := Vector3.ZERO
var _aiming := false


func _ready() -> void:
	process_priority = -10 # roda antes dos jogadores


func _physics_process(delta: float) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_move = _to_world(v)
	_sprint = Input.is_action_pressed("sprint")
	# Segurando CHUTE com a bola (ou perto dela): o analógico vira a MIRA e o
	# jogador para; a direção escolhida é exatamente para onde a bola vai.
	var was_aiming := _aiming
	_aiming = _shoot_hold >= 0.0 and current_player != null and _near_ball()
	if _aiming:
		if not was_aiming:
			_aim = current_player.facing
		if _move.length() > 0.25:
			_aim = _move.normalized()
		_move = Vector3.ZERO
		aim_changed.emit(true, _aim, clampf(_shoot_hold / MAX_CHARGE_TIME, 0.0, 1.0))
	elif was_aiming:
		aim_changed.emit(false, _aim, 0.0)

	if Input.is_action_just_pressed("switch_player"):
		switch_requested.emit()
	if Input.is_action_just_pressed("dribble"):
		_queue(PlayerIntent.Action.DRIBBLE, 1.0)

	# Sem a bola e com adversário conduzindo perto: chute vira desarme imediato.
	if Input.is_action_just_pressed("shoot") and _wants_tackle():
		_queue(PlayerIntent.Action.SHOOT, 0.0)
	else:
		_shoot_hold = _update_charge("shoot", _shoot_hold, delta, PlayerIntent.Action.SHOOT)
	_pass_hold = _update_charge("pass", _pass_hold, delta, PlayerIntent.Action.PASS)

	var charge := -1.0
	var kind: StringName = &""
	if _shoot_hold >= 0.0:
		charge = _shoot_hold / MAX_CHARGE_TIME
		kind = &"shoot"
	elif _pass_hold >= 0.0:
		charge = _pass_hold / MAX_CHARGE_TIME
		kind = &"pass"
	if charge != _last_charge:
		_last_charge = charge
		charge_changed.emit(clampf(charge, 0.0, 1.0), kind)


func fill_intent(_player: Player, intent: PlayerIntent, _delta: float) -> void:
	intent.move = _move
	intent.sprint = _sprint
	if _queued != PlayerIntent.Action.NONE:
		if _queued == PlayerIntent.Action.SHOOT and _aim != Vector3.ZERO and _queued_power > 0.0:
			intent.set_action(_queued, _queued_power, _aim)
			intent.precise = true
		else:
			intent.set_action(_queued, _queued_power, _move if _move.length() > 0.2 else Vector3.ZERO)
		_queued = PlayerIntent.Action.NONE
		_aim = Vector3.ZERO


func _update_charge(action: StringName, hold: float, delta: float, kind: PlayerIntent.Action) -> float:
	if Input.is_action_just_pressed(action):
		hold = 0.0
	elif hold >= 0.0 and Input.is_action_pressed(action):
		hold += delta
		if hold >= MAX_CHARGE_TIME:
			_queue(kind, 1.0)
			return -1.0
	if hold >= 0.0 and not Input.is_action_pressed(action):
		_queue(kind, clampf(hold / MAX_CHARGE_TIME, 0.0, 1.0))
		return -1.0
	return hold


func _queue(a: PlayerIntent.Action, power: float) -> void:
	_queued = a
	_queued_power = power


func _near_ball() -> bool:
	return current_player.ball != null and current_player.ball_control.ball_distance() < 2.0


func _wants_tackle() -> bool:
	if current_player == null or current_player.ball == null:
		return false
	return not current_player.ball_control.has_ball() and current_player.ball_control.find_tackle_target() != null


## Converte o analógico (tela) em direção no mundo, relativa à câmera.
func _to_world(v: Vector2) -> Vector3:
	if v.length() < 0.01:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera != null:
		right = camera.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		forward = Vector3.UP.cross(right).normalized()
	var w := right * v.x + forward * (-v.y)
	return w.limit_length(1.0)
