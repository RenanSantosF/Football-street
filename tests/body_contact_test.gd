extends Node
## Contato corpo a corpo (rodar no PC):
##   godot --headless --path . res://tests/body_contact_test.tscn --fixed-fps 60
## 1) trombada de frente correndo → ninguém atravessa, ninguém "pula", os dois
##    se desequilibram
## 2) empurrando quem está parado → separação natural, sem grudar
## 3) ombro a ombro correndo → disputa de espaço, sem atravessar/travar
## 4) quem conduz protegendo a bola → aguenta a carga e não perde a bola
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var a: Player
var b: Player
var f := 0
var phase := 0
var t0 := 0
var results := {}
var _min_d := INF
var _max_y := 0.0
var _stumbles := {}


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		a = mm.controlled
		for p in mm.players:
			if p != a and p.team != a.team and b == null:
				b = p
		for p in mm.players:
			if p != a and p != b:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		for p in [a, b]:
			p.controller = null
			p.action_started.connect(func(k): if k == &"stumble": _stumbles[p.name] = _stumbles.get(p.name, 0) + 1)
	if f < 80:
		return
	if t0 != 0:
		var dd := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
		_min_d = minf(_min_d, dd)
		_max_y = maxf(_max_y, maxf(a.global_position.y, b.global_position.y))
	match phase:
		0: _head_on()
		1: _push_still()
		2: _shoulder()
		3: _shield()
		4:
			print("RESULTADOS: ", results)
			get_tree().quit()


func _begin(pa: Vector3, fa: Vector3, pb: Vector3, fb: Vector3) -> void:
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	for p in [a, b]:
		p.set_frozen(false)
		p.intent.move = Vector3.ZERO
		p.intent.sprint = false
		p.balance = 1.0
		p.stamina = 1.0
	a.teleport(pa, fa)
	b.teleport(pb, fb)
	ball.in_play = true
	ball.restricted_team = -1
	ball.restricted_player = null
	ball.release()
	ball.place_at(Vector3(11, Ball.RADIUS, 3.5))
	_min_d = INF
	_max_y = 0.0
	_stumbles.clear()
	t0 = f


func _next() -> void:
	phase += 1
	t0 = 0


func _head_on() -> void:
	if t0 == 0:
		_begin(Vector3(-4, 0, 0), Vector3.RIGHT, Vector3(4, 0, 0.05), Vector3.LEFT)
	var t := f - t0
	a.intent.move = Vector3.RIGHT
	b.intent.move = Vector3.LEFT
	a.intent.sprint = true
	b.intent.sprint = true
	if t == 150:
		results["frente_dist_min"] = snappedf(_min_d, 0.01)
		results["frente_nao_atravessou"] = _min_d > 0.45 and a.global_position.x < b.global_position.x
		results["frente_sem_pulo"] = _max_y < 0.02
		results["frente_desequilibrio"] = _stumbles.size()
		_next()


func _push_still() -> void:
	if t0 == 0:
		_begin(Vector3(-2, 0, 0), Vector3.RIGHT, Vector3(0, 0, 0.1), Vector3.UP.cross(Vector3.RIGHT))
	var t := f - t0
	a.intent.move = Vector3.RIGHT if t < 100 else Vector3.ZERO
	b.intent.move = Vector3.ZERO
	if t == 100:
		results["empurra_b_deslocou"] = snappedf(b.global_position.distance_to(Vector3(0, 0, 0.1)), 0.01)
		results["empurra_dist_min"] = snappedf(_min_d, 0.01)
	if t == 160:
		var dd := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
		results["empurra_sem_grudar"] = dd > 0.5
		results["empurra_sem_pulo"] = _max_y < 0.02
		_next()


func _shoulder() -> void:
	if t0 == 0:
		_begin(Vector3(-6, 0, -0.5), Vector3.RIGHT, Vector3(-6, 0, 0.5), Vector3.RIGHT)
	var t := f - t0
	a.intent.sprint = true
	b.intent.sprint = true
	a.intent.move = Vector3(1, 0, 0.35).normalized() if t < 110 else Vector3.RIGHT
	b.intent.move = Vector3(1, 0, -0.35).normalized() if t < 110 else Vector3.RIGHT
	if OS.get_environment("DBG") != "" and t % 6 == 0:
		print("OMB t=", t, " a=", a.global_position.snapped(Vector3.ONE*0.01), " va=", a.get_flat_velocity().snapped(Vector3.ONE*0.01), " b=", b.global_position.snapped(Vector3.ONE*0.01), " vb=", b.get_flat_velocity().snapped(Vector3.ONE*0.01), " st=", a.state, "/", b.state, " bal=", snappedf(a.balance,0.01), "/", snappedf(b.balance,0.01), " ", a._action_kind, "/", b._action_kind)
	if t == 150:
		results["ombro_dist_min"] = snappedf(_min_d, 0.01)
		results["ombro_nao_atravessou"] = _min_d > 0.45
		results["ombro_seguem_correndo"] = a.get_flat_velocity().x > 2.5 and b.get_flat_velocity().x > 2.5
		results["ombro_sem_pulo"] = _max_y < 0.02
		_next()


func _shield() -> void:
	if t0 == 0:
		_begin(Vector3(0, 0, 0), Vector3.RIGHT, Vector3(-2.0, 0, 0.05), Vector3.RIGHT)
		ball.place_at(Vector3(0.42, Ball.RADIUS, 0))
		ball.claim(a)
	var t := f - t0
	a.intent.move = Vector3.ZERO
	b.intent.move = Vector3.RIGHT if t < 120 else Vector3.ZERO
	if t == 150:
		results["protege_tem_bola"] = a.ball_control.has_ball()
		results["protege_dist_min"] = snappedf(_min_d, 0.01)
		results["protege_carregador_deslocou"] = snappedf(a.global_position.length(), 0.01)
		results["protege_sem_pulo"] = _max_y < 0.02
		_next()
