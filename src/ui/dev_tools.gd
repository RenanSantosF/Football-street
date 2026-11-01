class_name DevTools
extends CanvasLayer
## Ferramentas dentro do jogo (botão ⚙):
##  - Movimento: gráfico de velocidade e distância da bola, estado de animação,
##    toques por segundo, câmera lenta
##  - Controle: analógico/mira ao vivo, botões, força, atraso aperto→ação
##  - Personagem: ajuste ao vivo de velocidades/aceleração/giro + laboratórios
##  - Mundo: hora do dia, sol, câmera, resolução 3D, sombras, pedestres
## Os ajustes ficam salvos em user://dev_tools.cfg.

const SAVE_PATH := "user://dev_tools.cfg"
const GRAPH_SAMPLES := 180

@export var match_manager: MatchManager
@export var human_input: HumanInput
@export var camera: MatchCamera
@export var sun: DirectionalLight3D
@export var pedestrians: Node3D

var _panel: PanelContainer
var _toggle: Button
var _tabs: TabContainer
var _info: Label
var _graph: Control
var _ctrl_view: Control
var _ctrl_info: Label
var _speed_hist: Array[float] = []
var _dist_hist: Array[float] = []
var _touches: Array[float] = []
var _press_time := -1.0
var _last_latency := 0.0
var _cfg := ConfigFile.new()
var _sliders := {}


func _ready() -> void:
	layer = 20
	_cfg.load(SAVE_PATH)
	_build()
	_panel.visible = false
	call_deferred("_apply_saved")


func _build() -> void:
	_toggle = Button.new()
	_toggle.text = "⚙"
	_toggle.add_theme_font_size_override("font_size", 22)
	_toggle.anchor_left = 1.0
	_toggle.anchor_right = 1.0
	_toggle.offset_left = -62
	_toggle.offset_right = -14
	_toggle.offset_top = 34
	_toggle.offset_bottom = 74
	_toggle.flat = false
	_toggle.pressed.connect(func(): _panel.visible = not _panel.visible)
	add_child(_toggle)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_top = 70
	_panel.offset_bottom = 560
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.9)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_tabs = TabContainer.new()
	_panel.add_child(_tabs)
	_tabs.add_child(_tab_movement())
	_tabs.add_child(_tab_control())
	_tabs.add_child(_tab_character())
	_tabs.add_child(_tab_world())


func _tab_movement() -> Control:
	var v := VBoxContainer.new()
	v.name = "Movimento"
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 15)
	v.add_child(_info)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(620, 150)
	_graph.draw.connect(_draw_graph)
	v.add_child(_graph)
	var row := HBoxContainer.new()
	for sp in [0.25, 0.5, 1.0]:
		var b := Button.new()
		b.text = "Velocidade %sx" % str(sp)
		b.pressed.connect(func(): Engine.time_scale = sp)
		row.add_child(b)
	v.add_child(row)
	return v


func _tab_control() -> Control:
	var v := VBoxContainer.new()
	v.name = "Controle"
	_ctrl_view = Control.new()
	_ctrl_view.custom_minimum_size = Vector2(620, 200)
	_ctrl_view.draw.connect(_draw_control)
	v.add_child(_ctrl_view)
	_ctrl_info = Label.new()
	_ctrl_info.add_theme_font_size_override("font_size", 15)
	v.add_child(_ctrl_info)
	return v


func _tab_character() -> Control:
	var v := VBoxContainer.new()
	v.name = "Personagem"
	_add_slider(v, "player/jog_speed", "Trote (m/s)", 2.5, 5.5, 3.9, func(x): _for_players("jog_speed", x))
	_add_slider(v, "player/sprint_speed", "Sprint (m/s)", 4.0, 7.5, 5.6, func(x): _for_players("sprint_speed", x))
	_add_slider(v, "player/acceleration", "Aceleração", 3.0, 14.0, 7.5, func(x): _for_players("acceleration", x))
	_add_slider(v, "player/deceleration", "Freada", 4.0, 18.0, 10.0, func(x): _for_players("deceleration", x))
	_add_slider(v, "player/turn_speed", "Giro (rad/s)", 3.0, 14.0, 7.5, func(x): _for_players("turn_speed", x))
	var row := HBoxContainer.new()
	for spec in [["Lab. personagens", "res://tests/character_lab.tscn"], ["Lab. chute", "res://tests/kick_lab.tscn"], ["Lab. dribles", "res://tests/skills_lab.tscn"]]:
		var b := Button.new()
		b.text = spec[0]
		var path: String = spec[1]
		b.pressed.connect(func(): Engine.time_scale = 1.0; get_tree().change_scene_to_file(path))
		row.add_child(b)
	v.add_child(row)
	return v


func _tab_world() -> Control:
	var v := VBoxContainer.new()
	v.name = "Mundo"
	_add_slider(v, "world/hour", "Hora do dia", 7.0, 18.0, 15.0, _set_hour)
	_add_slider(v, "world/sun", "Sol (intensidade)", 0.5, 2.5, 1.7, func(x): if sun: sun.light_energy = x)
	_add_slider(v, "camera/height", "Câmera altura", 2.5, 9.0, 4.6, func(x): if camera: camera.height = x)
	_add_slider(v, "camera/distance", "Câmera distância", 3.5, 12.0, 6.4, func(x): if camera: camera.distance = x)
	_add_slider(v, "camera/fov", "Câmera campo de visão", 35.0, 75.0, 52.0, func(x): if camera: camera.fov = x)
	_add_slider(v, "render/scale", "Resolução 3D", 0.5, 1.0, 0.85, func(x): get_viewport().scaling_3d_scale = x)
	var row := HBoxContainer.new()
	var shadows := CheckBox.new()
	shadows.text = "Sombras"
	shadows.button_pressed = _cfg.get_value("world", "shadows", true)
	shadows.toggled.connect(func(on): if sun: sun.shadow_enabled = on; _cfg.set_value("world", "shadows", on); _cfg.save(SAVE_PATH))
	row.add_child(shadows)
	var peds := CheckBox.new()
	peds.text = "Pedestres"
	peds.button_pressed = _cfg.get_value("world", "pedestrians", true)
	peds.toggled.connect(func(on): if pedestrians: pedestrians.visible = on; pedestrians.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED; _cfg.set_value("world", "pedestrians", on); _cfg.save(SAVE_PATH))
	row.add_child(peds)
	v.add_child(row)
	return v


func _add_slider(parent: Control, key: String, text: String, lo: float, hi: float, def: float, apply: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_font_size_override("font_size", 15)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.custom_minimum_size = Vector2(380, 30)
	s.value = _cfg.get_value("tune", key, def)
	l.text = "%s: %.2f" % [text, s.value]
	s.value_changed.connect(func(x):
		l.text = "%s: %.2f" % [text, x]
		apply.call(x)
		_cfg.set_value("tune", key, x)
		_cfg.save(SAVE_PATH))
	row.add_child(s)
	parent.add_child(row)
	_sliders[key] = [s, apply]


func _apply_saved() -> void:
	for key in _sliders:
		var s: HSlider = _sliders[key][0]
		(_sliders[key][1] as Callable).call(s.value)
	if sun:
		sun.shadow_enabled = _cfg.get_value("world", "shadows", true)
	if pedestrians:
		var on: bool = _cfg.get_value("world", "pedestrians", true)
		pedestrians.visible = on
		pedestrians.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _for_players(prop: String, value: float) -> void:
	if match_manager == null:
		return
	for p in match_manager.players:
		p.set(prop, value)


## Hora do dia: gira o sol (nascente a leste, poente a oeste).
func _set_hour(h: float) -> void:
	if sun == null:
		return
	var t := clampf((h - 6.0) / 12.0, 0.0, 1.0)   # 6h → 0, 18h → 1
	var elevation := sin(t * PI) * deg_to_rad(70.0) + deg_to_rad(8.0)
	var azimuth := lerpf(deg_to_rad(-80.0), deg_to_rad(80.0), t)
	var dir := Vector3(sin(azimuth) * cos(elevation), -sin(elevation), -cos(azimuth) * cos(elevation) * 0.6 + 0.4).normalized()
	sun.look_at(sun.global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	var warm := 1.0 - sin(t * PI)
	sun.light_color = Color(1.0, 0.95 - warm * 0.25, 0.88 - warm * 0.4)


func _process(delta: float) -> void:
	_track_input()
	if not _panel.visible or match_manager == null:
		return
	var p := match_manager.controlled
	if p == null:
		return
	_speed_hist.append(p.get_horizontal_speed())
	_dist_hist.append(p.ball_control.ball_distance() if p.ball_control.has_ball() else 0.0)
	if _speed_hist.size() > GRAPH_SAMPLES:
		_speed_hist.pop_front()
		_dist_hist.pop_front()
	var now := Time.get_ticks_msec() / 1000.0
	while not _touches.is_empty() and now - _touches[0] > 2.0:
		_touches.pop_front()
	var ac := p.anim_controller
	var anim := String(ac.playback.get_current_node()) if ac.is_active() else "-"
	_info.text = "Jogador: %s | estado: %s | animação: %s\nvelocidade %.2f m/s | passada x%.2f | bola %.2f m | toques/s %.1f | estamina %.0f%%\nmarcando: %s | travado (reinício): %s | FPS %d" % [
		p.name, ["MOVE", "AÇÃO", "DESEQUILÍBRIO", "PARADO"][p.state], anim,
		p.get_horizontal_speed(), p.get_horizontal_speed() / maxf(p.visual.call("get_locomotion_scale") if p.visual.has_method("get_locomotion_scale") else 1.0, 0.01),
		p.ball_control.ball_distance(), _touches.size() / 2.0, p.stamina * 100.0,
		p.is_marking(), p.is_restart_locked(), Engine.get_frames_per_second()]
	_graph.queue_redraw()
	_ctrl_view.queue_redraw()
	if not p.ball_touched.is_connected(_on_touch):
		p.ball_touched.connect(_on_touch)
		p.action_started.connect(_on_action)


func _on_touch(_kind: StringName) -> void:
	_touches.append(Time.get_ticks_msec() / 1000.0)


func _on_action(_kind: StringName) -> void:
	if _press_time >= 0.0:
		_last_latency = Time.get_ticks_msec() / 1000.0 - _press_time
		_press_time = -1.0


func _track_input() -> void:
	for a in ["pass", "shoot", "dribble"]:
		if Input.is_action_just_released(a) or (a == "dribble" and Input.is_action_just_pressed(a)):
			_press_time = Time.get_ticks_msec() / 1000.0


func _draw_graph() -> void:
	var r := Rect2(Vector2.ZERO, _graph.size)
	_graph.draw_rect(r, Color(1, 1, 1, 0.05))
	for i in 7:
		var y := r.size.y - i / 7.0 * r.size.y
		_graph.draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(1, 1, 1, 0.07))
	_plot(_speed_hist, 7.0, Color(0.3, 0.9, 0.4))
	_plot(_dist_hist, 2.0, Color(1.0, 0.75, 0.2))
	_graph.draw_string(get_theme_default_font_safe(), Vector2(6, 16), "velocidade (0–7 m/s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.9, 0.4))
	_graph.draw_string(get_theme_default_font_safe(), Vector2(200, 16), "distância da bola (0–2 m)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.75, 0.2))


func _plot(data: Array[float], max_v: float, c: Color) -> void:
	if data.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in data.size():
		pts.append(Vector2(i / float(GRAPH_SAMPLES) * _graph.size.x, _graph.size.y - clampf(data[i] / max_v, 0.0, 1.0) * _graph.size.y))
	_graph.draw_polyline(pts, c, 2.0)


func _draw_control() -> void:
	var c := Vector2(110, 100)
	_ctrl_view.draw_circle(c, 80, Color(1, 1, 1, 0.08))
	_ctrl_view.draw_arc(c, 80, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_ctrl_view.draw_circle(c + v * 80.0, 12, Color(0.3, 0.8, 1.0))
	var font := get_theme_default_font_safe()
	var y := 30.0
	for a in ["pass", "shoot", "dribble", "sprint", "pass_lob", "shoot_chip"]:
		var on := Input.is_action_pressed(a)
		_ctrl_view.draw_string(font, Vector2(240, y), "%s: %s" % [a, "■" if on else "□"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.4) if on else Color(1, 1, 1, 0.6))
		y += 26.0
	var ctx := "com a bola" if human_input == null or human_input.has_ball_context() else "sem a bola"
	_ctrl_info.text = "contexto dos botões: %s | analógico (%.2f, %.2f) | atraso do último aperto → ação: %d ms" % [ctx, v.x, v.y, int(_last_latency * 1000.0)]


func get_theme_default_font_safe() -> Font:
	return ThemeDB.fallback_font


## Botão "voltar ao jogo" para os laboratórios.
static func add_back_button(owner_node: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	var b := Button.new()
	b.text = "⟵ Voltar ao jogo"
	b.add_theme_font_size_override("font_size", 20)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -240
	b.offset_right = -14
	b.offset_top = 14
	b.offset_bottom = 58
	b.pressed.connect(func(): owner_node.get_tree().change_scene_to_file("res://src/main/main.tscn"))
	layer.add_child(b)
	owner_node.add_child(layer)
