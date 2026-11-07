extends Node3D
## VISUALIZADOR DE CLIPES (precisa de tela/GPU; no servidor use Xvfb):
##   CLIPS="stand_tackle,stand_tackle_b" xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/clip_viewer.tscn
## Toca cada nome lógico do AnimationCatalog no personagem (com a postura e a
## pele do jogo) e salva uma linha de quadros por clipe em OUT_DIR/clips.png.
## Serve para conferir qualidade/compatibilidade antes de usar um clipe.

const CELL := Vector2i(320, 360)
const COLS := 6

var ch: HumanoidCharacter
var ap: AnimationPlayer
var cam: Camera3D
var clips: Array[String] = []
var rows: Array = []


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.5, 0.45)
	ground.material_override = gm
	add_child(ground)
	ch = HumanoidCharacter.new()
	add_child(ch)
	ch.apply_appearance(CharacterAppearance.new(), Team.SHIRTS, 0)
	ch.anim_tree.active = false
	ap = AnimationPlayer.new()
	ch.model.add_child(ap)
	ap.root_node = NodePath("..")
	var libs := AnimationCatalog.get_libraries()
	for prefix in libs:
		ap.add_animation_library(prefix, libs[prefix])
	ap.mixer_applied.connect(ch.lean.notify_animation_applied)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	var side := OS.get_environment("SIDE") != ""
	cam.global_position = Vector3(3.4, 1.0, 0.0) if side else Vector3(1.6, 1.1, -3.2)
	cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)
	cam.make_current()
	for c in OS.get_environment("CLIPS").split(",", false):
		clips.append(c.strip_edges())
	_run()


func _run() -> void:
	for logical in clips:
		var row: Array[Image] = []
		if not AnimationCatalog.has_clip(StringName(logical)):
			print("sem clipe: ", logical)
			continue
		var name := String(AnimationCatalog.clip(StringName(logical)))
		var length := ap.get_animation(name).length
		ap.play(name)
		for i in COLS:
			var t := length * (0.04 + 0.92 * i / float(COLS - 1))
			ap.seek(t, true)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var crop := img.get_region(Rect2i(img.get_width() / 2 - img.get_height() * 4 / 9, 0, img.get_height() * 8 / 9, img.get_height()))
			crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			row.append(crop)
		print(logical, " = ", name, " (", snappedf(length, 0.01), " s)")
		rows.append(row)
	if rows.is_empty():
		get_tree().quit()
		return
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows.size(), false, (rows[0][0] as Image).get_format())
	for r in rows.size():
		for c in COLS:
			sheet.blit_rect(rows[r][c], Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
	var dir := OS.get_environment("OUT_DIR") if OS.get_environment("OUT_DIR") != "" else "user://clip_viewer"
	DirAccess.make_dir_recursive_absolute(dir)
	sheet.save_png(dir + "/clips.png")
	print("folha salva: ", dir, "/clips.png")
	get_tree().quit()
