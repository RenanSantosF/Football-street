extends Node
## Refinamentos da Etapa 26 (rodar no PC):
##   godot --headless --path . res://tests/refine_test.tscn --fixed-fps 60
## 1) cobrança: analógico girando 360° → o batedor não desliza nem gira
## 2) desequilibrado (tropeço): o analógico não gira o corpo
## 3) carrinho: alcance pela velocidade de entrada (andando curto, sprint longo)
## 4) falta: tela escurece ANTES do reposicionamento; defesa entre a bola e o
##    gol (barreira a ~3 m), com espaço entre os defensores, e fica lá
## 5) passe simples (toque rápido): firme para perto e para longe
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var me: Player
var mate: Player
var opp: Player
var f := 0
var phase := 0
var t0 := 0
var results := {}
var _fade_f := -1
var _restart_f := -1
var _p0 := Vector3.ZERO
var _face0 := Vector3.ZERO
var _maxdrift := 0.0
var _maxang := 0.0
var _slide_start := Vector3.ZERO
var _kick_v := 0.0


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")
	GameEvents.screen_fade.connect(func(_a, _b, _c): _fade_f = f)
	GameEvents.restart_started.connect(func(_t, _k, _p): _restart_f = f)


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		me = mm.controlled
		for p in mm.players:
			if p.team == me.team and p != me and mate == null:
				mate = p
			if p.team != me.team and opp == null:
				opp = p
	if f < 80:
		return
	match phase:
		0: _restart_still()
		1: _stunned_no_turn()
		2: _slide_distance(false)
		3: _slide_distance(true)
		4: _free_kick()
		5: _pass_speed(6.0, "perto")
		6: _pass_speed(12.0, "longe")
		7:
			print("RESULTADOS: ", results)
			get_tree().quit()


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "pass", "shoot", "dribble"]:
		Input.action_release(a)


func _solo(keep: Array) -> void:
	for p in mm.players:
		if not keep.has(p):
			p.set_physics_process(false)
			p.global_position = Vector3(0, -50, 0)
		else:
			p.set_physics_process(true)


func _next() -> void:
	_release()
	phase += 1
	t0 = 0


func _restart_still() -> void:
	if t0 == 0:
		t0 = f
		_solo([me, mate])
		mm.ball_out_system.cancel()
		mm.set_controlled(me)
		mm.begin_restart(me.team, BallOutSystem.Kind.END_LINE, Vector3(-12.4, Ball.RADIUS, 0))
		mm.set_controlled(ball.restricted_player)
		me = ball.restricted_player
	var t := f - t0
	if t == 20:
		_p0 = me.global_position
		_face0 = me.facing
	if t > 20 and t < 140:
		# analógico dando voltas completas
		var a := (t - 20) / 30.0 * TAU
		_release()
		var v := Vector2(cos(a), sin(a))
		Input.action_press("move_right" if v.x > 0.0 else "move_left", absf(v.x))
		Input.action_press("move_down" if v.y > 0.0 else "move_up", absf(v.y))
		_maxdrift = maxf(_maxdrift, me.global_position.distance_to(_p0))
		_maxang = maxf(_maxang, rad_to_deg(me.facing.angle_to(_face0)))
	if t == 140:
		results["cobranca_deslocou_m"] = snappedf(_maxdrift, 0.01)
		results["cobranca_girou_graus"] = snappedf(_maxang, 0.1)
		results["cobranca_imovel"] = _maxdrift < 0.05 and _maxang < 10.0
		_next()


func _stunned_no_turn() -> void:
	if t0 == 0:
		t0 = f
		_solo([me])
		ball.restricted_player = null
		ball.restricted_team = -1
		me.set_restart_lock(false)
		ball.release()
		ball.place_at(Vector3(10, Ball.RADIUS, 3))
		mm.state = MatchManager.MatchState.PLAYING
		me.teleport(Vector3(-5, 0, 0), Vector3.RIGHT)
		me.stumble(0.8)
		_face0 = me.facing
		_maxang = 0.0
		Input.action_press("move_left", 1.0)
	var t := f - t0
	if t < 40:
		_maxang = maxf(_maxang, rad_to_deg(me.facing.angle_to(_face0)))
	if t == 40:
		results["tropeco_girou_graus"] = snappedf(_maxang, 0.1)
		results["tropeco_sem_giro"] = _maxang < 5.0
		_next()


func _slide_distance(fast: bool) -> void:
	var key := "carrinho_sprint" if fast else "carrinho_andando"
	if t0 == 0:
		t0 = f
		_solo([me, opp])
		mm.state = MatchManager.MatchState.PLAYING
		me.set_frozen(false)
		me.stamina = 1.0
		me.teleport(Vector3(-10, 0, 0), Vector3.RIGHT)
		opp.set_frozen(false)
		opp.controller = null
		opp.intent.move = Vector3.ZERO
		opp.debug_dodge_chance = 0.0
		var d0 := 7.0 if fast else 2.2
		opp.teleport(Vector3(-10.0 + d0, 0, 0), Vector3.LEFT)
		ball.in_play = true
		ball.place_at(Vector3(-10.0 + d0 - 0.45, Ball.RADIUS, 0))
		ball.claim(opp)
		Input.action_press("move_right", 1.0 if fast else 0.3)
		if fast:
			Input.action_press("sprint")
	var t := f - t0
	var press_at := 75 if fast else 20
	if t == press_at:
		Input.action_press("shoot")
		_slide_start = me.global_position
	if t == press_at + 3:
		_release()
	if t == press_at + 150:
		results[key + "_m"] = snappedf(me.global_position.distance_to(_slide_start), 0.01)
		results[key + "_fez"] = me._action_kind == &"slide"
		_next()


func _free_kick() -> void:
	if t0 == 0:
		t0 = f
		for p in mm.players:
			p.set_physics_process(true)
			p.set_frozen(false)
			p.teleport(mm.formation_position(p.team, p.formation_index), Vector3(Field.attack_sign(p.team), 0, 0))
			if p != me:
				p.controller = p.ai
		_fade_f = -1
		_restart_f = -1
		mm.ball_out_system.cancel()
		mm.state = MatchManager.MatchState.PLAYING
		ball.in_play = true
		ball.restricted_player = null
		ball.restricted_team = -1
		me.set_restart_lock(false)
		# falta para o MEU time perto do gol adversário
		var goal_x := Field.goal_line_x(Team.other(me.team))
		var spot := Vector3(goal_x - Field.attack_sign(me.team) * 7.0, Ball.RADIUS, 1.5)
		ball.place_at(spot)
		mm.award_free_kick(me.team, spot)
	var t := f - t0
	if t == 200:
		results["falta_escureceu_antes"] = _fade_f > 0 and _restart_f > 0 and _fade_f < _restart_f \
			and _restart_f - _fade_f <= 14
		var def_team := Team.other(me.team)
		var goal := Field.goal_center(def_team)
		var bp := ball.global_position
		bp.y = 0.0
		var between := 0
		var wall_ok := false
		var min_sep := INF
		var defs := mm.get_team(def_team)
		for i in defs.size():
			var dp := defs[i].global_position
			dp.y = 0.0
			if dp.distance_to(goal) < bp.distance_to(goal):
				between += 1
			var db := dp.distance_to(bp)
			if db > 2.6 and db < 3.8:
				wall_ok = true
			for j in i:
				min_sep = minf(min_sep, dp.distance_to(Vector3(defs[j].global_position.x, 0, defs[j].global_position.z)))
		results["falta_defesa_entre_bola_e_gol"] = between == defs.size()
		if OS.get_environment("DBG") != "":
			for dd in defs:
				print("DEF ", dd.name, " pos=", dd.global_position.snapped(Vector3.ONE*0.01), " slot=", dd.get_meta("restart_slot", Vector3.INF), " bola=", bp, " gol=", goal, " ctrl_humano=", dd.is_human)
			for aa in mm.get_team(me.team):
				print("ATK ", aa.name, " pos=", aa.global_position.snapped(Vector3.ONE*0.01))
		results["falta_barreira_3m"] = wall_ok
		results["falta_espaco_min_m"] = snappedf(min_sep, 0.01)
		_p0 = defs[0].global_position
	if t == 260:
		var defs2 := mm.get_team(Team.other(me.team))
		results["falta_defesa_parada"] = defs2[0].global_position.distance_to(_p0) < 0.5
		_next()


func _pass_speed(dist: float, key: String) -> void:
	if t0 == 0:
		t0 = f
		for p in mm.players:
			if p.team == me.team and p != me:
				mate = p
		# os outros ficam no campo, longe da jogada (sem processar)
		var corner := 0
		for p in mm.players:
			if p != me and p != mate:
				p.set_physics_process(false)
				p.global_position = Vector3(-12.0 + corner * 1.5, 0, 4.5)
				corner += 1
			else:
				p.set_physics_process(true)
		mm.ball_out_system.cancel()
		mm.state = MatchManager.MatchState.PLAYING
		ball.in_play = true
		ball.restricted_player = null
		ball.restricted_team = -1
		me.set_restart_lock(false)
		mate.set_restart_lock(false)
		mm.set_controlled(me)
		me.set_human(true, mm.human_input)
		me.teleport(Vector3(-6, 0, 0), Vector3.RIGHT)
		ball.place_at(Vector3(-5.6, Ball.RADIUS, 0))
		ball.claim(me)
		mate.set_frozen(false)
		mate.set_human(false, null) # IA dele recebe o passe
		mate.teleport(Vector3(-6 + dist, 0, 0), Vector3.LEFT)
		_kick_v = 0.0
	var t := f - t0
	if t == 20:
		Input.action_press("pass")
	if t == 23:
		Input.action_release("pass")
	if _kick_v == 0.0 and ball.possessor == null and ball.flat_velocity().length() > 2.0:
		_kick_v = ball.flat_velocity().length()
	if OS.get_environment("DBG") != "" and t % 20 == 0:
		print("PAS proc=", mate.is_physics_processing(), " frozen=", mate.state == Player.State.FROZEN, " active=", mate.active, " ctrl=", mate.controller, " lockM=", mate.is_restart_locked(), " bola=", ball.global_position.snapped(Vector3.ONE*0.01), " mate=", mate.global_position.snapped(Vector3.ONE*0.01), " mate_st=", mate.state, " tgt=", ball.pass_target.name if ball.pass_target else "-", " t=", t, " st=", me.state, " mm=", mm.state, " poss=", ball.possessor.name if ball.possessor else "-", " held=", ball.held, " lock=", me.is_restart_locked(), " restr=", ball.restricted_player, " ctrl=", mm.controlled == me, " buf=", me._buffer_action, " inplay=", ball.in_play)
	if t == 200:
		results["passe_" + key + "_vel"] = snappedf(_kick_v, 0.1)
		results["passe_" + key + "_dominou"] = ball.possessor == mate
		_next()
