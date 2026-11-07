extends Node
## Disputas, desarmes, proteção e passe em profundidade (rodar no PC):
##   godot --headless --path . res://tests/duel_test.tscn --fixed-fps 60
## 1) bote em bola exposta → o PÉ tira a bola (sem troca mágica de dono)
## 2) bote em quem protege de costas → não rouba (pé bate no corpo)
## 3) bote de longe → erra e perde o equilíbrio
## 4) PROTEGER com marcador da IA em cima → segura a bola de costas/lado
## 5) passe do adversário passando a ~0,8 m → estica a perna (interceptação)
## 6) passe em PROFUNDIDADE → bola no espaço à frente de quem corre
## 7) inverter em sprint → desequilíbrio; chute desequilibrado sai mais fraco
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var me: Player
var opp: Player
var mate: Player
var f := 0
var phase := 0
var t0 := 0
var results := {}
var _touches := {}
var _poss_changes: Array = []
var _min_bal := 1.0
var _kick_v := Vector3.ZERO
var _kick_from := Vector3.ZERO
var _mate_at := Vector3.ZERO
var _mate_got := false


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")
	GameEvents.possession_changed.connect(func(n, o): _poss_changes.append([f, n, o]))


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		me = mm.controlled
		for p in mm.players:
			if p.team != me.team and opp == null:
				opp = p
			elif p.team == me.team and p != me and mate == null:
				mate = p
		for p in mm.players:
			if p != me and p != opp and p != mate:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		for p in [me, opp, mate]:
			p.ball_touched.connect(func(k): _touches[str(p.name) + ":" + k] = _touches.get(str(p.name) + ":" + k, 0) + 1)
	if f < 80:
		return
	if t0 != 0:
		_min_bal = minf(_min_bal, me.balance)
	match phase:
		0: _tackle_exposed()
		1: _tackle_shielded()
		2: _tackle_far()
		3: _shield_hold()
		4: _intercept()
		5: _through()
		6: _reverse_balance()
		7: _frontal_vulnerable()
		8:
			print("RESULTADOS: ", results)
			get_tree().quit()


func _release_inputs() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dribble", "through_pass", "shoot", "pass"]:
		Input.action_release(a)


func _park(p: Player) -> void:
	p.set_frozen(false)
	p.controller = null
	p.intent.move = Vector3.ZERO
	p.intent.sprint = false
	p.intent.shield = false
	p.teleport(Vector3(0, 0, -6.5) + Vector3(randf() * 0.1, 0, 0), Vector3.RIGHT)


func _begin(me_pos: Vector3, me_face: Vector3) -> void:
	_release_inputs()
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	for p in [me, opp, mate]:
		_park(p)
		p.balance = 1.0
		p.stamina = 1.0
	mm.set_controlled(me)
	me.set_human(true, mm.human_input)
	me.teleport(me_pos, me_face)
	ball.in_play = true
	ball.restricted_team = -1
	ball.restricted_player = null
	ball.pass_target = null
	_touches.clear()
	_poss_changes.clear()
	_min_bal = 1.0
	t0 = f


func _next() -> void:
	_release_inputs()
	phase += 1
	t0 = 0


## Adversário parado com a bola exposta à frente dele, virada para mim.
func _tackle_exposed() -> void:
	if t0 == 0:
		_begin(Vector3(-3.0, 0, 0), Vector3.RIGHT)
		opp.teleport(Vector3(-1.6, 0, 0), Vector3.LEFT)
		ball.place_at(Vector3(-2.15, Ball.RADIUS, 0.05))
		ball.claim(opp)
	var t := f - t0
	if OS.get_environment("DBG") != "" and t % 3 == 0 and t < 110:
		var sd: Array = BallControl._foot_segment(me, me.ball_control.foot.side)
		var fs := me.ball_control.foot.side
		var raw: Vector3 = me.visual.call("get_raw_ankle_position", fs)
		var ik: Vector3 = me.visual.call("get_ankle_position", fs)
		print("   raw_ankle-me=", (raw - me.global_position).snapped(Vector3.ONE*0.01), " ik_ankle-me=", (ik - me.global_position).snapped(Vector3.ONE*0.01), " tgt-me=", (me.ball_control.foot._target - me.global_position).snapped(Vector3.ONE*0.01), " w=", snappedf(me.ball_control.foot._weight, 0.01), " cap=", snappedf(me.ball_control.foot._ik_cap(), 0.01))
		print("EXP t=", t, " st=", me.state, " act=", me._action_kind, " me=", me.global_position.snapped(Vector3.ONE*0.01), " ball=", ball.global_position.snapped(Vector3.ONE*0.01), " poss=", ball.possessor.name if ball.possessor else "-", " foot=", me.ball_control.foot.phase, "/", me.ball_control.foot.side, " footd=", snappedf(me.ball_control.tackle_foot_distance(), 0.01), " tlist=", _touches, " buf=", me._buffer_action, " bal=", snappedf(me.balance, 0.01))
	if t == 15:
		Input.action_press("dribble")
	if t == 18:
		Input.action_release("dribble")
	if t == 120:
		var lost := ball.possessor != opp
		var touched_by_foot: bool = _touches.get(str(me.name) + ":tackle", 0) > 0
		results["bote_exposta_tirou_bola"] = lost and touched_by_foot
		results["bote_exposta_dono"] = str(ball.possessor.name) if ball.possessor != null else "solta"
		_next()


## Adversário de COSTAS para mim, bola do lado de lá (protegendo).
func _tackle_shielded() -> void:
	if t0 == 0:
		_begin(Vector3(-3.0, 0, 0), Vector3.RIGHT)
		opp.teleport(Vector3(-2.2, 0, 0), Vector3.RIGHT)
		ball.place_at(Vector3(-1.82, Ball.RADIUS, 0.0))
		ball.claim(opp)
		opp.intent.shield = true
	var t := f - t0
	if t == 15:
		Input.action_press("dribble")
	if t == 18:
		Input.action_release("dribble")
	if t == 120:
		results["bote_protegida_nao_rouba"] = ball.possessor == opp or ball.possessor == null and ball.last_toucher != me
		results["bote_protegida_dono"] = str(ball.possessor.name) if ball.possessor != null else "solta"
		_next()


func _tackle_far() -> void:
	if t0 == 0:
		_begin(Vector3(-3.0, 0, 0), Vector3.RIGHT)
		opp.teleport(Vector3(-1.3, 0, 0.0), Vector3.RIGHT)
		ball.place_at(Vector3(-0.95, Ball.RADIUS, 0.0))
		ball.claim(opp)
		opp.intent.move = Vector3.RIGHT * 0.5
	var t := f - t0
	if t == 5:
		Input.action_press("dribble")
	if t == 8:
		Input.action_release("dribble")
	if t == 90:
		results["bote_longe_errou"] = ball.possessor == opp
		results["bote_longe_equilibrio_min"] = snappedf(_min_bal, 0.01)
		results["bote_longe_desequilibrou"] = _min_bal < 0.8
		_next()


## Proteção AUTOMÁTICA: parado com a bola e a IA adversária chegando por trás.
func _shield_hold() -> void:
	if t0 == 0:
		_begin(Vector3(-4.0, 0, 0), Vector3.LEFT)
		ball.place_at(Vector3(-4.4, Ball.RADIUS, 0))
		ball.claim(me)
		opp.teleport(Vector3(-2.6, 0, 0.3), Vector3.LEFT)
		opp.controller = opp.ai
	var t := f - t0
	if t > 30 and t < 180 and ball.possessor == me and t % 10 == 0:
		var to_opp := opp.global_position - me.global_position
		to_opp.y = 0.0
		var to_ball := ball.global_position - me.global_position
		to_ball.y = 0.0
		if to_opp.length() < 1.6:
			results["protege_amostras"] = results.get("protege_amostras", 0) + 1
			if to_ball.dot(to_opp) < 0.0:
				results["protege_bola_lado_longe"] = results.get("protege_bola_lado_longe", 0) + 1
	if t == 180:
		# (informativo: a proteção ajuda, mas não é um escudo — a IA pode tomar)
		results["protege_tem_bola_3s"] = ball.possessor == me
		results["protege_sem_atravessar"] = me.global_position.distance_to(opp.global_position) > 0.45
		_next()


## Passe do adversário passando a ~0,8 m do meu jogador (IA ligada).
func _intercept() -> void:
	if t0 == 0:
		_begin(Vector3(0, 0, 0), Vector3.LEFT)
		me.controller = me.ai
		ball.release()
		ball.place_at(Vector3(-6, Ball.RADIUS, 0.8))
	var t := f - t0
	if t == 4:
		ball.kick(Vector3(8.5, 0, 0), Vector3.ZERO, opp, 0.1)
	if OS.get_environment("DBG") != "" and t % 4 == 0 and t < 70:
		print("INT t=", t, " st=", me.state, " me=", me.global_position.snapped(Vector3.ONE*0.01), " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.1), " ball=", ball.global_position.snapped(Vector3.ONE*0.01), " bv=", ball.flat_velocity().snapped(Vector3.ONE*0.1), " lt=", ball.last_toucher.name if ball.last_toucher else "-", " foot=", me.ball_control.foot.phase, " claim=", ball.can_be_claimed_by(me), " t=", _touches)
	if t == 90:
		results["intercepta_tentou"] = _touches.get(str(me.name) + ":intercept", 0) > 0 or ball.last_toucher == me
		results["intercepta_tocou"] = ball.last_toucher == me
		_next()


func _through() -> void:
	if t0 == 0:
		_begin(Vector3(-8, 0, 0), Vector3.RIGHT)
		ball.place_at(Vector3(-7.6, Ball.RADIUS, 0))
		ball.claim(me)
		mate.teleport(Vector3(-5, 0, 3.5), Vector3.RIGHT)
		mate.controller = null
		_kick_v = Vector3.ZERO
		_mate_got = false
	var t := f - t0
	if t < 40:
		mate.intent.move = Vector3.RIGHT if Field.attack_sign(me.team) > 0.0 else Vector3.LEFT
		mate.intent.sprint = true
	if t == 30:
		Input.action_press("through_pass")
	if t == 50:
		Input.action_release("through_pass")
	if OS.get_environment("DBG") != "" and t % 10 == 0:
		print("THR t=", t, " st=", me.state, " act=", me._action_kind, " ball=", ball.global_position.snapped(Vector3.ONE*0.01), " bv=", ball.flat_velocity().snapped(Vector3.ONE*0.1), " poss=", ball.possessor.name if ball.possessor else "-", " tgt=", ball.pass_target.name if ball.pass_target else "-", " mate=", mate.global_position.snapped(Vector3.ONE*0.01), " mv=", mate.get_flat_velocity().snapped(Vector3.ONE*0.1), " buf_thr=", me._buffer_through)
	if _kick_v == Vector3.ZERO and ball.possessor == null and ball.flat_velocity().length() > 3.0:
		_kick_v = ball.flat_velocity()
		_kick_from = ball.global_position
		_mate_at = mate.global_position
		mate.controller = mate.ai
	if _kick_v != Vector3.ZERO and ball.possessor == mate:
		_mate_got = true
	if t == 240:
		var s := Field.attack_sign(me.team)
		results["prof_saiu"] = _kick_v != Vector3.ZERO
		results["prof_alvo_correto"] = _mate_got
		# a bola foi para a FRENTE de onde ele estava (o espaço), não no pé
		# onde a linha da bola cruza o corredor de corrida dele (z), à frente dele
		var lead := 0.0
		if absf(_kick_v.z) > 0.3:
			var tz := (_mate_at.z - _kick_from.z) / _kick_v.z
			lead = (_kick_from.x + _kick_v.x * tz - _mate_at.x) * s
		results["prof_a_frente_m"] = snappedf(lead, 0.1)
		results["prof_no_espaco"] = lead > 1.0
		results["prof_recebedor_dominou"] = _mate_got
		results["prof_acao"] = _touches.get(str(me.name) + ":pass", 0) > 0
		_next()


## Adversário vindo pela FRENTE: sem proteção (não gira as costas, a bola
## não recua) — fica exposto ao bote.
func _frontal_vulnerable() -> void:
	if t0 == 0:
		_begin(Vector3(-4.0, 0, 0), Vector3.RIGHT)
		ball.place_at(Vector3(-3.6, Ball.RADIUS, 0))
		ball.claim(me)
		opp.teleport(Vector3(-2.6, 0, 0.0), Vector3.LEFT)
		opp.controller = null
		opp.intent.move = Vector3.LEFT * 0.4
	var t := f - t0
	if t == 30:
		opp.intent.move = Vector3.ZERO
	if t == 70:
		results["frente_sem_protecao"] = not me.is_shielding()
		results["frente_nao_girou"] = me.facing.dot(Vector3.RIGHT) > 0.8
		_next()


func _reverse_balance() -> void:
	if t0 == 0:
		_begin(Vector3(-9, 0, 0), Vector3.RIGHT)
		ball.release()
		ball.place_at(Vector3(9, Ball.RADIUS, 3))
		Input.action_press("move_right", 1.0)
		Input.action_press("sprint")
	var t := f - t0
	if t == 60:
		results["inverter_sprint_vel_antes"] = snappedf(me.get_horizontal_speed(), 0.1)
	if t == 90:
		results["inverter_sprint_vel_antes"] = snappedf(me.get_horizontal_speed(), 0.1)
		Input.action_release("move_right")
		Input.action_press("move_left", 1.0)
	if OS.get_environment("DBG") != "" and t >= 88 and t < 130 and t % 3 == 0:
		print("REV t=", t, " st=", me.state, " act=", me._action_kind, " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.1), " in=", me.intent.move.snapped(Vector3.ONE*0.1), " bal=", snappedf(me.balance, 0.01), " cd=", snappedf(me._turn_cooldown, 0.01))
	if t == 150:
		results["inverter_sprint_equilibrio_min"] = snappedf(_min_bal, 0.01)
		results["inverter_sprint_desequilibra"] = _min_bal < 0.85
		_next()
