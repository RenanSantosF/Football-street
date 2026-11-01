extends Node
## Domínio no ar (rodar no PC):  godot --headless --path . res://tests/aerial_test.tscn --fixed-fps 60
## Lança a bola no jogador em alturas diferentes e confere coxa / peito / cabeça
## e o cabeceio de primeira (PASSE apertado antes da bola chegar).

const MAIN := preload("res://src/main/main.tscn")
const CASES := [
	[0.55, "recv_knee", false],
	[1.1, "recv_chest", false],
	[1.7, "head_control", false],
	[1.7, "header", true],
]

var mm: MatchManager
var ball: Ball
var me: Player
var mate: Player
var f := 0
var idx := 0
var t0 := 0
var results := {}
var _kind := ""


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
		for p in mm.get_team(me.team):
			if p != me:
				mate = p
		me.action_started.connect(func(k): _kind = String(k))
	if f < 80:
		return
	if idx >= CASES.size():
		print("RESULTADOS: ", results)
		get_tree().quit()
		return
	var c: Array = CASES[idx]
	if t0 == 0:
		t0 = f
		_kind = ""
		mm.ball_out_system.cancel()
		mm.state = MatchManager.MatchState.PLAYING
		me.set_frozen(false)
		me.teleport(Vector3(0, 0, 0), Vector3(-1, 0, 0))
		mate.set_physics_process(true)
		mate.set_frozen(false)
		mate.teleport(Vector3(6, 0, 2), Vector3(-1, 0, 0))
		mate.set_physics_process(false)
		ball.in_play = true
		ball.restricted_team = -1
		ball.restricted_player = null
		# lança de 7 m: chega na altura pedida
		var from := Vector3(-7, 0.4, 0)
		ball.place_at(from)
	var t := f - t0
	if t == 2:
		var from := ball.global_position
		var speed := 9.0
		var tt := 7.0 / speed
		var vy: float = (float(c[0]) - from.y) / tt + 0.5 * 9.8 * tt
		ball.kick(Vector3(speed, vy, 0), Vector3.ZERO, null)
		ball.pass_target = me
		if c[2]:
			Input.action_press("pass")
	if t == 6 and c[2]:
		Input.action_release("pass")
	if t == 90:
		var key := "%s_%.1f" % [c[1], c[0]]
		results[key + "_acao"] = _kind
		if c[2]:
			results[key + "_ok"] = _kind == c[1] and ball.possessor != me and ball.flat_velocity().length() > 2.0
		else:
			results[key + "_ok"] = _kind == c[1] and ball.possessor == me
	if t == 160:
		if not c[2]:
			results["%s_%.1f_bola_no_pe" % [c[1], c[0]]] = ball.possessor == me and ball.global_position.y < 0.3 and me.ball_control.ball_distance() < 0.9
		idx += 1
		t0 = 0
