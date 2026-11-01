class_name Player
extends CharacterBody3D
## Jogador (humano ou IA). Cuida de movimento, rotação do corpo, estados e
## ações. A interação com a bola fica no componente BallControl e a escolha do
## que fazer vem de um "controller" (HumanInput ou AIController) que preenche
## um PlayerIntent a cada frame.

enum Role { FIELD, GOALKEEPER }
enum State { MOVE, ACTION, STUNNED, FROZEN }

## Uma ação começou (para animação/áudio): &"pass", &"long_pass", &"shoot",
## &"shoot_power", &"dribble", &"tackle", &"stumble".
signal action_started(kind: StringName)
## O jogador tocou na bola: &"receive", &"dribble_touch", &"trap", &"pass"...
signal ball_touched(kind: StringName)

const BUFFER_TIME := 0.3
## Com a posse, espera mais: o jogador ainda está alcançando a bola que rolou à frente.
const BUFFER_TIME_WITH_BALL := 0.9
const LONG_PASS_POWER := 0.55
## Quanto a preparação do chute pode esperar a bola chegar ao pé.
const MAX_CONTACT_WAIT := 0.3

@export var team: int = Team.SHIRTS
@export var role: Role = Role.FIELD
@export var appearance: CharacterAppearance
@export var shirt_number := 0

@export_group("Movimento")
@export var jog_speed := 4.6
@export var sprint_speed := 6.6
@export var ball_speed_factor := 0.92
@export var acceleration := 11.0
@export var deceleration := 15.0
## Velocidade de giro do corpo (rad/s).
@export var turn_speed := 11.0
@export var turn_speed_with_ball := 7.5

var intent := PlayerIntent.new()
var controller: Node = null
var match_manager: MatchManager = null
var ball: Ball = null
var state: State = State.MOVE
var facing := Vector3.FORWARD
var stamina := 1.0
var is_human := false
var formation_index := 0

var _action_kind: StringName = &""
var _action_time := 0.0
var _action_contact := 0.0
var _action_length := 0.0
var _action_contact_done := false
var _action_power := 0.0
var _action_aim := Vector3.ZERO
var _action_target: Node3D = null
var _action_move_factor := 0.4
var _action_face := Vector3.ZERO
var _stun_timer := 0.0
var _burst_timer := 0.0
var _buffer_action: PlayerIntent.Action = PlayerIntent.Action.NONE
var _buffer_power := 0.0
var _buffer_aim := Vector3.ZERO
var _buffer_target: Node3D = null
var _buffer_timer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var ball_control: BallControl = $BallControl
@onready var ai: AIController = $AIController
@onready var anim_controller: PlayerAnimationController = $PlayerAnimationController
@onready var visual: Node3D = $Visual
@onready var selection_ring: MeshInstance3D = $SelectionRing


func setup(mm: MatchManager, b: Ball) -> void:
	match_manager = mm
	ball = b
	ball_control.setup(self, b)
	if appearance == null:
		appearance = CharacterAppearance.new()
	if visual.has_method("apply_appearance"):
		visual.call("apply_appearance", appearance, team, role)
	visual.scale = Vector3.ONE * appearance.height_scale
	anim_controller.setup(self)
	set_human(false, null)


## Liga/desliga o controle humano. Sem humano, a própria IA assume.
func set_human(value: bool, human_input: Node) -> void:
	is_human = value and human_input != null
	controller = human_input if is_human else ai
	selection_ring.visible = is_human


func _physics_process(delta: float) -> void:
	if ball == null:
		return
	intent.clear_action()
	if controller != null:
		controller.fill_intent(self, intent, delta)
	_burst_timer = maxf(_burst_timer - delta, 0.0)

	match state:
		State.MOVE:
			_update_move(delta)
			_update_actions(delta)
		State.ACTION:
			_update_action(delta)
		State.STUNNED:
			_stun_timer -= delta
			_brake(delta, deceleration * 0.6)
			if _stun_timer <= 0.0:
				state = State.MOVE
		State.FROZEN:
			_brake(delta, deceleration)

	ball_control.physics_update(delta)
	velocity.y -= _gravity * delta
	move_and_slide()
	_update_facing(delta)
	_update_stamina(delta)
	anim_controller.physics_update(delta)


# --- Movimento ---------------------------------------------------------------

func _update_move(delta: float) -> void:
	var input := Vector3(intent.move.x, 0.0, intent.move.z)
	if input.length() > 1.0:
		input = input.normalized()
	var has_ball := ball_control.has_ball()
	var max_speed := sprint_speed if (intent.sprint and stamina > 0.05) else jog_speed
	if has_ball:
		max_speed *= ball_speed_factor
	if _burst_timer > 0.0:
		max_speed *= 1.15
	var desired := input * max_speed
	if has_ball and _has_pending_kick() and not ball_control.can_kick():
		# Chute/passe pedido com a bola um pouco à frente: ir até ela para finalizar.
		var to_ball := ball_control.ball_offset()
		desired = to_ball.normalized() * sprint_speed if to_ball.length() > 0.05 else desired
	elif has_ball and input.length() > 0.1:
		desired += ball_control.catch_up_velocity(input.normalized())
	var hv := get_flat_velocity()
	# Acelera mais devagar do que freia; inverter direção passa por uma freada.
	var speeding_up := desired.length() > hv.length() and hv.dot(desired) >= 0.0
	var rate := acceleration if speeding_up else deceleration
	hv = hv.move_toward(desired, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z


func _brake(delta: float, rate: float) -> void:
	var hv := get_flat_velocity().move_toward(Vector3.ZERO, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z


func _update_facing(delta: float) -> void:
	var hv := get_flat_velocity()
	var target_dir := facing
	if state == State.ACTION and _action_face != Vector3.ZERO:
		target_dir = _action_face
	elif hv.length() > 0.4:
		target_dir = hv.normalized()
	elif intent.move.length() > 0.2:
		target_dir = Vector3(intent.move.x, 0.0, intent.move.z).normalized()
	elif ball != null:
		var to_ball := ball.global_position - global_position
		to_ball.y = 0.0
		if to_ball.length() > 0.3:
			target_dir = to_ball.normalized()
	var rate := turn_speed_with_ball if ball_control.has_ball() else turn_speed
	if state == State.ACTION:
		rate *= 1.6
	rate *= lerpf(1.0, 0.55, clampf(hv.length() / sprint_speed, 0.0, 1.0))
	facing = _rotate_flat(facing, target_dir, rate * delta)
	rotation.y = atan2(-facing.x, -facing.z)


static func _rotate_flat(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	if to.length_squared() < 0.0001:
		return from
	var ang := from.signed_angle_to(to, Vector3.UP)
	return from.rotated(Vector3.UP, clampf(ang, -max_angle, max_angle)).normalized()


func _update_stamina(delta: float) -> void:
	var speed := get_horizontal_speed()
	if state == State.MOVE and intent.sprint and speed > jog_speed * 0.9:
		stamina -= 0.1 * delta
	else:
		stamina += (0.14 if speed < 1.0 else 0.06) * delta
	stamina = clampf(stamina, 0.0, 1.0)


# --- Ações ---------------------------------------------------------------------

func _update_actions(delta: float) -> void:
	if intent.action != PlayerIntent.Action.NONE:
		_buffer_action = intent.action
		_buffer_power = intent.power
		_buffer_aim = intent.aim
		_buffer_target = intent.target
		_buffer_timer = BUFFER_TIME_WITH_BALL if ball_control.has_ball() else BUFFER_TIME
	if _buffer_timer <= 0.0:
		return
	_buffer_timer -= delta

	var done := false
	match _buffer_action:
		PlayerIntent.Action.PASS, PlayerIntent.Action.SHOOT:
			if ball_control.can_kick() or ball_control.can_start_kick_on_run():
				_start_kick(_buffer_action, _buffer_power, _buffer_aim, _buffer_target)
				done = true
			elif _buffer_action == PlayerIntent.Action.SHOOT and ball_control.find_tackle_target() != null:
				_begin_action(&"tackle", 0.15, 0.45, 0.0, _buffer_aim, null, 0.8)
				var t := ball_control.find_tackle_target()
				_action_face = _flat_dir_to(t.global_position)
				done = true
		PlayerIntent.Action.DRIBBLE:
			if ball_control.has_ball() and ball_control.can_kick():
				var aim := _buffer_aim if _buffer_aim.length() > 0.2 else facing
				_begin_action(&"dribble", 0.06, 0.32, 1.0, aim, null, 1.0)
				_action_face = Vector3(aim.x, 0.0, aim.z).normalized()
			done = true
	if done:
		_buffer_timer = 0.0
		_buffer_action = PlayerIntent.Action.NONE


func _is_kick_action() -> bool:
	return _action_kind in [&"pass", &"long_pass", &"shoot", &"shoot_power"]


func _has_pending_kick() -> bool:
	return _buffer_timer > 0.0 and (_buffer_action == PlayerIntent.Action.PASS \
		or _buffer_action == PlayerIntent.Action.SHOOT)


func _start_kick(a: PlayerIntent.Action, power: float, aim: Vector3, target: Node3D) -> void:
	if a == PlayerIntent.Action.SHOOT:
		var kind: StringName = &"shoot_power" if power > 0.7 else &"shoot"
		var contact := 0.16 + 0.12 * power
		_begin_action(kind, contact, contact + 0.3, power, aim, null, 0.35)
		var goal := Field.goal_center(Team.other(team))
		_action_face = _flat_dir_to(goal) if aim.length() < 0.2 else Vector3(aim.x, 0.0, aim.z).normalized()
	else:
		var long := power >= LONG_PASS_POWER
		var contact := 0.2 if long else 0.13
		_begin_action(&"long_pass" if long else &"pass", contact, contact + 0.22, power, aim, target, 0.5)
		if target != null:
			_action_face = _flat_dir_to(target.global_position)
		elif aim.length() > 0.2:
			_action_face = Vector3(aim.x, 0.0, aim.z).normalized()
		else:
			_action_face = facing


func _begin_action(kind: StringName, contact: float, length: float, power: float,
		aim: Vector3, target: Node3D, move_factor: float) -> void:
	state = State.ACTION
	_action_kind = kind
	_action_time = 0.0
	_action_contact = contact
	_action_length = length
	_action_contact_done = false
	_action_power = power
	_action_aim = aim
	_action_target = target
	_action_move_factor = move_factor
	_action_face = Vector3.ZERO
	action_started.emit(kind)


func _update_action(delta: float) -> void:
	_action_time += delta
	var hv := get_flat_velocity()
	if _action_kind == &"dribble":
		var dir := Vector3(_action_aim.x, 0.0, _action_aim.z).normalized()
		hv = hv.move_toward(dir * sprint_speed * 0.95, acceleration * 1.5 * delta)
	elif not _action_contact_done and _is_kick_action():
		# Preparação do chute/passe: acompanhar a bola até o pé de apoio,
		# para que no contato ela esteja ao alcance (sem "furar").
		var remaining := maxf(_action_contact - _action_time, 0.05)
		var plant := ball_control.ball_offset() + ball.flat_velocity() * remaining
		plant -= plant.normalized() * BallControl.FOOT_DISTANCE if plant.length() > BallControl.FOOT_DISTANCE else plant
		hv = hv.move_toward((plant / remaining).limit_length(sprint_speed * 1.15), acceleration * 2.0 * delta)
	else:
		var cap := jog_speed * _action_move_factor
		var target := hv.limit_length(cap)
		hv = hv.move_toward(target, deceleration * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if not _action_contact_done and _action_time >= _action_contact:
		if _is_kick_action() and not ball_control.can_kick() and ball_control.has_ball() \
				and _action_time < _action_contact + MAX_CONTACT_WAIT:
			# Bola ainda um pouco longe: estende a preparação em vez de furar.
			_action_length += delta
		else:
			_do_contact()
	if state == State.ACTION and _action_time >= _action_length:
		state = State.MOVE


## Momento em que o pé encosta na bola. Na Etapa 3 a animação chama
## on_animation_contact() exatamente no quadro do contato.
func _do_contact() -> void:
	_action_contact_done = true
	match _action_kind:
		&"pass", &"long_pass":
			ball_control.execute_pass(_action_power, _action_aim, _action_target)
		&"shoot", &"shoot_power":
			ball_control.execute_shot(_action_power, _action_aim)
		&"dribble":
			if ball_control.execute_dribble(_action_aim):
				_burst_timer = 0.5
		&"tackle":
			if not ball_control.execute_tackle():
				stumble(0.6)


func on_animation_contact() -> void:
	if state == State.ACTION and not _action_contact_done:
		_do_contact()


## Desequilíbrio (desarme sofrido, bote errado). Animação: "Stumble".
func stumble(time: float) -> void:
	state = State.STUNNED
	_stun_timer = time
	_buffer_timer = 0.0
	action_started.emit(&"stumble")


# --- Controle externo (MatchManager) -------------------------------------------

func set_frozen(value: bool) -> void:
	if value:
		state = State.FROZEN
	elif state == State.FROZEN:
		state = State.MOVE


func teleport(pos: Vector3, face_dir: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	velocity = Vector3.ZERO
	var f := Vector3(face_dir.x, 0.0, face_dir.z)
	if f.length() > 0.01:
		facing = f.normalized()
		rotation.y = atan2(-facing.x, -facing.z)
	_buffer_timer = 0.0
	if state != State.FROZEN:
		state = State.MOVE


func notify_touch(kind: StringName) -> void:
	ball_touched.emit(kind)


# --- Consultas -----------------------------------------------------------------

func get_flat_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func get_horizontal_speed() -> float:
	return get_flat_velocity().length()


func is_goalkeeper() -> bool:
	return role == Role.GOALKEEPER


func get_teammates() -> Array[Player]:
	var result: Array[Player] = []
	if match_manager == null:
		return result
	for p in match_manager.get_team(team):
		if p != self:
			result.append(p)
	return result


func get_opponents() -> Array[Player]:
	if match_manager == null:
		var empty: Array[Player] = []
		return empty
	return match_manager.get_team(Team.other(team))


func _flat_dir_to(point: Vector3) -> Vector3:
	var d := point - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else facing
