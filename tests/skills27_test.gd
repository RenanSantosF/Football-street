extends Node
## Gestos da Etapa 27 (rodar no PC):
##   godot --headless --path . res://tests/skills27_test.tscn --fixed-fps 60
## 1) CALCANHAR: com a bola à frente e o companheiro atrás, passe para trás
##    sai de calcanhar — sem girar o corpo — e chega no companheiro;
## 2) VOLEIO de chute: bola chegando na altura da cintura + CHUTE apertado →
##    bate de primeira, forte, rumo ao gol;
## 3) VOLEIO de passe: bola na altura do joelho + PASSE → de primeira para o
##    companheiro;
## 4) PROFUNDIDADE arrastada: a bola vai pelo alto.
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var me: Player
var mate: Player
var f := 0
var phase := 0
var t0 := 0
var results := {}
var _kinds: Array[String] = []
var _face0 := Vector3.ZERO
var _min_face_dot := 1.0
var _kick_v := Vector3.ZERO
var _first_owner: Node = null


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")
	GameEvents.ball_kicked.connect(func(_k, _kind, _p):
		if _kick_v == Vector3.ZERO:
			_kick_v = Vector3(-1, -1, -1)) # marca: medir no próximo quadro


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		me = mm.controlled
		for p in mm.players:
			if p != me:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		for p in mm.get_team(me.team):
			if p != me:
				mate = p
		me.action_started.connect(func(k): _kinds.append(String(k)))
	if f < 80:
		return
	if _kick_v == Vector3(-1, -1, -1):
		_kick_v = ball.linear_velocity
	match phase:
		0: _heel()
		1: _volley(0.6, "pass", "voleio_passe")
		2: _volley(0.85, "shoot", "voleio_chute")
		3: _through_lob()
		4:
			print("RESULTADOS: ", results)
			get_tree().quit()


func _reset_case() -> void:
	_kinds.clear()
	_kick_v = Vector3.ZERO
	_first_owner = null
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "pass", "shoot", "through_pass", "through_lob"]:
		Input.action_release(a)
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	ball.in_play = true
	ball.restricted_team = -1
	ball.restricted_player = null
	me.set_restart_lock(false)
	me.set_frozen(false)


func _next() -> void:
	phase += 1
	t0 = 0


func _heel() -> void:
	var s := Field.attack_sign(me.team)
	if t0 == 0:
		t0 = f
		_reset_case()
		me.teleport(Vector3(-2 * s, 0, 0), Vector3(s, 0, 0))
		ball.place_at(Vector3(-2 * s + s * 0.42, Ball.RADIUS, 0))
		ball.claim(me)
		mate.set_physics_process(true)
		mate.set_frozen(false)
		mate.set_human(false, null)
		mate.teleport(Vector3(-9 * s, 0, 0.6), Vector3(s, 0, 0))
		_face0 = me.facing
		_min_face_dot = 1.0
	var t := f - t0
	if t == 20:
		Input.action_press("move_left" if s > 0 else "move_right", 1.0) # analógico para TRÁS
		Input.action_press("pass")
	if t == 24:
		Input.action_release("pass")
	if t == 30:
		Input.action_release("move_left")
		Input.action_release("move_right")
	if t > 20 and t < 60:
		_min_face_dot = minf(_min_face_dot, me.facing.dot(_face0))
	if t > 30 and _first_owner == null and ball.possessor != null and ball.possessor != me:
		_first_owner = ball.possessor
	if t == 220:
		results["calcanhar_fez"] = _kinds.has("heel_pass")
		results["calcanhar_sem_girar"] = _min_face_dot > 0.8
		results["calcanhar_bola_para_tras"] = _kick_v != Vector3.ZERO and _kick_v.dot(_face0) < -2.0
		results["calcanhar_vel"] = snappedf(Vector3(_kick_v.x, 0, _kick_v.z).length(), 0.1)
		results["calcanhar_chegou"] = _first_owner == mate
		mate.set_physics_process(false)
		mate.global_position = Vector3(0, -50, 0)
		_next()


func _volley(h: float, button: String, key: String) -> void:
	var s := Field.attack_sign(me.team)
	var goal_x := Field.goal_line_x(Team.other(me.team))
	if t0 == 0:
		t0 = f
		_reset_case()
		var at := Vector3(goal_x - s * 9.0, 0, 0)
		me.teleport(at, Vector3(s, 0, 0))
		if button == "pass":
			mate.set_physics_process(true)
			mate.set_frozen(false)
			mate.set_human(false, null)
			mate.teleport(at + Vector3(0, 0, 6.0), Vector3(0, 0, -1))
		mm.set_controlled(me)
		ball.release()
		# vem de lado (cruzamento de dentro do campo), na altura pedida
		ball.place_at(at + Vector3(-s * 3.0, 0.4, -3.6))
	var t := f - t0
	if t == 2:
		var from := ball.global_position
		var at2 := me.global_position
		var flat := Vector3(at2.x - from.x, 0, at2.z - from.z)
		var speed := 9.0
		var tt := flat.length() / speed
		var vy: float = (h - from.y) / tt + 0.5 * 9.8 * tt
		var hv := flat.normalized() * speed
		ball.kick(Vector3(hv.x, vy, hv.z), Vector3.ZERO, null)
		ball.pass_target = me
		_kick_v = Vector3.ZERO
		Input.action_press(button)
	if t == 6:
		Input.action_release(button)
	if OS.get_environment("DBG") != "" and t % 4 == 0 and t < 90:
		print("V t=", t, " st=", me.state, " ball=", ball.global_position.snapped(Vector3.ONE * 0.01), " me=", me.global_position.snapped(Vector3.ONE * 0.01), " tgt=", ball.pass_target.name if ball.pass_target else "-", " buf=", me._buffer_action, "/", snappedf(me._buffer_timer, 0.01), " poss=", ball.possessor.name if ball.possessor else "-", " inplay=", ball.in_play, " lock=", me.is_restart_locked(), " mm=", mm.state, " ctrl=", mm.controlled == me)
	if t > 10 and _first_owner == null and ball.possessor != null and ball.possessor != me:
		_first_owner = ball.possessor
	if t == 200:
		results[key + "_fez"] = _kinds.has("volley")
		results[key + "_acoes"] = str(_kinds)
		var flat := Vector3(_kick_v.x, 0, _kick_v.z)
		results[key + "_vel"] = snappedf(flat.length(), 0.1)
		if button == "shoot":
			results[key + "_rumo_ao_gol"] = flat.length() > 12.0 and flat.normalized().dot(Vector3(s, 0, 0)) > 0.8
		else:
			results[key + "_chegou"] = _first_owner == mate
		mate.set_physics_process(false)
		mate.global_position = Vector3(0, -50, 0)
		_next()


func _through_lob() -> void:
	var s := Field.attack_sign(me.team)
	if t0 == 0:
		t0 = f
		_reset_case()
		mm.set_controlled(me)
		me.teleport(Vector3(-6 * s, 0, 0), Vector3(s, 0, 0))
		ball.place_at(Vector3(-6 * s + s * 0.42, Ball.RADIUS, 0))
		ball.claim(me)
		mate.set_physics_process(true)
		mate.set_frozen(false)
		mate.set_human(false, null)
		mate.teleport(Vector3(-1 * s, 0, 3.0), Vector3(s, 0, 0))
	var t := f - t0
	if t == 20:
		Input.action_press("through_pass")
		Input.action_press("through_lob") # dedo arrastado
	if t == 30:
		Input.action_release("through_pass")
	if t == 34:
		Input.action_release("through_lob")
	if t == 120:
		results["profundidade_por_cima_vy"] = snappedf(_kick_v.y, 0.1)
		results["profundidade_por_cima"] = _kick_v.y > 3.0
		mate.set_physics_process(false)
		mate.global_position = Vector3(0, -50, 0)
		_next()
