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
## Alcance real da perna no chão (perna ~0,82 m a partir do quadril).
const TOUCH_REACH := 0.5
## Onde a bola fica no toque de condução: no caminho do pé da passada
## (medido na animação: o tornozelo chega ~0,14 m à frente do corpo).
const FOOT_DISTANCE := 0.36
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

var _since_touch := 10.0
var _since_contact := 10.0
var _foot_side := 1.0
var _save_rolled := false
var _touch_wait := 0.0
var _trapping := false
var _sole_on := false
var _carry_on := false
var _dragging := false
var _carry_frame := 0
## O pé que vai até a bola em cada toque (IK). Nenhum toque sem o pé encostar.
var foot := FootContact.new()
## Tempo entre decidir o toque e o pé encostar na bola.
const TOUCH_LEAD := 0.06
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
	# (sem amortecimento extra: os toques já contam com o atrito real da rua;
	#  amortecer a bola a fazia "morrer" embaixo do jogador na corrida)


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
		# Durante uma ação (chute, passe, drible) ou com chute pendente, sem toques de condução.
		if player.state == Player.State.MOVE and not player._has_pending_kick():
			_conduct(delta)
		elif ball_distance() > LOSE_RADIUS:
			ball.release()
	else:
		_try_gain_control()
		if not has_ball() and not (foot.busy() and foot.claiming()):
			# bola solta bate no corpo (desvio calculado: a física da cápsula
			# empurrava a bola para dentro do chão)
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


func find_tackle_target(max_range := TACKLE_RANGE) -> Player:
	var carrier := ball.possessor
	if carrier == null or carrier.team == player.team:
		return null
	if _flat(carrier.global_position - player.global_position).length() > max_range:
		return null
	return carrier


## Condução com virada: se a bola NÃO está à frente na direção desejada,
## devolve o deslocamento (plano) até o ponto atrás dela nessa direção, de
## onde o jogador puxa a bola para o novo lado. ZERO = bola já está à frente.
func turn_approach_point(dir: Vector3) -> Vector3:
	if not has_ball():
		return Vector3.ZERO
	var off := ball_offset()
	if off.length() < 0.25 or off.length() > LOSE_RADIUS:
		return Vector3.ZERO
	if off.normalized().dot(dir) > 0.35:
		return Vector3.ZERO
	return off - dir * 0.35


## Velocidade extra para o jogador alcançar a bola que rolou à frente.
func catch_up_velocity(dir: Vector3) -> Vector3:
	if not has_ball():
		return Vector3.ZERO
	var off := ball_offset()
	var along := off.dot(dir)
	var right := dir.cross(Vector3.UP)
	var v := Vector3.ZERO
	# O CORPO alcança a bola (não a bola que volta para o corpo): se ela está
	# além do ponto de toque, o jogador acelera para a passada chegar nela.
	if along > FOOT_DISTANCE + 0.1:
		v += dir * clampf((along - FOOT_DISTANCE - 0.1) * 2.0, 0.0, 1.6)
	if along > 0.0:
		v += right * clampf(off.dot(right) * 2.0, -1.5, 1.5)
	return v


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

	if player.is_restart_locked():
		ball.claim(player) # reinício: bola parada no pé do batedor
		return
	if gk:
		ball.claim(player)
		_since_touch = 0.0
		_first_touch()
		player.notify_touch(&"gk_catch" if rel_speed > 7.0 else &"receive")
		return
	if foot.busy():
		return # o pé já está indo matar a bola
	# Primeiro toque COM O PÉ: o pé vai até a bola e só no contato ela é
	# amortecida. Parado e bola mansa: às vezes pisa (sola); no resto, para a
	# bola com a parte de dentro do pé, do lado, amortecendo.
	var incoming := _flat(bv)
	var dir_in := incoming.normalized() if incoming.length() > 0.3 else -player.facing
	var lead := clampf((d - 0.3) / maxf(rel_speed, 1.0), 0.03, 0.12)
	var slow := player.get_horizontal_speed() < 0.8 and incoming.length() < 4.0
	var use_sole := slow and _rng.randf() < 0.4
	var f := foot.nearest_foot()
	# A posse só é tomada no contato do pé (se o pé não alcançar, a bola bate
	# no corpo de verdade em vez de atravessar o jogador).
	foot.begin(f, dir_in, lead, FootContact.Mode.SOLE if use_sole else FootContact.Mode.CUSHION,
		_first_touch, 0.08, Callable(), true)
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


func _body_contact() -> void:
	if _since_contact < 0.12 or ball.is_ignoring(player):
		return
	if player.state == Player.State.ACTION and player._action_kind in Player.AERIAL_KINDS \
			and not player._action_contact_done:
		return # vai dominar no peito/coxa/cabeça: o contato é da animação
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
	if d > LOSE_RADIUS or (ball.global_position.y > 1.3 and _since_aerial > 0.9):
		ball.release()
		return
	if ball.global_position.y > 0.35:
		return # caindo do domínio no peito/coxa/cabeça: espera chegar ao pé
	var want := _flat(player.intent.move)
	if want.length() >= 0.15 and _trapping:
		# voltou a mexer o analógico: a sola sai de cima da bola
		_trapping = false
		_sole_on = false
		if foot.mode == FootContact.Mode.SOLE and foot.phase == FootContact.Phase.HOLD:
			foot.cancel()
	if _dragging:
		# sola em cima da bola: ela gira junto com o corpo
		var pv0 := _flat(player.velocity)
		var w0 := want.normalized() if want.length() > 0.15 else player.facing
		if want.length() < 0.15 or player.facing.angle_to(w0) < deg_to_rad(12.0) or d > 0.55 or pv0.length() > 2.2:
			_dragging = false
		else:
			var tgt := player.global_position + player.facing * 0.3
			var dv := pv0 + _flat(tgt - ball.global_position) * 6.0
			ball.touch(Vector3(dv.x, 0.0, dv.z).limit_length(3.0), player)
			_since_touch = 0.0
			return
	if foot.busy():
		# Mudou de ideia (direção bem diferente) antes do pé chegar: cancela o
		# toque antigo em vez de empurrar a bola para o lado errado.
		if foot.phase == FootContact.Phase.REACH and foot.mode == FootContact.Mode.INSIDE \
				and want.length() >= 0.15 and want.normalized().dot(foot.dir) < 0.5:
			foot.cancel()
		return # o pé está indo até a bola: o toque acontece no contato
	var pv := _flat(player.velocity)
	var bv := _flat(ball.velocity_now())
	if want.length() < 0.15:
		_dragging = false
		if pv.length() <= 1.4:
			_trap(delta, off, d, pv, bv)
			return
		# Soltou o analógico correndo: vai FREANDO com a bola, com toques
		# curtos (cada toque deixa a bola mais lenta); pisa quando já está devagar.
		want = player.facing * 0.01
	_trapping = false
	_sole_on = false
	var w := want.normalized()
	var ahead := off.normalized().dot(w) if d > 0.05 else 1.0
	# PUXADA DE SOLA: pediu o lado contrário com a bola no pé → puxa a bola
	# para trás com a sola e o corpo vira (não sai correndo e deixa a bola).
	var in_front_of_body := off.dot(player.facing) > 0.12
	if d <= 0.45 and ahead < -0.35 and in_front_of_body and _since_touch > 0.25:
		var pull_speed := 1.25 + maxf(pv.dot(w), 0.0) * 0.6
		foot.begin(foot.nearest_foot(), -w, TOUCH_LEAD, FootContact.Mode.SOLE,
			func(): ball.touch(w * pull_speed, player), 0.1)
		_since_touch = 0.0
		_touch_wait = 0.0
		player.notify_touch(&"pull")
		return
	# VIRADA COM A SOLA: devagar/parado e pediu outro lado (mesmo pouco): o
	# pé pisa na bola e a arrasta junto enquanto o corpo gira.
	var turn_ang := player.facing.angle_to(w)
	if not _dragging and pv.length() < 1.5 and d <= 0.45 and in_front_of_body and turn_ang > deg_to_rad(25.0) \
			and turn_ang < deg_to_rad(150.0) and _since_touch > 0.2:
		var side := signf(player.facing.cross(Vector3.UP).dot(off))
		foot.begin(side if side != 0.0 else foot.nearest_foot(), w, 0.08, FootContact.Mode.SOLE,
			func(): _dragging = true, 0.1, func(): return _dragging)
		_since_touch = 0.0
		player.notify_touch(&"drag")
		return
	if d > TOUCH_REACH:
		return # longe: o Player vai até a bola primeiro (approach_point)
	var speed := pv.length()
	if _since_touch < 0.2:
		return
	var right := w.cross(Vector3.UP)
	var along := off.dot(w)
	var lateral := off.dot(right)
	var rel_along := (bv - pv).dot(w)
	var behind := along < FOOT_DISTANCE + 0.25 and rel_along < 0.3
	var drifting := absf(lateral) > 0.3
	var mismatch := bv.length() > 0.4 and bv.normalized().dot(w) < 0.8
	# freando (soltou o analógico): a bola mais rápida que o corpo pede um toque
	# curto que a segura
	var braking_touch := want.length() < 0.05 and (rel_along > 0.3 or bv.length() > 1.4) and _since_touch > 0.3
	if not (behind or drifting or mismatch or braking_touch):
		_touch_wait = 0.0
		return
	# Toque de lado: para ir para a DIREITA o pé bate no lado ESQUERDO da bola
	# (e vice-versa). Espera um instante pelo pé certo chegar na bola.
	var turn_side := 0.0
	if bv.length() > 0.4 or speed > 0.8:
		var ref := bv.normalized() if bv.length() > 0.4 else player.facing
		var ang := ref.signed_angle_to(w, Vector3.UP)
		if absf(ang) > deg_to_rad(18.0):
			turn_side = -signf(ang) # +1 = virando para a direita
	# Qual pé: virando, o do lado de onde a bola sai (dentro do pé esquerdo
	# empurra para a direita); reto, o pé que está mais perto da bola.
	var f := -turn_side
	if turn_side == 0.0:
		# reto: o pé que está mais perto do ponto de toque na passada
		f = 1.0 if foot.ideal_distance(1.0, w, FootContact.Mode.INSIDE) <= foot.ideal_distance(-1.0, w, FootContact.Mode.INSIDE) else -1.0
		if speed < 1.6:
			# devagar: o pé do lado em que a bola está (sem cruzar as pernas)
			f = 1.0 if lateral >= 0.0 else -1.0
	# Espera a passada da animação levar o pé até a bola (a perna não estica).
	var max_wait := 0.2 if turn_side != 0.0 else 0.32
	var near_ok := 0.2 if speed >= 1.6 else 0.4
	if _touch_wait < max_wait and foot.ideal_distance(f, w, FootContact.Mode.INSIDE) > near_ok:
		_touch_wait += delta
		return
	last_touch_forced = _touch_wait >= max_wait
	_touch_wait = 0.0
	_since_touch = 0.0
	var ts := turn_side
	foot.begin(f, w, TOUCH_LEAD, FootContact.Mode.INSIDE, func():
		_do_touch(w, _flat(player.velocity).length(), 0.0)
		if ts != 0.0:
			player.notify_touch(&"side_touch"))


## Soltou o analógico: o jogador PARA A BOLA. Se ela rolou à frente, ele vai
## até ela (Player.approach_point) e pisa; perto do pé, a sola segura a bola e
## os dois param juntos.
func _trap(_delta: float, off: Vector3, d: float, pv: Vector3, bv: Vector3) -> void:
	_touch_wait = 0.0
	var rel_v := (bv - pv).length()
	if (d > 0.45 or rel_v > 1.6) and not _sole_on:
		# longe (ou fugindo) para pisar: o Player alcança a bola primeiro
		_trapping = false
		return
	if d > TOUCH_REACH + 0.1:
		_trapping = false
		_sole_on = false
		return
	var target := player.global_position + player.facing * 0.3 + pv * 0.08
	var to := _flat(target - ball.global_position)
	if not _trapping:
		if bv.length() < 0.25 and pv.length() < 0.3 and to.length() < 0.12:
			return # já parada no pé
		_trapping = true
		_sole_on = false
		# A sola vai até a bola; só quando encosta a bola passa a parar junto.
		foot.begin(foot.nearest_foot(), player.facing, TOUCH_LEAD, FootContact.Mode.SOLE,
			func(): _sole_on = true, 0.15, func(): return _trapping and ball_distance() < 0.8)
		player.notify_touch(&"trap")
	if not _sole_on:
		return
	var new_v := pv * 0.85 + to * 5.0
	if (new_v - bv).length() > 0.05:
		ball.touch(new_v.limit_length(6.0), player)
	_since_touch = 0.0


## Girando com a bola presa na sola?
func is_dragging() -> bool:
	return _dragging and has_ball()


## Bola parada/presa na sola (soltou o analógico)?
func is_trapping() -> bool:
	return _trapping


## Ponto (mundo, no chão) aonde o jogador precisa ir ANTES de tocar a bola na
## direção [param w]: atrás da bola em relação à nova direção, onde ela vai
## estar daqui a pouco. Vector3.INF = não precisa (bola à frente, ao alcance).
func approach_point(w: Vector3) -> Vector3:
	if not has_ball():
		return Vector3.INF
	var off := ball_offset()
	var d := off.length()
	if d < 0.05:
		return Vector3.INF
	var ahead := off.normalized().dot(w)
	var bv := ball.flat_velocity()
	var ball_with_me := bv.length() < 0.5 or bv.normalized().dot(w) > 0.7
	if ahead > 0.75 and ball_with_me:
		return Vector3.INF # bola à frente indo junto: condução normal
	var in_front_of_body := off.dot(player.facing) > 0.12
	if d <= 0.45 and ahead > 0.2:
		return Vector3.INF # no pé e à frente: o toque de lado resolve
	if d <= 0.45 and in_front_of_body and ahead < -0.35:
		return Vector3.INF # bola no pé e pediu o contrário: puxada de sola
	var t := clampf(d / maxf(player.sprint_speed, 0.1), 0.05, 0.45)
	var b := ball.predict_ground_position(t)
	b.y = 0.0
	var me := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var right := w.cross(Vector3.UP)
	if (me - b).dot(w) > -0.15:
		# Estou "na frente" da bola (em relação a onde quero ir): contorno por
		# fora, pelo lado em que já estou, sem atravessar a bola.
		var side := signf((me - b).dot(right))
		if side == 0.0:
			side = 1.0
		return b + right * side * 0.45 - w * 0.25
	return b - w * (FOOT_DISTANCE - 0.04)


## Micro-correção entre os toques: em curva a bola tende a seguir reta e
## escapar para o lado. Corrige só a deriva lateral, de leve (o jogador faria
## isso com toques mínimos), sem mudar a velocidade à frente nem prender a bola.
func _foot_near_ball(dir := Vector3.ZERO, turn_side := 0.0) -> bool:
	var feet := player.get_foot_positions()
	if feet.is_empty():
		return true # sem modelo animado: toca imediatamente
	var b := ball.global_position
	var fwd := player.facing
	var p := player.global_position
	var right := dir.cross(Vector3.UP) if dir != Vector3.ZERO else fwd.cross(Vector3.UP)
	for f in feet:
		# Pé baixo, perto da bola e à frente do corpo (não toca com o calcanhar).
		var foot_along := (f - p).dot(fwd)
		if f.y < 0.35 and Vector2(f.x - b.x, f.z - b.z).length() < FOOT_TOUCH_RADIUS \
				and foot_along > 0.0 and foot_along <= (b - p).dot(fwd) + 0.04:
			# Virando: o pé tem que estar do lado de onde a bola sai.
			if turn_side != 0.0 and (f - b).dot(right) * turn_side > 0.02:
				continue
			return true
	return false


## Toque de condução com CONTROLE PRÓXIMO: a velocidade dada à bola é
## calculada para que ela chegue de novo junto ao pé no próximo passo (tempo T),
## considerando a velocidade que o jogador está buscando e o atrito do piso.
## Resultado: bola sempre perto, rolando junto, toques curtos e frequentes.
func _do_touch(dir: Vector3, speed: float, _lateral: float) -> void:
	var sprinting := player.intent.sprint and speed > player.jog_speed * 0.8
	var target_speed := player.intent.move.length() * player.ball_speed_factor \
		* (player.sprint_speed if player.intent.sprint else player.jog_speed)
	var v_p := maxf(minf(target_speed, speed + 0.8), speed * 0.9)
	# Cadência: passo mais curto devagar, toque mais longo no sprint.
	var T := clampf(0.55 - v_p * 0.035, 0.36, 0.55)
	var extra := 0.0
	if sprinting:
		T = 0.62
		extra = 0.35
	# Perto da linha: toque mais curto e sem empurrar a bola para fora.
	var bp := ball.global_position
	if Field.HALF_WIDTH - absf(bp.z) < 1.2 and signf(dir.z) == signf(bp.z):
		dir = Vector3(dir.x, 0.0, dir.z * 0.3)
		dir = dir.normalized() if dir.length() > 0.1 else player.facing
		extra = 0.0
	_foot_side = -_foot_side
	var right := dir.cross(Vector3.UP)
	var lead := FOOT_DISTANCE + 0.04 + extra + _rng.randf_range(-0.03, 0.05)
	# Onde o jogador vai estar no próximo passo: ainda carrega a velocidade
	# atual (inércia de uma virada) misturada com a nova direção.
	var pv_now := _flat(player.velocity)
	var travel := (pv_now * 0.45 + dir * v_p * 0.55) * T
	if player.intent.move.length() < 0.1:
		# freando: cada toque curto tira ~1,8 m/s da bola (o corpo freia junto)
		travel = dir * maxf(speed - 1.8, 0.0) * T
	var p_next := player.global_position + travel + dir * lead + right * (_foot_side * 0.07)
	var to := _flat(p_next - bp)
	var a := ball.rolling_resistance
	var v0 := to.length() / T + 0.5 * a * T
	ball.touch(to.normalized() * v0 if to.length() > 0.01 else dir * v_p, player)
	_since_touch = 0.0
	player.notify_touch(&"dribble_touch")


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
			func(): ball.touch(dir * 2.2, player), 0.12) # sai junto com o corpo no fim da virada
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
