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
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_patience = _rng.randf_range(1.6, 3.4)


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
	intent.sprint = _sprint and d > 2.0
	if _action != PlayerIntent.Action.NONE:
		intent.set_action(_action, _action_power, _action_aim, _action_target)
		_action = PlayerIntent.Action.NONE


# --- Decisão -----------------------------------------------------------------------

func _think() -> void:
	var mm := player.match_manager
	var ball := player.ball
	_sprint = false
	if not mm.is_ball_live():
		_move_target = mm.formation_position(player.team, player.formation_index, ball.global_position.x)
		_keep_restart_distance()
		return
	if player.is_goalkeeper():
		_think_goalkeeper()
	elif player.ball_control.has_ball():
		_think_with_ball()
	else:
		var carrier := ball.possessor
		if carrier == null:
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


func _think_with_ball() -> void:
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

	# Passe sob pressão ou por paciência.
	var nearest := _nearest_opponent_distance(pos)
	var pressured := nearest < 2.0
	if (pressured and _hold_time > 0.35) or _hold_time > _patience:
		var mate := _best_pass_option()
		if mate != null:
			var d := mate.global_position.distance_to(pos)
			_set_action(PlayerIntent.Action.PASS, 0.3 if d < 11.0 else 0.7, Vector3.ZERO, mate)
			_patience = _rng.randf_range(1.6, 3.4)
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
		# Apoio: abrir no corredor oposto ao de quem conduz, à frente da bola.
		var lane := -signf(carrier.global_position.z)
		if lane == 0.0:
			lane = 1.0 if player.formation_index == 1 else -1.0
		var ahead := 3.5 + 1.5 * float(player.formation_index)
		_move_target = Vector3(carrier.global_position.x + s * ahead, 0.0, lane * 2.2)
		_sprint = absf(_move_target.x - player.global_position.x) > 4.0
	else:
		# Bola livre e não sou o perseguidor: zona do meu lado.
		var base := player.match_manager.formation_position(player.team, player.formation_index, ball_pos.x)
		_move_target = base.lerp(ball_pos, 0.25)
	_separate_from_teammates()


func _defend(carrier: Player) -> void:
	var own_goal := Field.goal_center(player.team)
	if _is_closest_field_player_to(carrier.global_position):
		# Pressionar: ficar entre o atacante e o gol, e dar o bote.
		var to_goal := (own_goal - carrier.global_position)
		to_goal.y = 0.0
		_move_target = carrier.global_position + to_goal.normalized() * 0.7
		_sprint = true
		var d := player.global_position.distance_to(carrier.global_position)
		if d < 1.3 and _tackle_cooldown <= 0.0:
			_tackle_cooldown = _rng.randf_range(1.0, 2.0)
			if _rng.randf() < 0.45:
				_set_action(PlayerIntent.Action.SHOOT, 0.0, Vector3.ZERO, null)
		elif d < Player.SLIDE_RANGE - 0.4 and d > 1.8 and _tackle_cooldown <= 0.0:
			# Carrinho: mais provável quando o atacante se aproxima do gol.
			_tackle_cooldown = _rng.randf_range(1.5, 3.0)
			var danger := 1.0 - clampf(carrier.global_position.distance_to(own_goal) / 20.0, 0.0, 1.0)
			if _rng.randf() < 0.12 + 0.25 * danger:
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
		if d < 2.0 or d > 20.0 or not _lane_clear(pos, mate.global_position, 0.9):
			continue
		var advance := (mate.global_position.x - pos.x) * s
		var openness := minf(_nearest_opponent_distance(mate.global_position), 5.0)
		var score := advance * 0.4 + openness - d * 0.08
		if score > best_score:
			best_score = score
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
	if ball.restricted_team < 0 or ball.restricted_team == player.team:
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
