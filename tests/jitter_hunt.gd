extends Node
## Caça TREMOR e PISCADAS numa partida IA x IA (rodar no PC):
##   godot --headless --path . res://tests/jitter_hunt.tscn --fixed-fps 60
## Por jogador e por quadro, na pose FINAL do esqueleto:
##  - tremor: o tornozelo (relativo ao corpo) faz "zigue-zague" — a aceleração
##    troca de sentido em quadros seguidos com amplitude > 4 mm (movimento suave
##    não faz isso a 60 quadros/s);
##  - mão tremendo (mesmo critério);
##  - giro do corpo piscando (a velocidade de giro troca de sentido > 2 rad/s);
##  - estado da animação piscando (A → B → A em < 0,3 s);
##  - proteção automática ligando/desligando em < 0,3 s.
## Imprime totais por segundo e os contextos mais frequentes.
const MAIN := preload("res://src/main/main.tscn")
const SECONDS := 90.0
var _mm: MatchManager
var _time := 0.0
var _hist := {}
var _ctx := {}
var _ctx_t := {}
var _tot := {"pe": 0, "mao": 0, "giro": 0, "anim": 0, "protecao": 0, "corpo": 0, "pe_mundo": 0, "pe_cru": 0}


func _ready() -> void:
	process_priority = 100
	var main := MAIN.instantiate()
	_mm = main.get_node("MatchManager")
	_mm.autoplay = true
	_mm.match_seed = 777
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			_mm.match_seed = int(a.substr(7))
	add_child(main)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time < 1.0:
		return
	if _time > SECONDS:
		var dur := SECONDS - 1.0
		var out := {}
		for k in _tot:
			out[k + "_por_s"] = snappedf(_tot[k] / dur, 0.01)
		print("TREMOR/PISCADA (eventos por segundo, todos os jogadores): ", out)
		var keys := _ctx.keys()
		keys.sort_custom(func(a, b): return _ctx[a] > _ctx[b])
		for i in mini(keys.size(), 25):
			var c: String = keys[i].split(" | ", true, 1)[1]
			var tt: float = _ctx_t.get(c.split(" foot=")[0], 0.0)
			print("  ", _ctx[keys[i]], "x  (%.1f/s em %.0f s de jogador)  " % [_ctx[keys[i]] / maxf(tt, 0.01), tt], keys[i])
		get_tree().quit()
		return
	for p: Player in _mm.players:
		if not p.visible or not p.is_physics_processing():
			continue
		var h: Dictionary = _hist.get(p, {})
		var vis = p.visual
		var root := p.global_position
		var basis := Basis.looking_at(-p.facing, Vector3.UP) if p.facing.length() > 0.1 else Basis.IDENTITY
		var inv := basis.inverse() if OS.get_environment("WORLD") == "" else Basis.IDENTITY
		var sk: Skeleton3D = vis.skeleton
		var cur := String(p.anim_controller.playback.get_current_node()) if p.anim_controller.playback else ""
		var band := "lento" if p.get_horizontal_speed() < 0.6 else ("medio" if p.get_horizontal_speed() < 1.8 else "rapido")
		var ctx := "%s/%s anim=%s[%s] bola=%s prot=%s v=%.1f" % [Player.State.keys()[p.state], p._action_kind if p.state == Player.State.ACTION else "-", cur, band,
			"s" if p.ball_control.has_ball() else "n", "s" if p.is_shielding() else "n", p.get_horizontal_speed()]
		var base_ctx := ctx.split(" v=")[0]
		_ctx_t[base_ctx] = _ctx_t.get(base_ctx, 0.0) + delta
		for s in [1.0, -1.0]:
			var a: Vector3 = inv * (vis.get_ankle_position(s) - root)
			_zig(h, "pe%d" % int(s), a, 0.004, "pe", ctx + " foot=%s/%s" % [p.ball_control.foot.phase, p.ball_control.foot.mode])
			var hb := sk.find_bone("RightHand" if s > 0.0 else "LeftHand")
			if hb >= 0:
				var hp: Vector3 = inv * (sk.global_transform * sk.get_bone_global_pose(hb).origin - root)
				_zig(h, "mao%d" % int(s), hp, 0.006, "mao", ctx)
		if OS.get_environment("MK2") != "" and p.is_marking() and cur == "Mark" and _mk2 < 60 and _time > 20.0:
			var acx = p.anim_controller
			var ra: Vector3 = vis.get_raw_ankle_position(1.0) - root
			_mk2 += 1
			print("MK2 ", p.name, " f=", Engine.get_physics_frames(), " mp=", acx._mark_pos.snapped(Vector2.ONE * 0.01), " ts=", snappedf(acx._mark_cycle_mult(acx._mark_pos), 0.001), " raw_r=", ra.snapped(Vector3.ONE * 0.001), " fac=", p.facing.snapped(Vector3.ONE * 0.01))
		var hist: Array = h.get("rh", [])
		hist.append([root, p.velocity, p.intent.move, p._contact_time])
		if hist.size() > 4:
			hist.pop_front()
		h["rh"] = hist
		var before: int = _tot["corpo"]
		_zig(h, "root", root, 0.002, "corpo", ctx)
		if OS.get_environment("RDBG") != "" and _tot["corpo"] > before and _rdump < 30 and hist.size() == 4:
			_rdump += 1
			var line := "ROOT %s %s |" % [p.name, ctx]
			for i in range(1, 4):
				var dp: Vector3 = (hist[i][0] - hist[i - 1][0]) * 60.0
				line += " dp=%s v=%s in=%s ct=%.2f |" % [dp.snapped(Vector3.ONE * 0.01), Vector3(hist[i][1]).snapped(Vector3.ONE * 0.01), Vector3(hist[i][2]).snapped(Vector3.ONE * 0.01), hist[i][3]]
			print(line)
		for s2 in [1.0, -1.0]:
			_zig(h, "pew%d" % int(s2), vis.get_ankle_position(s2), 0.004, "pe_mundo", ctx)
			_zig(h, "per%d" % int(s2), vis.get_raw_ankle_position(s2), 0.004, "pe_cru", ctx)
		# giro do corpo
		var yaw := atan2(p.facing.x, p.facing.z)
		if h.has("yaw"):
			var w := wrapf(yaw - float(h["yaw"]), -PI, PI) / delta
			if h.has("w") and signf(w) != signf(float(h["w"])) and absf(w) > 2.0 and absf(float(h["w"])) > 2.0:
				_hit("giro", ctx)
			h["w"] = w
		h["yaw"] = yaw
		# estado da animação
		if h.has("anim") and h["anim"] != cur:
			if h.has("anim_prev") and h["anim_prev"] == cur and _time - float(h["anim_t"]) < 0.3:
				_hit("anim", "%s -> %s -> %s | %s" % [cur, h["anim"], cur, ctx])
			h["anim_prev"] = h["anim"]
			h["anim_t"] = _time
		h["anim"] = cur
		# proteção automática
		var sh := p.is_shielding()
		if h.has("sh") and h["sh"] != sh:
			if h.has("sh_t") and _time - float(h["sh_t"]) < 0.3:
				_hit("protecao", ctx)
			h["sh_t"] = _time
		h["sh"] = sh
		_hist[p] = h


func _zig(h: Dictionary, key: String, pos: Vector3, thr: float, kind: String, ctx: String) -> void:
	var k1 := key + "_1"
	var k2 := key + "_2"
	var kd := key + "_d"
	if h.has(k1) and h.has(k2):
		var d2: Vector3 = pos - 2.0 * Vector3(h[k1]) + Vector3(h[k2])
		if h.has(kd):
			var prev: Vector3 = h[kd]
			if d2.dot(prev) < 0.0 and d2.length() > thr and prev.length() > thr:
				_hit(kind, ctx)
		h[kd] = d2
	if h.has(k1):
		h[k2] = h[k1]
	h[k1] = pos


var _dumped := 0
var _rdump := 0
var _mk2 := 0
func _hit(kind: String, ctx: String) -> void:
	_tot[kind] += 1
	if OS.get_environment("MDBG") != "" and kind == "pe" and ctx.contains("anim=Mark") and _dumped < 40:
		_dumped += 1
		for p: Player in _mm.players:
			if p.is_marking():
				var ac = p.anim_controller
				print("MK ", p.name, " t=", snappedf(_time, 0.01), " mark_pos=", ac._mark_pos.snapped(Vector2.ONE * 0.01), " v=", p.get_flat_velocity().snapped(Vector3.ONE * 0.01), " fac=", p.facing.snapped(Vector3.ONE * 0.01), " intent=", p.intent.move.snapped(Vector3.ONE * 0.01), " ts=", snappedf(ac._mark_cycle_mult(ac._mark_pos), 0.01))
	var key := kind + " | " + ctx.split(" v=")[0]
	_ctx[key] = _ctx.get(key, 0) + 1
