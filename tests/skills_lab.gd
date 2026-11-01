extends Node3D
## Laboratório de dribles e defesa: um jogador conduz a bola, outro vem de
## carrinho. Às vezes quem conduz pula o carrinho, às vezes tropeça e cai.
## Na rodada do giro, quem conduz faz a roleta. Rode a cena sozinha no editor.
## No PC: SHOT_DIR=... salva quadros-chave e fecha.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const BALL_SCENE := preload("res://src/ball/ball.tscn")

var carrier: Player
var defender: Player
var ball: Ball
var label: Label
var _round := -1
var _t := 0.0
var _shot_dir := OS.get_environment("SHOT_DIR")
var _captured := {}


func _ready() -> void:
	_build_world()
	ball = BALL_SCENE.instantiate()
	add_child(ball)
	carrier = _spawn(Team.SHIRTS)
	defender = _spawn(Team.SKINS)
	if OS.get_environment("LAB_DEBUG") != "":
		defender.action_started.connect(func(k): print("r%d t=%.2f DEF %s dist=%.2f" % [_round, _t, k, defender.global_position.distance_to(carrier.global_position)]))
		carrier.action_started.connect(func(k): print("r%d t=%.2f CAR %s" % [_round, _t, k]))
		defender.ball_touched.connect(func(k): print("r%d t=%.2f DEF toque %s" % [_round, _t, k]))
	_next_round()


func _spawn(team: int) -> Player:
	var p := PLAYER_SCENE.instantiate() as Player
	add_child(p)
	p.team = team
	var a := CharacterAppearance.new()
	a.has_shirt = team == Team.SHIRTS
	a.shirt_color = Color(0.75, 0.15, 0.12)
	a.skin_color = Color(0.64, 0.44, 0.30) if team == Team.SHIRTS else Color(0.40, 0.26, 0.17)
	p.appearance = a
	p.setup(null, ball)
	p.controller = self
	return p


func _next_round() -> void:
	_round += 1
	_t = 0.0
	carrier.teleport(Vector3(-4.0, 0, 0), Vector3(1, 0, 0))
	defender.teleport(Vector3(1.5, 0, 0.3), Vector3(-1, 0, 0))
	ball.in_play = true
	ball.place_at(Vector3(-3.55, Ball.RADIUS, 0))
	ball.claim(carrier)
	# Rodada 0: força o pulo; 1: força o tropeço; 2: giro (roleta).
	var mode: String = ["jump", "trip", "spin"][_round % 3]
	carrier.set_meta("force", mode)
	carrier.debug_dodge_chance = 1.0 if mode == "jump" else 0.0
	defender.ball_control.debug_slide_trip = 1.0
	label.text = ["CARRINHO x PULO", "CARRINHO x QUEDA", "GIRO (ROLETA)"][_round % 3]


func fill_intent(p: Player, intent: PlayerIntent, _delta: float) -> void:
	var mode: String = carrier.get_meta("force", "")
	if p == carrier:
		intent.move = Vector3(1, 0, 0) if _t < 3.2 else Vector3.ZERO
		if mode == "spin" and _t > 0.9 and _t < 0.95:
			intent.set_action(PlayerIntent.Action.DRIBBLE, 1.0, Vector3(1, 0, 0))
	else:
		intent.move = Vector3.ZERO
		if mode != "spin" and _t > 0.55 and _t < 0.6:
			intent.set_action(PlayerIntent.Action.SHOOT, 0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _shot_dir != "":
		for at in [0.75, 1.0, 1.35, 1.9]:
			var key := "%d_%.2f" % [_round, at]
			if _t >= at and not _captured.has(key):
				_captured[key] = true
				_capture("skill_r%d_%.2f" % [_round, at])
	if _t > 4.0:
		if _shot_dir != "" and _round >= 2:
			get_tree().quit()
		_next_round()


func _capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_dir + "/%s.png" % name_)


func _build_world() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-1.0, 1.6, 5.2)
	cam.fov = 48.0
	cam.look_at(Vector3(-1.0, 0.6, 0.0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-45.0, 25.0, 0.0)
	sun.shadow_enabled = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.73, 0.7)
	add_child(env)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.3, 0.31)
	mi.material_override = m
	add_child(mi)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 30)
	ui.add_child(label)
