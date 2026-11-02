extends Node
## Condução (rodar no PC):  godot --headless --path . res://tests/dribble_test.tscn --fixed-fps 60
## 1) correr e soltar o analógico → para a bola junto ao pé
## 2) correr e inverter → puxa a bola e segue com ela
## 3) sprint e virar 90° com a bola longe → alcança a bola antes (não abandona)
## 4) chacoalhar o analógico → não perde a bola

const MAIN := preload("res://src/main/main.tscn")

var mm: MatchManager
var ball: Ball
var me: Player
var f := 0
var phase := 0
var t0 := 0
var results := {}
var _maxd := 0.0
var _lost := 0


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		for p in mm.players:
			if p != mm.controlled:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		me = mm.controlled
	if f < 80:
		return
	if me.ball_control.has_ball():
		_maxd = maxf(_maxd, me.ball_control.ball_distance())
	elif t0 != 0:
		_lost += 1
	match phase:
		0: _stop_test()
		1: _reverse_test()
		2: _turn_far_test()
		3: _shake_test()
		4: _back_pass_test()
		5: _ball_behind_test(Vector3(-0.55, 0, 0), "atras")
		6: _ball_behind_test(Vector3(-0.6, 0, -0.55), "atras_lado")
		7: _ball_behind_test(Vector3(-0.9, 0, 0.3), "atras_longe")
		8: _small_turn_test()
		9: _side_test()
		10:
			print("RESULTADOS: ", results)
			get_tree().quit()


func _setup(pos: Vector3, face: Vector3) -> void:
	_release_all()
	mm.ball_out_system.cancel()
	me.set_frozen(false)
	me.teleport(pos, face)
	ball.in_play = true
	ball.restricted_team = -1
	ball.restricted_player = null
	ball.place_at(pos + face * 0.42 + Vector3(0, Ball.RADIUS, 0))
	ball.claim(me)
	mm.state = MatchManager.MatchState.PLAYING
	_maxd = 0.0
	_lost = 0


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		Input.action_release(a)


func _next() -> void:
	_release_all()
	phase += 1
	t0 = 0


func _stop_test() -> void:
	if t0 == 0:
		_setup(Vector3(-9, 0, 0), Vector3(1, 0, 0))
		t0 = f
		Input.action_press("move_right", 1.0)
		Input.action_press("sprint")
	var t := f - t0
	if t == 90:
		_release_all()
	if t == 220:
		results["parar_tem_bola"] = me.ball_control.has_ball()
		results["parar_dist"] = snappedf(me.ball_control.ball_distance(), 0.01)
		results["parar_bola_vel"] = snappedf(ball.flat_velocity().length(), 0.01)
		results["parar_ok"] = me.ball_control.has_ball() and me.ball_control.ball_distance() < 0.7 and ball.flat_velocity().length() < 0.4
		_next()


func _reverse_test() -> void:
	if t0 == 0:
		_setup(Vector3(-6, 0, 0), Vector3(1, 0, 0))
		t0 = f
		Input.action_press("move_right", 1.0)
	var t := f - t0
	if t == 60:
		Input.action_release("move_right")
		Input.action_press("move_left", 1.0)
	if t % 10 == 0 and t >= 50 and OS.get_environment("DBG") != "":
		print("inv t=", t, " me=", me.global_position.snapped(Vector3.ONE*0.01), " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.01), " ball=", ball.global_position.snapped(Vector3.ONE*0.01), " bv=", ball.flat_velocity().snapped(Vector3.ONE*0.01), " act=", me._action_kind, " st=", me.state, " fac=", me.facing.snapped(Vector3.ONE*0.01), " drag=", me.ball_control.is_dragging(), " trap=", me.ball_control.is_trapping())
	if t > 60 and _inv_t < 0 and me.ball_control.has_ball() and me.get_flat_velocity().x < -1.5 \
			and ball.global_position.x < me.global_position.x - 0.1:
		_inv_t = t - 60
	if t == 180:
		results["inverter_tempo_s"] = snappedf(_inv_t / 60.0, 0.01) if _inv_t >= 0 else -1.0
		_inv_t = -1
		var off := ball.global_position - me.global_position
		results["inverter_tem_bola"] = me.ball_control.has_ball()
		results["inverter_bola_na_frente"] = off.x < 0.0
		results["inverter_dist_max"] = snappedf(_maxd, 0.01)
		results["inverter_andando_pra_esq"] = me.get_flat_velocity().x < -0.5
		results["inverter_vel"] = snappedf(me.get_flat_velocity().x, 0.1)
		_next()


func _turn_far_test() -> void:
	if t0 == 0:
		_setup(Vector3(-9, 0, 0), Vector3(1, 0, 0))
		t0 = f
		Input.action_press("move_right", 1.0)
		Input.action_press("sprint")
	var t := f - t0
	if OS.get_environment("DBG") != "" and t > 55 and t % 5 == 0 and t < 160:
		print("VL t=", t, " me=", me.global_position, " v=", me.get_flat_velocity(), " ball=", ball.global_position, " bv=", ball.flat_velocity(), " has=", me.ball_control.has_ball(), " in=", me.intent.move, " st=", me.state, " ", me._action_kind)
	if t == 70:
		# vira 90° (para cima na tela) sem soltar o sprint
		Input.action_release("move_right")
		Input.action_press("move_up", 1.0)
	if t == 160:
		results["virar_longe_tem_bola"] = me.ball_control.has_ball()
		results["virar_longe_dist_max"] = snappedf(_maxd, 0.01)
		results["virar_longe_sem_perder"] = _lost == 0
		_next()


var _mate: Player
var _inv_t := -1
var _kick_from := Vector3.ZERO
var _mate_at_kick := Vector3.ZERO
var _kick_v := Vector3.ZERO
var _mirror_seen := false


func _back_pass_test() -> void:
	if t0 == 0:
		_setup(Vector3(0, 0, 0), Vector3(1, 0, 0))
		for p in mm.get_team(me.team):
			if p != me:
				_mate = p
		_mate.set_physics_process(true)
		_mate.set_frozen(false)
		_mate.teleport(Vector3(-6, 0, 0.5), Vector3(1, 0, 0))
		t0 = f
		_kick_v = Vector3.ZERO
	var t := f - t0
	if t == 10:
		Input.action_press("move_left", 1.0)
		Input.action_press("pass")
	if t == 13:
		Input.action_release("pass")
	if t == 16:
		Input.action_release("move_left")
	if me.state == Player.State.ACTION and me._action_kind == &"pass":
		_mirror_seen = _mirror_seen or me.kick_mirrored()
	if _kick_v == Vector3.ZERO and ball.possessor == null and ball.flat_velocity().length() > 3.0:
		_kick_v = ball.flat_velocity()
		_kick_from = ball.global_position
		_mate_at_kick = _mate.global_position
	if t == 120:
		results["tras_passe_saiu"] = _kick_v != Vector3.ZERO
		results["tras_passe_dir_ok"] = _kick_v.x < -2.0
		var to_mate := (_mate_at_kick - _kick_from).normalized()
		results["tras_passe_desvio_graus"] = snappedf(rad_to_deg(Vector3(_kick_v.x, 0, _kick_v.z).normalized().angle_to(Vector3(to_mate.x, 0, to_mate.z))), 0.1) if _kick_v != Vector3.ZERO else -1.0
		results["tras_sem_cair"] = me.state != Player.State.STUNNED
		_next()


func _ball_behind_test(off: Vector3, key: String) -> void:
	if t0 == 0:
		_setup(Vector3(-6, 0, 0), Vector3(1, 0, 0))
		ball.place_at(Vector3(-6, Ball.RADIUS, 0) + off)
		ball.claim(me)
		me.velocity = Vector3(3.0, 0, 0)
		t0 = f
		Input.action_press("move_right", 1.0)
	var t := f - t0
	if t % 15 == 0 and OS.get_environment("DBG") != "":
		print(key, " t=", t, " me=", me.global_position, " v=", me.get_flat_velocity(), " ball=", ball.global_position, " st=", me.state, " act=", me._action_kind, " fac=", me.facing.snapped(Vector3.ONE*0.01), " ap=", me.ball_control.approach_point(Vector3.RIGHT), " drag=", me.ball_control.is_dragging(), " trap=", me.ball_control.is_trapping())
	if t == 150:
		var o := ball.global_position - me.global_position
		results[key + "_tem_bola"] = me.ball_control.has_ball()
		results[key + "_bola_frente"] = o.x > 0.1
		results[key + "_correndo"] = me.get_flat_velocity().x > 0.5
		results[key + "_vel"] = snappedf(me.get_flat_velocity().x, 0.1)
		_next()


var _dragged := 0


## Parado com a bola, analógico um pouco para o lado (~45°): vira puxando a
## bola com a sola e sai na nova direção com ela na frente.
func _small_turn_test() -> void:
	if t0 == 0:
		_setup(Vector3(-2, 0, 0), Vector3(1, 0, 0))
		t0 = f
		_dragged = 0
		me.ball_touched.connect(func(k): if k == &"drag": _dragged += 1)
	var t := f - t0
	if t == 20:
		Input.action_press("move_right", 0.7)
		Input.action_press("move_up", 0.7)
	if t == 110:
		var want := Vector3(1, 0, -1).normalized()
		var o := ball.global_position - me.global_position
		o.y = 0.0
		results["virada_leve_tem_bola"] = me.ball_control.has_ball()
		results["virada_leve_puxou_com_sola"] = _dragged > 0
		results["virada_leve_virou"] = me.facing.dot(want) > 0.85
		results["virada_leve_bola_na_frente"] = o.normalized().dot(want) > 0.6
		_next()


var _side_t := -1


## Andando com a bola para a frente e analógico 90° para o lado: quanto tempo
## até o toque levar a bola para o novo lado.
func _side_test() -> void:
	if t0 == 0:
		_setup(Vector3(-6, 0, 0), Vector3(1, 0, 0))
		t0 = f
		_side_t = -1
		Input.action_press("move_right", 1.0)
	var t := f - t0
	if t == 60:
		Input.action_release("move_right")
		Input.action_press("move_up", 1.0)
	if OS.get_environment("DBG") != "" and t >= 58 and t < 150 and t % 4 == 0:
		print("SD t=", t, " me=", me.global_position.snapped(Vector3.ONE*0.01), " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.1), " face=", me.facing.snapped(Vector3.ONE*0.01), " in=", me.intent.move.snapped(Vector3.ONE*0.01), " ball=", ball.global_position.snapped(Vector3.ONE*0.01), " bv=", ball.flat_velocity().snapped(Vector3.ONE*0.1), " d=", snappedf(me.ball_control.ball_distance(),0.01), " foot=", me.ball_control.foot.phase, "/", me.ball_control.foot.mode, " st=", me.state, " ", me._action_kind)
	if t > 60 and _side_t < 0 and ball.flat_velocity().dot(Vector3(0, 0, -1)) > 1.0:
		_side_t = t - 60
	if t == 150:
		results["lado_tempo_ate_toque_s"] = snappedf(_side_t / 60.0, 0.01) if _side_t >= 0 else -1.0
		results["lado_tem_bola"] = me.ball_control.has_ball()
		var o := ball.global_position - me.global_position
		results["lado_bola_na_frente"] = o.z < -0.1
		_next()


func _shake_test() -> void:
	if t0 == 0:
		_setup(Vector3(-4, 0, 0), Vector3(1, 0, 0))
		t0 = f
	var t := f - t0
	# esquerda/direita a cada 6 quadros (0,1 s), por 2 s
	if t < 120 and t % 6 == 0:
		_release_all()
		Input.action_press("move_left" if (t / 6) % 2 == 0 else "move_right", 1.0)
	if t == 120:
		_release_all()
	if OS.get_environment("DBG") != "" and t % 6 == 3:
		print("SH t=", t, " me=", me.global_position.snapped(Vector3.ONE*0.01), " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.01), " fac=", me.facing.snapped(Vector3.ONE*0.01), " off=", me.ball_control.ball_offset().snapped(Vector3.ONE*0.01), " bv=", ball.flat_velocity().snapped(Vector3.ONE*0.01), " in=", me.intent.move.snapped(Vector3.ONE*0.01), " drag=", me.ball_control.is_dragging(), " act=", me._action_kind if me.state == 1 else "")
	if t == 200:
		results["chacoalhar_tem_bola"] = me.ball_control.has_ball()
		results["chacoalhar_dist_max"] = snappedf(_maxd, 0.01)
		results["chacoalhar_sem_perder"] = _lost == 0
		_next()
