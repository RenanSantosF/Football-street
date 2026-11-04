class_name FootContact
extends RefCounted
## PÉ NA BOLA: nenhum toque acontece "no ar". Cada toque (condução, toque de
## lado, puxada de sola, domínio, passe, chute) é AGENDADO: a perna vai até a
## bola (IK por cima da animação) e a bola só muda de velocidade no instante
## em que o pé encosta nela. Depois a perna volta suavemente para a animação.

enum Phase { IDLE, REACH, HOLD, RELEASE }
## Como o pé encosta: parte de dentro (chapa), sola por cima da bola,
## chute (peito do pé), amortecer (recepção), ou parte externa (três dedos).
enum Mode { INSIDE = 0, SOLE = 1, KICK = 2, CUSHION = 3, OUTSIDE = 5 }

const ANKLE_HEIGHT := 0.075
const MAX_REACH := 0.88
const RELEASE_TIME := 0.16

var player: Player
var ball: Ball
var phase := Phase.IDLE
var side := 1.0
var mode := Mode.INSIDE
var dir := Vector3.FORWARD
var _t := 0.0
var _lead := 0.08
var _hold := 0.04
var _cb := Callable()
var _target := Vector3.ZERO
var _weight := 0.0
var _hold_while := Callable()
## Domínio: a posse só é tomada quando o pé encosta na bola.
var _claim := false
var _reachable := true
## O último contato aplicou o toque (pé alcançou a bola)?
var last_applied := false
var _shown := {1.0: 0.0, -1.0: 0.0}
## Deslocamento atual do corpo (mundo) para o pé chegar na bola.
var _shift := Vector3.ZERO
var _last_target := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}


static func get_physics_delta() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


func setup(p: Player, b: Ball) -> void:
	player = p
	ball = b


## O pé está indo/está na bola (não começar outro toque agora)?
func busy() -> bool:
	return phase == Phase.REACH or phase == Phase.HOLD


## Agenda um toque: o pé [param foot] chega na bola em [param lead] s e então
## [param on_contact] é chamado (aplica a velocidade na bola).
func begin(foot: float, d: Vector3, lead: float, m: Mode, on_contact: Callable, hold := 0.04,
		hold_while := Callable(), claim_on_contact := false) -> void:
	_claim = claim_on_contact
	side = 1.0 if foot >= 0.0 else -1.0
	dir = Vector3(d.x, 0.0, d.z).normalized() if Vector3(d.x, 0.0, d.z).length() > 0.01 else player.facing
	mode = m
	_lead = maxf(lead, 0.0)
	_hold = hold
	_cb = on_contact
	_hold_while = hold_while
	_t = 0.0
	phase = Phase.REACH
	if _lead <= 0.0:
		_contact()


func claiming() -> bool:
	return _claim


func cancel() -> void:
	if phase != Phase.IDLE:
		phase = Phase.RELEASE
		_t = 0.0


## Posição do tornozelo puro da animação (antes da IK).
func _raw_ankle(foot: float) -> Vector3:
	var v := player.visual
	if v == null:
		return player.global_position
	if v.has_method("get_raw_ankle_position"):
		return v.call("get_raw_ankle_position", foot)
	if v.has_method("get_ankle_position"):
		return v.call("get_ankle_position", foot)
	return player.global_position


## Lado do pé mais perto da bola NA ANIMAÇÃO (menos distorção da perna).
func nearest_foot() -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 1.0
	var b := ball.global_position
	# bola claramente de um lado: o pé desse lado (não cruza a perna)
	var lat := (b - player.global_position).dot(player.facing.cross(Vector3.UP))
	if absf(lat) > 0.12:
		return signf(lat)
	var r: Vector3 = _raw_ankle(1.0)
	var l: Vector3 = _raw_ankle(-1.0)
	return 1.0 if Vector2(r.x - b.x, r.z - b.z).length() <= Vector2(l.x - b.x, l.z - b.z).length() else -1.0


## Distância (no chão) entre o tornozelo da animação e a bola.
func foot_distance(foot: float) -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 0.0
	var a: Vector3 = _raw_ankle(foot)
	var b := ball.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ball_flat_dist() -> float:
	return Vector2(ball.global_position.x - player.global_position.x,
		ball.global_position.z - player.global_position.z).length()


## O corpo se move puramente pela física e inércia real (zero impulsos artificiais).
func body_correction() -> Vector3:
	return Vector3.ZERO


func update(delta: float) -> void:
	if phase == Phase.IDLE:
		if _shown[1.0] > 0.0 or _shown[-1.0] > 0.0 or _shift.length() > 0.001:
			_apply()
		return
	_t += delta
	match phase:
		Phase.REACH:
			_target = _target_now(maxf(_lead - _t, 0.0))
			var k := clampf(_t / maxf(_lead, 0.001), 0.0, 1.0)
			_weight = maxf(_weight, k * k * (3.0 - 2.0 * k))
			if _t >= _lead:
				if (not _reachable or (mode != Mode.KICK and _ik_cap() <= 0.25)) and _t < _lead + 0.14 \
						and not (_claim and _ball_flat_dist() < 0.52):
					pass
				else:
					_contact()
		Phase.HOLD:
			_weight = 1.0
			if mode == Mode.SOLE:
				_target = _target_now(0.0) # sola acompanha a bola presa
			var keep := _hold_while.is_valid() and bool(_hold_while.call())
			if _t >= _hold and not keep:
				phase = Phase.RELEASE
				_t = 0.0
		Phase.RELEASE:
			_weight = maxf(_weight - delta / RELEASE_TIME, 0.0)
			if _weight <= 0.0:
				phase = Phase.IDLE
	_apply()


const BODY_SHIFT_MAX := 0.045
## IK analítica de 2 ossos (sem torção de coxa/joelho) ligada no LeanModifier.
const USE_LEG_IK := true
const TOL_INSIDE := 0.18
const TOL_SOLE := 0.24
const TOL_CUSHION := 0.22
const WAIT_WINDOW := 0.3
const BODY_ADJUST_SPEED := 1.4
const IK_FULL := 0.32
const IK_MAX := 0.58
const IK_FULL_SOLE := 0.36
const IK_MAX_SOLE := 0.62


func _ik_cap() -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 1.0
	var a: Vector3 = _raw_ankle(side) - _shift
	var disp := maxf(a.distance_to(_target) - BODY_SHIFT_MAX, 0.0)
	var full := IK_FULL
	var mx := IK_MAX
	var rel := _target - player.global_position
	var fwd := rel.dot(player.facing)
	var lat_s := rel.dot(player.facing.cross(Vector3.UP)) * side
	# Impede que a perna atravesse o eixo central do corpo.
	var crossing := lat_s < -0.18
	if crossing or fwd < -0.24:
		return 0.0
	if mode == Mode.CUSHION:
		full = 0.40
		mx = 0.68
	elif mode == Mode.SOLE:
		full = IK_FULL_SOLE
		mx = IK_MAX_SOLE
	elif mode in [Mode.INSIDE, Mode.OUTSIDE]:
		full = 0.38
		mx = 0.64
	elif mode == Mode.KICK:
		full = 0.44
		mx = 0.74
	return clampf(1.0 - (disp - full) / maxf(mx - full, 0.05), 0.0, 0.92)


## Distância (no chão) entre o tornozelo da ANIMAÇÃO do pé [param foot] e o
## ponto onde ele teria que estar para tocar a bola na direção [param d].
func ideal_distance(foot: float, d: Vector3, m: Mode) -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 0.0
	var keep_side := side
	var keep_dir := dir
	var keep_mode := mode
	side = foot
	dir = Vector3(d.x, 0.0, d.z).normalized() if Vector3(d.x, 0.0, d.z).length() > 0.01 else player.facing
	mode = m
	var t := _target_now(0.0)
	side = keep_side
	dir = keep_dir
	mode = keep_mode
	var a: Vector3 = _raw_ankle(foot)
	return Vector2(a.x - t.x, a.z - t.z).length()


func _contact() -> void:
	_target = _target_now(0.0)
	var d := Vector2(ball.global_position.x - player.global_position.x,
		ball.global_position.z - player.global_position.z).length()
	var natural := mode == Mode.KICK or _ik_cap() > 0.15 or (_claim and d < 0.65) or d < 0.85
	var mine := ball.possessor == player or (_claim and ball.possessor == null and ball.can_be_claimed_by(player))
	if mine and ball.in_play and d < 1.25 \
			and ball.global_position.y < 0.55 and _reachable and natural:
		if _claim and ball.possessor != player:
			ball.claim(player)
		if _cb.is_valid():
			_cb.call()
		last_applied = true
	else:
		last_applied = false
		if _claim:
			_cb = Callable()
			phase = Phase.RELEASE
			_t = 0.0
			return
	_cb = Callable()
	phase = Phase.HOLD
	_weight = 1.0
	_t = 0.0


## Onde o tornozelo tem que estar para o pé encostar na bola daqui a [param t] s.
func _target_now(t: float) -> Vector3:
	var b := ball.predict_ground_position(t) if ball.global_position.y < 0.3 else ball.global_position
	b.y = ball.global_position.y
	var right := dir.cross(Vector3.UP)
	var p: Vector3
	match mode:
		Mode.SOLE:
			p = b - dir * 0.05 + Vector3.UP * 0.09
		Mode.KICK:
			p = b - dir * 0.13 + right * side * 0.02
			p.y = maxf(b.y - 0.02, ANKLE_HEIGHT)
		Mode.CUSHION:
			p = b + dir * 0.12 + right * side * 0.03
			p.y = ANKLE_HEIGHT
		Mode.OUTSIDE:
			# parte externa do pé (três dedos): atrás da bola e levemente por dentro
			p = b - dir * 0.13 - right * side * 0.035
			p.y = ANKLE_HEIGHT
		_:
			# parte de dentro do pé (chapa): atrás da bola, um pouco do lado do pé
			p = b - dir * 0.14 + right * side * 0.03
			p.y = ANKLE_HEIGHT
	var v := player.visual
	_reachable = true
	if v != null and v.has_method("get_hip_position"):
		var hip: Vector3 = v.call("get_hip_position", side)
		var to := p - hip
		if to.length() > MAX_REACH:
			_reachable = to.length() < MAX_REACH + 0.20
			p = hip + to.normalized() * MAX_REACH
	return p


func _apply() -> void:
	var v := player.visual
	if v == null or not v.has_method("set_foot_target"):
		return
	var cap := _ik_cap() if phase == Phase.REACH or phase == Phase.HOLD else 0.92
	var dt := get_physics_delta()
	if phase == Phase.HOLD:
		_shown[side] = cap
	elif phase == Phase.REACH:
		_shown[side] = _weight * cap
	else:
		_shown[side] = move_toward(_shown[side], _weight * cap, dt * 11.0)
	_shown[-side] = move_toward(_shown[-side], 0.0, dt * 11.0)
	if v.position != Vector3.ZERO:
		v.position = Vector3.ZERO
	v.call("set_foot_target", side, _target, _shown[side], player.facing, int(mode))
	v.call("set_foot_target", -side, _last_target[-side], _shown[-side], player.facing, int(mode))
	_last_target[side] = _target
