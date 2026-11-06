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
## Giro máximo parado (rad/s) fora dos clipes de virada.
const IDLE_TURN_RATE := 1.6
## Correção máxima do corpo na aproximação do chute/passe (m/s).
const KICK_ADJUST_SPEED := 1.6
## Giro máximo do corpo (rad/s) andando/correndo.
const MAX_TURN_RATE := 9.0
const MAX_TURN_RATE_BALL := 8.8
const DODGE_CHANCE_AI := 0.35
const DODGE_CHANCE_HUMAN := 0.25
## Tempo caído antes de levantar (quando não há clipe de levantar).
const DOWN_TIME := 0.35
## Viradas tocadas um pouco mais rápidas (responsivo sem perder o movimento).
const TURN_SPEED_UP := 1.35

@export var team: int = Team.SHIRTS
@export var role: Role = Role.FIELD
@export var appearance: CharacterAppearance
@export var shirt_number := 0

@export_group("Movimento")
@export var jog_speed := 2.45
## Velocidade máxima correndo (CORRER) — cadenciada, pesada e firme no chão.
@export var sprint_speed := 4.05
## Velocidade máxima conduzindo a bola em velocidade (cadência de futebol realista).
@export var speed_dribbling := 3.45
@export var ball_speed_factor := 0.99
@export var acceleration := 7.8
@export var deceleration := 7.2
## Velocidade de giro do corpo (rad/s).
@export var turn_speed := 6.6
## Giro ágil com a bola: mesma fluidez de correr sem a bola.
@export var turn_speed_with_ball := 6.5

var intent := PlayerIntent.new()
var controller: Node = null
var match_manager: MatchManager = null
var ball: Ball = null
var state: State = State.MOVE
var facing := Vector3.FORWARD
## Ajuste do corpo até a bola neste quadro (a passada da animação conta com ele).
var body_adjust := Vector3.ZERO
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
var _turn_start_facing := Vector3.FORWARD
var _turn_yaw_on := false
## Recebendo um passe em profundidade (correndo junto com a bola)?
var _receiving_through := false
var _steady_input := Vector3.ZERO
var _steady_time := 0.0
var _prev_input_len := 0.0
var _turn_cooldown := 0.0
## Chute/passe atual com o pé ESQUERDO (clipe espelhado)?
var _kick_mirror := false
## Giro com a bola antes de um passe/chute para trás.
var _pivot_dir := Vector3.ZERO
var _kick_ik := false
var _turn_speed_k := TURN_SPEED_UP
var _auto_tackle_cooldown := 0.0
var _is_through_pass := false

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
	_add_charge_ring()
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


var _charge_ring: MeshInstance3D = null


## Barra de força do passe/chute no chão, em volta do jogador controlado.
func _add_charge_ring() -> void:
	_charge_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.25, 1.25)
	_charge_ring.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/shaders/charge_ring.gdshader")
	_charge_ring.material_override = mat
	_charge_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_ring.position.y = 0.035
	_charge_ring.visible = false
	add_child(_charge_ring)


## Força atual (0..1) do botão segurado; kind vazio = solto (esconde).
func set_charge(value: float, kind: StringName) -> void:
	if _charge_ring == null:
		return
	_charge_ring.visible = kind != &""
	if _charge_ring.visible:
		(_charge_ring.material_override as ShaderMaterial).set_shader_parameter("fill", clampf(value, 0.0, 1.0))


## Liga/desliga o controle humano. Sem humano, a própria IA assume.
func set_human(value: bool, human_input: Node) -> void:
	is_human = value and human_input != null
	controller = human_input if is_human else ai
	selection_ring.visible = is_human
	if not is_human:
		set_charge(0.0, &"")


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

	_record_buffer()
	match state:
		State.MOVE:
			_update_move(delta)
			_update_actions(delta)
			_try_auto_safe_tackle(delta)
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
	_update_body_contest(delta)
	if not is_jumping():
		velocity.y = minf(velocity.y, 0.0) - _gravity * delta
	else:
		velocity.y -= _gravity * delta
	body_adjust = Vector3.ZERO
	move_and_slide()
	if not is_jumping() and global_position.y > 0.0:
		global_position.y = 0.0
		velocity.y = minf(velocity.y, 0.0)
	_update_facing(delta)
	_update_stamina(delta)
	anim_controller.physics_update(delta)


# --- Movimento ---------------------------------------------------------------

func _update_move(delta: float) -> void:
	var input := Vector3(intent.move.x, 0.0, intent.move.z)
	if _restart_lock:
		_check_restart_unlock()
	if _restart_lock:
		_restart_orbit(input, delta)
		return
	if _try_aerial_reception():
		return
	if _pivot_dir != Vector3.ZERO:
		# Passe para trás correndo: o corpo ainda vai para a frente pela inércia
		# enquanto gira (freia aos poucos), a bola vai junto no pé.
		_brake(delta, deceleration if get_horizontal_speed() < 2.0 else 4.5)
		ball_control.carry_during_skill(delta)
		if facing.angle_to(_pivot_dir) < deg_to_rad(30.0) or not ball_control.has_ball() or _buffer_timer <= 0.0:
			_pivot_dir = Vector3.ZERO
		return
	elif ball != null and ball.pass_target == self and ball.possessor == null and ball.in_play:
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
		max_speed = speed_dribbling if (intent.sprint and stamina > 0.05) else jog_speed * ball_speed_factor
	if _burst_timer > 0.0:
		max_speed *= 1.15
	if _marking:
		max_speed = minf(max_speed, jog_speed * 0.85)
	var desired := input * max_speed
	if has_ball and _has_pending_kick() and not ball_control.can_kick():
		# Chute/passe pedido com a bola um pouco à frente: ir até ela para finalizar.
		var to_ball := ball_control.ball_offset()
		desired = to_ball.normalized() * sprint_speed * 1.08 if to_ball.length() > 0.05 else desired
	elif has_ball and input.length() <= 0.1:
		# Soltou o analógico: freia firme no lugar e estabiliza o corpo junto à bola.
		desired = Vector3.ZERO
	var hv := get_flat_velocity()
	if input.length() > 0.2 and hv.length() > 1.8:
		var turn_cos := hv.normalized().dot(input.normalized())
		if turn_cos < 0.72:
			var curve_damp := lerpf(0.84, 1.0, clampf((turn_cos + 0.35) / 1.07, 0.0, 1.0))
			desired *= curve_damp
	# Acelera progressivamente; inverter direção passa por uma freada com peso.
	var speeding_up := desired.length() > hv.length() and hv.dot(desired) >= 0.0
	var rate := acceleration if speeding_up else deceleration
	hv = hv.move_toward(desired, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z


## Reinício: o analógico só escolhe a direção do passe. O jogador gira em
## volta da bola parada (passinhos), sempre com a bola à frente do pé.
func _restart_orbit(input: Vector3, delta: float) -> void:
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	var aim := facing
	if input.length() > 0.25:
		aim = input.normalized()
	var spot := ball.global_position - aim * 0.45
	spot.y = global_position.y
	var to := spot - global_position
	to.y = 0.0
	var desired := to * 5.0
	desired = desired.limit_length(1.6)
	if to.length() < 0.04:
		desired = Vector3.ZERO
	var hv := get_flat_velocity().move_toward(desired, deceleration * delta)
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
	elif _pivot_dir != Vector3.ZERO:
		target_dir = _pivot_dir
	elif state == State.MOVE and ball_control.is_reverse_pulling() and intent.move.length() > 0.15:
		target_dir = Vector3(intent.move.x, 0.0, intent.move.z).normalized()
	elif ball != null and ball.pass_target == self and ball.possessor == null and _receiving_through and hv.length() > 0.5:
		target_dir = hv.normalized() # profundidade: corre de frente para onde vai
	elif ball != null and ball.pass_target == self and ball.possessor == null and hv.length() < 2.6:
		target_dir = _flat_dir_to(ball.global_position) # recebendo: de frente para a bola
	elif _restart_lock:
		target_dir = _flat_dir_to(ball.global_position) # sempre de frente para a bola
	elif _marking and state == State.MOVE:
		target_dir = _flat_dir_to(_mark_focus())
	elif hv.length() > 0.35:
		target_dir = hv.normalized()
	elif intent.move.length() > 0.15:
		target_dir = Vector3(intent.move.x, 0.0, intent.move.z).normalized()
	elif state == State.MOVE and ball_control.has_ball() and hv.length() < 0.8 \
			and _shield_threat() != Vector3.ZERO and intent.move.length() < 0.15:
		# PROTEÇÃO AUTOMÁTICA: parado/desacelerando sem mexer no analógico e marcador colado
		target_dir = -_shield_threat()
	elif ball != null:
		var to_ball := ball.global_position - global_position
		to_ball.y = 0.0
		if to_ball.length() > 0.3:
			target_dir = to_ball.normalized()
	# Rotação com INÉRCIA (lerp_angle): mais pesada com a bola.
	var rate := turn_speed_with_ball if ball_control.has_ball() else turn_speed
	if state == State.ACTION:
		rate *= 1.6
	if _pivot_dir != Vector3.ZERO or ball_control.is_reverse_pulling():
		rate = 11.0
	if target_dir.length_squared() > 0.0001:
		# Frente do jogador = -Z (o modelo Mixamo, que olha para +Z, está girado
		# 180° dentro do Visual): ângulo = atan2(-x, -z).
		var cur := atan2(-facing.x, -facing.z)
		var tgt := atan2(-target_dir.x, -target_dir.z)
		var a := lerp_angle(cur, tgt, clampf(rate * delta, 0.0, 1.0))
		if state == State.MOVE and hv.length() < 0.5 and _pivot_dir == Vector3.ZERO and not _marking \
				and not ball_control.is_dragging():
			# PARADO: o corpo não "gira no eixo" com os pés colados no chão
			# (deslizando). Giro grande é feito pelos clipes de virada; aqui só
			# um ajuste lento, que a passada acompanha.
			var da := wrapf(a - cur, -PI, PI)
			a = cur + clampf(da, -IDLE_TURN_RATE * delta, IDLE_TURN_RATE * delta)
		# Em alta velocidade, girar o corpo exige mais espaço (inércia angular).
		var max_rate := MAX_TURN_RATE_BALL if ball_control.has_ball() else MAX_TURN_RATE
		if hv.length() > 2.6 and state == State.MOVE and _pivot_dir == Vector3.ZERO and not ball_control.is_reverse_pulling():
			var hs_factor := clampf((hv.length() - 2.6) / 2.8, 0.0, 1.0)
			max_rate *= lerpf(1.0, 0.72, hs_factor)
		if _pivot_dir != Vector3.ZERO or state == State.ACTION or ball_control.is_reverse_pulling():
			max_rate *= 1.5
		var step := wrapf(a - cur, -PI, PI)
		a = cur + clampf(step, -max_rate * delta, max_rate * delta)
		facing = Vector3(-sin(a), 0.0, -cos(a))
	rotation.y = atan2(-facing.x, -facing.z)


## Disputa física ombro a ombro e separação anatômica entre jogadores: impede que
## partes de um jogador entrem dentro de outro e aplica carga de ombro realista.
func _update_body_contest(delta: float) -> void:
	if is_goalkeeper() and state != State.MOVE:
		return
	var all_others: Array[Player] = []
	all_others.append_array(get_opponents())
	all_others.append_array(get_teammates())
	for other in all_others:
		if other == null or other == self or not other.active:
			continue
		var diff := global_position - other.global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_sep := 0.54
		if dist < 0.001 or dist > 0.72:
			continue
		var n := diff / dist
		# Separação horizontal firme para evitar interpenetração de malhas
		if dist < min_sep and not is_jumping() and not other.is_jumping():
			var overlap := min_sep - dist
			global_position += n * (overlap * 0.52)
		if other.team != team and state == State.MOVE and other.state == State.MOVE:
			var near_ball := ball != null and (ball_control.ball_distance() < 1.9 or other.ball_control.ball_distance() < 1.9)
			if near_ball:
				var rel_v := other.get_flat_velocity() - get_flat_velocity()
				var closing := rel_v.dot(n)
				if closing > 0.15:
					var resist := 0.32 if ball_control.has_ball() else 0.48
					var push := n * minf(closing * resist, 2.0) * delta * 12.0
					velocity.x += push.x
					velocity.z += push.z


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

## Guarda o botão apertado (também durante uma ação: parada, virada...),
## para não perder o comando.
func _record_buffer() -> void:
	if intent.action != PlayerIntent.Action.NONE:
		_buffer_action = intent.action
		_buffer_power = intent.power
		_buffer_aim = intent.aim
		_buffer_target = intent.target
		_buffer_precise = intent.precise
		_buffer_lofted = intent.lofted
		var incoming := ball != null and ball.pass_target == self and ball.possessor == null
		_buffer_timer = BUFFER_TIME_WITH_BALL if (ball_control.has_ball() or incoming) else BUFFER_TIME
		if incoming:
			_buffer_timer = 3.0 # de primeira: espera a bola chegar
		elif ball != null and ball.possessor == null and ball.in_play \
				and global_position.distance_to(ball.global_position) < 3.5:
			_buffer_timer = 1.4 # bola chegando/solta perto: toca assim que ela chegar no pé


func _update_actions(delta: float) -> void:
	if _buffer_timer <= 0.0:
		return
	_buffer_timer -= delta
	if _restart_lock and _buffer_action not in [PlayerIntent.Action.PASS, PlayerIntent.Action.THROUGH_PASS]:
		_buffer_timer = 0.0 # no reinício só vale o passe
		return

	var done := false
	match _buffer_action:
		PlayerIntent.Action.PASS, PlayerIntent.Action.THROUGH_PASS, PlayerIntent.Action.SHOOT:
			if ball_control.has_ball() and ball_control.can_kick() and _pivot_dir == Vector3.ZERO and not _restart_lock:
				# Passe/chute para TRÁS: primeiro gira o corpo com a bola na sola
				# (passinhos rápidos), depois toca de frente — preciso, sem "cair".
				var kd := _kick_direction(_buffer_action, _buffer_aim, _buffer_target)
				if kd != Vector3.ZERO and facing.angle_to(kd) > deg_to_rad(100.0):
					_pivot_dir = kd
					return
			if _pivot_dir != Vector3.ZERO:
				return # ainda girando
			if ball_control.can_kick() or ball_control.can_start_kick_on_run() or _first_time_ready():
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
						_start_standing_tackle(d)
					done = true
		PlayerIntent.Action.DRIBBLE:
			if not ball_control.has_ball():
				# DESARME em pé (botão de drible sem a bola): estica a perna para dar o bote!
				var t2 := ball_control.find_tackle_target(POKE_RANGE + 0.55)
				if t2 != null:
					_start_standing_tackle(_buffer_aim)
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


func _start_standing_tackle(aim_dir: Vector3) -> void:
	var b_dir := _flat_dir_to(ball.global_position) if ball != null else facing
	_kick_mirror = _choose_kick_foot(b_dir)
	var t_foot := -1.0 if _kick_mirror else 1.0
	var act := &"tackle"
	if _rng.randf() < 0.5 and AnimationCatalog.has_clip(&"stand_tackle_alt"):
		act = &"tackle"
	_begin_action(act, 0.16, 0.44, 1.0, aim_dir, null, 0.85)
	_action_face = b_dir
	# Estica a perna de bote na direção da bola com alcance amplo de IK
	ball_control.foot.begin(t_foot, _action_face, 0.15, FootContact.Mode.INSIDE, Callable(), 0.12)


## Bote automático inteligente e seguro: mesmo sem apertar o botão de bote, quando o
## jogador defensor está colado na bola com linha limpa e baixo risco de falta, tenta
## esticar a perna para roubar a bola!
func _try_auto_safe_tackle(delta: float) -> void:
	_auto_tackle_cooldown = maxf(_auto_tackle_cooldown - delta, 0.0)
	if _auto_tackle_cooldown > 0.0 or state != State.MOVE or is_goalkeeper():
		return
	if ball == null or not ball.in_play or ball_control.has_ball():
		return
	var carrier := ball.possessor
	if carrier == null or carrier.team == team or carrier.is_jumping():
		return
	var me := Vector3(global_position.x, 0.0, global_position.z)
	var bp := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	var cp := Vector3(carrier.global_position.x, 0.0, carrier.global_position.z)
	var reach := (bp - me).length()
	var dist_c := (cp - me).length()
	if reach > 0.94 or dist_c < 0.56 or dist_c > 1.38:
		return
	var to_b := (bp - me).normalized() if reach > 0.05 else facing
	if facing.dot(to_b) < 0.35:
		return
	# Verifica se o corpo/perna do adversário está no meio do caminho (evita cometer falta!)
	var seg := bp - me
	var tt := clampf((cp - me).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
	var dist_to_seg := (me + seg * tt).distance_to(cp)
	if dist_to_seg < 0.38 and dist_c < reach + 0.05:
		return # risco de acertar a perna do adversário -> não dá o bote automático
	# Verifica se a bola está exposta à frente do adversário
	var ball_from_c := (bp - cp).length()
	var frontal := carrier.facing.dot((me - cp).normalized()) > 0.25
	if ball_from_c < 0.38 and not frontal:
		return
	# Tenta o bote seguro algumas vezes quando a oportunidade é clara (~4.5 chances/s na janela ideal)
	if _rng.randf() < delta * 4.5:
		_auto_tackle_cooldown = 1.25
		_start_standing_tackle(to_b)


func _is_kick_action() -> bool:
	return _action_kind in [&"pass", &"long_pass", &"shoot", &"shoot_power", &"chip", &"run_pass"]


func _has_pending_kick() -> bool:
	return _buffer_timer > 0.0 and (_buffer_action == PlayerIntent.Action.PASS \
		or _buffer_action == PlayerIntent.Action.THROUGH_PASS \
		or _buffer_action == PlayerIntent.Action.SHOOT)


## De primeira: a bola (sem dono) está chegando e vai estar no pé no
## instante do contato do passe/chute.
func _first_time_ready() -> bool:
	if ball == null or ball.possessor != null or not ball.in_play or not ball.can_be_kicked_by(self):
		return false
	if ball.global_position.y > 0.5:
		return false
	var rel := ball.global_position - global_position
	rel.y = 0.0
	var v := ball.flat_velocity() - get_flat_velocity()
	var closing := -rel.dot(v) / maxf(rel.length(), 0.01)
	if closing < 0.5:
		return rel.length() <= BallControl.KICK_REACH
	var t_arrive := (rel.length() - 0.4) / closing
	return t_arrive <= 0.24


## Para onde a bola vai sair (para escolher o pé e saber se precisa girar).
func _kick_direction(a: PlayerIntent.Action, aim: Vector3, target: Node3D) -> Vector3:
	var kdir := Vector3(aim.x, 0.0, aim.z)
	if target != null:
		kdir = _flat_dir_to(target.global_position)
	elif a == PlayerIntent.Action.SHOOT and kdir.length() < 0.2:
		kdir = _flat_dir_to(Field.goal_center(Team.other(team)))
	elif a in [PlayerIntent.Action.PASS, PlayerIntent.Action.THROUGH_PASS] and kdir.length() < 0.2:
		var mate := ball_control.pick_pass_target(facing, 180.0)
		if mate != null:
			kdir = _flat_dir_to(mate.global_position)
	return kdir.normalized() if kdir.length() > 0.1 else Vector3.ZERO


## No meio do chute/passe (antes do pé encostar na bola)?
func is_kicking() -> bool:
	return state == State.ACTION and _is_kick_action() and not _action_contact_done


func kick_mirrored() -> bool:
	return _kick_mirror


## Qual pé chuta: o do lado em que a bola está e para onde ela vai. Bola à
## esquerda do corpo / chute para a esquerda → pé ESQUERDO (clipe espelhado).
func _choose_kick_foot(dir: Vector3) -> bool:
	var right := facing.cross(Vector3.UP)
	var lat_ball := ball_control.ball_offset().dot(right)
	var lat_dir := dir.dot(right) if dir.length() > 0.1 else 0.0
	var score := lat_ball * 2.5 + lat_dir
	if score < -0.12:
		return true
	if score > 0.12:
		return false
	return _rng.randf() < 0.25 # neutro: pé direito na maioria das vezes


func _start_kick(a: PlayerIntent.Action, power: float, aim: Vector3, target: Node3D, lofted := false) -> void:
	_is_through_pass = (a == PlayerIntent.Action.THROUGH_PASS)
	if a in [PlayerIntent.Action.PASS, PlayerIntent.Action.THROUGH_PASS] and lofted and not is_human:
		power = maxf(power, LONG_PASS_POWER) # passe por cima
	var kdir := _kick_direction(a, aim, target)
	_kick_mirror = _choose_kick_foot(kdir)
	if a == PlayerIntent.Action.SHOOT and lofted:
		# CAVADINHA: só um toque leve por baixo da bola (animação do passe curto,
		# não o chute forte inteiro).
		_begin_action(&"chip", 0.2, 0.42, power, aim, null, 0.45)
		_action_face = facing if aim.length() < 0.2 else Vector3(aim.x, 0.0, aim.z).normalized()
	elif a == PlayerIntent.Action.SHOOT:
		var kind: StringName = &"shoot_power" if power > 0.7 else &"shoot"
		var contact := 0.16 + 0.12 * power
		_begin_action(kind, contact, contact + 0.3, power, aim, null, 0.35)
		_action_face = facing if aim.length() < 0.2 else Vector3(aim.x, 0.0, aim.z).normalized()
	else:
		# Humano: segurar = passe RASTEIRO mais forte; só sobe arrastando o dedo.
		var long := lofted or (not is_human and power >= LONG_PASS_POWER)
		# Pequena preparação antes do toque, como no futebol de verdade.
		var contact := 0.26 if long else 0.19
		var kind_p: StringName = &"long_pass" if long else &"pass"
		var hv0 := get_flat_velocity()
		if not long and hv0.length() > 2.4 and kdir != Vector3.ZERO and hv0.normalized().dot(kdir) > 0.35 \
				and AnimationCatalog.has_clip(&"shoot"):
			# CORRENDO: toque de passe na própria passada da corrida (clipe de
			# chute em corrida) — o corpo segue com o embalo, sem frear seco.
			kind_p = &"run_pass"
			contact = 0.17
		_begin_action(kind_p, contact, contact + 0.22, power, aim, target, 0.5)
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
	var map := {&"pass": &"pass_short", &"long_pass": &"pass_long", &"shoot": &"shoot", &"shoot_power": &"shoot_power", &"chip": &"pass_short", &"run_pass": &"shoot"}
	_kick_logical = map.get(_action_kind, &"")
	if _kick_logical == &"" or not AnimationCatalog.has_clip(_kick_logical):
		_kick_logical = &""
		return
	if _kick_mirror and AnimationCatalog.has_clip(AnimationCatalog.mirrored_name(_kick_logical)):
		_kick_logical = AnimationCatalog.mirrored_name(_kick_logical)
	var sp := PlayerAnimationController.ACTION_SPEED
	_kick_seek = maxf(AnimationCatalog.contact_time(_kick_logical) - _action_contact * sp, 0.0)


func _begin_action(kind: StringName, contact: float, length: float, power: float,
		aim: Vector3, target: Node3D, move_factor: float) -> void:
	ball_control.foot.cancel() # um toque de condução pendente não dispara mais
	_turn_yaw_on = false
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
	_kick_ik = false
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
			speed = _turn_speed_k
		var anim_t := _action_seek + _action_time * speed
		var rv := AnimationCatalog.root_motion_velocity(_action_logical, anim_t)
		var hips_h := 0.85
		if visual != null and visual.has_method("get_hips_height"):
			hips_h = visual.call("get_hips_height")
		var fr := facing
		if _turn_yaw_on:
			# o corpo gira JUNTO com o clipe (sem pulo no fim da virada)
			fr = _turn_start_facing
			facing = _turn_start_facing.rotated(Vector3.UP, AnimationCatalog.root_yaw_at(_action_logical, anim_t)).normalized()
			_action_face = facing
			rotation.y = atan2(-facing.x, -facing.z)
		var left := Vector3.UP.cross(fr)
		var target := (fr * rv.z + left * rv.x) * hips_h * speed
		hv = hv.move_toward(target, acceleration * 3.0 * delta)
		if _action_kind == &"spin" or _action_kind == &"run_stop":
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
	elif not _action_contact_done and _action_kind in AERIAL_KINDS:
		# Apertou PASSE/CHUTE com a bola ainda vindo: vira cabeceio de primeira.
		if _action_kind == &"head_control" and _buffer_timer > 0.0 \
				and _buffer_action in [PlayerIntent.Action.PASS, PlayerIntent.Action.SHOOT] \
				and _action_contact - _action_time > 0.15 and AnimationCatalog.has_clip(&"header"):
			_action_kind = &"header"
			_action_aim = _buffer_aim
			_action_power = _buffer_power
			_action_precise = _buffer_action == PlayerIntent.Action.SHOOT
			_buffer_timer = 0.0
			action_started.emit(&"header")
		var remaining := maxf(_action_contact - _action_time, 0.05)
		var to := _aerial_point - global_position
		to.y = 0.0
		hv = hv.move_toward((to / remaining).limit_length(sprint_speed), acceleration * 3.0 * delta)
	elif not _action_contact_done and _action_kind == &"tackle":
		# bote: um passo rápido até a bola (o pé de apoio chega perto dela)
		var remaining_t := maxf(_action_contact - _action_time, 0.05)
		var to_b := ball_control.ball_offset()
		to_b -= to_b.normalized() * minf(0.55, to_b.length())
		hv = hv.move_toward((to_b / remaining_t).limit_length(sprint_speed), acceleration * 3.0 * delta)
	elif not _action_contact_done and _is_kick_action():
		# Preparação do chute/passe: acompanhar a bola até o pé de apoio,
		# para que no contato ela esteja ao alcance (sem "furar").
		var remaining := maxf(_action_contact - _action_time, 0.05)
		if not _kick_ik and remaining <= 0.14:
			# O pé que chuta vai até a bola com a superfície anatômica exata:
			# - Passe curto / chute colocado: chapa (INSIDE) ou três dedos (OUTSIDE) conforme ângulo
			# - Lançamento / chute forte: peito do pé (KICK)
			_kick_ik = true
			var kf := anim_controller.kick_foot(_action_kind)
			if kf == 0.0:
				kf = -1.0 if _kick_mirror else 1.0
			var kd := _action_face if _action_face != Vector3.ZERO else facing
			var right_f := facing.cross(Vector3.UP)
			var lat_kd := kd.dot(right_f)
			var k_mode := FootContact.Mode.KICK
			if _action_kind in [&"pass", &"run_pass"]:
				# Se o alvo sai para o lado de fora do pé de batida, usa três dedos (OUTSIDE); senão chapa (INSIDE).
				if lat_kd * kf < -0.14:
					k_mode = FootContact.Mode.OUTSIDE
				else:
					k_mode = FootContact.Mode.INSIDE
			elif _action_kind == &"chip":
				k_mode = FootContact.Mode.INSIDE
			elif _action_kind == &"shoot":
				if _action_power < 0.45 or _action_precise:
					k_mode = FootContact.Mode.OUTSIDE if lat_kd * kf < -0.18 else FootContact.Mode.INSIDE
				else:
					k_mode = FootContact.Mode.KICK
			ball_control.foot.begin(kf, kd, remaining, k_mode, Callable(), 0.07)
		var plant := ball_control.ball_offset() + ball.flat_velocity() * remaining
		var to_ball_dir := plant.normalized() if plant.length() > 0.01 else facing
		# Pé de apoio ao lado da bola: quem chuta de direita deixa a bola à direita.
		var side := anim_controller.kick_foot(_action_kind)
		plant -= to_ball_dir * minf(BallControl.FOOT_DISTANCE, plant.length())
		plant -= to_ball_dir.cross(Vector3.UP) * side * BallControl.KICK_FOOT_OFFSET
		if _kick_logical != &"":
			# Os passos de aproximação são os DA ANIMAÇÃO (o pé apoiado não
			# desliza); só a diferença até o ponto certo é corrigida, de leve.
			var sp := PlayerAnimationController.ACTION_SPEED
			var t_now := _kick_seek + _action_time * sp
			var t_hit := _kick_seek + _action_contact * sp
			var hh := 0.85
			if visual != null and visual.has_method("get_hips_height"):
				hh = visual.call("get_hips_height")
			var left_k := Vector3.UP.cross(facing)
			var rvk := AnimationCatalog.root_motion_velocity(_kick_logical, t_now)
			var base := (facing * rvk.z + left_k * rvk.x) * hh * sp
			var clip_d := AnimationCatalog.root_offset_at(_kick_logical, t_hit) - AnimationCatalog.root_offset_at(_kick_logical, t_now)
			var clip_disp := (facing * clip_d.z + left_k * clip_d.x) * hh
			var corr := ((plant - clip_disp) / remaining).limit_length(KICK_ADJUST_SPEED)
			var want_v := base + corr
			# inércia: o corpo não para seco (freia no máximo ~7 m/s²) e não
			# deixa a bola fugir (acompanha a bola que vai à frente)
			var bvel := ball.flat_velocity()
			var bdir := ball_control.ball_offset().normalized() if ball_control.ball_distance() > 0.05 else facing
			var b_along := bvel.dot(bdir)
			if want_v.dot(bdir) < b_along:
				want_v += bdir * (b_along - want_v.dot(bdir))
			var rate_k := acceleration * 2.5 if want_v.length() > hv.length() else 7.0
			hv = hv.move_toward(want_v, rate_k * delta)
		else:
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
			if not _turn_yaw_on:
				facing = _turn_target
				rotation.y = atan2(-facing.x, -facing.z)
			_turn_target = Vector3.ZERO
		_turn_yaw_on = false
	# Passe chegando no meio de uma virada/parada sem bola: interrompe para dominar.
	if state == State.ACTION and _action_kind in [&"turn_l", &"turn_r", &"walk_stop", &"run_stop"] \
			and ball != null and ball.pass_target == self and ball.possessor == null and ball.in_play \
			and ball.global_position.distance_to(global_position) < 3.5:
		state = State.MOVE
		if _turn_target != Vector3.ZERO and not _turn_yaw_on:
			var k := clampf(_action_time / maxf(_action_length, 0.01), 0.0, 1.0)
			facing = facing.rotated(Vector3.UP, facing.signed_angle_to(_turn_target, Vector3.UP) * k).normalized()
			rotation.y = atan2(-facing.x, -facing.z)
		_turn_target = Vector3.ZERO
		_turn_yaw_on = false
	# Parada brusca: se voltar a mexer o analógico (ou pedir passe/chute), sai da parada.
	if state == State.ACTION and (_action_kind == &"run_stop" or _action_kind == &"walk_stop") and \
			((_action_time > 0.25 and intent.move.length() > 0.5) or (_action_time > 0.1 and _has_pending_kick())):
		state = State.MOVE
	if state != State.ACTION and collision_mask != 3:
		collision_mask = 3


## Momento em que o pé encosta na bola. Na Etapa 3 a animação chama
## on_animation_contact() exatamente no quadro do contato.
func _do_contact() -> void:
	_action_contact_done = true
	match _action_kind:
		&"pass", &"long_pass", &"run_pass":
			var ok := false
			if _is_through_pass:
				ok = ball_control.execute_through_pass(_action_power, _action_aim, _action_lofted)
			else:
				ok = ball_control.execute_pass(_action_power, _action_aim, _action_target, _action_lofted)
			if ok:
				_restart_lock = false
			_is_through_pass = false
		&"chip":
			ball_control.execute_shot(_action_power, _action_aim, _action_precise, true)
		&"shoot", &"shoot_power":
			ball_control.execute_shot(_action_power, _action_aim, _action_precise, _action_lofted)
		&"dribble":
			if ball_control.execute_dribble(_action_aim):
				_burst_timer = 0.5
		&"tackle":
			ball_control.execute_tackle() # errou: só recupera o passo (sem cair)
		&"slide":
			ball_control.execute_slide_tackle()
		&"spin":
			ball_control.release_after_skill()
		&"recv_chest", &"recv_knee", &"head_control", &"header", &"header_jump":
			ball_control.aerial_touch(_action_kind, _aerial_height, _action_aim, _action_power, _action_precise)


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
	if ball_control.has_ball():
		return false # Com a bola: giro e condução 100% livres e fluidos (nunca trava em clipe de parada/virada)
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
	if ball != null and ball.pass_target == self and ball.possessor == null and ball.in_play:
		return false # passe chegando: nada de virada de clipe (o domínio vem primeiro)
	# IA: viradas animadas com moderação (senão fica lenta e repetitiva).
	var ai_turn_ok := is_human or _rng.randf() < 0.04
	var fetching := ball_control.has_ball() and in_len > 0.1 \
		and ball_control.approach_point(input.normalized()) != Vector3.INF
	if in_len > 0.6 and speed > (2.6 if is_human else 3.6) and ai_turn_ok and not fetching \
			and AnimationCatalog.has_clip(&"turn180"):
		# Com a bola, só vira "de clipe" se ela estiver no pé (a sola alcança);
		# senão primeiro freia e chega na bola.
		# (bola colada e não fugindo: senão a sola não alcança e a bola segue
		#  sozinha; nesse caso o jogador primeiro freia conduzindo)
		# Com a bola, a inversão é a PUXADA DE SOLA (BallControl), não o clipe.
		var ball_ok := not ball_control.has_ball()
		if hv.normalized().dot(input.normalized()) < -0.55 and ball_ok:
			_start_turn(&"turn180", &"turn180", input.normalized())
			return true
	if in_len > 0.6 and speed < 0.5 and not ball_control.has_ball() and ai_turn_ok:
		var ang := facing.signed_angle_to(input.normalized(), Vector3.UP)
		if absf(ang) > deg_to_rad(45.0) and absf(ang) < deg_to_rad(160.0) and AnimationCatalog.has_clip(&"turn_l"):
			var turned := facing.rotated(Vector3.UP, signf(ang) * PI * 0.5)
			_start_turn(&"turn_l" if ang > 0.0 else &"turn_r", &"turn_l" if ang > 0.0 else &"turn_r", turned)
			return true
	var bc0 := ball_control
	var has_b := bc0.has_ball()
	var ball_at_foot := not has_b or (bc0.ball_distance() < 0.5 and bc0.ball_offset().dot(facing) > 0.05 \
		and absf(bc0.ball_offset().dot(facing.cross(Vector3.UP))) < 0.24 \
		and (ball.flat_velocity() - hv).length() < 1.2) # bola indo embora (1º toque longo): não para pra girar
	if in_len > 0.6 and ai_turn_ok and not fetching and ball_at_foot:
		var w := input.normalized()
		var vdir := hv.normalized() if speed > 0.3 else facing
		var ang_v := vdir.signed_angle_to(w, Vector3.UP) # + = esquerda
		# CORTE correndo (~40°): "Running Right Turn" (espelhado p/ esquerda).
		# (com a bola não: o toque de lado vem primeiro, com o pé certo, e o corpo
		#  acompanha a bola — sem girar o corpo antes do toque)
		if speed > 3.0 and absf(ang_v) > deg_to_rad(28.0) and absf(ang_v) < deg_to_rad(75.0) and not has_b \
				and AnimationCatalog.has_clip(&"cut_r") and _steady_time > 0.04:
			var left := ang_v > 0.0
			var lg: StringName = &"cut_r_m" if left else &"cut_r"
			var nd := facing.rotated(Vector3.UP, deg_to_rad(AnimationCatalog.turn_angle(lg)))
			_start_turn(&"cut_l" if left else &"cut_r", lg, nd, 1.0, false)
			if has_b:
				bc0.touch_towards(nd) # toque de lado com o pé certo no início do corte
			return true
		# VIRADA de 180° ANDANDO (devagar): "Walking Turn 180".
		if speed > 0.35 and speed < 2.4 and absf(ang_v) > deg_to_rad(140.0) and not has_b \
				and AnimationCatalog.has_clip(&"walk_turn180") and _steady_time > 0.04:
			var left2 := ang_v > 0.0
			_start_turn(&"walk_turn180_l" if left2 else &"walk_turn180_r",
				&"walk_turn180_m" if left2 else &"walk_turn180", w, 1.45, false)
			if has_b:
				bc0.drag_ball_to(w, 1.6)
			return true
		# GIRO PARADO com a bola (~55°): "Standing Cover Turn" com a sola na bola.
		if has_b and speed < 0.6:
			var ang_f := facing.signed_angle_to(w, Vector3.UP)
			if absf(ang_f) > deg_to_rad(35.0) and absf(ang_f) < deg_to_rad(85.0) \
					and AnimationCatalog.has_clip(&"stand_turn_r"):
				var left3 := ang_f > 0.0
				var lg3: StringName = &"stand_turn_r_m" if left3 else &"stand_turn_r"
				var nd3 := facing.rotated(Vector3.UP, deg_to_rad(AnimationCatalog.turn_angle(lg3)))
				_start_turn(&"stand_turn_l" if left3 else &"stand_turn_r", lg3, nd3, 1.2, false)
				bc0.drag_ball_around(nd3, _action_length * 0.8)
				return true
	# Parada andando (sem bola): "Stop Walking".
	if released and speed > 0.9 and speed < 2.8 and not has_b and AnimationCatalog.has_clip(&"walk_stop") \
			and bc0.ball_distance() > 2.0 and ai_turn_ok:
		_start_root_action(&"walk_stop", &"walk_stop", 0.0, facing)
		_action_length = minf(_action_length, 1.6)
		return true
	if released and speed > 3.2 and AnimationCatalog.has_clip(&"run_stop"):
		var bc := ball_control
		var ball_ok := bc.ball_distance() > 3.0
		if bc.has_ball():
			# Com a bola: parada brusca pisando na bola (ela para junto).
			# só com a bola NO PÉ (a sola alcança) e indo junto com o corpo
			ball_ok = bc.ball_distance() < 0.45 and bc.ball_offset().dot(facing) > 0.0 \
				and ball.flat_velocity().length() < hv.length() + 0.5
		if ball_ok and (is_human or not bc.has_ball()):
			_start_root_action(&"run_stop", &"run_stop", 0.0, facing)
			return true
	return false


func _start_turn(kind: StringName, logical: StringName, new_dir: Vector3, play_speed := TURN_SPEED_UP,
		drag := true) -> void:
	_turn_cooldown = 1.0
	_start_root_action(kind, logical, 0.0, facing)
	_turn_speed_k = play_speed
	_action_length /= play_speed
	_turn_target = Vector3(new_dir.x, 0.0, new_dir.z).normalized()
	_turn_start_facing = facing
	_turn_yaw_on = AnimationCatalog.has_root_yaw(logical)
	if drag and ball_control.has_ball():
		ball_control.drag_ball_to(_turn_target) # puxa a bola junto na virada


## Gesto de espera (só parado).
func play_gesture(kind: StringName, duration: float) -> void:
	if state == State.MOVE and get_horizontal_speed() < 0.3:
		gesture = kind
		_gesture_timer = duration


func _receive_pass(delta: float) -> void:
	# O recebedor PREPARA o domínio:
	#  - passe na direção dele: espera DE FRENTE, com a bola chegando na frente
	#    do corpo (um passo ao encontro), nunca no calcanhar;
	#  - passe em profundidade (a bola vai no mesmo sentido da corrida): corre
	#    AO LADO da linha da bola, no ritmo dela, e domina com a parte de dentro
	#    do pé já saindo.
	var target := _pass_intercept_point()
	var bv := ball.flat_velocity()
	var bdir := bv.normalized() if bv.length() > 0.5 else Vector3.ZERO
	var to_me := global_position - ball.global_position
	to_me.y = 0.0
	var through := bdir != Vector3.ZERO and to_me.length() > 0.5 and bdir.dot(to_me.normalized()) < 0.75 \
		and _receive_run_dir(bdir).dot(bdir) > 0.3
	_receiving_through = through
	if through:
		# lado da linha da bola em que eu já estou (a bola passa pelo pé de dentro)
		var right := bdir.cross(Vector3.UP)
		var side := signf((global_position - target).dot(right))
		if side == 0.0:
			side = 1.0
		target += right * side * 0.22 - bdir * 0.25
	elif bdir != Vector3.ZERO:
		target -= bdir * 0.42 # a bola chega na FRENTE do corpo
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	var desired := Vector3.ZERO
	var t_ball := _ball_time_to(target)
	if through:
		# corre junto: chega ao ponto na hora e segue no ritmo da bola
		var need := d / maxf(t_ball, 0.12)
		desired = (to / maxf(d, 0.01)) * clampf(need, 0.0, sprint_speed) if d > 0.1 else Vector3.ZERO
		if t_ball < 0.5:
			desired = desired.lerp(bdir * minf(bv.length(), sprint_speed), clampf(1.0 - t_ball / 0.5, 0.0, 1.0))
	elif d > 0.3:
		var need := d / maxf(t_ball, 0.15)
		var top := sprint_speed
		if t_ball < 0.6:
			top = 2.6 # chegando: passo ao encontro, controlado
		desired = to / d * clampf(need, 0.8, top)
	var hv := get_flat_velocity()
	hv = hv.move_toward(desired, (acceleration if desired.length() > hv.length() else deceleration) * delta)
	velocity.x = hv.x
	velocity.z = hv.z


## Para onde o recebedor vai correr (analógico do humano ou rumo da bola).
func _receive_run_dir(bdir: Vector3) -> Vector3:
	var m := Vector3(intent.move.x, 0.0, intent.move.z)
	if m.length() > 0.3:
		return m.normalized()
	var hv := get_flat_velocity()
	if hv.length() > 1.5:
		return hv.normalized()
	return bdir


const AERIAL_KINDS: Array[StringName] = [&"recv_chest", &"recv_knee", &"header", &"head_control", &"header_jump"]
var _aerial_point := Vector3.ZERO
var _aerial_height := 0.0


## Bola alta vindo em mim: escolhe o domínio pela altura em que ela vai chegar
## (coxa, peito, cabeça) ou cabeceia (com PASSE/CHUTE apertado: de primeira).
## A ação começa antes, para o contato do clipe casar com a chegada da bola.
func _try_aerial_reception() -> bool:
	if ball == null or ball.possessor != null or not ball.in_play or is_goalkeeper():
		return false
	if not ball.can_be_claimed_by(self):
		return false
	var v := ball.flat_velocity()
	if v.length() < 1.5:
		return false
	var rel := ball.global_position - global_position
	rel.y = 0.0
	var mine := ball.pass_target == self or (is_human and rel.length() < 6.0)
	if not mine:
		return false
	var t := -rel.dot(v) / v.length_squared()
	if t < 0.05 or t > 1.6:
		return false
	var closest := rel + v * t
	if closest.length() > 0.9:
		return false
	var vy := ball.velocity_now().y
	var h := ball.global_position.y + vy * t - 0.5 * _gravity * t * t
	if h < 0.32 or h > 2.4:
		return false # rasteira (domínio normal) ou alta demais
	var kind: StringName
	var pending := _buffer_timer > 0.0 and _buffer_action in [PlayerIntent.Action.PASS, PlayerIntent.Action.SHOOT]
	if h < 0.75:
		kind = &"recv_knee"
	elif h < 1.35:
		kind = &"recv_chest"
	elif h < 2.0:
		kind = &"header" if pending else &"head_control"
	else:
		kind = &"header_jump"
	if not AnimationCatalog.has_clip(kind):
		return false
	var lead := AnimationCatalog.contact_time(kind) / PlayerAnimationController.ACTION_SPEED
	if t > lead + 0.03:
		return false # ainda cedo: o Player segue indo ao encontro (recepção normal)
	_begin_action(kind, t, t + 0.45, 1.0, Vector3.ZERO, null, 0.3)
	_action_face = -v.normalized()
	_aerial_point = global_position + closest - v.normalized() * 0.12
	_aerial_height = h
	if kind in [&"header", &"header_jump"] and pending:
		_action_aim = _buffer_aim
		_action_power = _buffer_power
		_action_precise = _buffer_action == PlayerIntent.Action.SHOOT
		_buffer_timer = 0.0
	return true


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
	if get_flat_velocity().dot(facing) < -1.3:
		return false # recuando rápido: vira e corre (sem passo de marcação para trás)
	return d < (MARK_RANGE_EXIT if _marking else MARK_RANGE)


## Condições que desligam a marcação na hora (sem esperar o tempo mínimo).
func _compute_marking_allowed() -> bool:
	return ball != null and ball.in_play and state == State.MOVE and not ball_control.has_ball()


var _side_hold_t := 0.0


## Virando correndo com a bola à frente: o corpo segura a direção até o toque
## de lado mandar a bola para o novo lado (no máximo ~0,45 s).
func _hold_for_side_touch(w: Vector3) -> bool:
	var hv := get_flat_velocity()
	var bv := ball.flat_velocity()
	var off := ball_control.ball_offset()
	var turning := hv.length() > 1.5 and hv.normalized().angle_to(w) > deg_to_rad(25.0)
	var ball_not_yet := bv.length() < 0.5 or bv.normalized().angle_to(w) > deg_to_rad(25.0)
	var ball_near_front := off.dot(hv.normalized()) > -0.05 and off.length() < 0.9
	if turning and ball_not_yet and ball_near_front and _side_hold_t < 0.45:
		_side_hold_t += get_physics_process_delta_time()
		return true
	_side_hold_t = 0.0
	return false


## Adversário colado (até 1,65 m) de quem está com a bola ou disputando espaço:
## direção até ele (ZERO se ninguém perto).
func _shield_threat() -> Vector3:
	var best := 1.65
	var dir := Vector3.ZERO
	for opp in get_opponents():
		if not opp.active:
			continue
		var off := opp.global_position - global_position
		off.y = 0.0
		if off.length() < best and off.length() > 0.05:
			best = off.length()
			dir = off / off.length()
	return dir


## Direção e intensidade (0..1) do jogo de corpo / proteção de bola para o LeanModifier.
func get_shield_info() -> Dictionary:
	var best_d := 1.15
	var threat_dir := Vector3.ZERO
	for opp in get_opponents():
		if not opp.active:
			continue
		var off := opp.global_position - global_position
		off.y = 0.0
		var d := off.length()
		if d < best_d and d > 0.05:
			best_d = d
			threat_dir = off / d
	if threat_dir == Vector3.ZERO or get_horizontal_speed() > 1.5:
		return {"dir": Vector3.ZERO, "weight": 0.0}
	var has_b := ball_control.has_ball()
	var near_b := ball != null and ball_control.ball_distance() < 1.1
	if not has_b and not near_b:
		return {"dir": Vector3.ZERO, "weight": 0.0}
	var prox := clampf(1.0 - (best_d - 0.50) / 0.65, 0.0, 1.0)
	var speed_k := clampf(1.0 - get_horizontal_speed() / 1.5, 0.0, 1.0)
	return {"dir": threat_dir, "weight": prox * speed_k * 0.75}


## Dados da ação atual para inclinação procedural de tronco e braços no LeanModifier.
func get_action_posture_info() -> Dictionary:
	if state != State.ACTION or _action_kind == &"":
		return {"kind": &"", "phase": 0.0, "power": 0.0, "side": 1.0}
	var ph := clampf(_action_time / maxf(_action_length, 0.05), 0.0, 1.0)
	var sd := -1.0 if _kick_mirror else 1.0
	return {"kind": _action_kind, "phase": ph, "power": _action_power, "side": sd}


## Alvo de olhar para o companheiro antes/durante um passe (olha para o colega sem virar o tronco).
func get_pass_gaze_target() -> Node3D:
	if state == State.ACTION and _action_kind in [&"pass", &"long_pass", &"run_pass"]:
		if _action_target != null:
			return _action_target
		var aim_d := Vector3(_action_aim.x, 0.0, _action_aim.z)
		var mate := ball_control.pick_pass_target(aim_d.normalized() if aim_d.length() > 0.2 else facing, 110.0)
		return mate
	if _buffer_timer > 0.0 and _buffer_action == PlayerIntent.Action.PASS:
		if _buffer_target != null:
			return _buffer_target
		var aim_b := Vector3(_buffer_aim.x, 0.0, _buffer_aim.z)
		return ball_control.pick_pass_target(aim_b.normalized() if aim_b.length() > 0.2 else facing, 110.0)
	return null


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
	# quem deu o carrinho levanta logo (não fica deitado)
	_action_length += AnimationCatalog.getup_duration(&"getup_b") * 0.8
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
	ball_control.foot.cancel()
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
