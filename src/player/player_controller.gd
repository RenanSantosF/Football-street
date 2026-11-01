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
const BUFFER_TIME_WITH_BALL := 1.1
const LONG_PASS_POWER := 0.55
## Quanto a preparação do chute pode esperar a bola chegar ao pé.
const MAX_CONTACT_WAIT := 0.45
## Marcação: com o adversário conduzindo a até esta distância, o jogador
## encara quem tem a bola e anda de lado/de costas.
const MARK_RANGE := 5.0
const MARK_RANGE_EXIT := 6.2
## Tempo mínimo em cada modo (marcando / correndo) para não tremer a animação.
const MARK_MIN_TIME := 0.5
## Carrinho: alcance (m) e chance do conduzidor pular por cima.
const SLIDE_RANGE := 3.2
const POKE_RANGE := 1.3
const DODGE_CHANCE_AI := 0.35
const DODGE_CHANCE_HUMAN := 0.25
## Tempo caído antes de levantar (quando não há clipe de levantar).
const DOWN_TIME := 0.7
## Viradas tocadas um pouco mais rápidas (responsivo sem perder o movimento).
const TURN_SPEED_UP := 1.35

@export var team: int = Team.SHIRTS
@export var role: Role = Role.FIELD
@export var appearance: CharacterAppearance
@export var shirt_number := 0

@export_group("Movimento")
@export var jog_speed := 3.5
@export var sprint_speed := 5.2
@export var ball_speed_factor := 0.92
@export var acceleration := 6.5
@export var deceleration := 9.0
## Velocidade de giro do corpo (rad/s).
@export var turn_speed := 6.5
@export var turn_speed_with_ball := 5.5

var intent := PlayerIntent.new()
var controller: Node = null
var match_manager: MatchManager = null
var ball: Ball = null
var state: State = State.MOVE
var facing := Vector3.FORWARD
var stamina := 1.0
var is_human := false
var formation_index := 0
## Fora de jogo no modo TREINO (adversários desligados).
var active := true

var _action_kind: StringName = &""
var _action_time := 0.0
var _action_contact := 0.0
var _action_length := 0.0
var _action_contact_done := false
var _action_power := 0.0
var _action_aim := Vector3.ZERO
var _action_target: Node3D = null
var _action_precise := false
var _action_lofted := false
var _kick_logical: StringName = &""
var _kick_seek := 0.0
var _action_move_factor := 0.4
var _action_face := Vector3.ZERO
var _stun_timer := 0.0
var _burst_timer := 0.0
var _buffer_action: PlayerIntent.Action = PlayerIntent.Action.NONE
var _buffer_power := 0.0
var _buffer_aim := Vector3.ZERO
var _buffer_target: Node3D = null
var _buffer_timer := 0.0
var _buffer_precise := false
var _buffer_lofted := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _marking := false
var _mark_timer := 0.0
var _action_logical: StringName = &""
var _action_seek := 0.0
var _jump_timer := 0.0
var _reaction: StringName = &""
var _rng := RandomNumberGenerator.new()
## Reinício (saída, lateral, escanteio, tiro de meta): parado com a bola,
## só pode tocar para um companheiro.
var _restart_lock := false
## Testes/laboratórios: força a chance de pular carrinhos (-1 = normal).
var debug_dodge_chance := -1.0
## Gesto de espera (reclamar, aquecer, conversar...) enquanto parado.
var gesture: StringName = &""
var _gesture_timer := 0.0
## Virada animada: direção final aplicada ao terminar o clipe.
var _turn_target := Vector3.ZERO
var _steady_input := Vector3.ZERO
var _steady_time := 0.0
var _prev_input_len := 0.0
var _turn_cooldown := 0.0

@onready var ball_control: BallControl = $BallControl
@onready var ai: AIController = $AIController
@onready var anim_controller: PlayerAnimationController = $PlayerAnimationController
@onready var visual: Node3D = $Visual
@onready var selection_ring: MeshInstance3D = $SelectionRing


func setup(mm: MatchManager, b: Ball) -> void:
	match_manager = mm
	ball = b
	_rng.randomize()
	ball_control.setup(self, b)
	if appearance == null:
		appearance = CharacterAppearance.new()
	if visual.has_method("apply_appearance"):
		visual.call("apply_appearance", appearance, team, role)
	# Todos os jogadores com a mesma skin e o mesmo tamanho.
	visual.scale = Vector3.ONE
	anim_controller.setup(self)
	_add_team_disc()
	set_human(false, null)


## Marca discreta do time sob os pés: um anel fino e transparente (todos usam
## a mesma skin, então ajuda a saber quem é de qual time).
func _add_team_disc() -> void:
	var ring := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = 0.31
	m.outer_radius = 0.325
	m.rings = 24
	m.ring_segments = 3
	ring.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c := Team.COLORS[team]
	mat.albedo_color = Color(c.r, c.g, c.b, 0.16)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.01
	ring.scale = Vector3(1.0, 0.05, 1.0)
	add_child(ring)


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
	_jump_timer = maxf(_jump_timer - delta, 0.0)
	_mark_timer += delta
	if gesture != &"":
		_gesture_timer -= delta
		if _gesture_timer <= 0.0 or get_horizontal_speed() > 0.4 or state != State.MOVE:
			gesture = &""
	var want_mark := _compute_marking()
	if want_mark != _marking and _mark_timer >= MARK_MIN_TIME:
		_marking = want_mark
		_mark_timer = 0.0
	elif not _compute_marking_allowed():
		_marking = false

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
	if _restart_lock:
		_check_restart_unlock()
	if _restart_lock:
		input = Vector3.ZERO # parado: o analógico só gira o corpo (mira do passe)
	elif ball != null and ball.pass_target == self and ball.possessor == null and ball.in_play \
			and not (is_human and input.length() > 0.5):
		# A bola vem para mim: vou buscá-la sozinho (IA ou humano sem mexer no
		# analógico). Bola direto em mim → espero e dou um passo ao encontro;
		# em profundidade → corro para onde ela vai estar.
		_receive_pass(delta)
		return
	if input.length() > 1.0:
		input = input.normalized()
	var has_ball := ball_control.has_ball()
	if _try_animated_turn_or_stop(input, delta):
		return
	var max_speed := sprint_speed if (intent.sprint and stamina > 0.05) else jog_speed
	if has_ball:
		max_speed *= ball_speed_factor
	if _burst_timer > 0.0:
		max_speed *= 1.15
	if _marking:
		max_speed = minf(max_speed, jog_speed * 0.85)
	var desired := input * max_speed
	if has_ball and _has_pending_kick() and not ball_control.can_kick():
		# Chute/passe pedido com a bola um pouco à frente: ir até ela para finalizar.
		var to_ball := ball_control.ball_offset()
		desired = to_ball.normalized() * sprint_speed * 1.08 if to_ball.length() > 0.05 else desired
	elif has_ball and input.length() > 0.1:
		var turn_target := ball_control.turn_approach_point(input.normalized())
		if turn_target != Vector3.ZERO:
			# Virou para o lado oposto da bola: vai até ela contornando, para
			# puxá-la para a nova direção (não abandona a bola).
			# Corre mais que a bola para alcançá-la (se ela estiver fugindo).
			var chase := clampf(ball.flat_velocity().length() + 1.5, jog_speed * 0.85, sprint_speed)
			desired = turn_target.normalized() * chase if turn_target.length() > 0.12 else input * jog_speed * 0.4
		else:
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
	elif ball != null and ball.pass_target == self and ball.possessor == null and hv.length() < 2.0:
		target_dir = _flat_dir_to(ball.global_position) # recebendo: olha para a bola
	elif _restart_lock and intent.move.length() > 0.2:
		target_dir = Vector3(intent.move.x, 0.0, intent.move.z).normalized()
	elif _marking and state == State.MOVE:
		target_dir = _flat_dir_to(_mark_focus())
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
		_buffer_precise = intent.precise
		_buffer_lofted = intent.lofted
		_buffer_timer = BUFFER_TIME_WITH_BALL if ball_control.has_ball() else BUFFER_TIME
	if _buffer_timer <= 0.0:
		return
	_buffer_timer -= delta
	if _restart_lock and _buffer_action != PlayerIntent.Action.PASS:
		_buffer_timer = 0.0 # no reinício só vale o passe
		return

	var done := false
	match _buffer_action:
		PlayerIntent.Action.PASS, PlayerIntent.Action.SHOOT:
			if ball_control.can_kick() or ball_control.can_start_kick_on_run():
				_start_kick(_buffer_action, _buffer_power, _buffer_aim, _buffer_target, _buffer_lofted)
				_action_precise = _buffer_precise
				_action_lofted = _buffer_lofted
				done = true
			elif _buffer_action == PlayerIntent.Action.SHOOT and not ball_control.has_ball():
				# CARRINHO (botão de chute sem a bola).
				var t := ball_control.find_tackle_target(SLIDE_RANGE)
				if t != null:
					var d := _flat_dir_to(t.global_position)
					if AnimationCatalog.has_clip(&"tackle"):
						_start_slide(t, d)
					else:
						_begin_action(&"tackle", 0.15, 0.45, 0.0, _buffer_aim, null, 0.8)
						_action_face = d
					done = true
		PlayerIntent.Action.DRIBBLE:
			if not ball_control.has_ball():
				# DESARME em pé (botão de drible sem a bola).
				var t2 := ball_control.find_tackle_target(POKE_RANGE + 0.3)
				if t2 != null:
					_begin_action(&"tackle", 0.15, 0.45, 0.0, _buffer_aim, null, 0.8)
					_action_face = _flat_dir_to(t2.global_position)
					_buffer_timer = 0.0
					_buffer_action = PlayerIntent.Action.NONE
				return
			if ball_control.has_ball() and not ball_control.can_kick():
				return # bola um pouco à frente: espera chegar ao pé (buffer)
			if ball_control.has_ball() and ball_control.can_kick():
				var aim := _buffer_aim if _buffer_aim.length() > 0.2 else facing
				if AnimationCatalog.has_clip(&"spin") and Vector3(aim.x, 0.0, aim.z).normalized().dot(facing) > 0.3:
					# Giro inteiro: a bola é solta no fim (contato do clipe).
					_start_root_action(&"spin", &"spin",
						AnimationCatalog.contact_time(&"spin") / PlayerAnimationController.ACTION_SPEED, facing)
				else:
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


func _start_kick(a: PlayerIntent.Action, power: float, aim: Vector3, target: Node3D, lofted := false) -> void:
	if a == PlayerIntent.Action.PASS and lofted:
		power = maxf(power, LONG_PASS_POWER) # passe por cima
	if a == PlayerIntent.Action.SHOOT:
		var kind: StringName = &"shoot_power" if power > 0.7 else &"shoot"
		var contact := 0.16 + 0.12 * power
		_begin_action(kind, contact, contact + 0.3, power, aim, null, 0.35)
		_action_face = facing if aim.length() < 0.2 else Vector3(aim.x, 0.0, aim.z).normalized()
	else:
		var long := power >= LONG_PASS_POWER
		# Pequena preparação antes do toque, como no futebol de verdade.
		var contact := 0.28 if long else 0.2
		_begin_action(&"long_pass" if long else &"pass", contact, contact + 0.22, power, aim, target, 0.5)
		if target != null:
			_action_face = _flat_dir_to(target.global_position)
		elif aim.length() > 0.2:
			_action_face = Vector3(aim.x, 0.0, aim.z).normalized()
		else:
			_action_face = facing
	_setup_kick_root_motion()


## Continuação do corpo depois do contato: segue o deslocamento do próprio
## clipe (antes o quadril ficava pregado e os pés deslizavam).
func _setup_kick_root_motion() -> void:
	var map := {&"pass": &"pass_short", &"long_pass": &"pass_long", &"shoot": &"shoot", &"shoot_power": &"shoot_power"}
	_kick_logical = map.get(_action_kind, &"")
	if _kick_logical == &"" or not AnimationCatalog.has_clip(_kick_logical):
		_kick_logical = &""
		return
	var sp := PlayerAnimationController.ACTION_SPEED
	_kick_seek = maxf(AnimationCatalog.contact_time(_kick_logical) - _action_contact * sp, 0.0)


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
	_action_logical = &""
	_action_precise = false
	_action_lofted = false
	_kick_logical = &""
	action_started.emit(kind)


func _update_action(delta: float) -> void:
	_action_time += delta
	var hv := get_flat_velocity()
	if _action_logical != &"":
		# Root motion: o corpo segue a curva de deslocamento gravada no clipe.
		var speed := PlayerAnimationController.ACTION_SPEED
		if _turn_target != Vector3.ZERO:
			speed = TURN_SPEED_UP
		var anim_t := _action_seek + _action_time * speed
		var rv := AnimationCatalog.root_motion_velocity(_action_logical, anim_t)
		var hips_h := 0.85
		if visual != null and visual.has_method("get_hips_height"):
			hips_h = visual.call("get_hips_height")
		var left := Vector3.UP.cross(facing)
		var target := (facing * rv.z + left * rv.x) * hips_h * speed
		hv = hv.move_toward(target, acceleration * 3.0 * delta)
		if _action_kind == &"spin":
			ball_control.carry_during_skill(delta)
	elif _action_kind == &"dribble":
		var dir := Vector3(_action_aim.x, 0.0, _action_aim.z).normalized()
		hv = hv.move_toward(dir * sprint_speed * 0.95, acceleration * 1.5 * delta)
	elif _action_contact_done and _kick_logical != &"":
		var sp := PlayerAnimationController.ACTION_SPEED
		var rv := AnimationCatalog.root_motion_velocity(_kick_logical, _kick_seek + _action_time * sp)
		var hips_h := 0.85
		if visual != null and visual.has_method("get_hips_height"):
			hips_h = visual.call("get_hips_height")
		var left := Vector3.UP.cross(facing)
		hv = hv.move_toward((facing * rv.z + left * rv.x) * hips_h * sp, acceleration * 2.0 * delta)
	elif not _action_contact_done and _is_kick_action():
		# Preparação do chute/passe: acompanhar a bola até o pé de apoio,
		# para que no contato ela esteja ao alcance (sem "furar").
		var remaining := maxf(_action_contact - _action_time, 0.05)
		var plant := ball_control.ball_offset() + ball.flat_velocity() * remaining
		var to_ball_dir := plant.normalized() if plant.length() > 0.01 else facing
		# Pé de apoio ao lado da bola: quem chuta de direita deixa a bola à direita.
		var side := anim_controller.kick_foot(_action_kind)
		plant -= to_ball_dir * minf(BallControl.FOOT_DISTANCE, plant.length())
		plant -= to_ball_dir.cross(Vector3.UP) * side * BallControl.KICK_FOOT_OFFSET
		hv = hv.move_toward((plant / remaining).limit_length(sprint_speed * 1.25), acceleration * 2.5 * delta)
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
		if _turn_target != Vector3.ZERO:
			facing = _turn_target
			rotation.y = atan2(-facing.x, -facing.z)
			_turn_target = Vector3.ZERO
	# Parada brusca: se voltar a mexer o analógico, sai da parada.
	if state == State.ACTION and _action_kind == &"run_stop" and _action_time > 0.25 and intent.move.length() > 0.5:
		state = State.MOVE
	if state != State.ACTION and collision_mask != 3:
		collision_mask = 3


## Momento em que o pé encosta na bola. Na Etapa 3 a animação chama
## on_animation_contact() exatamente no quadro do contato.
func _do_contact() -> void:
	_action_contact_done = true
	match _action_kind:
		&"pass", &"long_pass":
			if ball_control.execute_pass(_action_power, _action_aim, _action_target, _action_lofted):
				_restart_lock = false
		&"shoot", &"shoot_power":
			ball_control.execute_shot(_action_power, _action_aim, _action_precise, _action_lofted)
		&"dribble":
			if ball_control.execute_dribble(_action_aim):
				_burst_timer = 0.5
		&"tackle":
			if not ball_control.execute_tackle():
				stumble(0.6)
		&"slide":
			ball_control.execute_slide_tackle()
		&"spin":
			ball_control.release_after_skill()


func action_time_left() -> float:
	return maxf(_action_length - _action_time, 0.0) if state == State.ACTION else 0.0


## Tempo até o pé encostar na bola na ação atual (0 se não houver).
func time_to_contact() -> float:
	if state != State.ACTION or _action_contact_done:
		return 0.0
	return maxf(_action_contact - _action_time, 0.0)


## Posições (mundo) das pontas dos pés do modelo animado, se houver.
func get_foot_positions() -> Array[Vector3]:
	if visual != null and visual.has_method("get_foot_positions"):
		return visual.call("get_foot_positions")
	var none: Array[Vector3] = []
	return none


## Virada animada / parada brusca (clipes do Mixamo com o corpo girando):
##  - correndo e invertendo a direção → "Running Turn 180"
##  - parado e pedindo direção a 60–135° → "Left/Right Turn" (90°)
##  - correndo e soltando o analógico → "Run To Stop"
## Durante o clipe o corpo gira pela própria animação; no fim aplicamos a nova
## direção de uma vez (o clipe termina exatamente virado).
func _try_animated_turn_or_stop(input: Vector3, delta: float) -> bool:
	var hv := get_flat_velocity()
	var speed := hv.length()
	var in_len := input.length()
	# Entrada estável (evita disparar com toques rápidos no analógico).
	if in_len > 0.4 and _steady_input.length() > 0.01 and input.normalized().dot(_steady_input) > 0.9:
		_steady_time += delta
	else:
		_steady_time = 0.0
		_steady_input = input.normalized() if in_len > 0.4 else Vector3.ZERO
	var released := in_len < 0.1 and _prev_input_len > 0.5
	_prev_input_len = in_len
	_turn_cooldown -= delta
	if _marking or _restart_lock or _turn_cooldown > 0.0:
		return false
	# IA: viradas animadas com moderação (senão fica lenta e repetitiva).
	var ai_turn_ok := is_human or _rng.randf() < 0.04
	if in_len > 0.6 and speed > (2.6 if is_human else 3.6) and ai_turn_ok and AnimationCatalog.has_clip(&"turn180"):
		if hv.normalized().dot(input.normalized()) < -0.55:
			_start_turn(&"turn180", &"turn180", input.normalized())
			return true
	if in_len > 0.6 and speed < 0.5 and not ball_control.has_ball() and ai_turn_ok:
		var ang := facing.signed_angle_to(input.normalized(), Vector3.UP)
		if absf(ang) > deg_to_rad(60.0) and absf(ang) < deg_to_rad(135.0) and AnimationCatalog.has_clip(&"turn_l"):
			var turned := facing.rotated(Vector3.UP, signf(ang) * PI * 0.5)
			_start_turn(&"turn_l" if ang > 0.0 else &"turn_r", &"turn_l" if ang > 0.0 else &"turn_r", turned)
			return true
	if released and speed > 3.2 and not ball_control.has_ball() and ball_control.ball_distance() > 3.0 \
			and AnimationCatalog.has_clip(&"run_stop"):
		_start_root_action(&"run_stop", &"run_stop", 0.0, facing)
		return true
	return false


func _start_turn(kind: StringName, logical: StringName, new_dir: Vector3) -> void:
	_turn_cooldown = 1.2
	_start_root_action(kind, logical, 0.0, facing)
	_action_length /= TURN_SPEED_UP
	_turn_target = Vector3(new_dir.x, 0.0, new_dir.z).normalized()
	if ball_control.has_ball():
		ball_control.drag_ball_to(_turn_target) # puxa a bola junto na virada


## Gesto de espera (só parado).
func play_gesture(kind: StringName, duration: float) -> void:
	if state == State.MOVE and get_horizontal_speed() < 0.3:
		gesture = kind
		_gesture_timer = duration


func _receive_pass(delta: float) -> void:
	var target := _pass_intercept_point()
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	var desired := Vector3.ZERO
	if d > 0.35:
		var t_ball := _ball_time_to(target)
		var need := d / maxf(t_ball, 0.15)
		desired = to / d * clampf(need, 0.8, sprint_speed)
	var hv := get_flat_velocity()
	hv = hv.move_toward(desired, (acceleration if desired.length() > hv.length() else deceleration) * delta)
	velocity.x = hv.x
	velocity.z = hv.z


## Onde e quando consigo encontrar a bola em movimento.
func _pass_intercept_point() -> Vector3:
	var t := 0.1
	while t <= 3.0:
		var bp := ball.predict_ground_position(t)
		var need := global_position.distance_to(bp) / sprint_speed + 0.1
		if need <= t:
			return bp
		t += 0.1
	return ball.predict_ground_position(3.0)


func _ball_time_to(point: Vector3) -> float:
	var v := ball.flat_velocity().length()
	var d := Vector2(point.x - ball.global_position.x, point.z - ball.global_position.z).length()
	return d / maxf(v, 1.0)


func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
	collision_layer = 2 if value else 0
	collision_mask = 3 if value else 0
	if not value:
		global_position = Vector3(0.0, -30.0, 0.0)
		velocity = Vector3.ZERO


func set_restart_lock(value: bool) -> void:
	_restart_lock = value


func is_restart_locked() -> bool:
	return _restart_lock


## A trava some quando o passe sai ou quando outro jogador fica com a bola.
func _check_restart_unlock() -> void:
	if ball == null:
		return
	if ball.possessor != null and ball.possessor != self:
		_restart_lock = false


func is_marking() -> bool:
	return _marking


func is_jumping() -> bool:
	return _jump_timer > 0.0


func current_reaction() -> StringName:
	return _reaction


func _compute_marking() -> bool:
	if not _compute_marking_allowed():
		return false
	if is_goalkeeper():
		return true
	var carrier := ball.possessor
	if carrier == null or carrier.team == team or intent.sprint:
		return false
	var d := global_position.distance_to(carrier.global_position)
	return d < (MARK_RANGE_EXIT if _marking else MARK_RANGE)


## Condições que desligam a marcação na hora (sem esperar o tempo mínimo).
func _compute_marking_allowed() -> bool:
	return ball != null and ball.in_play and state == State.MOVE and not ball_control.has_ball()


## Para onde o jogador olha ao marcar: quem tem a bola (ou a bola, no goleiro).
func _mark_focus() -> Vector3:
	if ball.possessor != null and ball.possessor.team != team:
		return ball.possessor.global_position
	return ball.global_position


## Ação com deslocamento vindo da animação (root motion).
func _start_root_action(kind: StringName, logical: StringName, lead: float, face: Vector3) -> void:
	var speed := PlayerAnimationController.ACTION_SPEED
	var contact := AnimationCatalog.contact_time(logical)
	var seek := maxf(contact - lead * speed, 0.0) if AnimationCatalog.CONTACTS.has(logical) else 0.0
	var length := (AnimationCatalog.clip_length(logical) - seek) / speed
	var contact_t := maxf(contact - seek, 0.0) / speed if AnimationCatalog.CONTACTS.has(logical) else length
	_begin_action(kind, contact_t, length, 1.0, face, null, 1.0)
	_action_logical = logical
	_action_seek = seek
	# Carrinho, queda e pulo passam por baixo/por cima de quem está perto.
	collision_mask = 1
	_action_face = Vector3(face.x, 0.0, face.z).normalized()


## Carrinho: desliza em direção a quem conduz; o conduzidor pode pular.
func _start_slide(target: Player, dir: Vector3) -> void:
	_start_root_action(&"slide", &"tackle", 0.25, dir)
	_action_length += DOWN_TIME * 0.5 + AnimationCatalog.getup_duration(&"getup_b")
	target.on_tackle_incoming(self)


## Um adversário veio de carrinho: talvez pular por cima (com a bola).
func on_tackle_incoming(_tackler: Player) -> void:
	if state != State.MOVE or not ball_control.has_ball() or not AnimationCatalog.has_clip(&"jump"):
		return
	var chance := DODGE_CHANCE_HUMAN if is_human else DODGE_CHANCE_AI
	if debug_dodge_chance >= 0.0:
		chance = debug_dodge_chance
	if _rng.randf() >= chance:
		return
	_start_root_action(&"jump", &"jump", 0.0, facing)
	_jump_timer = _action_length
	ball_control.push_ahead(1.6)


## Levou um carrinho / foi derrubado: tropeça, cai, fica no chão e levanta.
func trip() -> void:
	if not AnimationCatalog.has_clip(&"trip"):
		stumble(0.8)
		return
	_start_root_action(&"trip", &"trip", 0.0, facing)
	_action_length += DOWN_TIME + AnimationCatalog.getup_duration(&"getup")
	_buffer_timer = 0.0


## Comemoração/lamento (gol). O jogador fica parado até a próxima saída.
func play_reaction(kind: StringName) -> void:
	_reaction = kind
	state = State.FROZEN
	action_started.emit(kind)


func on_animation_contact() -> void:
	if state == State.ACTION and not _action_contact_done:
		_do_contact()


## Desequilíbrio (desarme sofrido, bote errado). Animação: "Stumble".
func stumble(time: float) -> void:
	collision_mask = 3
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
		_reaction = &""


func teleport(pos: Vector3, face_dir: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	velocity = Vector3.ZERO
	var f := Vector3(face_dir.x, 0.0, face_dir.z)
	if f.length() > 0.01:
		facing = f.normalized()
		rotation.y = atan2(-facing.x, -facing.z)
	_buffer_timer = 0.0
	_reaction = &""
	_restart_lock = false
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
