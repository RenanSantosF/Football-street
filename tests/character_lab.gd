extends Node3D
## Laboratório de personagens: vários adolescentes com aparências diferentes,
## cada um numa velocidade de locomoção (parado → andando → trotando → correndo).
## Rode esta cena sozinha (abrir a cena e tocar em "Rodar cena atual").
## Variável de ambiente SHOT_DIR (só no PC): salva capturas e fecha.

const SPEEDS: Array[float] = [0.0, 1.2, 3.0, 4.6, 6.6, 0.0]

var _chars: Array[HumanoidCharacter] = []
var _frame := 0
var _shot_dir := OS.get_environment("SHOT_DIR")
var _time := 0.0


func _ready() -> void:
	if OS.get_environment("SHOT_DIR") == "":
		DevTools.add_back_button(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in SPEEDS.size():
		var c := HumanoidCharacter.new()
		add_child(c)
		c.position = Vector3((i - (SPEEDS.size() - 1) * 0.5) * 0.9, 0.0, 0.0)
		c.rotation.y = PI # olhando para a câmera
		var team := Team.SHIRTS if i % 2 == 0 else Team.SKINS
		var a := CharacterAppearance.random_for_team(team, rng)
		a.hair_style = i % 5
		c.scale = Vector3.ONE * a.height_scale
		c.apply_appearance(a, team, Player.Role.FIELD)
		_chars.append(c)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.25, 4.6)
	cam.fov = 48.0
	cam.look_at(Vector3(0.0, 0.9, 0.0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	sun.shadow_enabled = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.78, 0.74)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 8)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.3, 0.3)
	floor_mi.material_override = fm
	add_child(floor_mi)


func _process(delta: float) -> void:
	_time += delta
	_frame += 1
	for i in _chars.size():
		var t := _chars[i].anim_tree
		if t == null:
			continue
		var stride := SPEEDS[i] / _chars[i].get_locomotion_scale()
		t.set("parameters/Locomotion/Speed/blend_position", stride)
		var top: float = AnimationCatalog.LOCOMOTION_SPEEDS[&"sprint"]
		t.set("parameters/Locomotion/Scale/scale", stride / top if stride > top else 1.0)
	# O último demonstra uma reação (desequilíbrio) a cada 2,5 s.
	if _chars[-1].anim_tree != null and fmod(_time, 2.5) < delta:
		var pb := _chars[-1].anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		pb.travel(&"Stumble")
	if _shot_dir != "" and _frame in [30, 45, 60]:
		get_viewport().get_texture().get_image().save_png(_shot_dir + "/lab_%d.png" % _frame)
	if _shot_dir != "" and _frame > 60:
		get_tree().quit()
