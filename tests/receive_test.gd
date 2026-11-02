extends Node
## Domínio (rodar no PC):  godot --headless --path . res://tests/receive_test.tscn --fixed-fps 60
## Passes rasteiros de várias direções e forças para o jogador; conta quantos
## ele DOMINA (fica com a bola parada perto do pé) sem deixar passar.

const MAIN := preload("res://src/main/main.tscn")
const CASES := [
	# [ângulo de onde vem (graus, 0 = de frente), velocidade m/s]
	[0, 8.0], [0, 12.0], [0, 15.0], [35, 9.0], [-35, 11.0], [70, 9.0], [-70, 12.0],
	[110, 8.0], [-110, 10.0], [180, 8.0], [20, 6.0], [-20, 14.0],
]

var mm: MatchManager
var ball: Ball
var me: Player
var f := 0
var idx := 0
var t0 := 0
var ok := 0
var fails: Array[String] = []


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
	if idx >= CASES.size():
		print("domínios: %d/%d" % [ok, CASES.size()])
		if not fails.is_empty():
			print("falhas: ", fails)
		get_tree().quit()
		return
	var c: Array = CASES[idx]
	if t0 == 0:
		t0 = f
		mm.ball_out_system.cancel()
		mm.state = MatchManager.MatchState.PLAYING
		me.set_frozen(false)
		me.teleport(Vector3(0, 0, 0), Vector3(-1, 0, 0))
		ball.in_play = true
		ball.restricted_team = -1
		ball.restricted_player = null
		var a := deg_to_rad(float(c[0]))
		var from_dir := Vector3(-cos(a), 0, sin(a)) # 0° = na frente do jogador (-x)
		var dist := minf(8.0, 4.2 / maxf(absf(sin(a)), 0.01)) # dentro das laterais
		ball.place_at(from_dir * dist + Vector3(0, Ball.RADIUS, 0))
	var t := f - t0
	if t == 1 and OS.get_environment("SPRINT") != "":
		Input.action_press("sprint") # recebendo com CORRER apertado
		if OS.get_environment("MOVE") != "":
			Input.action_press(OS.get_environment("MOVE"), 1.0)
	if t == 3:
		var v := (Vector3(0, Ball.RADIUS, 0) - ball.global_position)
		v.y = 0.0
		ball.kick(v.normalized() * float(c[1]), Vector3.ZERO, null)
		ball.pass_target = me
	if OS.get_environment("DBGR") == str(c[0]) and t % 6 == 0 and t <= 150:
		print("R t=", t, " me=", me.global_position.snapped(Vector3.ONE*0.01), " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.01), " fac=", me.facing.snapped(Vector3.ONE*0.01), " ball=", ball.global_position.snapped(Vector3.ONE*0.01), " bv=", ball.flat_velocity().snapped(Vector3.ONE*0.01), " pos=", ball.possessor.name if ball.possessor else "-", " act=", me._action_kind, " st=", me.state)
	if t == 150:
		for a in ["sprint", "move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		# dominou = está com a bola no pé (parado ou já conduzindo, se o analógico estava apertado)
		var moving_on := OS.get_environment("MOVE") != ""
		var got := ball.possessor == me and me.ball_control.ball_distance() < 0.9 \
			and (moving_on or ball.flat_velocity().length() < 2.0)
		if got:
			ok += 1
		else:
			fails.append("%d°/%.0fm/s (dono=%s d=%.2f v=%.1f)" % [c[0], c[1], ball.possessor.name if ball.possessor else "-", me.ball_control.ball_distance(), ball.flat_velocity().length()])
		idx += 1
		t0 = 0
