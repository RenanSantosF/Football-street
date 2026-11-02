class_name FootContact
extends RefCounted
## PÉ NA BOLA: nenhum toque acontece "no ar". Cada toque (condução, toque de
## lado, puxada de sola, domínio, passe, chute) é AGENDADO: a perna vai até a
## bola (IK por cima da animação) e a bola só muda de velocidade no instante
## em que o pé encosta nela. Depois a perna volta suavemente para a animação.

enum Phase { IDLE, REACH, HOLD, RELEASE }
## Como o pé encosta: parte de dentro/peito do pé atrás da bola, sola por
## cima da bola, chute (peito do pé), amortecer (pé na frente da bola que vem).
enum Mode { INSIDE, SOLE, KICK, CUSHION }

const ANKLE_HEIGHT := 0.075
const MAX_REACH := 0.86
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
var _reachable := true
## O último contato aplicou o toque (pé alcançou a bola)?
var last_applied := false


func setup(p: Player, b: Ball) -> void:
	player = p
	ball = b


## O pé está indo/está na bola (não começar outro toque agora)?
func busy() -> bool:
	return phase == Phase.REACH or phase == Phase.HOLD


## Agenda um toque: o pé [param foot] chega na bola em [param lead] s e então
## [param on_contact] é chamado (aplica a velocidade na bola).
func begin(foot: float, d: Vector3, lead: float, m: Mode, on_contact: Callable, hold := 0.04,
		hold_while := Callable()) -> void:
	side = foot
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


func cancel() -> void:
	if phase != Phase.IDLE:
		phase = Phase.RELEASE
		_t = 0.0


## Lado do pé mais perto da bola NA ANIMAÇÃO (menos distorção da perna).
func nearest_foot() -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 1.0
	var b := ball.global_position
	var r: Vector3 = v.call("get_ankle_position", 1.0)
	var l: Vector3 = v.call("get_ankle_position", -1.0)
	return 1.0 if Vector2(r.x - b.x, r.z - b.z).length() <= Vector2(l.x - b.x, l.z - b.z).length() else -1.0


## Distância (no chão) entre o tornozelo da animação e a bola.
func foot_distance(foot: float) -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 0.0
	var a: Vector3 = v.call("get_ankle_position", foot)
	var b := ball.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func update(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_t += delta
	match phase:
		Phase.REACH:
			_target = _target_now(maxf(_lead - _t, 0.0))
			var k := clampf(_t / maxf(_lead, 0.001), 0.0, 1.0)
			_weight = maxf(_weight, k * k * (3.0 - 2.0 * k))
			if _t >= _lead:
				# Bola ainda fora do alcance da perna: espera um pouco mais
				# (o corpo continua chegando) em vez de tocar "de longe".
				if not _reachable and _t < _lead + 0.14:
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


func _contact() -> void:
	_target = _target_now(0.0)
	# Só toca se a bola continua comigo e de fato ao alcance do pé.
	var d := Vector2(ball.global_position.x - player.global_position.x,
		ball.global_position.z - player.global_position.z).length()
	# O pé tem que alcançar de verdade (sem toque "de longe").
	if _cb.is_valid() and ball.possessor == player and ball.in_play and d < 1.25 \
			and ball.global_position.y < 0.5 and _reachable:
		_cb.call()
		last_applied = true
	else:
		last_applied = false
	_cb = Callable()
	phase = Phase.HOLD
	_t = 0.0


## Onde o tornozelo tem que estar para o pé encostar na bola daqui a [param t] s.
func _target_now(t: float) -> Vector3:
	var b := ball.predict_ground_position(t) if ball.global_position.y < 0.3 else ball.global_position
	b.y = ball.global_position.y
	var right := dir.cross(Vector3.UP)
	var p: Vector3
	match mode:
		Mode.SOLE:
			p = b - dir * 0.05 + Vector3.UP * 0.1
		Mode.KICK:
			p = b - dir * 0.13 + right * side * 0.02
			p.y = maxf(b.y - 0.02, ANKLE_HEIGHT)
		Mode.CUSHION:
			p = b + dir * 0.12 + right * side * 0.03
			p.y = ANKLE_HEIGHT
		_:
			# parte de dentro do pé: atrás da bola, um pouco do lado do pé
			p = b - dir * 0.14 + right * side * 0.03
			p.y = ANKLE_HEIGHT
	# a perna não estica além do alcance
	var v := player.visual
	_reachable = true
	if v != null and v.has_method("get_hip_position"):
		var hip: Vector3 = v.call("get_hip_position", side)
		var to := p - hip
		if to.length() > MAX_REACH:
			_reachable = to.length() < MAX_REACH + 0.08
			p = hip + to.normalized() * MAX_REACH
	return p


func _apply() -> void:
	var v := player.visual
	if v == null or not v.has_method("set_foot_target"):
		return
	v.call("set_foot_target", side, _target, _weight, player.facing)
	v.call("set_foot_target", -side, _target, 0.0, player.facing)
