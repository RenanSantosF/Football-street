class_name BallControl
extends Node
## Interação jogador ↔ bola: domínio, condução por toques, passe, chute,
## drible básico, desarme e desvios no corpo.
##
## CONDUÇÃO: a bola não fica grudada. O jogador dá toques periódicos que a
## empurram alguns palmos à frente (distância varia com a velocidade e com um
## pouco de aleatoriedade); entre os toques ela rola livre. Se o jogador muda
## de direção, o próximo toque já sai na nova direção. Se a bola escapa além do
## alcance, a posse é perdida e qualquer um pode pegá-la.

const CONTROL_RADIUS := 0.75
const GK_CONTROL_RADIUS := 1.05
const CONTROL_MAX_HEIGHT := 0.9
const GK_CONTROL_MAX_HEIGHT := 1.9
const MAX_CONTROL_SPEED := 12.0
const GK_SAFE_CATCH_SPEED := 10.0
const KICK_REACH := 1.0
const KICK_MAX_HEIGHT := 0.9
const TOUCH_REACH := 0.8
const FOOT_DISTANCE := 0.42
const LOSE_RADIUS := 2.5
const BODY_RADIUS := 0.3
const GK_BODY_RADIUS := 0.55
const TACKLE_RANGE := 1.5
const LONG_PASS_POWER := 0.55
## Distância lateral entre o centro do corpo e a bola no chute (pé de chute).
const KICK_FOOT_OFFSET := 0.13
## Condução: espera até um pé da animação chegar perto da bola para tocar.
const FOOT_TOUCH_RADIUS := 0.32
const MAX_TOUCH_WAIT := 0.3

var player: Player
var ball: Ball

var _since_touch := 10.0
var _since_contact := 10.0
var _foot_side := 1.0
var _save_rolled := false
var _touch_wait := 0.0
## O último toque saiu por tempo esgotado (nenhum pé chegou perto)?
var last_touch_forced := false
var _rng := RandomNumberGenerator.new()


func setup(p: Player, b: Ball) -> void:
	player = p
	ball = b
	_rng.randomize()


func has_ball() -> bool:
	return ball != null and ball.possessor == player


func physics_update(delta: float) -> void:
	if ball == null:
		return
	_since_touch += delta
	_since_contact += delta
	if not ball.in_play:
		return
	if has_ball():
		# Durante uma ação (chute, passe, drible) ou com chute pendente, sem toques de condução.
		if player.state == Player.State.MOVE and not player._has_pending_kick():
			_conduct(delta)
		elif ball_distance() > LOSE_RADIUS:
			ball.release()
	else:
		_try_gain_control()
		if not has_ball():
			_body_contact()


# --- Consultas ---------------------------------------------------------------

func ball_offset() -> Vector3:
	return _flat(ball.global_position - player.global_position)


func ball_distance() -> float:
	return ball_offset().length()


func can_kick() -> bool:
	if ball == null or not ball.in_play or not ball.can_be_kicked_by(player):
		return false
	return ball_distance() <= KICK_REACH and ball.global_position.y <= KICK_MAX_HEIGHT


## Com a posse e correndo atrás da bola: pode iniciar o chute um pouco antes,
## porque na preparação o jogador continua se aproximando dela.
func can_start_kick_on_run() -> bool:
	if not has_ball() or not ball.in_play or ball.global_position.y > KICK_MAX_HEIGHT:
		return false
	var off := ball_offset()
	if off.length() > KICK_REACH + 0.5 or off.dot(player.get_flat_velocity()) <= 0.0:
		return false
	# Só se estiver alcançando a bola (ela não está fugindo mais rápido que ele).
	var dir := off.normalized()
	return (ball.flat_velocity() - player.get_flat_velocity()).dot(dir) < 0.8


func find_tackle_target() -> Player:
	var carrier := ball.possessor
	if carrier == null or carrier.team == player.team:
		return null
	if _flat(carrier.global_position - player.global_position).length() > TACKLE_RANGE:
		return null
	return carrier


## Velocidade extra para o jogador alcançar a bola que rolou à frente.
func catch_up_velocity(dir: Vector3) -> Vector3:
	if not has_ball():
		return Vector3.ZERO
	var off := ball_offset()
	var along := off.dot(dir)
	var right := dir.cross(Vector3.UP)
	var v := Vector3.ZERO
	if along > FOOT_DISTANCE + 0.45:
		v += dir * clampf((along - FOOT_DISTANCE - 0.45) * 1.6, 0.0, 2.0)
	if along > 0.0:
		v += right * clampf(off.dot(right) * 1.2, -0.8, 0.8)
	return v


# --- Domínio, condução e contato -------------------------------------------------

func _try_gain_control() -> void:
	if player.state != Player.State.MOVE or not ball.can_be_claimed_by(player):
		return
	var gk := player.is_goalkeeper()
	var d := ball_distance()
	if d > (GK_CONTROL_RADIUS if gk else CONTROL_RADIUS):
		_save_rolled = false
		return
	if ball.global_position.y > (GK_CONTROL_MAX_HEIGHT if gk else CONTROL_MAX_HEIGHT):
		return
	var bv := ball.velocity_now()
	var rel_speed := (bv - player.velocity).length()
	if gk:
		if rel_speed > GK_SAFE_CATCH_SPEED:
			if _save_rolled:
				return
			_save_rolled = true
			var chance := clampf(1.0 - (rel_speed - GK_SAFE_CATCH_SPEED) / 20.0, 0.35, 0.95)
			if _rng.randf() > chance:
				_deflect_save(bv)
				return
	elif rel_speed > MAX_CONTROL_SPEED:
		return

	ball.claim(player)
	var pv := _flat(player.velocity)
	var settle := pv + player.facing * (0.5 if pv.length() > 1.0 else 0.0)
	ball.touch(settle, player)
	_since_touch = 0.0
	player.notify_touch(&"receive")


func _deflect_save(bv: Vector3) -> void:
	var out := Vector3(-bv.x * 0.35, absf(bv.y) * 0.3 + 1.5, bv.z * 0.5 + _rng.randf_range(-3.0, 3.0))
	ball.touch(out, player)
	ball.set_ignore(player, 0.35)
	_since_contact = 0.0
	player.notify_touch(&"save")


func _body_contact() -> void:
	if _since_contact < 0.12 or ball.is_ignoring(player):
		return
	var off := ball_offset()
	var d := off.length()
	var r := (GK_BODY_RADIUS if player.is_goalkeeper() else BODY_RADIUS) + Ball.RADIUS
	var h := ball.global_position.y
	if d > r or d < 0.001 or h > 1.75:
		return
	var n := off / d
	var bv := ball.velocity_now()
	var vn := (bv - player.velocity).dot(n)
	if vn >= 0.0:
		return
	var new_v := bv - n * vn * 1.25
	new_v.x *= 0.85
	new_v.z *= 0.85
	ball.touch(new_v, player)
	_since_contact = 0.0
	player.notify_touch(&"body")


func _conduct(delta: float) -> void:
	var off := ball_offset()
	var d := off.length()
	if d > LOSE_RADIUS or ball.global_position.y > 1.3:
		ball.release()
		return
	if d > TOUCH_REACH:
		return # correndo atrás da bola: catch_up_velocity() cuida disso

	var pv := _flat(player.velocity)
	var speed := pv.length()
	var move_dir := _flat(player.intent.move)
	var bv := _flat(ball.velocity_now())

	if speed < 0.6 and move_dir.length() < 0.15:
		# Parado: pisa na bola para segurá-la perto do pé.
		if bv.length() > 0.35 and _since_touch > 0.25:
			ball.touch(bv * 0.15, player)
			_since_touch = 0.0
			player.notify_touch(&"trap")
		return

	if _since_touch < 0.22:
		return
	var dir := move_dir.normalized() if move_dir.length() > 0.15 else player.facing
	var right := dir.cross(Vector3.UP)
	var along := off.dot(dir)
	var lateral := off.dot(right)
	var rel_along := (bv - pv).dot(dir)
	var behind := along < FOOT_DISTANCE + 0.45 and rel_along < 0.4
	var drifting := absf(lateral) > 0.35
	var mismatch := bv.length() > 0.5 and bv.normalized().dot(dir) < 0.75
	if not (behind or drifting or mismatch):
		_touch_wait = 0.0
		return
	# Sincronia com a animação: o toque sai quando um pé passa perto da bola
	# (com limite de espera, para nunca perder o controle por causa disso).
	if along > FOOT_DISTANCE - 0.1 and _touch_wait < MAX_TOUCH_WAIT and not _foot_near_ball():
		_touch_wait += delta
		return
	last_touch_forced = _touch_wait >= MAX_TOUCH_WAIT
	_touch_wait = 0.0
	_do_touch(dir, speed, lateral)


func _foot_near_ball() -> bool:
	var feet := player.get_foot_positions()
	if feet.is_empty():
		return true # sem modelo animado: toca imediatamente
	var b := ball.global_position
	var fwd := player.facing
	var p := player.global_position
	for f in feet:
		# Pé baixo, perto da bola e à frente do corpo (não toca com o calcanhar).
		var foot_along := (f - p).dot(fwd)
		if f.y < 0.35 and Vector2(f.x - b.x, f.z - b.z).length() < FOOT_TOUCH_RADIUS \
				and foot_along > 0.05 and foot_along <= (b - p).dot(fwd) + 0.02:
			return true
	return false


func _do_touch(dir: Vector3, speed: float, lateral: float) -> void:
	# "lead" = quanto a bola se afasta à frente do ponto do toque.
	var lead := lerpf(0.6, 1.1, clampf(speed / player.jog_speed, 0.0, 1.0))
	if player.intent.sprint and speed > player.jog_speed * 0.8:
		lead = lerpf(1.1, 1.6, clampf((speed - player.jog_speed) / (player.sprint_speed - player.jog_speed), 0.0, 1.0))
	lead *= _rng.randf_range(0.85, 1.15)
	# Perto da lateral ou do fundo: toque curto e sem empurrar a bola para fora.
	var bp := ball.global_position
	var line_gap := minf(Field.HALF_WIDTH - absf(bp.z), Field.HALF_LENGTH - absf(bp.x))
	if line_gap < 1.2:
		lead *= lerpf(0.5, 1.0, clampf(line_gap / 1.2, 0.0, 1.0))
		if Field.HALF_WIDTH - absf(bp.z) < 1.2 and signf(dir.z) == signf(bp.z):
			dir = Vector3(dir.x, 0.0, dir.z * 0.3)
			dir = dir.normalized() if dir.length() > 0.1 else player.facing
	var push := sqrt(2.0 * ball.rolling_resistance * lead)
	# Usa a velocidade que o jogador está BUSCANDO (ele pode estar acelerando).
	var target_speed := player.intent.move.length() * player.ball_speed_factor \
		* (player.sprint_speed if player.intent.sprint else player.jog_speed)
	var base := maxf(_flat(player.velocity).dot(dir), minf(target_speed, speed + 0.8))
	_foot_side = -_foot_side
	var side := clampf(-lateral * 2.0, -1.5, 1.5) + _foot_side * 0.12
	ball.touch(dir * (base + push) + dir.cross(Vector3.UP) * side, player)
	_since_touch = 0.0
	player.notify_touch(&"dribble_touch")


# --- Ações com a bola ------------------------------------------------------------

func execute_pass(power: float, aim: Vector3, target: Node3D) -> bool:
	if not can_kick():
		return false
	var from := ball.global_position
	var dir := _aim_dir(aim)
	var mate := target as Player
	if mate == null:
		mate = pick_pass_target(dir)
	var long := power >= LONG_PASS_POWER
	var vel: Vector3
	if mate != null:
		var dest := _lead_target(mate, from)
		var dist := _flat(dest - from).length()
		if long or dist > 15.0:
			vel = lofted_velocity(from, from + _flat(dest - from) * 0.9, lerpf(22.0, 35.0, power))
		else:
			vel = ground_pass_velocity(from, dest, lerpf(2.5, 5.5, power))
	else:
		var dest := from + dir * lerpf(7.0, 18.0, power)
		vel = lofted_velocity(from, dest, 30.0) if long else ground_pass_velocity(from, dest, 1.0)
	var err := deg_to_rad(2.0 + 3.0 * power)
	vel = vel.rotated(Vector3.UP, _rng.randf_range(-err, err))
	ball.kick(vel, Vector3.ZERO, player)
	player.notify_touch(&"pass")
	GameEvents.ball_kicked.emit(player, &"long_pass" if long else &"pass", power)
	return true


func execute_shot(power: float, aim: Vector3) -> bool:
	if not can_kick():
		return false
	var goal_x := Field.goal_line_x(Team.other(player.team))
	var from := ball.global_position
	var ty := _rng.randf_range(0.2, 0.85)
	var target := Vector3(goal_x, ty, _choose_shot_z(from, goal_x, aim))
	var speed := lerpf(11.0, 24.0, power)
	var flat_to := _flat(target - from)
	var d := maxf(flat_to.length(), 0.5)
	var dir := flat_to / d
	# Imprecisão: maior com força alta, bola longe do pé ou corpo desalinhado.
	var spread := deg_to_rad(lerpf(1.5, 6.5, power))
	if ball_distance() > 0.7:
		spread *= 1.3
	if player.facing.dot(dir) < 0.3:
		spread *= 1.6
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var t := d / speed
	var vy := (ty - from.y) / t + 0.5 * g * t
	vy += _rng.randf_range(-0.4, 1.2) * power
	var spin := Vector3.UP * _rng.randf_range(-8.0, 8.0) * power
	ball.kick(dir * speed + Vector3.UP * vy, spin, player)
	player.notify_touch(&"shoot")
	GameEvents.ball_kicked.emit(player, &"shoot", power)
	return true


## Drible básico (Etapa 1): toque mais longo/lateral + arrancada.
## A Etapa 4 troca isto pelo DribbleSystem completo (pedalada, cortes, finta).
func execute_dribble(aim: Vector3) -> bool:
	if not has_ball() or ball_distance() > KICK_REACH:
		return false
	var dir := _aim_dir(aim)
	var cut := player.facing.dot(dir) < 0.8
	var base := maxf(_flat(player.velocity).dot(dir), 0.0)
	ball.touch(dir * (base + (2.6 if cut else 3.6)), player)
	_since_touch = 0.0
	player.notify_touch(&"dribble")
	return true


func execute_tackle() -> bool:
	var carrier := find_tackle_target()
	if carrier == null or ball_distance() > TACKLE_RANGE + 0.2:
		return false
	var chance := 0.55
	if carrier.state == Player.State.ACTION:
		chance += 0.1
	if carrier.get_horizontal_speed() > carrier.jog_speed:
		chance -= 0.15
	var from_carrier := _flat(player.global_position - carrier.global_position).normalized()
	if carrier.facing.dot(from_carrier) < -0.3:
		chance -= 0.15 # vindo por trás
	if _rng.randf() > chance:
		return false
	var poke := _flat(player.global_position - ball.global_position).normalized()
	if poke.length() < 0.1:
		poke = -player.facing
	poke = poke.rotated(Vector3.UP, _rng.randf_range(-1.0, 1.0))
	ball.kick(poke * _rng.randf_range(2.5, 4.5), Vector3.ZERO, player, 0.1)
	carrier.stumble(0.45)
	GameEvents.ball_kicked.emit(player, &"tackle", 0.5)
	return true


func pick_pass_target(dir: Vector3) -> Player:
	var best: Player = null
	var best_score := -INF
	for mate in player.get_teammates():
		var to := _flat(mate.global_position - player.global_position)
		var d := to.length()
		if d < 1.5:
			continue
		var ang := dir.angle_to(to / d)
		if ang > deg_to_rad(70.0):
			continue
		var score := -ang * 2.0 - d * 0.04
		if mate.is_goalkeeper():
			score -= 0.6
		if score > best_score:
			best_score = score
			best = mate
	return best


static func ground_pass_velocity(from: Vector3, to: Vector3, end_speed: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := flat.length()
	if d < 0.01:
		return Vector3.ZERO
	var a := 1.6 # desaceleração média: rolamento (1,1) + arrasto do ar aproximado
	var v0 := clampf(sqrt(end_speed * end_speed + 2.0 * a * d), 3.0, 22.0)
	return flat / d * v0


static func lofted_velocity(from: Vector3, to: Vector3, angle_deg: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := maxf(flat.length(), 0.5)
	var theta := deg_to_rad(angle_deg)
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var v := sqrt(g * d / sin(2.0 * theta)) * 1.04
	return flat / d * v * cos(theta) + Vector3.UP * v * sin(theta)


func _lead_target(mate: Player, from: Vector3) -> Vector3:
	var dest := mate.global_position
	for i in 2:
		var t := _flat(dest - from).length() / 11.0
		dest = mate.global_position + mate.get_flat_velocity() * t * 0.8
	return Field.clamp_inside(Vector3(dest.x, 0.0, dest.z), 0.3)


func _choose_shot_z(from: Vector3, goal_x: float, aim: Vector3) -> float:
	var limit := Field.GOAL_HALF_WIDTH - 0.18
	if aim.length() > 0.2 and absf(aim.x) > 0.05 and signf(aim.x) == signf(goal_x - from.x):
		var t := (goal_x - from.x) / aim.x
		return clampf(from.z + aim.z * t, -limit, limit)
	var gk := player.match_manager.get_goalkeeper(Team.other(player.team)) if player.match_manager else null
	var gz := gk.global_position.z if gk != null else 0.0
	var side := -signf(gz) if absf(gz) > 0.1 else (1.0 if _rng.randf() > 0.5 else -1.0)
	return side * limit * _rng.randf_range(0.5, 1.0)


func _aim_dir(aim: Vector3) -> Vector3:
	var a := _flat(aim)
	return a.normalized() if a.length() > 0.2 else player.facing


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
