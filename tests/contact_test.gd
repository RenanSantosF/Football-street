extends Node
## Mede se o PÉ encosta na bola em cada toque (rodar no PC):
##   godot --headless --path . res://tests/contact_test.tscn --fixed-fps 60
## Para cada toque (condução, toque de lado, puxada, sola), mede a distância
## entre o tornozelo JÁ COM A IK e o centro da bola no instante do contato.
## Pé encostando na bola: ~0,12–0,22 m (tornozelo → centro da bola).

const MAIN := preload("res://src/main/main.tscn")
var mm: MatchManager
var ball: Ball
var me: Player
var f := 0
var samples: Array[float] = []
var _pending := false
var _last_phase := 0


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
		var sk: Skeleton3D = me.visual.skeleton
		sk.skeleton_updated.connect(_on_skel)
	if f < 80:
		return
	if f == 80:
		me.set_frozen(false)
		me.set_restart_lock(false)
		ball.held = false
		ball.restricted_player = null
		mm.state = MatchManager.MatchState.PLAYING
		me.teleport(Vector3(-8, 0, 0), Vector3(1, 0, 0))
		ball.in_play = true
		ball.place_at(Vector3(-7.58, Ball.RADIUS, 0))
		ball.claim(me)
		Input.action_press("move_right", 1.0)
	var t := f - 80
	if t == 90: Input.action_press("move_up", 1.0); Input.action_release("move_right")
	if t == 150: Input.action_press("move_right", 1.0); Input.action_release("move_up")
	if t == 210: Input.action_release("move_right"); Input.action_press("move_left", 1.0)
	if t == 300: Input.action_release("move_left")
	if t == 360: Input.action_press("move_down", 1.0); Input.action_press("sprint")
	if t == 440:
		Input.action_release("move_down"); Input.action_release("sprint")
	var ph := me.ball_control.foot.phase
	if ph == FootContact.Phase.HOLD and _last_phase == FootContact.Phase.REACH:
		_pending = true
	_last_phase = ph
	if t == 520:
		samples.sort()
		var n := samples.size()
		var avg := 0.0
		for x in samples: avg += x
		print("toques medidos: ", n)
		if n > 0:
			print("tornozelo→bola no contato: min %.2f  mediana %.2f  máx %.2f  média %.2f" % [samples[0], samples[n / 2], samples[n - 1], avg / n])
			var ok := 0
			for x in samples:
				if x < 0.3: ok += 1
			print("toques com o pé na bola (< 0,30 m): %d/%d" % [ok, n])
		get_tree().quit()


func _on_skel() -> void:
	if not _pending:
		return
	_pending = false
	var sk: Skeleton3D = me.visual.skeleton
	var side := me.ball_control.foot.side
	var bone := sk.find_bone("RightFoot" if side > 0.0 else "LeftFoot")
	var ankle := sk.global_transform * sk.get_bone_global_pose(bone).origin
	samples.append(ankle.distance_to(ball.global_position))
