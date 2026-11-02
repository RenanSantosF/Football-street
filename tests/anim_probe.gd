extends Node
## Detector: pé apoiado deslizando e "pulo" de pose (quadril), por estado de animação.
## Rodar: SECS=60 godot --headless --path . res://tests/anim_probe.tscn
const MAIN := preload("res://src/main/main.tscn")
var SECONDS := 120.0
var _mm: MatchManager
var _t := 0.0
var _prev := {}  # player -> {hips_local, yaw_local, ankles: {1: pos, -1: pos}}
var slide := {}   # estado -> metros deslizados com o pé apoiado
var slide_time := {} # estado -> segundos de amostra
var pops := {}    # "estado|ação" -> contagem
var pop_examples := []
var _miny := 1.0
var _hist := {}
var _watch := {}
var _nbig := 0
var lb := {}
var lbt := {}
var _ys: Array[float] = []
var PLANT_Y := 0.1

func _ready() -> void:
	var main := MAIN.instantiate()
	_mm = main.get_node("MatchManager")
	_mm.autoplay = true
	_mm.match_seed = 777
	if OS.get_environment("PLANT") != "":
		PLANT_Y = float(OS.get_environment("PLANT"))
	if OS.get_environment("SECS") != "":
		SECONDS = float(OS.get_environment("SECS"))
	add_child(main)

func _physics_process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		return
	for p in _mm.players:
		var v = p.visual
		if v == null or not ("skeleton" in v) or v.skeleton == null:
			continue
		var sk: Skeleton3D = v.skeleton
		var hb := sk.find_bone("Hips")
		var hips_w: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
		var hips_l: Vector3 = p.global_transform.affine_inverse() * hips_w
		var hb_basis: Basis = (sk.global_transform.basis * sk.get_bone_global_pose(hb).basis)
		var fwd: Vector3 = hb_basis.z
		var side_ax: Vector3 = hb_basis.x
		var yaw_w := atan2(side_ax.z, side_ax.x) * -1.0 # pelo eixo lateral do quadril (estável com inclinação)
		var yaw_f := atan2(fwd.x, fwd.z)
		var yaw_l := wrapf(yaw_w - p.rotation.y, -PI, PI)
		var st := String(p.anim_controller.playback.get_current_node()) if p.anim_controller.is_active() else "?"
		var key := st + "|" + String(p._action_kind if p.state == Player.State.ACTION else "")
		var ank := {1.0: v.get_ankle_position(1.0), -1.0: v.get_ankle_position(-1.0)}
		var hist: Array = _hist.get(p, [])
		hist.append(snappedf(rad_to_deg(yaw_w), 1.0))
		if hist.size() > 8:
			hist.pop_front()
		_hist[p] = hist
		if _watch.has(p):
			_watch[p] -= 1
			if _watch[p] <= 0:
				print("   seq ", p.name, " ", hist, " bp=", p.anim_controller._mark_pos, " st=", st)
				_watch.erase(p)
		if _prev.has(p):
			var pr: Dictionary = _prev[p]
			var dh: float = (hips_l - pr.hips_l).length()
			var dy: float = minf(absf(wrapf(yaw_w - pr.yaw_w, -PI, PI)), absf(wrapf(yaw_f - pr.yaw_f, -PI, PI))) # os dois eixos concordam
			var teleported: bool = p.global_position.distance_to(pr.pos) > 0.4
			if not teleported and (dh > 0.09 or dy > deg_to_rad(18.0)):
				var k2: String = pr.key + " -> " + key
				pops[k2] = pops.get(k2, 0) + 1
				if dy > deg_to_rad(60.0) and _nbig < 6:
					_nbig += 1
					_watch[p] = 4
				if pop_examples.size() < 12:
					pop_examples.append("%s t=%.2f dh=%.2f dyaw=%.0f gk=%s rotdelta=%.0f v=%.1f" % [k2, _t, dh, rad_to_deg(dy), p.is_goalkeeper(), rad_to_deg(absf(wrapf(p.rotation.y - pr.roty, -PI, PI))), p.get_flat_velocity().length()])
			for side in [1.0, -1.0]:
				var a: Vector3 = ank[side]
				var a0: Vector3 = pr.ank[side]
				if st == "Locomotion" and _ys.size() < 200000: _ys.append(a.y)
				if a.y < PLANT_Y and a0.y < PLANT_Y and absf(a.y - a0.y) / delta < 0.15:
					var hs := Vector2(a.x - a0.x, a.z - a0.z).length()
					if hs / delta > 0.35:
						slide[st] = slide.get(st, 0.0) + hs
						if st == "Locomotion":
							var bk := "v%.1f%s" % [snappedf(p.get_flat_velocity().length(), 0.5), "B" if p.ball_control.has_ball() else ""]
							lb[bk] = lb.get(bk, 0.0) + hs
			if st == "Locomotion":
				var bk2 := "v%.1f%s" % [snappedf(p.get_flat_velocity().length(), 0.5), "B" if p.ball_control.has_ball() else ""]
				lbt[bk2] = lbt.get(bk2, 0.0) + delta
			slide_time[st] = slide_time.get(st, 0.0) + delta
		_prev[p] = {"hips_l": hips_l, "yaw_l": yaw_l, "yaw_w": yaw_w, "yaw_f": yaw_f, "ank": ank, "key": key, "pos": p.global_position, "roty": p.rotation.y}
	if _t >= SECONDS:
		_ys.sort()
		print("tornozelo (Locomotion) p5/p10/p25/p50: ", _ys[int(_ys.size()*0.05)], " ", _ys[int(_ys.size()*0.1)], " ", _ys[int(_ys.size()*0.25)], " ", _ys[int(_ys.size()*0.5)])
		print("== PÉ DESLIZANDO (cm por segundo no estado) ==")
		var rows := []
		for s in slide.keys():
			rows.append([slide[s] / maxf(slide_time[s], 0.01) * 100.0, s, slide_time[s]])
		rows.sort_custom(func(a, b): return a[0] > b[0])
		for r in rows:
			print("  %-22s %6.1f cm/s  (amostra %.0f s)" % [r[1], r[0], r[2]])
		var ks := lbt.keys()
		ks.sort()
		for k in ks:
			print("   Locomotion %-7s %6.1f cm/s (%.0f s)" % [k, lb.get(k, 0.0) / lbt[k] * 100.0, lbt[k]])
		print("== POSE PULANDO (transição -> contagem) ==")
		var pr2 := []
		for k in pops.keys():
			pr2.append([pops[k], k])
		pr2.sort_custom(func(a, b): return a[0] > b[0])
		for r in pr2.slice(0, 25):
			print("  %4d  %s" % [r[0], r[1]])
		for e in pop_examples:
			print("   ex: ", e)
		get_tree().quit()
