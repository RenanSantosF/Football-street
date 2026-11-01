extends Node3D
## Laboratório de chute: um jogador real (Player + física + animação) com a
## bola, repetindo passe curto, passe longo, chute e chute forte em sequência.
## Rode esta cena sozinha no editor ("Rodar cena atual").
## No PC: SHOT_DIR=... salva quadros em volta de cada contato.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const BALL_SCENE := preload("res://src/ball/ball.tscn")
const SEQUENCE: Array = [
	[PlayerIntent.Action.PASS, 0.2, "PASSE CURTO"],
	[PlayerIntent.Action.PASS, 0.8, "PASSE LONGO"],
	[PlayerIntent.Action.SHOOT, 0.4, "CHUTE"],
	[PlayerIntent.Action.SHOOT, 0.95, "CHUTE FORTE"],
]

var player: Player
var ball: Ball
var label: Label
var _step := -1
var _timer := 0.5
var _waiting_kick := false
var _frame := 0
var _shot_dir := OS.get_environment("SHOT_DIR")
var _shots_left := 0
var _shot_index := 0


func _ready() -> void:
	_build_world()
	ball = BALL_SCENE.instantiate()
	add_child(ball)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.appearance = CharacterAppearance.new()
	player.setup(null, ball)
	player.controller = self
	player.ball_touched.connect(_on_touch)
	_reset()


## Interface de controller (igual HumanInput/AIController).
## Fases: espera 1 s com a bola no pé → executa a ação → espera 1,6 s → repõe.
func fill_intent(_p: Player, intent: PlayerIntent, delta: float) -> void:
	intent.move = Vector3.ZERO
	_timer -= delta
	if _timer > 0.0:
		return
	if _waiting_kick:
		_waiting_kick = false
		_step = (_step + 1) % SEQUENCE.size()
		var s: Array = SEQUENCE[_step]
		label.text = s[2]
		intent.set_action(s[0], s[1], Vector3(1, 0, 0))
		_timer = 1.6
	else:
		_reset()


func _reset() -> void:
	player.teleport(Vector3(-0.45, 0, 0), Vector3(1, 0, 0))
	ball.in_play = true
	ball.place_at(Vector3(0.0, Ball.RADIUS, 0.0))
	ball.claim(player)
	_waiting_kick = true
	_timer = 1.0


func _on_touch(kind: StringName) -> void:
	if _shot_dir != "" and kind in [&"pass", &"shoot"]:
		_shots_left = 1
		_capture("contact_%d_%s" % [_shot_index, kind])
		_shot_index += 1


func _process(_delta: float) -> void:
	_frame += 1
	if _shot_dir != "" and _shot_index >= 4:
		get_tree().quit()


func _capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_dir + "/%s.png" % name_)


func _build_world() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.3, 1.1, 3.4)
	cam.fov = 45.0
	cam.look_at(Vector3(0.3, 0.6, 0.0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
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
	label.add_theme_font_size_override("font_size", 32)
	ui.add_child(label)
