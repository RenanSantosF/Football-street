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
## Domínio: a posse só é tomada quando o pé encosta na bola.
var _claim := false
var _reachable := true
## O último contato aplicou o toque (pé alcançou a bola)?
var last_applied := false
var _shown := {1.0: 0.0, -1.0: 0.0}
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


func claiming() -> bool:
	return _claim


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
		if _shown[1.0] > 0.0 or _shown[-1.0] > 0.0:
			_apply()
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
				if (not _reachable or (mode != Mode.KICK and _ik_cap() <= 0.35)) and _t < _lead + 0.16:
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


## Quanto a IK pode puxar a perna: só pequenas correções a partir da pose da
## animação (como nos jogos). Longe disso a perna NÃO estica — o toque espera
## a passada certa (o corpo é que se ajusta).
const IK_FULL := 0.16
const IK_MAX := 0.32
## Pisar na bola à frente (sola) é uma pose natural de perna levantada para a
## frente: aceita um pouco mais, mas só para a frente e pouco para o lado.
const IK_FULL_SOLE := 0.3
const IK_MAX_SOLE := 0.48


func _ik_cap() -> float:
	var v := player.visual
	if v == null or not v.has_method("get_ankle_position"):
		return 1.0
	var a: Vector3 = v.call("get_ankle_position", side)
	var disp := a.distance_to(_target)
	var full := IK_FULL
	var mx := IK_MAX
	var rel := _target - player.global_position
	var fwd := rel.dot(player.facing)
	var lat_s := rel.dot(player.facing.cross(Vector3.UP)) * side # >0 = do lado do próprio pé
	var crossing := lat_s < -0.08 # perna cruzando na frente do corpo: não
	if mode == Mode.CUSHION and fwd > -0.1 and absf(lat_s) < 0.4 and not crossing:
		# domínio: esticar a perna para matar a bola é natural
		full = 0.3
		mx = 0.52
	elif mode == Mode.SOLE and fwd > 0.05 and absf(lat_s) < 0.3 and not crossing:
		full = IK_FULL_SOLE
		mx = IK_MAX_SOLE
	elif player.get_horizontal_speed() < 1.6 and fwd > -0.05 and not crossing:
		# Devagar/parado: esticar a perna para tocar a bola do lado ou à frente
		# é natural (passada curta). Correndo, só correções pequenas.
		full = 0.26
		mx = 0.44
	return clampf(1.0 - (disp - full) / (mx - full), 0.0, 1.0)


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
	var a: Vector3 = v.call("get_ankle_position", foot)
	return Vector2(a.x - t.x, a.z - t.z).length()


func _contact() -> void:
	_target = _target_now(0.0)
	# Só toca se a bola continua comigo e de fato ao alcance do pé.
	var d := Vector2(ball.global_position.x - player.global_position.x,
		ball.global_position.z - player.global_position.z).length()
	# O pé tem que alcançar de verdade, com a perna numa pose natural.
	var natural := mode == Mode.KICK or _ik_cap() > 0.35
	var mine := ball.possessor == player or (_claim and ball.possessor == null and ball.can_be_claimed_by(player))
	if _cb.is_valid() and mine and ball.in_play and d < 1.25 \
			and ball.global_position.y < 0.5 and _reachable and natural:
		if _claim and ball.possessor != player:
			ball.claim(player)
		_cb.call()
		last_applied = true
	else:
		last_applied = false
		if OS.get_environment("DBGF") != "" and _cb.is_valid():
			var a: Vector3 = player.visual.call("get_ankle_position", side)
			print("SKIP mode=", mode, " cap=", snappedf(_ik_cap(), 0.01), " reach=", _reachable, " poss=", ball.possessor == player, " d=", snappedf(d, 0.01), " spd=", snappedf(player.get_horizontal_speed(), 0.1), " disp=", snappedf(a.distance_to(_target), 0.01), " rel=", (_target - player.global_position).snapped(Vector3.ONE * 0.01), " side=", side)
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
	var cap := _ik_cap() if phase == Phase.REACH or phase == Phase.HOLD else 1.0
	# peso de cada perna muda suave (a perna nunca "pula" de pose)
	var dt := get_physics_delta()
	_shown[side] = move_toward(_shown[side], _weight * cap, dt * 14.0)
	_shown[-side] = move_toward(_shown[-side], 0.0, dt * 9.0)
	v.call("set_foot_target", side, _target, _shown[side], player.facing)
	v.call("set_foot_target", -side, _last_target[-side], _shown[-side], player.facing)
	_last_target[side] = _target
