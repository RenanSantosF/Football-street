class_name AIController
extends Node
## IA simples e organizada (Etapa 1). Decide a cada 0,1–0,2 s (tempo de reação)
## e produz o mesmo PlayerIntent que o controle humano.
##
## Estrutura por situação, pronta para virar uma máquina de estados/utility AI
## na Etapa 5:
##   - com a bola: chutar / passar / conduzir evitando marcadores
##   - bola livre: o melhor perseguidor do time vai nela, os outros se posicionam
##   - companheiro com a bola: apoiar abrindo espaço (sem embolar)
##   - adversário com a bola: um pressiona e tenta desarmar, os outros marcam
##   - goleiro: posicionamento no arco, saída do gol e defesa de chute

var player: Player

var _think_timer := 0.0
var _move_target := Vector3.ZERO
var _sprint := false
var _action: PlayerIntent.Action = PlayerIntent.Action.NONE
var _action_power := 0.0
var _action_aim := Vector3.ZERO
var _action_target: Player = null
var _hold_time := 0.0
var _tackle_cooldown := 0.0
var _patience := 2.5
## Espera (bola parada): comportamento variado e mais lento.
var _idle_timer := 0.0
var _idle_target := Vector3.ZERO
var _walk_only := false
## Protegendo a bola (corpo entre o marcador e a bola).
var _shield := false
## Há quanto tempo está protegendo (ninguém segura a bola para sempre).
var _shield_time := 0.0
## Próximo passe é em profundidade (para o espaço à frente do companheiro).
var _through := false
## Personalidade defensiva: quão cedo/afoito dá o bote (0,6..1,3).
var _aggression := 1.0
## Lado por onde este defensor tenta chegar na bola (+1/-1), trocado às vezes.
var _attack_side := 1.0
const GESTURES: Array[StringName] = [&"argue", &"warmup", &"talk", &"kick_up"]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_patience = _rng.randf_range(1.6, 3.4)
	_aggression = _rng.randf_range(0.6, 1.3)
	_attack_side = 1.0 if _rng.randf() < 0.5 else -1.0


func fill_intent(p: Player, intent: PlayerIntent, delta: float) -> void:
	player = p
	if player.match_manager == null:
		return
	_tackle_cooldown -= delta
	if player.ball_control.has_ball():
		_hold_time += delta
	else:
		_hold_time = 0.0
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = _rng.randf_range(0.1, 0.2)
		_think()

	var to := _move_target - player.global_position
	to.y = 0.0
	var d := to.length()
	intent.move = Vector3.ZERO if d < 0.25 else to / d * clampf(d / 1.5, 0.3, 1.0)
	if _walk_only:
		intent.move = intent.move.limit_length(0.42) # andando, sem pressa
	intent.sprint = _sprint and d > 2.0 and not _walk_only
	intent.shield = _shield and player.ball_control.has_ball()
	_shield_time = _shield_time + delta if intent.shield else 0.0
	if intent.shield:
		intent.move = intent.move.limit_length(0.5)
	if _action != PlayerIntent.Action.NONE:
		intent.set_action(_action, _action_power, _action_aim, _action_target)
		intent.through = _through and _action == PlayerIntent.Action.PASS
		_action = PlayerIntent.Action.NONE
		_through = false


# --- Decisão -----------------------------------------------------------------------

func _think() -> void:
	var mm := player.match_manager
	var ball := player.ball
	_sprint = false
	_shield = false
	_walk_only = false
	if not mm.is_ball_live():
		_think_waiting(mm.formation_position(player.team, player.formation_index, ball.global_position.x))
		_keep_restart_distance()
		return
	# Reinício pendente (saída, lateral, escanteio, tiro de meta, falta): até o
	# batedor tocar, ninguém vai na bola — cada um na sua posição da formação,
	# parado do seu jeito ou andando pouquinho. Adversário no próprio campo.
	if ball.restricted_player != null and ball.restricted_player != player:
		var slot := mm.formation_position(player.team, player.formation_index, ball.global_position.x)
		if mm.waiting_kickoff:
			slot.x = minf(slot.x * Field.attack_sign(player.team), -1.5) * Field.attack_sign(player.team)
		_think_waiting(slot)
		_keep_restart_distance()
		return
	if player.is_goalkeeper():
		_think_goalkeeper()
	elif player.ball_control.has_ball():
		_think_with_ball()
	else:
		var carrier := ball.possessor
		if carrier == null and ball.restricted_player != null and ball.restricted_player != player:
			# Reinício do meu time (ou do outro): não vou na bola, me posiciono.
			_support_or_mark(ball.restricted_player if ball.restricted_player.team == player.team else null)
		elif carrier == null and ball.pass_target == player:
			# O passe é para mim: o Player busca a bola sozinho (_receive_pass).
			_move_target = player.global_position
		elif carrier == null:
			if _is_best_chaser():
				_move_target = _intercept_point()
				_sprint = true
			else:
				_support_or_mark(null)
		elif carrier.team == player.team:
			_support_or_mark(carrier)
		else:
			_defend(carrier)
	_keep_restart_distance()
	_move_target = Field.clamp_inside(_move_target, 0.3)


## Bola parada (tiro de meta, lateral, saída, gol): cada um faz uma coisa —
## parado respirando, andando um pouco, reclamando, aquecendo, conversando,
## fazendo embaixadinha. Sempre andando (devagar), nunca correndo.
func _think_waiting(slot: Vector3) -> void:
	_walk_only = true
	if _idle_target == Vector3.ZERO or _idle_target.distance_to(slot) > 4.5:
		_idle_target = slot
	_idle_timer -= 0.15
	if _idle_timer <= 0.0:
		_idle_timer = _rng.randf_range(2.5, 6.5)
		var r := _rng.randf()
		if r < 0.35:
			_idle_target = slot + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-1.5, 1.5))
		elif r < 0.75:
			_idle_target = player.global_position
			player.play_gesture(GESTURES[_rng.randi_range(0, GESTURES.size() - 1)], _rng.randf_range(2.5, 5.5))
		else:
			_idle_target = player.global_position
	_move_target = Field.clamp_inside(_idle_target, 0.5)


func _think_with_ball() -> void:
	if player.is_restart_locked():
		# Reinício: obrigado a tocar. Espera um instante e passa.
		_move_target = player.global_position
		if _hold_time > 0.6:
			var mate := _best_pass_option()
			if mate == null:
				mate = _nearest_teammate()
			if mate != null:
				var d := mate.global_position.distance_to(player.global_position)
				_set_action(PlayerIntent.Action.PASS, 0.3 if d < 11.0 else 0.7, Vector3.ZERO, mate)
		return
	if _go_to_loose_ball():
		return
	var opp_goal := Field.goal_center(Team.other(player.team))
	var pos := player.global_position
	var to_goal := opp_goal - pos
	to_goal.y = 0.0
	var dist_goal := to_goal.length()
	var dir_goal := to_goal / maxf(dist_goal, 0.01)

	# Chute.
	if _hold_time > 0.25 and dist_goal < 10.0 and absf(dir_goal.x) > 0.55:
		if dist_goal < 6.0 or _lane_clear(pos, opp_goal, 0.8, true):
			_set_action(PlayerIntent.Action.SHOOT, clampf(dist_goal / 12.0, 0.35, 0.95), Vector3.ZERO, null)
			_move_target = pos + dir_goal
			return

	# 1. Tabela (1-2 / passa e vai) ou companheiro infiltrando livre à frente.
	var s := Field.attack_sign(player.team)
	if _hold_time > 0.26:
		var best_mate := _best_pass_option()
		if best_mate != null:
			var mate_pass_ms := best_mate.get_meta("last_pass_ms", -100000) as int
			var is_give_and_go := Time.get_ticks_msec() - mate_pass_ms < 2600 \
				and (best_mate.global_position.x - pos.x) * s > 1.2
			var adv := (best_mate.global_position.x - pos.x) * s
			var mate_open := _nearest_opponent_distance(best_mate.global_position) > 2.4
			# Companheiro arrancando para o ataque com espaço na frente: PROFUNDIDADE.
			var mate_runs := best_mate.get_flat_velocity().dot(Vector3(s, 0.0, 0.0)) > 1.6
			if mate_runs and adv > 1.0 and _rng.randf() < 0.55:
				var pw := _rng.randf_range(0.35, 0.75)
				var dest := player.ball_control.through_destination(best_mate, pw, Vector3.ZERO)
				if _nearest_opponent_distance(dest) > 2.4 and _lane_clear(pos, dest, 0.7):
					_set_action(PlayerIntent.Action.PASS, pw, Vector3.ZERO, best_mate)
					_through = true
					_patience = _rng.randf_range(1.2, 2.5)
					return
			if is_give_and_go or (_hold_time > 0.55 and adv > 2.2 and mate_open):
				var dp := best_mate.global_position.distance_to(pos)
				_set_action(PlayerIntent.Action.PASS, 0.32 if dp < 11.0 else 0.68, Vector3.ZERO, best_mate)
				_patience = _rng.randf_range(1.2, 2.5)
				return

	# 2. Passe sob pressão ou por paciência (troca de passes fluida).
	var nearest := _nearest_opponent_distance(pos)
	var pressured := nearest < 2.2
	if (pressured and _hold_time > 0.28) or _hold_time > _patience:
		var mate := _best_pass_option()
		if mate != null:
			var d := mate.global_position.distance_to(pos)
			_set_action(PlayerIntent.Action.PASS, 0.3 if d < 11.0 else 0.7, Vector3.ZERO, mate)
			_patience = _rng.randf_range(1.3, 2.6)
			return

	# Marcador colado e sem passe: PROTEGE (corpo entre ele e a bola) e
	# gira para o lado, sem correr para cima dele.
	if nearest < 1.4:
		var closest: Player = null
		for opp in player.get_opponents():
			if closest == null or opp.global_position.distance_to(pos) < closest.global_position.distance_to(pos):
				closest = opp
		var away := pos - closest.global_position
		away.y = 0.0
		away = away.normalized()
		# Marcador colado: PROTEGE com o corpo (base aberta, bola do lado de longe)
		# por pouco tempo; depois toca para alguém ou sai girando para o lado.
		if _shield_time > _rng.randf_range(0.9, 1.6):
			var out_mate := _best_pass_option()
			if out_mate == null:
				out_mate = _nearest_teammate()
			if out_mate != null and _rng.randf() < 0.65:
				var dpm := out_mate.global_position.distance_to(pos)
				_set_action(PlayerIntent.Action.PASS, 0.3 if dpm < 11.0 else 0.65, Vector3.ZERO, out_mate)
			else:
				var lat_out := away.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
				_set_action(PlayerIntent.Action.DRIBBLE, 1.0, (lat_out + away * 0.5).normalized(), null)
			_shield_time = 0.0
			return
		_shield = nearest < 1.2
		if away.dot(dir_goal) < 0.2:
			var lateral := dir_goal.cross(Vector3.UP)
			if lateral.dot(away) < 0.0:
				lateral = -lateral
			_move_target = pos + (away * 0.6 + lateral * 0.8).normalized() * 1.2
			_sprint = false
			return

	# Conduzir para o gol, desviando de quem está na frente.
	var dir := dir_goal
	for opp in player.get_opponents():
		var off := opp.global_position - pos
		off.y = 0.0
		var dd := off.length()
		if dd < 3.5 and off.dot(dir_goal) > 0.0:
			var side := signf(dir_goal.cross(Vector3.UP).dot(off))
			if side == 0.0:
				side = 1.0
			dir -= dir_goal.cross(Vector3.UP) * side * (3.5 - dd) * 0.5
			if dd < 1.6 and _rng.randf() < 0.15:
				var cut := (dir_goal - dir_goal.cross(Vector3.UP) * side * 1.5).normalized()
				_set_action(PlayerIntent.Action.DRIBBLE, 1.0, cut, null)
	# Não colar na lateral.
	if absf(pos.z) > Field.HALF_WIDTH - 0.8:
		dir.z -= signf(pos.z) * 0.8
	dir = dir.normalized()
	_move_target = pos + dir * 3.0
	_sprint = nearest > 3.0 and player.stamina > 0.4 and dist_goal > 8.0


func _support_or_mark(carrier: Player) -> void:
	var s := Field.attack_sign(player.team)
	var ball_pos := player.ball.global_position
	if carrier != null:
		# APOIO: os dois companheiros ficam LONGE o bastante para receber
		# (nunca colados em quem conduz) e se mexem:
		#  - o de frente INFILTRA: alterna entre vir buscar e correr nas costas
		#    do marcador, no corredor oposto ao da bola;
		#  - o outro abre no lado da bola, na diagonal, como opção segura.
		#  - quem acabou de passar faz o "passa e vai" (tabela): corre para a
		#    frente para receber de volta.
		var c := carrier.global_position
		var side := signf(c.z)
		if absf(c.z) < 0.6:
			side = 1.0 if player.formation_index == 1 else -1.0
		var goal_x := Field.goal_line_x(Team.other(player.team))
		# linha do último defensor (sem goleiro) entre a bola e o gol
		var def_x := c.x + s * 3.0
		for opp in player.get_opponents():
			if opp.is_goalkeeper():
				continue
			if (opp.global_position.x - c.x) * s > 0.0:
				def_x = opp.global_position.x if (opp.global_position.x - c.x) * s > (def_x - c.x) * s else def_x
		var t := Time.get_ticks_msec() / 1000.0 + float(player.formation_index) * 2.3
		var running := fmod(t, 4.5) > 2.3 # ciclo: vem buscar ↔ corre nas costas
		var deep_x := def_x + s * 1.8
		var short_x := c.x + s * 4.5
		var run_x := deep_x if running else short_x
		run_x = c.x + s * clampf((run_x - c.x) * s, 4.0, 9.0)
		run_x = goal_x - s * maxf((goal_x - run_x) * s, 2.2)
		var spot_a := Vector3(run_x, 0.0, -side * 3.1)
		var spot_b := Vector3(c.x + s * 1.0, 0.0, side * 3.8) if absf(c.z) < 1.8 \
			else Vector3(c.x - s * 4.5, 0.0, -side * 0.5)
		var mates: Array[Player] = []
		for m in player.get_teammates():
			if m != carrier and not m.is_goalkeeper():
				mates.append(m)
		var target := spot_a
		var my_pass := player.get_meta("last_pass_ms", -100000) as int
		var just_passed := Time.get_ticks_msec() - my_pass < 2600 and player.ball.last_toucher != player
		if just_passed:
			# PASSA E VAI: corre para o espaço à frente de quem recebeu, pelo
			# outro lado — opção da tabela.
			target = Vector3(c.x + s * 5.5, 0.0, -side * 2.6)
			target.x = goal_x - s * maxf((goal_x - target.x) * s, 2.2)
			_sprint = true
		elif mates.size() >= 1:
			var other: Player = mates[0] # get_teammates() já exclui o próprio jogador
			var mine_a := player.global_position.distance_to(spot_a) + other.global_position.distance_to(spot_b)
			var mine_b := player.global_position.distance_to(spot_b) + other.global_position.distance_to(spot_a)
			# desempate estável pelo número da formação
			if absf(mine_a - mine_b) < 1.5:
				target = spot_a if player.formation_index < other.formation_index else spot_b
			else:
				target = spot_a if mine_a < mine_b else spot_b
			_sprint = target == spot_a and running
		# nunca colado em quem está com a bola
		var from_c := target - c
		from_c.y = 0.0
		if from_c.length() < 5.0:
			target = c + (from_c.normalized() if from_c.length() > 0.1 else Vector3(s, 0, 0)) * 5.0
		# Se um defensor estiver bloqueando a linha de passe, abre lateralmente para sair da sombra.
		if not _lane_clear(c, target, 0.85):
			var shift_dir := Vector3(0.0, 0.0, 1.6 if target.z <= 0.0 else -1.6)
			var alt := Field.clamp_inside(target + shift_dir, 0.7)
			if _lane_clear(c, alt, 0.8):
				target = alt
		_move_target = Field.clamp_inside(target, 0.7)
		_sprint = _sprint or player.global_position.distance_to(_move_target) > 4.0
		return
	else:
		# Bola livre e não sou o perseguidor: zona do meu lado.
		var base := player.match_manager.formation_position(player.team, player.formation_index, ball_pos.x)
		_move_target = base.lerp(ball_pos, 0.25)
	_separate_from_teammates()


func _defend(carrier: Player) -> void:
	var own_goal := Field.goal_center(player.team)
	# O jogador que VOCÊ controla é quem pressiona quando está perto (ou
	# segurando BUSCAR): a IA do seu time fica marcando, não vai junto.
	var human_presses := false
	for mate in player.get_teammates():
		if mate.is_human:
			var hi := player.match_manager.human_input
			var chasing: bool = hi != null and hi.chasing
			if chasing or mate.global_position.distance_to(carrier.global_position) < \
					player.global_position.distance_to(carrier.global_position) + 2.0:
				human_presses = true
	if not human_presses and _is_closest_field_player_to(carrier.global_position):
		# Pressionar: ficar entre o atacante e o gol, e dar o bote.
		var to_goal := (own_goal - carrier.global_position)
		to_goal.y = 0.0
		var d := player.global_position.distance_to(carrier.global_position)
		# CERCAR: chega rápido, fecha o corredor do gol e encurta na bola quando o atacante dá espaço.
		var bp := player.ball.global_position
		var ball_exposed := Vector2(bp.x - carrier.global_position.x, bp.z - carrier.global_position.z).length() > 0.48
		var dist_offset := 0.85 if ball_exposed else 1.05
		_move_target = carrier.global_position + to_goal.normalized() * dist_offset + carrier.get_flat_velocity() * 0.28
		_sprint = d > 2.4
		var me := player.global_position
		if d < 2.3:
			# Perto: ataca a BOLA, não o corpo. Chega pelo lado em que a bola está
			# exposta (ao lado dela), e troca de lado se o corpo dele fecha.
			var cp := carrier.global_position
			var c_to_b := Vector3(bp.x - cp.x, 0.0, bp.z - cp.z)
			var axis := c_to_b.normalized() if c_to_b.length() > 0.1 else carrier.facing
			var perp := axis.cross(Vector3.UP)
			var mine := signf((me - cp).dot(perp))
			if mine != 0.0 and _rng.randf() < 0.85:
				_attack_side = mine
			if _line_blocked_by(carrier, me, bp) and _rng.randf() < 0.25:
				_attack_side = -_attack_side # corpo dele na frente: tenta pelo outro lado
			_move_target = Vector3(bp.x, 0.0, bp.z) + axis * 0.2 + perp * _attack_side * 0.62
			_sprint = false
		var ball_near_me := Vector2(bp.x - me.x, bp.z - me.z).length() < 1.15
		var clear := not _line_blocked_by(carrier, me, bp)
		var just_touched: bool = carrier.ball_control._since_touch < 0.25
		var chance := (0.55 if ball_exposed or just_touched else 0.12) * _aggression
		if ball_near_me and clear and _tackle_cooldown <= 0.0 and _rng.randf() < chance:
			# Bote em pé com linha limpa até a bola: o pé vai nela (física do contato).
			_tackle_cooldown = _rng.randf_range(0.7, 1.4) / _aggression
			_set_action(PlayerIntent.Action.DRIBBLE, 0.0, Vector3.ZERO, null)
		elif d < Player.SLIDE_RANGE - 0.4 and d > 1.8 and _tackle_cooldown <= 0.0:
			# Carrinho: mais provável quando o atacante se aproxima do gol.
			_tackle_cooldown = _rng.randf_range(1.5, 3.0)
			var danger := 1.0 - clampf(carrier.global_position.distance_to(own_goal) / 20.0, 0.0, 1.0)
			if _rng.randf() < 0.06 + 0.16 * danger:
				_set_action(PlayerIntent.Action.SHOOT, 0.0, Vector3.ZERO, null)
	else:
		# Marcar o outro atacante pelo lado do gol.
		var mark: Player = null
		var best := INF
		for opp in player.get_opponents():
			if opp == carrier or opp.is_goalkeeper():
				continue
			var dd := opp.global_position.distance_to(own_goal)
			if dd < best:
				best = dd
				mark = opp
		if mark != null:
			var back := own_goal - mark.global_position
			back.y = 0.0
			_move_target = mark.global_position + back.normalized() * 1.5
		else:
			_move_target = carrier.global_position.lerp(own_goal, 0.5)
		_sprint = player.global_position.distance_to(_move_target) > 4.0
	_separate_from_teammates()


func _think_goalkeeper() -> void:
	var team := player.team
	var goal := Field.goal_center(team)
	var s := Field.attack_sign(team)
	var ball := player.ball
	var bp := ball.global_position

	if player.ball_control.has_ball():
		if _go_to_loose_ball():
			return
		_move_target = player.global_position
		if _hold_time > 0.7:
			var mate := _best_pass_option()
			if mate != null:
				_set_action(PlayerIntent.Action.PASS, 0.35, Vector3.ZERO, mate)
			elif _hold_time > 2.0:
				_set_action(PlayerIntent.Action.PASS, 0.8, Vector3(s, 0.0, 0.0), null)
		return

	# Chute vindo: ir para o ponto onde a bola cruza a linha.
	var bv := ball.velocity_now()
	if bv.x * s < -3.0:
		var t := (goal.x - bp.x) / bv.x
		if t > 0.0 and t < 1.6:
			var zc := bp.z + bv.z * t
			if absf(zc) < Field.GOAL_HALF_WIDTH + 0.7:
				_move_target = Vector3(goal.x + s * 0.4, 0.0, clampf(zc, -0.95, 0.95))
				_sprint = true
				return

	# Bola livre perto do gol: sair para pegar.
	var flat_bp := Vector3(bp.x, 0.0, bp.z)
	if ball.possessor == null and flat_bp.distance_to(goal) < 3.5:
		var my_d := player.global_position.distance_to(flat_bp)
		if my_d < _nearest_opponent_distance(flat_bp) + 0.3:
			_move_target = flat_bp
			_sprint = true
			return

	# Posicionamento: na linha bola–centro do gol, saindo um pouco.
	var to_ball := flat_bp - goal
	var dist := to_ball.length()
	var out := clampf(dist * 0.12, 0.4, 1.4)
	var p := goal + to_ball.normalized() * out if dist > 0.01 else goal + Vector3(s * 0.5, 0.0, 0.0)
	p.z = clampf(p.z, -0.9, 0.9)
	var depth := clampf((p.x - goal.x) * s, 0.25, 3.0)
	p.x = goal.x + depth * s
	_move_target = p
	_sprint = player.global_position.distance_to(p) > 1.5


# --- Auxiliares ------------------------------------------------------------------------

## Tem a posse mas a bola ficou fora do alcance do pé: ir até ela primeiro.
func _go_to_loose_ball() -> bool:
	if player.ball_control.ball_distance() <= BallControl.TOUCH_REACH - 0.05:
		return false
	var bp := player.ball.global_position
	_move_target = Vector3(bp.x, 0.0, bp.z)
	return true


## O corpo de [param carrier] está entre [param from] e a bola em [param bp]?
func _line_blocked_by(carrier: Player, from: Vector3, bp: Vector3) -> bool:
	var a := Vector3(from.x, 0.0, from.z)
	var b := Vector3(bp.x, 0.0, bp.z)
	var c := Vector3(carrier.global_position.x, 0.0, carrier.global_position.z)
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_to(c) < 0.26 and (c - a).length() < ab.length()


func _set_action(a: PlayerIntent.Action, power: float, aim: Vector3, target: Player) -> void:
	_action = a
	_action_power = power
	_action_aim = aim
	_action_target = target


func _intercept_point() -> Vector3:
	var ball := player.ball
	var t := 0.1
	while t <= 2.0:
		var bp := ball.predict_ground_position(t)
		var need := player.global_position.distance_to(bp) / player.sprint_speed + 0.15
		if need <= t:
			return bp
		t += 0.1
	return ball.predict_ground_position(2.0)


func _chase_score(p: Player) -> float:
	var bp := player.ball.predict_ground_position(0.4)
	return p.global_position.distance_to(bp)


func _is_best_chaser() -> bool:
	var mine := _chase_score(player) - 0.3 # leve preferência por si (histerese)
	for mate in player.get_teammates():
		if mate.is_goalkeeper():
			continue
		if _chase_score(mate) < mine:
			return false
		# O jogador que VOCÊ controla tem prioridade na bola: a IA do meu time
		# não vai "roubar" a bola dele; só vai se ele estiver bem mais longe.
		if mate.is_human and _chase_score(mate) < mine + 3.5:
			return false
		if mate.is_human and player.ball.last_toucher == mate \
				and mate.global_position.distance_to(player.ball.global_position) < 3.0:
			return false
	return true


func _is_closest_field_player_to(point: Vector3) -> bool:
	var mine := player.global_position.distance_to(point) - 0.3
	for mate in player.get_teammates():
		if not mate.is_goalkeeper() and mate.global_position.distance_to(point) < mine:
			return false
	return true


func _nearest_opponent_distance(point: Vector3) -> float:
	var best := INF
	for opp in player.get_opponents():
		best = minf(best, Vector2(opp.global_position.x - point.x, opp.global_position.z - point.z).length())
	return best


func _lane_clear(from: Vector3, to: Vector3, width: float, ignore_keeper := false) -> bool:
	for opp in player.get_opponents():
		if ignore_keeper and opp.is_goalkeeper():
			continue
		if _distance_to_segment(opp.global_position, from, to) < width:
			return false
	return true


func _best_pass_option() -> Player:
	var s := Field.attack_sign(player.team)
	var pos := player.global_position
	var best: Player = null
	var best_score := -INF
	for mate in player.get_teammates():
		if mate.is_goalkeeper():
			continue
		var d := pos.distance_to(mate.global_position)
		if d < 2.0 or d > 20.0 or not _lane_clear(pos, mate.global_position, 0.85):
			continue
		var advance := (mate.global_position.x - pos.x) * s
		var openness := minf(_nearest_opponent_distance(mate.global_position), 5.0)
		var mate_pass_ms := mate.get_meta("last_pass_ms", -100000) as int
		var give_and_go_bonus := 1.2 if (Time.get_ticks_msec() - mate_pass_ms < 2600 and advance > 0.5) else 0.0
		var score := advance * 0.45 + openness + give_and_go_bonus - d * 0.07
		if score > best_score:
			best_score = score
			best = mate
	return best


func _nearest_teammate() -> Player:
	var best: Player = null
	var best_d := INF
	for mate in player.get_teammates():
		var d := mate.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = mate
	return best


func _separate_from_teammates() -> void:
	var push := Vector3.ZERO
	for mate in player.get_teammates():
		if mate.is_goalkeeper():
			continue
		var off := _move_target - mate.global_position
		off.y = 0.0
		var d := off.length()
		if d < 3.0:
			push += (off / maxf(d, 0.1)) * (3.0 - d)
	_move_target += push * 0.6


## Durante reinício do adversário, manter distância da bola.
func _keep_restart_distance() -> void:
	var ball := player.ball
	var restricted := ball.restricted_team
	if ball.restricted_player != null:
		restricted = ball.restricted_player.team
	if restricted < 0 or restricted == player.team:
		return
	var bp := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	var off := _move_target - bp
	off.y = 0.0
	if off.length() < 2.5:
		if off.length() < 0.1:
			off = Field.goal_center(player.team) - bp
		_move_target = bp + off.normalized() * 2.5


static func _distance_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p2.distance_to(a2)
	var t := clampf((p2 - a2).dot(ab) / len2, 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)
