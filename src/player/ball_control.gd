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
const MAX_CONTROL_SPEED := 18.0
const GK_SAFE_CATCH_SPEED := 10.0
const KICK_REACH := 1.0
const KICK_MAX_HEIGHT := 0.9
## Alcance real da perna no chão (perna ~0,82 m a partir do quadril).
const TOUCH_REACH := 0.5
## Onde a bola fica no toque de condução: no caminho do pé da passada
## (medido na animação: o tornozelo chega ~0,14 m à frente do corpo).
const FOOT_DISTANCE := 0.30
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
## Toques de condução feitos (contato do pé).
var _touch_count := 0
## Puxada de sola na inversão de direção (o corpo gira por cima da bola).
var _reverse_pull := false
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
	_track_feet(delta)
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
		_keep_ball_outside_body_and_feet()
	else:
		_try_gain_control()
		if not has_ball():
			# bola solta bate no corpo (desvio calculado: a física da cápsula
			# empurrava a bola para dentro do chão)
			_body_contact()


## Impede que a bola entre dentro das canelas/corpo ou dentro dos pés do jogador
## enquanto a exceção de colisão da posse está ativa.
func _keep_ball_outside_body_and_feet() -> void:
	if ball == null or ball.global_position.y > 0.55:
		return
	var off := ball_offset()
	var d := off.length()
	var min_body_dist := 0.28 # raio da canela/corpo + raio da bola (0.11m)
	if d < min_body_dist:
		var push_dir := off / d if d > 0.005 else player.facing
		# Se estiver atrás do corpo, empurra para a frente/lateral
		if push_dir.dot(player.facing) < -0.10:
			push_dir = player.facing
		ball.global_position.x = player.global_position.x + push_dir.x * min_body_dist
		ball.global_position.z = player.global_position.z + push_dir.z * min_body_dist
		var bv := ball.velocity_now()
		var vn := (bv - player.velocity).dot(push_dir)
		if vn < 0.0:
			ball.linear_velocity = bv - push_dir * vn
	# Anti-penetração pé ↔ bola: garante que a superfície do pé (tornozelo → ponta do pé)
	# nunca atravesse o volume da bola (raio 0.11m + margem do pé 0.05m = 0.16m).
	var v := player.visual
	if v != null and v.has_method("get_toe_position"):
		var b_pos := ball.global_position
		var min_foot_dist := Ball.RADIUS + 0.052
		for sd in [1.0, -1.0]:
			var an: Vector3 = v.call("get_ankle_position", sd)
			var tp: Vector3 = v.call("get_toe_position", sd)
			if minf(an.y, tp.y) > b_pos.y + 0.08:
				continue # pé por cima da bola (sola): não empurra horizontalmente
			var seg_x := tp.x - an.x
			var seg_z := tp.z - an.z
			var seg_len_sq := seg_x * seg_x + seg_z * seg_z
			var t_seg := 0.0
			if seg_len_sq > 0.0001:
				t_seg = clampf(((b_pos.x - an.x) * seg_x + (b_pos.z - an.z) * seg_z) / seg_len_sq, 0.0, 1.0)
			var near_x := an.x + seg_x * t_seg
			var near_z := an.z + seg_z * t_seg
			var dx := b_pos.x - near_x
			var dz := b_pos.z - near_z
			var dist_xz := sqrt(dx * dx + dz * dz)
			if dist_xz < min_foot_dist:
				var f_dir := Vector3(dx, 0.0, dz)
				if f_dir.length() < 0.005 or f_dir.dot(player.facing) < -0.2:
					f_dir = player.facing
				else:
					f_dir = f_dir.normalized()
				b_pos.x = near_x + f_dir.x * min_foot_dist
				b_pos.z = near_z + f_dir.z * min_foot_dist
				ball.global_position.x = b_pos.x
				ball.global_position.z = b_pos.z
	if ball.global_position.y < Ball.RADIUS:
		ball.global_position.y = Ball.RADIUS


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
	# a bola fugiu além do tapa normal: o corpo acelera para alcançá-la
	var v_t := player.intent.move.length() * _top_speed_with_ball()
	var lead_max := 0.45 + tap_lead(v_t) + 0.3
	if along > lead_max:
		v += dir * clampf((along - lead_max) * 1.5, 0.0, 1.0)
	# alinha o corpo com a bola (ela fica entre os pés, na linha da passada):
	# acompanha o deslize lateral dela e ainda fecha a diferença
	if along > -0.1:
		var blat := ball.flat_velocity().dot(right)
		v += right * clampf(blat + off.dot(right) * 4.0, -1.8, 1.8)
	return v


# --- Domínio, condução e contato -------------------------------------------------

func _try_gain_control() -> void:
	if player.state != Player.State.MOVE or not ball.can_be_claimed_by(player):
		return
	var gk := player.is_goalkeeper()
	var d := ball_distance()
	# Domínio pela PickupArea (área em volta dos pés); goleiro alcança mais.
	var inside := d <= GK_CONTROL_RADIUS if gk else _ball_in_pickup_area()
	# Bola rápida: agenda o pé pela PREVISÃO de chegada (senão, a 9 m/s ela
	# atravessa a área dos pés entre um quadro e outro e o pé chega tarde).
	var rel_p := _flat(ball.global_position - player.global_position)
	var rel_v := _flat(ball.velocity_now() - player.velocity)
	var t_close := -1.0
	if rel_v.length_squared() > 1.0:
		t_close = -rel_p.dot(rel_v) / rel_v.length_squared()
		if not inside and not gk and t_close > 0.0 and t_close < 0.13 \
				and (rel_p + rel_v * t_close).length() < 0.55:
			inside = true
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
	if t_close > 0.0 and rel_speed > 4.0:
		lead = clampf(t_close, 0.03, 0.13) # o pé encontra a bola no ponto mais perto
	# Pisar na bola só com ela chegando bem mansa (a animação levanta o pé
	# alto); no resto, parte de dentro do pé amortecendo.
	var slow := player.get_horizontal_speed() < 0.6 and incoming.length() < 2.0
	var use_sole := slow and _rng.randf() < 0.5
	var f := foot.nearest_foot()
	var mode := FootContact.Mode.SOLE if use_sole else FootContact.Mode.CUSHION
	var pv0 := _flat(player.velocity)
	if pv0.length() > 1.5 and incoming.length() > 0.5 and incoming.normalized().dot(pv0.normalized()) > 0.3:
		# bola indo no mesmo sentido da corrida (profundidade / bola de trás):
		# parte de DENTRO do pé, empurrando para a frente (nada de calcanhar)
		mode = FootContact.Mode.INSIDE
		dir_in = pv0.normalized()
		var lat := (ball.global_position - player.global_position).dot(pv0.normalized().cross(Vector3.UP))
		f = signf(lat) if absf(lat) > 0.05 else f # o pé do lado da bola (sem cruzar as pernas)
	# A posse só é tomada no contato do pé (se o pé não alcançar, a bola bate
	# no corpo de verdade em vez de atravessar o jogador).
	foot.begin(f, dir_in, lead, mode, _first_touch, 0.08, Callable(), true)
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
		# domínio ORIENTADO: o primeiro toque já leva a bola para onde você quer
		# ir, na velocidade de quem sai correndo com ela
		var wn := want.normalized()
		var push := 2.6 + (0.9 if player.intent.sprint else 0.0) # correndo: toque mais longo
		settle = wn * clampf(maxf(pv.dot(wn), 0.0) + push, 2.6, 5.2) + (pv - wn * pv.dot(wn)) * 0.5
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
	# Passe para mim (ou bola solta mansa) batendo no corpo: o corpo AMORTECE
	# e a bola fica comigo (canela/coxa/peito) — não atravessa nem espirra.
	var rel_in := (bv - player.velocity).length()
	if player.state == Player.State.MOVE and h < 1.3 and ball.can_be_claimed_by(player) \
			and not player.is_restart_locked() \
			and ((ball.pass_target == player and rel_in < 16.0) or rel_in < 6.0 \
				or (ball.last_toucher != null and ball.last_toucher != player \
					and ball.last_toucher.team == player.team and rel_in < 14.0)):
		foot.cancel()
		ball.claim(player)
		_first_touch()
		_since_contact = 0.0
		player.notify_touch(&"receive")
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
	var pv := _flat(player.velocity)
	var bv := _flat(ball.velocity_now())
	_dragging = false
	_reverse_pull = false
	if want.length() >= 0.15 and _trapping:
		_trapping = false
		_sole_on = false
		if foot.mode == FootContact.Mode.SOLE and foot.phase == FootContact.Phase.HOLD:
			foot.cancel()
	if want.length() < 0.15:
		# Soltou o analógico: traz a bola suavemente para a frente do pé e pisa quando parar.
		if pv.length() <= 1.2:
			_trap(delta, off, d, pv, bv)
			return
		var stop_pocket := player.global_position + player.facing * 0.35
		var to_stop := _flat(stop_pocket - ball.global_position)
		var brake_v := pv * 0.88 + to_stop * 5.5
		ball.touch(Vector3(brake_v.x, 0.0, brake_v.z), player)
		return
	_trapping = false
	_sole_on = false
	var w := want.normalized()
	var move_dir := pv.normalized() if pv.length() > 0.55 else w
	var right := move_dir.cross(Vector3.UP)
	# Condução com CONTROLE PRÓXIMO E FLUIDO:
	# 1) Agenda os toques visuais e anatômicos dos pés (chapa do pé esquerdo para cortar à direita,
	#    chapa do pé direito para cortar à esquerda, três dedos no sprint, alternância na reta).
	if foot.busy():
		if foot.phase == FootContact.Phase.REACH and want.normalized().dot(foot.dir) < 0.35:
			foot.cancel()
	else:
		_foot_contact_touch(want, pv, bv)
	# 2) Guia contínua de condução próxima: mantém a bola sempre no bolso da passada à frente
	#    do jogador (~0.34m a 0.44m à frente), acompanhando curvas e arrancadas sem jamais escapar!
	var speed := pv.length()
	var target_speed := maxf(want.length() * _top_speed_with_ball(), speed)
	var lead_pocket := clampf(0.34 + speed * 0.024, 0.34, 0.44)
	var lat_pocket := _foot_side * 0.045
	var threat := player._shield_threat()
	if threat != Vector3.ZERO and speed < 2.2:
		lat_pocket = -signf(threat.dot(right)) * 0.13
	var ideal_pos := player.global_position + move_dir * lead_pocket + right * lat_pocket
	var to_ideal := _flat(ideal_pos - ball.global_position)
	var along := off.dot(move_dir)
	var lat_err := absf(off.dot(right) - lat_pocket)
	var turn_ang := move_dir.angle_to(w)
	# Condução orgânica sem efeito "ímã": a bola rola solta com física real,
	# e a assistência suave só atua em limites extremos de desvio (> 0.68m) com blend sutil e imperceptível.
	if along < 0.18 or d > 0.68 or lat_err > 0.22 or turn_ang > deg_to_rad(24.0):
		var guide_vel := w * target_speed + to_ideal * 2.2
		var blend := clampf(delta * 4.5, 0.0, 0.65)
		if along < 0.12 or d > 0.75 or turn_ang > deg_to_rad(38.0):
			blend = clampf(delta * 7.5, 0.0, 0.85)
		var next_bv := bv.lerp(guide_vel, blend)
		ball.touch(Vector3(next_bv.x, 0.0, next_bv.z), player)


## Pés da animação no mundo (posição e velocidade) — para o contato com a bola.
var _ank_prev := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _ank_vel := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _toe_prev := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
const TAP_COOLDOWN := 0.09


func _track_feet(delta: float) -> void:
	var v := player.visual
	if v == null or not v.has_method("get_toe_position") or delta <= 0.0:
		return
	for sd in [1.0, -1.0]:
		var an: Vector3 = v.call("get_ankle_position", sd)
		var tp: Vector3 = v.call("get_toe_position", sd)
		if _toe_prev[sd] != Vector3.ZERO:
			_ank_vel[sd] = (tp - _toe_prev[sd]) / delta
		_ank_prev[sd] = an
		_toe_prev[sd] = tp


## O PÉ (tornozelo → ponta, em 3D) está encostando na bola e indo NA bola?
func _foot_hits_ball(sd: float, bv: Vector3) -> bool:
	var an: Vector3 = _ank_prev[sd]
	var tp: Vector3 = _toe_prev[sd]
	if an == Vector3.ZERO or tp == Vector3.ZERO:
		return false
	var b := ball.global_position
	if minf(an.y, tp.y) > b.y + 0.06:
		return false # pé por cima da bola (passando/pisando): não é o tapa
	var seg := tp - an
	var tt := clampf((b - an).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
	var near := an + seg * tt
	var dist := b.distance_to(near)
	if dist > Ball.RADIUS + 0.055:
		return false
	var n := Vector3(b.x - near.x, 0.0, b.z - near.z)
	if n.length() < 0.02:
		return false # pé em cima da bola (pisando), não é toque de condução
	n = n.normalized()
	var vf: Vector3 = _ank_vel[sd]
	var rel := Vector2(vf.x - bv.x, vf.z - bv.z).dot(Vector2(n.x, n.z))
	return rel > 0.25 # o pé vem na bola (pé apoiado parado não "toca")


func _foot_contact_touch(want: Vector3, pv: Vector3, bv: Vector3) -> void:
	if _since_touch < TAP_COOLDOWN or foot.busy():
		return
	var v := player.visual
	if v == null or not v.has_method("get_toe_position"):
		if ball_distance() < 0.42:
			_tap(want, pv, 0.0)
		return
	var off := ball_offset()
	var d := off.length()
	var speed := pv.length()
	var ref := pv.normalized() if speed > 0.5 else player.facing
	var w := want.normalized() if want.length() >= 0.15 else ref
	var turn_ang := ref.signed_angle_to(w, Vector3.UP)
	var turning := want.length() >= 0.15 and absf(turn_ang) > deg_to_rad(14.0)
	var preferred_foot := _choose_conduction_foot(w, ref, turn_ang, off)
	# 1. Se o pé da animação já encostou na bola, dispara o contato imediato com IK.
	# Quando em curva/corte, prioriza testar o pé preferencial anatomicamente correto.
	var check_order := [preferred_foot, -preferred_foot] if turning else [1.0, -1.0]
	for sd in check_order:
		if _foot_hits_ball(sd, bv):
			if turning and sd != preferred_foot and foot.foot_distance(preferred_foot) < 0.44:
				continue # dá preferência para o pé ideal do corte conduzir
			var mode_hit := _select_conduction_mode(sd, w, pv)
			_foot_side = sd
			foot.begin(sd, w, 0.015, mode_hit, func(): _tap(want, pv, sd), 0.032)
			return
	# 2. Alcance ativo sincronizado com a passada: quando a bola está na zona de
	# condução à frente dos pés (ou quando o jogador pede mudança de direção),
	# escolhe o pé anatomicamente ideal (chapa do pé esquerdo para cortar para a direita,
	# chapa do pé direito para cortar para a esquerda, ou três dedos / sola).
	if d > 0.64:
		return
	var in_front := off.dot(ref) > -0.08 or (turning and off.dot(player.facing) > -0.08)
	if not in_front:
		return
	var cadence := clampf(0.18 - speed * 0.012, 0.11, 0.18)
	if turning:
		cadence = 0.09
	if _since_touch < cadence and d > 0.32 and not turning:
		return
	var chosen_foot := preferred_foot
	var f_dist := foot.foot_distance(chosen_foot)
	if f_dist > 0.54 and not turning and d > 0.36:
		return
	var touch_mode := _select_conduction_mode(chosen_foot, w, pv)
	var lead_t := clampf((f_dist - 0.12) / 4.2, 0.022, 0.048)
	_foot_side = chosen_foot
	foot.begin(chosen_foot, w, lead_t, touch_mode, func(): _tap(want, pv, chosen_foot), 0.038)


func _choose_conduction_foot(_w: Vector3, ref: Vector3, turn_ang: float, off: Vector3) -> float:
	var right := ref.cross(Vector3.UP)
	var lat := off.dot(right)
	# Protegendo a bola do marcador: usa o pé mais distante do adversário (mantendo o corpo entre o marcador e a bola)
	var threat := player._shield_threat()
	if threat != Vector3.ZERO and player.get_horizontal_speed() < 2.3 and absf(turn_ang) < deg_to_rad(25.0):
		var sh_side := -signf(threat.dot(right))
		if absf(sh_side) > 0.1 and foot.foot_distance(sh_side) < 0.48:
			return sh_side
	# Biomecânica real de futebol:
	# Ao cortar para a DIREITA (turn_ang < 0):
	#   O corte natural de futebol é feito com a CHAPA DO PÉ ESQUERDO (-1.0), que vem do lado
	#   esquerdo da bola e empurra para a direita.
	#   Se o pé esquerdo estiver muito longe (> 0.48m) e o direito estiver no pé da bola,
	#   usa o pé direito (que usará três dedos ou sola).
	if turn_ang < -deg_to_rad(12.0):
		var d_left := foot.foot_distance(-1.0)
		var d_right := foot.foot_distance(1.0)
		if d_left <= d_right + 0.22 or d_left < 0.44:
			return -1.0
		return 1.0
	# Ao cortar para a ESQUERDA (turn_ang > 0):
	#   O corte natural de futebol é feito com a CHAPA DO PÉ DIREITO (1.0), que vem do lado
	#   direito da bola e empurra para a esquerda.
	elif turn_ang > deg_to_rad(12.0):
		var d_right := foot.foot_distance(1.0)
		var d_left := foot.foot_distance(-1.0)
		if d_right <= d_left + 0.22 or d_right < 0.44:
			return 1.0
		return -1.0

	# Em condução reta / leve desvio:
	if absf(lat) > 0.12:
		return signf(lat)
	# Alternância natural das passadas entre pé esquerdo e pé direito
	var next_alt := -_foot_side
	var d_alt := foot.foot_distance(next_alt)
	var d_cur := foot.foot_distance(_foot_side)
	if d_alt <= d_cur + 0.14:
		return next_alt
	return _foot_side


func _select_conduction_mode(foot_side: float, w: Vector3, pv: Vector3) -> FootContact.Mode:
	var speed := pv.length()
	var ref := pv.normalized() if speed > 0.5 else player.facing
	var ang := ref.signed_angle_to(w, Vector3.UP)
	# Mudança de direção significativa (corte / curva):
	if absf(ang) > deg_to_rad(10.0):
		var turn_left := ang > 0.0
		if turn_left:
			# Curva para a ESQUERDA:
			# - Pé direito (+1.0): bate de CHAPA do lado direito da bola levando para a esquerda.
			# - Pé esquerdo (-1.0): se velocidade baixa, puxada de SOLA; se alta, TRÊS DEDOS.
			if foot_side > 0.0:
				return FootContact.Mode.INSIDE
			else:
				return FootContact.Mode.SOLE if speed < 2.8 else FootContact.Mode.OUTSIDE
		else:
			# Curva para a DIREITA:
			# - Pé esquerdo (-1.0): bate de CHAPA do lado esquerdo da bola levando para a direita.
			# - Pé direito (+1.0): se velocidade baixa, puxada de SOLA; se alta, TRÊS DEDOS.
			if foot_side < 0.0:
				return FootContact.Mode.INSIDE
			else:
				return FootContact.Mode.SOLE if speed < 2.8 else FootContact.Mode.OUTSIDE

	# Em velocidade alta de corrida: três dedos / peito de pé para conduzir em velocidade
	if speed > 3.6 and player.intent.sprint:
		return FootContact.Mode.OUTSIDE
	# Andando bem devagar ou ajustando ajeitada curta: toque com a sola
	if speed < 1.4 and absf(ang) > deg_to_rad(6.0):
		return FootContact.Mode.SOLE
	return FootContact.Mode.INSIDE


## Distância extra que a bola corre à frente do pé a cada toque (m): perto
## andando, mais longa correndo ("tapas").
static func tap_lead(v_target: float) -> float:
	return lerpf(0.07, 0.30, clampf((v_target - 1.1) / 3.2, 0.0, 1.0))


func _top_speed_with_ball() -> float:
	return player.speed_dribbling if (player.intent.sprint and player.stamina > 0.05) \
		else player.jog_speed * player.ball_speed_factor


## O TAPA: o pé encostou na bola — ela sai na direção pedida, na frente do
## corpo, com a força certa para o jogador alcançá-la na próxima passada.
func _tap(want: Vector3, pv: Vector3, foot_side: float) -> void:
	var speed := pv.length()
	var a := ball.current_rolling()
	var vel: Vector3
	var kind := &"dribble_touch"
	if want.length() < 0.15:
		# soltou o analógico: toque curto que segura a bola (o corpo freia junto)
		var bdir := pv.normalized() if speed > 0.3 else player.facing
		vel = bdir * speed * 0.45
	else:
		var w := want.normalized()
		var ref := pv.normalized() if speed > 0.6 else player.facing
		var ang := ref.signed_angle_to(w, Vector3.UP) # + = esquerda
		var left := ang > 0.0
		var outer := (left and foot_side > 0.0) or (not left and foot_side < 0.0) or foot_side == 0.0
		var lim := deg_to_rad(88.0) if (outer or absf(ang) < deg_to_rad(20.0)) else deg_to_rad(80.0)
		var dir := ref.rotated(Vector3.UP, clampf(ang, -lim, lim))
		var is_cut := absf(ang) > deg_to_rad(18.0)
		if is_cut:
			kind = &"side_touch"
		var v_t := maxf(want.length() * _top_speed_with_ball(), 0.9)
		var lead_dist := tap_lead(v_t) * (0.72 if is_cut else 1.0)
		var u := sqrt(2.0 * a * lead_dist)
		vel = dir * (v_t + u)
		# leva a bola para a linha do corpo (ou para o lado protegido quando sob pressão)
		var right := dir.cross(Vector3.UP)
		var target_lat := 0.0
		var threat := player._shield_threat()
		if threat != Vector3.ZERO and speed < 2.3:
			target_lat = -signf(threat.dot(right)) * 0.14
		var lat := ball_offset().dot(right) - target_lat
		vel -= right * clampf(lat * (2.6 if is_cut else 1.8), -0.95, 0.95)
	ball.touch(Vector3(vel.x, 0.0, vel.z), player)
	_since_touch = 0.0
	_touch_count += 1
	player.notify_touch(kind)


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
	# bola parada à frente, entre os pés e sem encostar nos dedos
	var target := player.global_position + player.facing * 0.37 + pv * 0.08
	var threat: Vector3 = player._shield_threat()
	if threat != Vector3.ZERO:
		# PROTEGENDO: a sola rola a bola para o lado de longe do marcador
		# (o corpo fica entre ele e a bola)
		target = player.global_position - threat * 0.34
	var to := _flat(target - ball.global_position)
	if threat == Vector3.ZERO and not _trapping and bv.length() < 0.3 and pv.length() < 0.6 and d > 0.24 and d < 0.6:
		return # bola parada perto do pé: ela fica; quem se ajusta é o corpo
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
		if not foot.busy() and _since_touch > 0.35 and to.length() > 0.12:
			# a sola não chegou (o corpo girou): tenta de novo com o pé do lado
			_since_touch = 0.0
			foot.begin(foot.nearest_foot(), player.facing, TOUCH_LEAD, FootContact.Mode.SOLE,
				func(): _sole_on = true, 0.15, func(): return _trapping and ball_distance() < 0.8)
		return
	var new_v := pv * 0.85 + to * 5.0
	if (new_v - bv).length() > 0.05:
		ball.touch(new_v.limit_length(6.0), player)
	_since_touch = 0.0


## Girando com a bola presa na sola?
func is_dragging() -> bool:
	return _dragging and has_ball()


func is_reverse_pulling() -> bool:
	return _reverse_pull and _dragging and has_ball()


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
	var lat_w := absf(off.dot(w.cross(Vector3.UP)))
	if ahead > 0.75 and ball_with_me and (lat_w < 0.17 or bv.length() > 1.0):
		return Vector3.INF # bola à frente indo junto: condução normal
	# (bola parada à frente mas fora da linha: o corpo se alinha atrás dela,
	#  senão passa do lado sem o pé alcançar)
	var in_front_of_body := off.dot(player.facing) > 0.12
	var lat_b := absf(off.dot(player.facing.cross(Vector3.UP)))
	# (sem esticar a perna, "no pé" é a bola perto da linha dos pés — o pé ajeita na hora sem precisar rodear)
	if d <= 0.58 and ahead > -0.40 and off.dot(player.facing) > 0.02 and lat_b < 0.30:
		return Vector3.INF # no pé (à frente ou do lado): o toque de lado resolve NA HORA
	if d <= 0.45 and in_front_of_body and ahead < -0.35:
		return Vector3.INF # bola no pé e pediu o contrário: puxada de sola
	var t := clampf(d / maxf(player.sprint_speed, 0.1), 0.05, 0.45)
	var b := ball.predict_ground_position(t)
	b.y = 0.0
	var me := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var right := w.cross(Vector3.UP)
	if in_front_of_body and d < 1.0:
		# Bola à frente do corpo (virada para o lado correndo): vai DIRETO ao
		# ponto atrás dela na nova direção — sem dar a volta.
		return b - w * 0.28 - player.facing * 0.08
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
	# mesma velocidade máxima que o corpo pode ter COM a bola (senão o toque
	# manda a bola mais rápido do que ele corre e ela foge)
	var top := player.speed_dribbling if (player.intent.sprint and player.stamina > 0.05) \
		else player.jog_speed * player.ball_speed_factor
	var target_speed := player.intent.move.length() * top
	# arrancando: o toque já leva a bola no ritmo da arrancada (o corpo acelera
	# rápido atrás dela), não 0,8 m/s por vez
	var v_p := maxf(minf(target_speed, speed + 2.4), speed * 0.9)
	# Cadência: passo mais curto devagar, toque mais longo no sprint.
	var T := clampf(0.55 - v_p * 0.035, 0.36, 0.55)
	var extra := 0.0
	if sprinting:
		# correndo forte: toque um pouco mais longo, mas a bola continua perto
		T = 0.46
		extra = 0.1
	# Perto da linha: toque mais curto e sem empurrar a bola para fora.
	var bp := ball.global_position
	if Field.HALF_WIDTH - absf(bp.z) < 1.2 and signf(dir.z) == signf(bp.z):
		dir = Vector3(dir.x, 0.0, dir.z * 0.3)
		dir = dir.normalized() if dir.length() > 0.1 else player.facing
		extra = 0.0
	_foot_side = -_foot_side
	var right := dir.cross(Vector3.UP)
	var lead := FOOT_DISTANCE + 0.02 + extra + _rng.randf_range(-0.03, 0.03)
	# Onde o jogador vai estar no próximo passo: ainda carrega a velocidade
	# atual (inércia de uma virada) misturada com a nova direção.
	var pv_now := _flat(player.velocity)
	var travel := (pv_now * 0.45 + dir * v_p * 0.55) * T
	if player.intent.move.length() < 0.1:
		# freando: cada toque curto tira ~2,2 m/s da bola (o corpo freia junto)
		travel = dir * maxf(speed - 2.2, 0.0) * T
	var p_next := player.global_position + travel + dir * lead + right * (_foot_side * 0.025)
	var to := _flat(p_next - bp)
	var a := ball.current_rolling()
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

func execute_through_pass(power: float, aim: Vector3, lofted := false) -> bool:
	return execute_pass(power, aim, null, lofted)


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
	player.set_meta("last_pass_ms", Time.get_ticks_msec()) # p/ o "passa e vai"
	var vel: Vector3
	var receiver: Player = mate
	var align_dot := player.facing.dot(dir)
	var align_k := lerpf(0.82, 1.0, clampf((align_dot + 1.0) * 0.5, 0.0, 1.0))
	if mate != null:
		var dest := _lead_target(mate, from)
		if long:
			vel = lofted_velocity(from, from + _flat(dest - from) * 0.92, lerpf(32.0, 50.0, power))
		else:
			# Passe rasteiro com peso e força padrão assertiva desde o toque único
			vel = ground_pass_velocity(from, dest, lerpf(4.8, 6.8, power))
			vel = vel.normalized() * clampf(vel.length() * align_k, lerpf(11.0, 16.5, power), 18.0)
	else:
		# Passe em profundidade (para o espaço): vai quem estiver melhor para chegar.
		var dest := from + dir * lerpf(7.0, 16.0, power)
		dest = Field.clamp_inside(dest, 0.5)
		receiver = _best_runner_to(dest)
		if long:
			vel = lofted_velocity(from, dest, lerpf(34.0, 50.0, power))
		else:
			# Para o espaço: passe firme na corrida
			vel = ground_pass_velocity(from, dest, lerpf(2.2, 3.8, power))
			vel = vel.normalized() * clampf(vel.length() * align_k, 8.5, 14.8)
	# Precisão: toque curto praticamente no pé; passe forte ou desalinhado um pouco menos.
	var err := deg_to_rad(0.25 + 0.75 * power)
	if align_dot < 0.2:
		err *= 1.35
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
	var ty := _rng.randf_range(0.12, 0.46)
	var target := Vector3(goal_x, ty, _choose_shot_z(from, goal_x, aim))
	var speed := lerpf(14.2, 22.0, power)
	var flat_to := _flat(target - from)
	var d := maxf(flat_to.length(), 0.5)
	var dir := flat_to / d
	# Modulação biomecânica (inspirado em striker-3d): alinhamento do corpo e distância da bola ao pé.
	var facing_dot := player.facing.dot(dir)
	var back := facing_dot < -0.2 # de costas para o gol
	if back:
		speed *= 0.55
	elif facing_dot < 0.4:
		speed *= lerpf(0.76, 1.0, clampf((facing_dot + 0.2) / 0.6, 0.0, 1.0))
	var spread := deg_to_rad(lerpf(0.8, 3.2, power))
	if back:
		spread *= 3.0
	if ball_distance() > 0.7:
		spread *= 1.3
		speed *= 0.90
	if facing_dot < 0.3:
		spread *= 1.6
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var t := d / speed
	var vy := (ty - from.y) / t + 0.5 * g * t
	vy += _rng.randf_range(-0.18, 0.32) * power
	var spin := Vector3.UP * _rng.randf_range(-6.5, 6.5) * power
	ball.kick(dir * speed + Vector3.UP * vy, spin + _roll_spin(dir), player, kick_cooldown)
	player.notify_touch(&"shoot")
	GameEvents.ball_kicked.emit(player, &"shoot", power)
	return true


## Chute mirado pelo humano: a bola segue a direção escolhida (com peso e
## velocidade realista de futebol de rua, sem sair como um foguete).
func _execute_aimed_shot(power: float, dir: Vector3) -> bool:
	var from := ball.global_position
	var speed := lerpf(14.2, 22.0, power)
	var spread := deg_to_rad(lerpf(0.4, 1.8, power))
	var facing_dot := player.facing.dot(dir)
	if facing_dot < 0.3:
		spread *= 1.6
		speed *= lerpf(0.76, 1.0, clampf((facing_dot + 0.2) / 0.5, 0.0, 1.0))
	if facing_dot < -0.2:
		# de costas para onde quer chutar: sem força e sem precisão
		spread *= 3.0
		speed *= 0.55
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	# Altura: até o gol (se estiver mirando para ele) ou ~10 m.
	var goal_x := Field.goal_line_x(Team.other(player.team))
	var d := 10.0
	if absf(dir.x) > 0.1 and signf(dir.x) == signf(goal_x - from.x):
		d = clampf((goal_x - from.x) / dir.x, 2.0, 25.0)
	var ty := lerpf(0.12, 0.42, power) + _rng.randf_range(-0.05, 0.08)
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var t := d / speed
	var vy := clampf((ty - from.y) / t + 0.5 * g * t, 0.0, 5.2)
	var spin := Vector3.UP * _rng.randf_range(-4.0, 4.0) * power
	ball.kick(dir * speed + Vector3.UP * vy, spin + _roll_spin(dir), player, kick_cooldown)
	player.notify_touch(&"shoot")
	GameEvents.ball_kicked.emit(player, &"shoot", power)
	return true


## Cavadinha: bola alta e lenta, por cima de quem está na frente.
func _execute_chip(power: float, dir: Vector3) -> bool:
	var spread := deg_to_rad(2.0)
	dir = dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	# barra cheia + arrastar para cima = bem mais alto (e mais longe)
	var speed := lerpf(4.8, 9.2, power)
	var vy := lerpf(5.2, 9.8, power)
	ball.kick(dir * speed + Vector3.UP * vy, Vector3.ZERO, player)
	player.notify_touch(&"shoot")
	GameEvents.ball_kicked.emit(player, &"shoot", power)
	return true


## Drible bilateral: corte curto/explosivo com o pé adequado (parte externa
## para corte lateral rápido ou parte interna para finta/mudança de direção).
func execute_dribble(aim: Vector3) -> bool:
	if not has_ball() or ball_distance() > KICK_REACH:
		return false
	var dir := _aim_dir(aim)
	var ang := player.facing.signed_angle_to(dir, Vector3.UP)
	var cut := absf(ang) > deg_to_rad(22.0)
	var d_foot := (-1.0 if ang > 0.0 else 1.0) if cut else -_foot_side
	_foot_side = d_foot
	var d_mode := FootContact.Mode.OUTSIDE if cut else FootContact.Mode.INSIDE
	foot.begin(d_foot, dir, 0.02, d_mode, Callable(), 0.05)
	var base := maxf(_flat(player.velocity).dot(dir), 0.0)
	ball.touch(dir * (base + (2.2 if cut else 3.0)), player)
	_since_touch = 0.0
	_touch_count += 1
	player.notify_touch(&"dribble")
	return true


func execute_tackle() -> bool:
	var carrier := find_tackle_target(TACKLE_RANGE + 0.3)
	if carrier == null:
		return false
	# DESARME pela GEOMETRIA e ALCANCE DO PÉ (inspirado em HaxSoccer / striker-3d):
	# o pé de bote precisa ter linha limpa até a bola (sem atravessar o corpo de quem protege).
	var me := _flat(player.global_position)
	var bp := _flat(ball.global_position)
	var cp := _flat(carrier.global_position)
	var reach := (bp - me).length()
	if reach > 1.12:
		return false # bola longe do pé: errou o bote
	# Corpo no caminho (protegendo de costas/de lado): o pé bate na perna dele.
	var seg := bp - me
	var tt := clampf((cp - me).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
	var body_block := (me + seg * tt).distance_to(cp) < 0.28 and (cp - me).length() < reach
	if body_block:
		if (cp - me).length() < 0.78 and _rng.randf() < 0.28:
			carrier.stumble(0.45)
			if player.match_manager != null:
				player.match_manager.award_free_kick(carrier.team, carrier.global_position)
		return false
	# Bola exposta (longe do pé de quem conduz) = fácil; colada = disputa física.
	var ball_from_c := (bp - cp).length()
	var exposure := clampf((ball_from_c - 0.28) / 0.42, 0.0, 1.0)
	var p_win := 0.35 + exposure * 0.62
	var cbc: BallControl = carrier.ball_control
	if cbc._since_touch < 0.12:
		p_win -= 0.14 # acabou de tocar: a bola está sob controle do pé dele
	if carrier.facing.dot((me - cp).normalized()) > 0.35:
		p_win += 0.12 # bote frontal: a bola está exposta à frente
	if carrier.state == Player.State.ACTION:
		p_win += 0.15
	if _rng.randf() > p_win:
		return false
	var poke := (me - bp).normalized() if reach > 0.05 else -player.facing
	if reach <= 0.88 and ball.flat_velocity().length() < 4.2:
		# Bem perto e equilibrado: o pé fisga a bola com firmeza e assume o domínio.
		ball.claim(player)
		var steal_vel := (player.facing * 1.3 + _flat(player.velocity) * 0.45).limit_length(2.8)
		ball.touch(steal_vel, player)
		_since_touch = 0.0
	else:
		poke = poke.rotated(Vector3.UP, _rng.randf_range(-0.45, 0.45))
		ball.kick(poke * _rng.randf_range(1.8, 2.9), Vector3.ZERO, player, 0.05)
	carrier.stumble(0.38)
	GameEvents.ball_kicked.emit(player, &"tackle", 0.5)
	return true


## Carrinho: no instante em que o pé chega na bola. Se ela estiver ao alcance
## do pé que desliza, é desviada; quem conduzia tropeça (ou já tinha pulado).
func execute_slide_tackle() -> bool:
	if ball == null or not ball.in_play:
		return false
	var off := ball_offset()
	var carrier := ball.possessor
	var ball_hit := not (off.length() > 1.25 or off.dot(player.facing) < -0.1 or ball.global_position.y > 0.6)
	if not ball_hit:
		# Não pegou a bola: se o carrinho pegou o ADVERSÁRIO, é falta.
		if carrier != null and carrier.team != player.team and not carrier.is_jumping():
			var to_c := _flat(carrier.global_position - player.global_position)
			if to_c.length() < 1.1 and to_c.dot(player.facing) > -0.1:
				carrier.trip()
				if player.match_manager != null:
					player.match_manager.award_free_kick(carrier.team, carrier.global_position)
		return false
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
func drag_ball_to(dir: Vector3, speed := 2.2) -> void:
	if has_ball():
		# A sola vai na bola e a puxa para o novo lado.
		foot.begin(foot.nearest_foot(), -dir, 0.07, FootContact.Mode.SOLE,
			func(): ball.touch(dir * speed, player), 0.12) # sai junto com o corpo no fim da virada
		_since_touch = 0.0
		player.notify_touch(&"drag")


## Toque de lado com o pé do lado certo (início de um corte correndo).
## Giro parado: a sola leva a bola até a frente da NOVA direção do corpo
## (ela termina no pé quando o giro termina).
func drag_ball_around(new_dir: Vector3, time: float) -> void:
	if not has_ball():
		return
	foot.begin(foot.nearest_foot(), new_dir, 0.07, FootContact.Mode.SOLE, func():
		var tgt := player.global_position + new_dir * 0.46
		var v := _flat(tgt - ball.global_position) / maxf(time, 0.2) + new_dir * (0.5 * ball.current_rolling() * time)
		ball.touch(v.limit_length(2.5), player), 0.15)
	_since_touch = 0.0
	player.notify_touch(&"drag")


func touch_towards(dir: Vector3) -> void:
	if not has_ball():
		return
	var turn_side := -signf(player.facing.signed_angle_to(dir, Vector3.UP))
	var f := -turn_side if turn_side != 0.0 else foot.nearest_foot()
	foot.begin(f, dir, 0.06, FootContact.Mode.INSIDE, func():
		_do_touch(dir, _flat(player.velocity).length(), 0.0)
		player.notify_touch(&"side_touch"))
	_since_touch = 0.0


## Empurra a bola à frente (ex.: ao pular um carrinho).
func push_ahead(mult: float) -> void:
	if has_ball():
		var v := _flat(player.velocity)
		ball.touch(player.facing * maxf(v.length(), 3.0) * mult, player)
		_since_touch = 0.0


func pick_pass_target(dir: Vector3, max_angle_deg := 70.0) -> Player:
	var best: Player = null
	var best_score := -INF
	var pos := player.global_position
	for mate in player.get_teammates():
		var to := _flat(mate.global_position - pos)
		var d := to.length()
		if d < 1.5:
			continue
		var ang := dir.angle_to(to / d)
		if ang > deg_to_rad(max_angle_deg):
			continue
		var score := -ang * 2.0 - d * 0.04
		if mate.is_goalkeeper():
			score -= 0.6
		for opp in player.get_opponents():
			var p2 := Vector2(opp.global_position.x, opp.global_position.z)
			var a2 := Vector2(pos.x, pos.z)
			var b2 := Vector2(mate.global_position.x, mate.global_position.z)
			var ab := b2 - a2
			var l2 := ab.length_squared()
			if l2 > 0.01:
				var t := clampf((p2 - a2).dot(ab) / l2, 0.0, 1.0)
				if p2.distance_to(a2 + ab * t) < 0.80:
					score -= 1.1
		if score > best_score:
			best_score = score
			best = mate
	return best


static func ground_pass_velocity(from: Vector3, to: Vector3, end_speed: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := flat.length()
	if d < 0.01:
		return Vector3.ZERO
	var a := 2.45 # desaceleração média: rolamento nos bloquinhos (2,0) + arrasto do ar
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
	var mv := mate.get_flat_velocity()
	for i in 2:
		var t := _flat(dest - from).length() / 11.2
		dest = mate.global_position + mv * t * 0.82
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
