extends Node
## LABORATÓRIO VISUAL (precisa de tela/GPU; no servidor use Xvfb):
##   SCN=run xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/visual_lab.tscn --fixed-fps 60
## Roda o jogo de verdade, comanda o jogador e grava folhas de contato
## (várias capturas numa imagem) em user://visual_lab/<SCN>.png (ou OUT_DIR).
## Cenários (SCN): idle, run, sprint, dribble, curve, reverse, shield, tackle,
## kick, feet (close dos pés na corrida).
## VIEW=side|back|front|feet escolhe o enquadramento.

const MAIN := preload("res://src/main/main.tscn")
const CELL := Vector2i(640, 360)
const COLS := 3

var mm: MatchManager
var ball: Ball
var me: Player
var opp: Player
var cam: Camera3D
var f := 0
var scn := "run"
var view := "side"
var shots: Array[Image] = []
var labels: Array[String] = []
## Quadros (desde o início do cenário) em que captura.
var capture_at: Array[int] = []
var t0 := 90
var _head_w := Vector3.ZERO


func _on_skel() -> void:
	var sk: Skeleton3D = me.visual.skeleton
	_head_w = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin


func _ready() -> void:
	scn = OS.get_environment("SCN") if OS.get_environment("SCN") != "" else "run"
	view = OS.get_environment("VIEW") if OS.get_environment("VIEW") != "" else "side"
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")
	for c in main.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var ui := main.get_node_or_null("MobileUI")
	if ui is CanvasItem:
		(ui as CanvasItem).visible = false
	elif ui is CanvasLayer:
		(ui as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var every := int(OS.get_environment("EVERY")) if OS.get_environment("EVERY") != "" else 6
	var first := int(OS.get_environment("FIRST")) if OS.get_environment("FIRST") != "" else 60
	var count := int(OS.get_environment("COUNT")) if OS.get_environment("COUNT") != "" else 8
	for i in count:
		capture_at.append(first + i * every)


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		me = mm.controlled
		if me.visual.get("skeleton") != null:
			(me.visual.skeleton as Skeleton3D).skeleton_updated.connect(_on_skel)
		for p in mm.players:
			if p != me and p.team != me.team and opp == null:
				opp = p
		for p in mm.players:
			if p != me and p != opp:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0)
		if not scn in ["shield", "tackle", "duel", "slide", "slidewalk"]:
			opp.set_physics_process(false)
			opp.global_position = Vector3(0, -50, 0)
	if f < t0:
		return
	var t := f - t0
	if t == 0:
		_setup()
	_drive(t)


func _setup() -> void:
	mm.ball_out_system.cancel()
	mm.state = MatchManager.MatchState.PLAYING
	me.set_frozen(false)
	me.stamina = 1.0
	me.teleport(Vector3(-10, 0, 0), Vector3.RIGHT)
	ball.in_play = true
	ball.restricted_team = -1
	ball.restricted_player = null
	if scn in ["dribble", "curve", "reverse", "shield", "kick", "duel", "runpass", "heel"]:
		ball.place_at(Vector3(-9.6, Ball.RADIUS, 0))
		ball.claim(me)
		if scn == "heel":
			_mate_at(Vector3(-16.0, 0, 0.5))
	elif scn == "volley":
		ball.release()
		ball.place_at(Vector3(-13.0, 0.4, -3.6))
	else:
		ball.release()
		ball.place_at(Vector3(10, Ball.RADIUS, 3.0))
	if opp != null and scn in ["shield", "tackle", "duel", "slide", "slidewalk"]:
		opp.set_frozen(false)
		opp.controller = opp.ai
		if scn == "shield":
			opp.teleport(Vector3(-8.0, 0, 0.0), Vector3.LEFT)
		elif scn == "duel":
			opp.teleport(Vector3(-6.5, 0, 0.6), Vector3.LEFT)
		elif scn in ["slide", "slidewalk"]:
			var d0 := 7.0 if scn == "slide" else 3.2
			opp.teleport(Vector3(-10.0 + d0, 0, 0.0), Vector3.LEFT)
			ball.place_at(Vector3(-10.0 + d0 - 0.45, Ball.RADIUS, 0.05))
			ball.claim(opp)
			opp.controller = null
			opp.intent.move = Vector3.ZERO
		else:
			# o humano (me) vai dar o bote no adversário que conduz
			opp.teleport(Vector3(-8.0, 0, 0.0), Vector3.LEFT)
			ball.place_at(Vector3(-8.5, Ball.RADIUS, 0.08))
			ball.claim(opp)
			opp.controller = null # parado com a bola (para ver o bote)
			opp.intent.move = Vector3.ZERO


func _mate_at(pos: Vector3) -> void:
	for p in mm.players:
		if p != me and p.team == me.team:
			p.set_physics_process(true)
			p.set_frozen(false)
			p.teleport(pos, Vector3.RIGHT)
			return


func _drive(t: int) -> void:
	match scn:
		"idle":
			pass
		"run", "feet":
			if t == 1:
				Input.action_press("move_right", 0.6)
		"sprint":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
		"dribble":
			if t == 1:
				Input.action_press("move_right", 1.0)
		"curve":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
			if t == 50:
				Input.action_press("move_up", 1.0)
			if t == 75:
				Input.action_release("move_right")
		"brake":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
			if t == 70:
				Input.action_release("move_right")
				Input.action_release("sprint")
		"reverse":
			if t == 1:
				Input.action_press("move_right", 1.0)
				Input.action_press("sprint")
			if t == 60:
				Input.action_release("move_right")
				Input.action_press("move_left", 1.0)
		"shield":
			pass # parado com a bola; o adversário (IA) vem tomar
		"duel":
			if t == 1:
				Input.action_press("move_right", 0.7)
		"tackle":
			if t == 1:
				Input.action_press("move_right", 0.7)
			if t == 22:
				Input.action_release("move_right")
				Input.action_press("dribble")
			if t == 26:
				Input.action_release("dribble")
		"slide", "slidewalk":
			if t == 1:
				Input.action_press("move_right", 1.0 if scn == "slide" else 0.35)
				if scn == "slide":
					Input.action_press("sprint")
			var press_at := 75 if scn == "slide" else 30
			if t == press_at:
				Input.action_press("shoot")
			if t == press_at + 3:
				Input.action_release("shoot")
				Input.action_release("move_right")
				Input.action_release("sprint")
		"freekick":
			if t == 2:
				for p in mm.players:
					p.set_physics_process(true)
					p.set_frozen(false)
					p.teleport(mm.formation_position(p.team, p.formation_index), Vector3(Field.attack_sign(p.team), 0, 0))
					if p != me:
						p.controller = p.ai
				var gx := Field.goal_line_x(Team.other(me.team))
				var spot := Vector3(gx - Field.attack_sign(me.team) * 7.0, Ball.RADIUS, 1.5)
				ball.place_at(spot)
				mm.award_free_kick(me.team, spot)
		"runpass":
			if t == 1:
				Input.action_press("move_right", 1.0)
			if t == 50:
				Input.action_press("pass")
			if t == 53:
				Input.action_release("pass")
		"heel":
			if t == 20:
				Input.action_press("move_left", 1.0)
				Input.action_press("pass")
			if t == 24:
				Input.action_release("pass")
			if t == 30:
				Input.action_release("move_left")
		"volley":
			if t == 2:
				var from := ball.global_position
				var flat := Vector3(me.global_position.x - from.x, 0, me.global_position.z - from.z)
				var tt := flat.length() / 9.0
				var vy: float = (0.8 - from.y) / tt + 0.5 * 9.8 * tt
				var hv := flat.normalized() * 9.0
				ball.kick(Vector3(hv.x, vy, hv.z), Vector3.ZERO, null)
				ball.pass_target = me
				Input.action_press("shoot")
			if t == 6:
				Input.action_release("shoot")
		"kick":
			if t == 1:
				Input.action_press("move_right", 0.8)
			if t == 40:
				Input.action_press("shoot")
			if t == 52:
				Input.action_release("shoot")


func _process(_d: float) -> void:
	if me == null or f < t0:
		return
	var t := f - t0
	_place_camera()
	if OS.get_environment("STATEDBG") != "" and t % 6 == 0 and t >= 66:
		var cur := ""
		if me.anim_controller.playback != null:
			cur = String(me.anim_controller.playback.get_current_node())
		print("t=%d me st=%d act=%s anim=%s v=%.2f pos=%s | opp st=%d act=%s d=%.2f" % [t, me.state, me._action_kind, cur, me.get_horizontal_speed(), str(me.global_position.snapped(Vector3.ONE*0.01)), opp.state, opp._action_kind, me.global_position.distance_to(opp.global_position)])
	if OS.get_environment("LEANDBG") != "" and t % 4 == 0:
		var right := me.facing.cross(Vector3.UP)
		var acc: Vector3 = me.anim_controller._acc_vec
		print("t=%d v=%.2f acc_lat=%.2f acc_fwd=%.2f  cabeça-raiz: lat=%.3f fwd=%.3f  bal=%.2f" % [t, me.get_horizontal_speed(), acc.dot(right), acc.dot(me.facing), (_head_w - me.global_position).dot(right), (_head_w - me.global_position).dot(me.facing), me.balance])
	if capture_at.has(t) and labels.size() < capture_at.size() and not labels.has(str(t)):
		var img := get_viewport().get_texture().get_image()
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		shots.append(img)
		labels.append(str(t))
	if labels.size() >= capture_at.size():
		_save_sheet()
		get_tree().quit()


func _place_camera() -> void:
	var p := me.global_position
	var fwd := me.facing
	var right := fwd.cross(Vector3.UP)
	var look := p + Vector3.UP * 0.8
	var pos: Vector3
	match view:
		"back":
			pos = p - fwd * 3.4 + Vector3.UP * 1.3
		"front":
			pos = p + fwd * 3.4 + Vector3.UP * 1.1
		"feet":
			pos = p - right * 1.25 + Vector3.UP * 0.25
			look = p + Vector3.UP * 0.12
		"top":
			var bpt := ball.global_position
			pos = bpt + Vector3(-Field.attack_sign(me.team) * 5.5, 7.5, 6.0)
			look = bpt + Vector3(Field.attack_sign(me.team) * 3.0, 0, 0)
		"feetfront":
			pos = p + fwd * 1.2 + right * 0.4 + Vector3.UP * 0.3
			look = p + Vector3.UP * 0.12
		_:
			pos = p - right * 3.6 + Vector3.UP * 1.0
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.make_current()


func _save_sheet() -> void:
	var rows := int(ceil(shots.size() / float(COLS)))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
	var dir := OS.get_environment("OUT_DIR") if OS.get_environment("OUT_DIR") != "" else "user://visual_lab"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s_%s.png" % [dir, scn, view]
	sheet.save_png(path)
	print("folha salva: ", path, " quadros=", labels)
