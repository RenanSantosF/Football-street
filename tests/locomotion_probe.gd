extends Node
## Sonda da locomoção (rodar no PC):
##   godot --headless --path . res://tests/locomotion_probe.tscn --fixed-fps 60
## Para cada velocidade constante (BALL=1 com bola) mede, na pose FINAL do
## esqueleto: velocidade, cadência (passos/s), deslize do pé apoiado,
## TREMOR do pé (resíduo de alta frequência do tornozelo, em mm), balanço dos
## braços (pico a pico da mão para a frente, cm) e quique do quadril (cm).
const MAIN := preload("res://src/main/main.tscn")
const LEVELS := [[0.3, false], [0.55, false], [0.8, false], [1.0, false], [1.0, true]]
const SETTLE := 90
const MEASURE := 150
var mm: MatchManager
var me: Player
var f := 0
var li := 0
var t0 := 0
var _ank := {1.0: [], -1.0: []}
var _hand := {1.0: [], -1.0: []}
var _ank_w := {1.0: [], -1.0: []}
var _hips: Array = []
var _v: Array = []
var _slide := 0.0
var _slide_n := 0.0
var _prev := {}
var results := []


func _ready() -> void:
	process_priority = 100
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
			_ball().place_at(Vector3(-13.5, 0.11, 4.6))
	if f < 60:
		return
	if li >= LEVELS.size():
		for r in results:
			print(r)
		get_tree().quit()
		return
	var lv: Array = LEVELS[li]
	if t0 == 0:
		t0 = f
		mm.ball_out_system.cancel()
		mm.state = MatchManager.MatchState.PLAYING
		me.set_frozen(false)
		me.stamina = 1.0
		me.teleport(Vector3(-13, 0, 0), Vector3(1, 0, 0))
		if OS.get_environment("BALL") != "":
			var b := _ball()
			b.in_play = true
			b.restricted_team = -1
			b.restricted_player = null
			b.place_at(Vector3(-12.55, Ball.RADIUS, 0))
			b.claim(me)
		Input.action_press("move_right", lv[0])
		if lv[1]:
			Input.action_press("sprint")
		for s in [1.0, -1.0]:
			_ank[s] = []
			_ank_w[s] = []
			_hand[s] = []
		_hips = []
		_v = []
		_slide = 0.0
		_slide_n = 0.0
		_prev = {}
	var t := f - t0
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	if t > SETTLE and t <= SETTLE + MEASURE:
		var vis = me.visual
		var root: Vector3 = me.global_position
		var fwd := me.facing
		for s in [1.0, -1.0]:
			var a: Vector3 = vis.get_raw_ankle_position(s) if OS.get_environment("RAW") != "" else vis.get_ankle_position(s)
			_ank[s].append(a - root)
			_ank_w[s].append(a)
			if _prev.has(s):
				var a0: Vector3 = _prev[s]
				if a.y < 0.1 and a0.y < 0.1 and absf(a.y - a0.y) / delta < 0.15:
					_slide += Vector3(a.x - a0.x, 0, a.z - a0.z).length()
					_slide_n += delta
			_prev[s] = a
			var sk: Skeleton3D = vis.skeleton
			var hb := sk.find_bone("RightHand" if s > 0.0 else "LeftHand")
			if hb >= 0:
				var hp := sk.global_transform * sk.get_bone_global_pose(hb).origin
				_hand[s].append((hp - root).dot(fwd))
		var sk2: Skeleton3D = vis.skeleton
		var hi := sk2.find_bone("Hips")
		_hips.append((sk2.global_transform * sk2.get_bone_global_pose(hi).origin).y)
		_v.append(me.get_flat_velocity().length())
	if t == SETTLE + MEASURE + 1:
		results.append(_summary(lv))
		_release()
		li += 1
		t0 = 0


func _summary(lv: Array) -> String:
	var v := 0.0
	for x in _v:
		v += x
	v /= maxf(_v.size(), 1)
	var steps := 0
	var slide_sum := 0.0
	var slide_n := 0
	var hf_amp := 0.0
	var hf_ratio := 0.0
	for s in [1.0, -1.0]:
		var arr: Array = _ank[s]
		var w: Array = _ank_w[s]
		var ys: Array[float] = []
		for p in arr:
			ys.append(p.y)
		var ymin: float = ys.min() if ys.size() > 0 else 0.0
		# apoio = tornozelo a até 1,5 cm da altura mínima
		var was := false
		var last := -100
		for i in range(1, ys.size()):
			var st: bool = ys[i] < ymin + 0.015
			if st and not was and i - last > 10:
				steps += 1
				last = i
			if st and ys[i - 1] < ymin + 0.015:
				var d: Vector3 = w[i] - w[i - 1]
				d.y = 0.0
				slide_sum += d.length() * 60.0
				slide_n += 1
			was = st
		# tremor: energia acima de 9 Hz (a passada vive abaixo de ~7 Hz)
		var n := arr.size()
		for axis in 3:
			var xs := PackedFloat64Array()
			var mean := 0.0
			for p in arr:
				xs.append(p[axis])
				mean += p[axis]
			mean /= maxf(n, 1)
			var tot := 0.0
			var hi := 0.0
			for k in range(1, n / 2):
				var re := 0.0
				var im := 0.0
				for i in n:
					var a := TAU * k * i / n
					var win := 0.5 - 0.5 * cos(TAU * i / (n - 1))
					re += (xs[i] - mean) * win * cos(a)
					im -= (xs[i] - mean) * win * sin(a)
				var pw := re * re + im * im
				tot += pw
				if float(k) * 60.0 / n > 9.0:
					hi += pw
			hf_ratio = maxf(hf_ratio, hi / maxf(tot, 1e-12))
			hf_amp = maxf(hf_amp, sqrt(hi) / n * 2.0 * 1000.0 * 1.63)
	var zig := 0
	for s in [1.0, -1.0]:
		var arr: Array = _ank[s]
		for i in range(3, arr.size()):
			var d2: Vector3 = arr[i] - 2.0 * arr[i - 1] + arr[i - 2]
			var d1: Vector3 = arr[i - 1] - 2.0 * arr[i - 2] + arr[i - 3]
			if d2.dot(d1) < 0.0 and d2.length() > 0.004 and d1.length() > 0.004:
				zig += 1
				if OS.get_environment("ZDBG") != "" and lv[1] and s > 0.0:
					print("ZIG i=", i, " y=", snappedf(arr[i].y, 0.001), " fwd=", snappedf(arr[i].x, 0.001), " d2=", d2.snapped(Vector3.ONE * 0.0001), " d1=", d1.snapped(Vector3.ONE * 0.0001))
	var dur := MEASURE / 60.0
	var arm := 0.0
	for s in [1.0, -1.0]:
		var h: Array = _hand[s]
		if h.size() > 0:
			arm = maxf(arm, (float(h.max()) - float(h.min())) * 100.0)
	var bob: float = (_hips.max() - _hips.min()) * 100.0 if _hips.size() > 0 else 0.0
	var ac = me.anim_controller
	return "in=%.2f%s v=%.2f m/s | cadência %.2f passos/s | pé apoiado desliza %.0f cm/s | tremor (>9 Hz) %.1f mm, %.1f%% da energia | zigue-zague %.1f/s | braço p-p %.0f cm | quadril p-p %.1f cm | blend=%.2f ts=%.2f" % [
		lv[0], " SPRINT" if lv[1] else "", v, steps / dur, slide_sum / maxf(slide_n, 1),
		hf_amp, hf_ratio * 100.0, zig / dur, arm, bob, ac._blend_pos, ac._time_scale]


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		Input.action_release(a)


func _ball() -> Ball:
	return get_tree().get_first_node_in_group("ball") as Ball
