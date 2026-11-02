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

@export_group("Condução e Chute")
## Tempo entre os toques na bola na corrida (um toque a cada ~passada).
@export var dribble_tap_interval := 0.28
## Força do alinhamento suave da bola entre os toques (0 = desliga).
@export var dribble_pull := 1.0
## Distância em que a posse é perdida (bote, parede...).
@export var dribble_lose_distance := 1.7
## Tempo de alinhamento da bola no KickPoint durante a preparação do chute.
@export var kick_snap_time := 0.18
## Sem poder dominar de novo logo depois de chutar.
@export var kick_cooldown := 0.45

var player: Player
var ball: Ball
var dribble_point: Marker3D
var kick_point: Marker3D
var kick_point_left: Marker3D
var pickup_area: Area3D
var _grabbed := false
var _dribble_timer := 0.0
var _kick_snap_t := 0.0

var _since_touch := 10.0
var _since_contact := 10.0
var _foot_side := 1.0
var _save_rolled := false
var _touch_wait := 0.0
var _trapping := false
var _sole_on := false
var _carry_on := false
var _carry_frame := 0
## O pé que vai até a bola em cada toque (IK). Nenhum toque sem o pé encostar.
var foot := FootContact.new()
## Tempo entre decidir o toque e o pé encostar na bola.
const TOUCH_LEAD := 0.09
var _since_aerial := 10.0
## O último toque saiu por tempo esgotado (nenhum pé chegou perto)?
var last_touch_forced := false
var _rng := RandomNumberGenerator.new()
## Testes/laboratórios: força o resultado do carrinho (-1 = normal).
var debug_slide_trip := -1.0


func setup(p: Player, b: Ball) -> void:
	player = p
	ball = b
	_rng.randomize()
	foot.setup(p, b)
	# Nós dentro do Visual (giram junto com o jogador; frente = -Z).
	dribble_point = p.get_node_or_null("Visual/DribblePoint") as Marker3D
	kick_point = p.get_node_or_null("Visual/KickPoint") as Marker3D
	kick_point_left = p.get_node_or_null("Visual/KickPointLeft") as Marker3D
	pickup_area = p.get_node_or_null("Visual/PickupArea") as Area3D
	if pickup_area != null and not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
		pickup_area.body_entered.connect(_on_pickup_area_body_entered)


# --- Posse: exceção de colisão enquanto a bola está no pé -----------------------

func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body == ball and body.is_in_group("ball") and not has_ball():
		_try_gain_control()


## Ganhou a posse: o corpo (cápsula) deixa de colidir com a bola — ela não
## quica na canela de quem conduz — e a bola fica mais "amortecida" no pé.
func grab_ball() -> void:
	if _grabbed:
		return
	_grabbed = true
	player.add_collision_exception_with(ball)
	ball.linear_damp = 2.0


## Perdeu a posse (chute, passe, bote): rolamento livre de novo e a colisão com
## o corpo volta só depois de 0,25 s (a bola não bate na canela ao sair do pé).
func release_ball() -> void:
	if not _grabbed:
		return
	_grabbed = false
	ball.linear_damp = 0.0 # rolamento livre: a resistência dos bloquinhos fica na Ball
	var b := ball
	var p := player
	p.get_tree().create_timer(0.25, true, true).timeout.connect(func():
		if is_instance_valid(p) and is_instance_valid(b) and b.possessor != p:
			p.remove_collision_exception_with(b))


## A posse muda por vários caminhos (passe, bote, reinício...): sincroniza a
## exceção de colisão com quem é o dono da bola neste quadro.
func _sync_possession() -> void:
	if has_ball() and not _grabbed:
		grab_ball()
	elif not has_ball() and _grabbed:
		release_ball()


func has_ball() -> bool:
	return ball != null and ball.possessor == player


func physics_update(delta: float) -> void:
	if ball == null:
		return
	foot.update(delta)
	_sync_possession()
	if _carry_on and Engine.get_physics_frames() - _carry_frame > 2:
		_carry_on = false
	_since_touch += delta
	_since_contact += delta
	_since_aerial += delta
	if not ball.in_play:
		return
	if player.is_restart_locked():
		if not has_ball():
			_try_gain_control() # o batedor "assume" a bola parada (sem tocá-la)
		return # reinício: a bola fica parada até o passe
	if has_ball():
		if player.state == Player.State.MOVE and not player._has_pending_kick():
			_kick_snap_t = 0.0
			_process_ball_dribble(delta)
		elif player.is_kicking():
			_snap_to_kick_point(delta)
		elif ball_distance() > LOSE_RADIUS:
			ball.release()
	else:
		_try_gain_control()


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


func find_tackle_target(max_range := TACKLE_RANGE) -> Player:
	var carrier := ball.possessor
	if carrier == null or carrier.team == player.team:
		return null
	if _flat(carrier.global_position - player.global_position).length() > max_range:
		return null
	return carrier


# --- Domínio, condução e contato -------------------------------------------------

func _try_gain_control() -> void:
	if player.state != Player.State.MOVE or not ball.can_be_claimed_by(player):
		return
	var gk := player.is_goalkeeper()
	var d := ball_distance()
	# Domínio pela PickupArea (área em volta dos pés); goleiro alcança mais.
	var inside := d <= GK_CONTROL_RADIUS if gk else _ball_in_pickup_area()
	if not inside:
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
	_since_touch = 0.0
	if gk:
		_first_touch()
		player.notify_touch(&"gk_catch" if rel_speed > 7.0 else &"receive")
		return
	# Primeiro toque COM O PÉ: o pé vai até a bola e só no contato ela é
	# amortecida. Parado e bola mansa: às vezes pisa (sola); no resto, para a
	# bola com a parte de dentro do pé, do lado, amortecendo.
	var incoming := _flat(bv)
	var dir_in := incoming.normalized() if incoming.length() > 0.3 else -player.facing
	var lead := clampf((d - 0.3) / maxf(rel_speed, 1.0), 0.03, 0.12)
	var slow := player.get_horizontal_speed() < 0.8 and incoming.length() < 4.0
	var use_sole := slow and _rng.randf() < 0.4
	var f := foot.nearest_foot()
	foot.begin(f, dir_in, lead, FootContact.Mode.SOLE if use_sole else FootContact.Mode.CUSHION,
		_first_touch, 0.08)
	player.notify_touch(&"receive" if use_sole else &"receive_side")


## Velocidade do primeiro toque (no instante em que o pé encosta).
func _ball_in_pickup_area() -> bool:
	if pickup_area == null:
		return ball_distance() <= CONTROL_RADIUS
	return pickup_area.overlaps_body(ball)


func _first_touch() -> void:
	var pv := _flat(player.velocity)
	var want := _flat(player.intent.move)
	var settle: Vector3
	if want.length() > 0.3:
		settle = pv * 0.9 + want.normalized() * 1.1 # domínio orientado
	else:
		var keep := player.global_position + player.facing * 0.38
		settle = pv * 0.8 + _flat(keep - ball.global_position) * 3.0
	ball.touch(Vector3(settle.x, minf(ball.velocity_now().y, 0.0), settle.z), player)
	_since_touch = 0.0


func _deflect_save(bv: Vector3) -> void:
	var out := Vector3(-bv.x * 0.35, absf(bv.y) * 0.3 + 1.5, bv.z * 0.5 + _rng.randf_range(-3.0, 3.0))
	ball.touch(out, player)
	ball.set_ignore(player, 0.35)
	_since_contact = 0.0
	player.notify_touch(&"save")


## CONDUÇÃO (arquitetura de referência): a bola vive em volta do DribblePoint
## (no chão, ~0,55 m à frente; gira junto com o jogador, então nas curvas ela
## tem o "peso" da rotação mais lenta com a bola). Correndo, um toque rítmico a
## cada dribble_tap_interval — dado pelo PÉ (IK), aplicado só no contato —
## leva a bola um pouco à frente; entre os toques ela é alinhada suavemente ao
## ponto para não escapar nas curvas. Parado: estabiliza perto do pé.
func _process_ball_dribble(delta: float) -> void:
	if ball_distance() > dribble_lose_distance or ball.global_position.y > 1.3 and _since_aerial > 0.9:
		ball.release()
		return
	if ball.global_position.y > 0.35:
		return # caindo do domínio no peito/coxa/cabeça: espera chegar ao pé
	if foot.busy():
		return # o pé está indo até a bola: o toque acontece no contato
	var target := _dribble_target()
	var pv := _flat(player.velocity)
	var bv := ball.velocity_now()
	var intensity := _flat(player.intent.move).length()
	if intensity > 0.1:
		_trapping = false
		_dribble_timer -= delta
		var fwd := player.facing
		# Só toca para a frente quando o corpo já está virado para onde corre
		# (no meio de uma virada pesada, só o alinhamento segura a bola).
		var aligned := pv.length() < 0.5 or pv.normalized().dot(fwd) > 0.6
		if _dribble_timer <= 0.0 and aligned:
			_dribble_timer = dribble_tap_interval
			var side := foot.nearest_foot()
			foot.begin(side, fwd, TOUCH_LEAD, FootContact.Mode.INSIDE, func():
				# Toque: pequeno adianto na direção da corrida + velocidade do corpo.
				var tap_target := _dribble_target() + player.facing * 0.35
				var desired := (tap_target - ball.global_position) * 11.0 + _flat(player.velocity) * 0.45
				if _flat(player.intent.move).length() < 0.1:
					# soltou o analógico no meio do toque: o pé segura em vez de empurrar
					desired = (_dribble_target() - ball.global_position) * 9.0
				ball.touch(Vector3(desired.x, ball.velocity_now().y, desired.z), player)
				_since_touch = 0.0
				player.notify_touch(&"dribble_touch"))
		elif dribble_pull > 0.0:
			# Entre os toques: alinhamento suave ao ponto (não escapa nas curvas).
			var pull := (target - ball.global_position) * 6.5 + pv * 0.6
			var k := clampf(8.0 * delta * dribble_pull, 0.0, 1.0)
			var nv := bv.lerp(Vector3(pull.x, bv.y, pull.z), k)
			if (nv - bv).length() > 0.01:
				ball.touch(nv, player)
	else:
		# PARADO: estabiliza a bola perto do pé (a sola vai até ela primeiro).
		if not _trapping or (not _sole_on and not foot.busy()):
			_trapping = true
			_sole_on = false
			if _flat(bv).length() > 0.5 or ball_distance() > 0.75:
				foot.begin(foot.nearest_foot(), player.facing, TOUCH_LEAD, FootContact.Mode.SOLE,
					func(): _sole_on = true, 0.15, func(): return _trapping and ball_distance() < 0.9)
				player.notify_touch(&"trap")
				return
			_sole_on = true
		if not _sole_on:
			return
		var stop := (target - ball.global_position) * 9.0
		ball.touch(Vector3(stop.x, bv.y, stop.z), player)


## DribblePoint no chão (altura do centro da bola).
func _dribble_target() -> Vector3:
	var t := dribble_point.global_position if dribble_point != null \
		else player.global_position + player.facing * 0.55
	return Vector3(t.x, ball.global_position.y, t.z)


## CHUTE/PASSE (preparação): enquanto a perna vai para trás, a bola é alinhada
## no KickPoint (o ponto por onde o pé do Mixamo passa) em kick_snap_time; depois
## fica ali, acompanhando o corpo, até o quadro de contato do clipe.
func _snap_to_kick_point(delta: float) -> void:
	if ball_distance() > dribble_lose_distance:
		ball.release()
		return
	_kick_snap_t += delta
	var kp := kick_point_left if player.kick_mirrored() and kick_point_left != null else kick_point
	var target := kp.global_position if kp != null else player.global_position + player.facing * 0.45
	target.y = ball.global_position.y
	var pv := _flat(player.velocity)
	var v: Vector3
	var left := kick_snap_time - _kick_snap_t
	if left > 0.0:
		v = pv + (target - ball.global_position) / maxf(left, delta)
	else:
		v = pv + (target - ball.global_position) * 12.0
	v = v.limit_length(8.0)
	ball.touch(Vector3(v.x, 0.0, v.z), player)


## Bola parada/presa na sola (soltou o analógico)?
func is_trapping() -> bool:
	return _trapping


## Contato do domínio no ar / cabeceio (no quadro de contato do clipe).
func aerial_touch(kind: StringName, expected_h: float, aim: Vector3, power: float, shot: bool) -> void:
	var off := ball_offset()
	var h := ball.global_position.y
	if off.length() > 1.0 or absf(h - expected_h) > 0.7 or not ball.can_be_claimed_by(player):
		return # a bola não veio onde esperado: passou
	var f := player.facing
	_since_aerial = 0.0
	_since_touch = 0.0
	match kind:
		&"recv_knee":
			ball.claim(player)
			ball.touch(f * 0.7 + Vector3.UP * 1.2, player)
		&"recv_chest":
			ball.claim(player)
			ball.touch(f * 0.9 + Vector3.UP * 0.4, player)
		&"head_control":
			ball.claim(player)
			ball.touch(f * 0.8 + Vector3.UP * 1.6, player)
		&"header", &"header_jump":
			_header(aim, power, shot)
			return
	player.notify_touch(&"receive_air")


## Cabeceio de primeira: passe de cabeça para o companheiro (ou para o gol).
func _header(aim: Vector3, power: float, shot: bool) -> void:
	var from := ball.global_position
	var dir := _aim_dir(aim)
	var vel: Vector3
	var receiver: Player = null
	if shot:
		var goal_x := Field.goal_line_x(Team.other(player.team))
		var target := Vector3(goal_x, 0.35, _choose_shot_z(from, goal_x, aim))
		var flat := _flat(target - from)
		var speed := lerpf(8.0, 12.0, power)
		var t := flat.length() / speed
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		vel = flat.normalized() * speed + Vector3.UP * ((target.y - from.y) / t + 0.5 * g * t)
	else:
		receiver = pick_pass_target(dir)
		if receiver == null and _flat(aim).length() < 0.2:
			receiver = pick_pass_target(dir, 180.0)
		var dest := _lead_target(receiver, from) if receiver != null else from + dir * 6.0
		var flat := _flat(dest - from)
		var speed := clampf(flat.length() * 1.1, 5.0, lerpf(8.0, 11.0, power))
		var t := flat.length() / speed
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		# Chega no pé do companheiro (altura ~0,2 m).
		vel = flat.normalized() * speed + Vector3.UP * ((0.2 - from.y) / t + 0.5 * g * t)
	vel = vel.rotated(Vector3.UP, _rng.randf_range(-0.03, 0.03))
	ball.kick(vel, Vector3.ZERO, player)
	ball.pass_target = receiver
	player.notify_touch(&"header")
	GameEvents.ball_kicked.emit(player, &"shoot" if shot else &"pass", power)


# --- Ações com a bola ------------------------------------------------------------

func execute_pass(power: float, aim: Vector3, target: Node3D, lofted := false) -> bool:
	if not can_kick():
		return false
	var from := ball.global_position
	var dir := _aim_dir(aim)
	var mate := target as Player
	if mate == null:
		mate = pick_pass_target(dir)
		if mate == null and _flat(aim).length() < 0.2:
			# Sem direção no analógico: toca no companheiro mais fácil,
			# nunca no vazio (evita entregar a bola na saída).
			mate = pick_pass_target(dir, 180.0)
	var long := lofted or (not player.is_human and power >= LONG_PASS_POWER)
	var vel: Vector3
	var receiver: Player = mate
	if mate != null:
		var dest := _lead_target(mate, from)
		var dist := _flat(dest - from).length()
		if long:
			vel = lofted_velocity(from, from + _flat(dest - from) * 0.92, lerpf(32.0, 44.0, power))
		else:
			# Passe firme: chega com velocidade (o recebedor domina), nunca "mascando".
			vel = ground_pass_velocity(from, dest, lerpf(5.5, 7.5, power))
			vel = vel.normalized() * clampf(vel.length(), lerpf(10.0, 18.0, power), 20.0)
	else:
		# Passe em profundidade (para o espaço): vai quem estiver melhor para chegar.
		var dest := from + dir * lerpf(7.0, 18.0, power)
		dest = Field.clamp_inside(dest, 0.5)
		receiver = _best_runner_to(dest)
		if long:
			vel = lofted_velocity(from, dest, 40.0)
		else:
			# Para o espaço: a bola tem que MORRER perto do ponto (não sair do campo).
			vel = ground_pass_velocity(from, dest, lerpf(1.5, 3.0, power))
			vel = vel.normalized() * clampf(vel.length(), 4.5, 16.0)
	# Precisão: toque curto praticamente no pé; passe forte um pouco menos.
	var err := deg_to_rad(0.25 + 0.75 * power)
	if ball_distance() > 0.75:
		err *= 1.5 # bola longe do pé
	vel = vel.rotated(Vector3.UP, _rng.randf_range(-err, err))
	ball.kick(vel, _roll_spin(vel), player, kick_cooldown)
	ball.pass_target = receiver
	player.notify_touch(&"pass")
	GameEvents.ball_kicked.emit(player, &"long_pass" if long else &"pass", power)
	return true


## Companheiro que chega primeiro num ponto (para o passe em profundidade).
func _best_runner_to(dest: Vector3) -> Player:
	var best: Player = null
	var best_t := INF
	for mate in player.get_teammates():
		var t := mate.global_position.distance_to(dest) / maxf(mate.sprint_speed, 0.1)
		if t < best_t:
			best_t = t
			best = mate
	return best


func execute_shot(power: float, aim: Vector3, precise := false, chip := false) -> bool:
	if not can_kick():
		return false
	if chip:
		return _execute_chip(power, _flat(aim).normalized() if _flat(aim).length() > 0.2 else player.facing)
	if precise and _flat(aim).length() > 0.2:
		return _execute_aimed_shot(power, _flat(aim).normalized())
	var goal_x := Field.goal_line_x(Team.other(player.team))
	var from := ball.global_position
	var ty := _rng.randf_range(0.12, 0.5)
	var target := Vector3(goal_x, ty, _choose_shot_z(from, goal_x, aim))
	var speed := lerpf(12.0, 23.0, power)
	var flat_to := _flat(target - from)
	var d := maxf(flat_to.length(), 0.5)
	var dir := flat_to / d
	# Imprecisão: maior com força alta, bola longe do pé ou corpo desalinhado.
	var spread := deg_to_rad(lerpf(0.8, 3.5, power))
	if ball_distance() > 0.7:
		spread *= 1.3
	if player.facing.dot(dir) < 0.3:
		spread *= 1.6
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var t := d / speed
	var vy := (ty - from.y) / t + 0.5 * g * t
	vy += _rng.randf_range(-0.2, 0.4) * power
	var spin := Vector3.UP * _rng.randf_range(-8.0, 8.0) * power
	ball.kick(dir * speed + Vector3.UP * vy, spin + _roll_spin(dir), player, kick_cooldown)
	player.notify_touch(&"shoot")
	GameEvents.ball_kicked.emit(player, &"shoot", power)
	return true


## Chute mirado pelo humano: a bola segue a direção escolhida (com uma
## pequena imprecisão natural), em velocidade de pelada.
func _execute_aimed_shot(power: float, dir: Vector3) -> bool:
	var from := ball.global_position
	var speed := lerpf(12.0, 23.0, power)
	var spread := deg_to_rad(lerpf(0.4, 1.8, power))
	if player.facing.dot(dir) < 0.3:
		spread *= 1.6 # chutar de lado para onde o corpo não está virado
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	# Altura: até o gol (se estiver mirando para ele) ou ~10 m.
	var goal_x := Field.goal_line_x(Team.other(player.team))
	var d := 10.0
	if absf(dir.x) > 0.1 and signf(dir.x) == signf(goal_x - from.x):
		d = clampf((goal_x - from.x) / dir.x, 2.0, 25.0)
	var ty := lerpf(0.12, 0.45, power) + _rng.randf_range(-0.05, 0.08)
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var t := d / speed
	var vy := clampf((ty - from.y) / t + 0.5 * g * t, 0.0, 6.0)
	var spin := Vector3.UP * _rng.randf_range(-4.0, 4.0) * power
	ball.kick(dir * speed + Vector3.UP * vy, spin + _roll_spin(dir), player, kick_cooldown)
	player.notify_touch(&"shoot")
	GameEvents.ball_kicked.emit(player, &"shoot", power)
	return true


## Cavadinha: bola alta e lenta, por cima de quem está na frente.
func _execute_chip(power: float, dir: Vector3) -> bool:
	var spread := deg_to_rad(2.0)
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	var speed := lerpf(4.5, 8.0, power)
	var vy := lerpf(5.5, 7.5, power)
	ball.kick(dir * speed + Vector3.UP * vy, Vector3.ZERO, player)
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
		chance -= 0.2 # vindo por trás
	elif carrier.facing.dot(from_carrier) > 0.5:
		chance += 0.12 # de frente: fecha o caminho da bola
	if _rng.randf() > chance:
		# Errou a bola: se pegou o adversário, é FALTA.
		if player.global_position.distance_to(carrier.global_position) < 0.95 and _rng.randf() < 0.55:
			if _rng.randf() < 0.5:
				carrier.trip()
			else:
				carrier.stumble(0.6)
			if player.match_manager != null:
				player.match_manager.award_free_kick(carrier.team, carrier.global_position)
		return false
	var poke := _flat(player.global_position - ball.global_position).normalized()
	if poke.length() < 0.1:
		poke = -player.facing
	poke = poke.rotated(Vector3.UP, _rng.randf_range(-1.0, 1.0))
	ball.kick(poke * _rng.randf_range(2.5, 4.5), Vector3.ZERO, player, 0.1)
	carrier.stumble(0.45)
	GameEvents.ball_kicked.emit(player, &"tackle", 0.5)
	return true


## Carrinho: no instante em que o pé chega na bola. Se ela estiver ao alcance
## do pé que desliza, é desviada; quem conduzia tropeça (ou já tinha pulado).
func execute_slide_tackle() -> bool:
	if ball == null or not ball.in_play:
		return false
	var off := ball_offset()
	if off.length() > 1.25 or off.dot(player.facing) < -0.1 or ball.global_position.y > 0.6:
		return false
	var carrier := ball.possessor
	if carrier != null and carrier.team != player.team and carrier.is_jumping():
		return false # pulou o carrinho
	if debug_slide_trip < 0.0 and _rng.randf() > 0.8:
		return false
	var side := player.facing.cross(Vector3.UP) * (1.0 if _rng.randf() > 0.5 else -1.0)
	var dir := (player.facing * 0.6 + side).normalized()
	ball.kick(dir * _rng.randf_range(3.5, 6.0) + Vector3.UP * 0.8, Vector3.ZERO, player, 0.4)
	if carrier != null and carrier != player and carrier.team != player.team:
		var trip_chance := 0.55 if debug_slide_trip < 0.0 else debug_slide_trip
		if _rng.randf() < trip_chance:
			carrier.trip()
		else:
			carrier.stumble(0.5)
	player.notify_touch(&"slide")
	GameEvents.ball_kicked.emit(player, &"tackle", 0.8)
	return true


## Durante um drible com o corpo (giro): a bola acompanha o pé de perto.
## Não é presa: recebe uma velocidade que a puxa para junto do pé.
func carry_during_skill(_delta: float) -> void:
	if not has_ball():
		return
	var target := player.global_position + player.facing * 0.35
	var to := _flat(target - ball.global_position)
	if to.length() > 1.4:
		return
	_carry_frame = Engine.get_physics_frames()
	if not foot.busy() and not _carry_on:
		# A sola vai até a bola antes de levá-la junto (nada de bola "imã").
		foot.begin(foot.nearest_foot(), player.facing, 0.07, FootContact.Mode.SOLE,
			func(): _carry_on = true, 0.1,
			func(): return Engine.get_physics_frames() - _carry_frame <= 2)
	if not _carry_on:
		return
	if Engine.get_physics_frames() - _carry_frame > 2:
		_carry_on = false
		return
	ball.touch(_flat(player.velocity) + to * 6.0, player)


func release_after_skill() -> void:
	if has_ball():
		ball.touch(_flat(player.velocity) + player.facing * 1.2, player)
		_since_touch = 0.0


## Virada animada com a bola: puxa a bola com a sola para a nova direção,
## devagar, para ela terminar junto ao pé quando o corpo terminar de virar.
func drag_ball_to(dir: Vector3) -> void:
	if has_ball():
		# A sola vai na bola e a puxa para o novo lado.
		foot.begin(foot.nearest_foot(), -dir, 0.07, FootContact.Mode.SOLE,
			func(): ball.touch(dir * 0.9, player), 0.12)
		_since_touch = 0.0
		player.notify_touch(&"drag")


## Empurra a bola à frente (ex.: ao pular um carrinho).
func push_ahead(mult: float) -> void:
	if has_ball():
		var v := _flat(player.velocity)
		ball.touch(player.facing * maxf(v.length(), 3.0) * mult, player)
		_since_touch = 0.0


func pick_pass_target(dir: Vector3, max_angle_deg := 70.0) -> Player:
	var best: Player = null
	var best_score := -INF
	for mate in player.get_teammates():
		var to := _flat(mate.global_position - player.global_position)
		var d := to.length()
		if d < 1.5:
			continue
		var ang := dir.angle_to(to / d)
		if ang > deg_to_rad(max_angle_deg):
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
	var a := 1.9 # desaceleração média: rolamento nos bloquinhos (1,45) + arrasto do ar
	var v0 := clampf(sqrt(end_speed * end_speed + 2.0 * a * d), 3.0, 16.0)
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


## Rotação ao sair do pé (efeito de rolamento para a frente, ~18 rad/s):
## a bola "agarra" o chão e quica menos.
static func _roll_spin(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	if f.length() < 0.01:
		return Vector3.ZERO
	return Vector3.UP.cross(f.normalized()) * 18.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
