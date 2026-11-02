extends Node
## Pé apoiado x corpo, andando reto em várias velocidades (BALL=1 com bola, SPR=1 correndo).
const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var me: Player
var f := 0
var levels := [0.55, 0.62, 0.7, 0.78, 0.85, 0.92, 1.0]
var li := 0
var t0 := 0
var slide := 0.0
var n := 0.0
var prev := {}
var fwd_sum := 0.0
func _ready() -> void:
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
func _physics_process(delta: float) -> void:
	f += 1
	if f == 3:
		me = mm.controlled
		for p in mm.players:
			if p != me:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		if OS.get_environment("BALL") == "":
			main_ball().place_at(Vector3(-13.5, 0.11, 4.6))
	if f < 60:
		return
	if li >= levels.size():
		get_tree().quit()
		return
	if t0 == 0:
		t0 = f
		mm.state = MatchManager.MatchState.PLAYING
		me.set_frozen(false)
		me.teleport(Vector3(-12, 0, 0), Vector3(1, 0, 0))
		Input.action_press("move_right", levels[li])
		if OS.get_environment("SPR") != "":
			Input.action_press("sprint")
		if OS.get_environment("BALL") != "":
			main_ball().place_at(Vector3(-11.6, 0.11, 0))
			main_ball().in_play = true
			main_ball().restricted_team = -1
			main_ball().restricted_player = null
			main_ball().claim(me)
		slide = 0.0
		n = 0.0
		fwd_sum = 0.0
		prev = {}
	var t := f - t0
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	var v = me.visual
	var ank := {1.0: v.get_ankle_position(1.0), -1.0: v.get_ankle_position(-1.0)}
	if t > 90 and prev.size() > 0:
		for s in [1.0, -1.0]:
			var a: Vector3 = ank[s]
			var a0: Vector3 = prev[s]
			if a.y < 0.1 and a0.y < 0.1 and absf(a.y - a0.y) / delta < 0.15:
				slide += (a.x - a0.x)  # deslize ao longo do movimento (+ = pé indo pra frente)
				n += delta
	prev = ank
	if OS.get_environment("DBG") != "" and t % 10 == 0 and li == levels.size() - 1:
		print("t=", t, " v=", me.get_flat_velocity().snapped(Vector3.ONE*0.01), " off=", me.ball_control.ball_offset().snapped(Vector3.ONE*0.01), " bv=", main_ball().flat_velocity().snapped(Vector3.ONE*0.01), " foot=", me.ball_control.foot.phase, "/", me.ball_control.foot.mode, " ap=", me.ball_control.approach_point(Vector3.RIGHT), " st=", me.state, " ", me._action_kind)
	if t == 230:
		var ac = me.anim_controller
		Input.action_release("sprint")
		print("in=%.2f v=%.2f  pé apoiado anda %.1f cm/s (+frente)  blend=%.2f ts=%.2f" % [levels[li], me.get_flat_velocity().length(), slide / maxf(n, 0.01) * 100.0, ac._blend_pos, ac._time_scale])
		Input.action_release("move_right")
		li += 1
		t0 = 0
func main_ball() -> RigidBody3D:
	return get_tree().get_first_node_in_group("ball")
