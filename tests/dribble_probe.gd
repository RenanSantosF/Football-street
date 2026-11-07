extends Node
## Diagnóstico da condução: imprime corpo/bola/pé a cada N quadros num cenário.
## CEN=stop|run|behind|turn  godot --headless --path . res://tests/dribble_probe.tscn --fixed-fps 60
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var me: Player
var f := 0
var cen := "stop"

func _ready() -> void:
	process_priority = -100
	cen = OS.get_environment("CEN") if OS.get_environment("CEN") != "" else "stop"
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
	var t := f - 80
	if t == 0:
		mm.ball_out_system.cancel()
		me.set_frozen(false)
		me.teleport(Vector3(-9, 0, 0), Vector3(1, 0, 0))
		ball.in_play = true
		ball.restricted_team = -1
		ball.restricted_player = null
		var off := Vector3(0.42, 0, 0)
		if cen == "behind":
			off = Vector3(-0.55, 0, 0)
			me.velocity = Vector3(3, 0, 0)
		ball.place_at(Vector3(-9, 0, 0) + off + Vector3(0, Ball.RADIUS, 0))
		ball.claim(me)
		mm.state = MatchManager.MatchState.PLAYING
		Input.action_press("move_right", 1.0)
		if cen != "behind" and cen != "reverse":
			Input.action_press("sprint")
	if cen == "stop" and t == 90:
		Input.action_release("move_right"); Input.action_release("sprint")
	if cen == "reverse" and t == 60:
		Input.action_release("move_right"); Input.action_press("move_left", 1.0)
	if cen == "turn" and t == 70:
		Input.action_release("move_right"); Input.action_press("move_up", 1.0)
	if t % 4 == 0 or (OS.get_environment("FR") != "" and t >= int(OS.get_environment("FR")) and t < int(OS.get_environment("FR")) + 16):
		var o := me.ball_control.ball_offset()
		print("t=%d st=%d v=(%.2f,%.2f) off=(%.2f,%.2f) bv=(%.2f,%.2f) by=%.2f has=%s foot=%d/%d in=(%.1f,%.1f) fac=(%.2f,%.2f) trap=%s sole=%s" % [t, me.state, me.velocity.x, me.velocity.z, o.x, o.z, ball.flat_velocity().x, ball.flat_velocity().z, ball.global_position.y, me.ball_control.has_ball(), me.ball_control.foot.phase, me.ball_control.foot.mode, me.intent.move.x, me.intent.move.z, me.facing.x, me.facing.z, me.ball_control._trapping, me.ball_control._sole_on])
	if t == 200:
		get_tree().quit()
