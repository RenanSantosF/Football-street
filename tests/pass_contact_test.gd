extends Node
## Contato do pé no PASSE em movimento (rodar no PC):
##   godot --headless --path . res://tests/pass_contact_test.tscn --fixed-fps 60
## Para cada situação (andando, correndo, em curva, mudando de direção,
## desacelerando) toca PASSE várias vezes em momentos diferentes da passada e
## mede: o passe saiu? o PÉ estava na bola no contato? quanto esperou?
const MAIN := preload("res://src/main/main.tscn")
const SCEN := ["andando", "correndo", "curva", "mudando", "desacelerando"]
const REPS := 6
var mm: MatchManager
var ball: Ball
var me: Player
var mate: Player
var f := 0
var t0 := 0
var si := 0
var rep := 0
var results := {}
var _press_f := -1
var _contact_f := -1
var _foot_d := -1.0
var _kicked := false
var _speed_at_press := 0.0


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
			if p.team == me.team and p != me and mate == null:
				mate = p
		for p in mm.players:
			if p != me and p != mate:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		me.ball_touched.connect(_on_touch)
	if f < 80:
		return
	if si >= SCEN.size():
		_report()
		return
	if t0 == 0:
		_setup()
	_drive(f - t0)


func _setup() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "pass"]:
		Input.action_release(a)
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	mm.set_controlled(me)
	me.set_human(true, mm.human_input)
	me.set_frozen(false)
	me.stamina = 1.0
	me.balance = 1.0
	me.teleport(Vector3(-11, 0, 0), Vector3.RIGHT)
	ball.in_play = true
	ball.restricted_team = -1
	ball.restricted_player = null
	ball.place_at(Vector3(-10.6, Ball.RADIUS, 0))
	ball.claim(me)
	mate.set_frozen(false)
	mate.controller = null
	mate.intent.move = Vector3.ZERO
	mate.teleport(Vector3(4, 0, -2.5), Vector3.LEFT)
	_press_f = -1
	_contact_f = -1
	_foot_d = -1.0
	_kicked = false
	t0 = f


func _drive(t: int) -> void:
	var scen: String = SCEN[si]
	# momento do passe varia com a repetição (fases diferentes da passada)
	var press_t := 70 + rep * 5
	match scen:
		"andando":
			if t == 1:
				Input.action_press("move_right", 0.45)
		"correndo":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
		"curva":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
			if t == press_t - 12:
				Input.action_press("move_up", 0.8)
		"mudando":
			if t == 1:
				Input.action_press("move_right", 1.0)
			if t == press_t - 8:
				Input.action_release("move_right")
				Input.action_press("move_up", 1.0)
		"desacelerando":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
			if t == press_t - 10:
				Input.action_release("move_right")
				Input.action_release("sprint")
	if t == press_t:
		_speed_at_press = me.get_horizontal_speed()
		Input.action_press("pass")
		_press_f = f
	if t == press_t + 3:
		Input.action_release("pass")
	if OS.get_environment("DBG") == scen and t >= press_t - 2 and t <= press_t + 60 and t % 3 == 0:
		print("%s r%d t=%d st=%d act=%s ct=%.2f/%.2f off=%s bv=%s pv=%s foot=%d/%.0f fd=%.2f can=%s buf=%d/%.2f poss=%s" % [scen, rep, t - press_t, me.state, me._action_kind, me._action_time, me._action_contact, str(me.ball_control.ball_offset().snapped(Vector3.ONE*0.01)), str(ball.flat_velocity().snapped(Vector3.ONE*0.1)), str(me.get_flat_velocity().snapped(Vector3.ONE*0.1)), me.ball_control.foot.phase, me.ball_control.foot.side, me.ball_control.active_foot_distance(), me.ball_control.can_kick(), me._buffer_action, me._buffer_timer, ball.possessor.name if ball.possessor else "-"])
	if not _kicked and _press_f > 0 and ball.possessor == null and ball.last_toucher == me \
			and ball.flat_velocity().length() > 3.0:
		_kicked = true
	if t == press_t + 90:
		var key: String = scen
		var r: Dictionary = results.get(key, {"saiu": 0, "pe_na_bola": 0, "n": 0, "dist": [], "espera_q": []})
		r["n"] += 1
		if _kicked:
			r["saiu"] += 1
		if _foot_d >= 0.0:
			r["dist"].append(snappedf(_foot_d, 0.01))
			if _foot_d <= 0.26:
				r["pe_na_bola"] += 1
		if _contact_f > 0:
			r["espera_q"].append(_contact_f - _press_f)
		r["vel"] = snappedf(_speed_at_press, 0.1)
		results[key] = r
		rep += 1
		if rep >= REPS:
			rep = 0
			si += 1
		t0 = 0


func _on_touch(kind: StringName) -> void:
	if kind == &"pass" and _press_f > 0 and _contact_f < 0:
		_contact_f = f
		_foot_d = _effective_foot_distance()


## Pé que chutou (animação + correção da IK, como no solver) até a bola.
func _effective_foot_distance() -> float:
	var bc := me.ball_control
	var fc := bc.foot
	var v := me.visual
	var side := fc.side
	var raw: Vector3 = v.call("get_raw_ankle_position", side)
	var w := clampf(fc._weight, 0.0, 1.0) if fc.phase != FootContact.Phase.IDLE else 0.0
	var an := raw + (fc._target - raw).limit_length(0.34) * w
	var tp := an + fc.dir * 0.16
	return BallControl._seg_point_dist(an, tp, ball.global_position)


func _report() -> void:
	for k in SCEN:
		var r: Dictionary = results.get(k, {})
		print("%-14s vel=%.1f  saiu %d/%d  pé na bola %d/%d  dist=%s  espera(quadros)=%s" % [k, r.get("vel", 0.0), r.get("saiu", 0), r.get("n", 0), r.get("pe_na_bola", 0), r.get("n", 0), str(r.get("dist", [])), str(r.get("espera_q", []))])
	get_tree().quit()
