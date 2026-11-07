extends Node
## Trepidação na condução em CURVAS (rodar no PC):
##   godot --headless --path . res://tests/curve_jitter_test.tscn --fixed-fps 60
## Conduz fazendo curvas (90°, zigue-zague suave, círculo) e mede, por segundo,
## quantas vezes a velocidade da bola muda bruscamente e QUEM mudou (toque
## programado, pé passivo, corpo, correção lateral, pé que desistiu), além da
## suavidade da distância bola-jogador (variação quadro a quadro).
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var me: Player
var f := 0
var t0 := 0
var _prev_off := Vector3.ZERO
var _prev_bv := Vector3.ZERO
var _jerk := 0
var _off_jumps := 0
var _frames := 0
var _lost := false


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		me = mm.controlled
		for p in mm.players:
			if p != me:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
	if f < 80:
		return
	if t0 == 0:
		t0 = f
		mm.ball_out_system.cancel()
		mm.state = MatchManager.MatchState.PLAYING
		me.teleport(Vector3(-10, 0, -2.5), Vector3.RIGHT)
		ball.in_play = true
		ball.restricted_team = -1
		ball.restricted_player = null
		ball.place_at(Vector3(-9.6, Ball.RADIUS, -2.5))
		ball.claim(me)
		me.ball_control.debug_stats = true
		me.ball_control.dbg = {}
	var t := f - t0
	# curvas contínuas: o analógico gira devagar (círculo) e depois zigue-zague
	var ang := 0.0
	if t < 240:
		ang = t / 240.0 * PI * 1.5 # 270° em 4 s
	else:
		ang = PI * 1.5 + sin((t - 240) / 30.0) * 0.9
	var dir := Vector2(cos(ang), sin(ang))
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x > 0.0:
		Input.action_press("move_right", dir.x)
	else:
		Input.action_press("move_left", -dir.x)
	if dir.y > 0.0:
		Input.action_press("move_down", dir.y)
	else:
		Input.action_press("move_up", -dir.y)
	if t > 30:
		var off := me.ball_control.ball_offset()
		var bv := ball.flat_velocity()
		_frames += 1
		if (bv - _prev_bv).length() > 0.6:
			_jerk += 1
		if (off - _prev_off).length() > 0.045:
			_off_jumps += 1
		if not me.ball_control.has_ball():
			_lost = true
		_prev_off = off
		_prev_bv = bv
	else:
		_prev_off = me.ball_control.ball_offset()
		_prev_bv = ball.flat_velocity()
	if t == 480:
		var secs := _frames / 60.0
		print("duração %.1f s | perdeu a bola: %s" % [secs, _lost])
		print("mudanças bruscas de velocidade da bola (>0,6 m/s num quadro): %.1f/s" % (_jerk / secs))
		print("saltos da posição bola-jogador (>4,5 cm num quadro): %.1f/s" % (_off_jumps / secs))
		for k in me.ball_control.dbg:
			var e: Array = me.ball_control.dbg[k]
			print("  %-12s %.1f/s  (bruscas >0,4: %.1f/s, Δv médio %.2f)" % [k, e[0] / secs, e[2] / secs, e[1] / maxf(e[0], 1)])
		get_tree().quit()
