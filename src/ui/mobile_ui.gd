class_name MobileUI
extends CanvasLayer
## Interface de celular: analógico, botões, placar animado, faixa de GOL,
## minimapa, mensagens e barra de força.

@export var human_input: HumanInput
@export var match_manager: MatchManager

@onready var message_label: Label = $Message
@onready var charge_bar: ProgressBar = $ChargeBar

var _message_timer := 0.0
var _score_labels: Array[Label] = []
var _scores: Array[int] = [0, 0]
var _banner: Control
var _banner_title: Label
var _banner_team: Label
var _minimap: Minimap
var _fps_label: Label
@onready var shoot_button: TouchButton = $ShootButton
@onready var pass_button: TouchButton = $PassButton
@onready var dribble_button: TouchButton = $DribbleButton
var _charge_kind: StringName = &""


func _ready() -> void:
	var old := get_node_or_null("Score")
	if old != null:
		old.queue_free()
	_build_scoreboard()
	_build_banner()
	_build_minimap()
	_build_fps()
	_show_hints()
	GameEvents.score_changed.connect(_on_score_changed)
	GameEvents.goal_scored.connect(_on_goal)
	GameEvents.match_message.connect(_on_message)
	if human_input != null:
		human_input.charge_changed.connect(_on_charge_changed)
	charge_bar.visible = false
	message_label.visible = false


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false
	if _minimap.match_manager == null and match_manager != null:
		_minimap.match_manager = match_manager
		_minimap.ball = match_manager.ball
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_update_button_labels()


## Os botões mudam de significado: com a bola / sem a bola.
func _update_button_labels() -> void:
	var with_ball := human_input == null or human_input.has_ball_context()
	if with_ball:
		shoot_button.set_label("CHUTE")
		shoot_button.alt_hint = "arraste: cavadinha"
		pass_button.set_label("PASSE")
		pass_button.alt_hint = "arraste: por cima"
		dribble_button.set_label("DRIBLE")
	else:
		shoot_button.set_label("CARRINHO")
		shoot_button.alt_hint = ""
		pass_button.set_label("TROCAR")
		pass_button.alt_hint = ""
		dribble_button.set_label("DESARME")


# --- Placar ------------------------------------------------------------------------

func _build_scoreboard() -> void:
	var panel := PanelContainer.new()
	panel.name = "ScoreBoard"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 10.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.82)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	for team in [Team.SHIRTS, Team.SKINS]:
		if team == Team.SKINS:
			var x := _label("x", 22, Color(1, 1, 1, 0.5))
			row.add_child(x)
		var strip := ColorRect.new()
		strip.color = Team.COLORS[team]
		strip.custom_minimum_size = Vector2(6, 34)
		var name_l := _label(Team.NAMES[team], 18, Color(1, 1, 1, 0.92))
		var score_l := _label("0", 34, Color.WHITE)
		score_l.custom_minimum_size = Vector2(36, 0)
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_l.pivot_offset = Vector2(18, 24)
		_score_labels.append(score_l)
		if team == Team.SHIRTS:
			row.add_child(strip)
			row.add_child(name_l)
			row.add_child(score_l)
		else:
			row.add_child(score_l)
			row.add_child(name_l)
			row.add_child(strip)


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_score_changed(a: int, b: int) -> void:
	var new_scores: Array[int] = [a, b]
	for i in 2:
		_score_labels[i].text = str(new_scores[i])
		if new_scores[i] != _scores[i]:
			_pop_score(_score_labels[i], Team.COLORS[i])
	_scores = new_scores


## Número do placar salta, brilha na cor do time e volta.
func _pop_score(l: Label, c: Color) -> void:
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.9, 1.9), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate", c.lightened(0.3), 0.18)
	tw.tween_property(l, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate", Color.WHITE, 0.9)


# --- Faixa de GOL ------------------------------------------------------------------

func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)
	var stripe := ColorRect.new()
	stripe.name = "Stripe"
	stripe.anchor_left = 0.0
	stripe.anchor_right = 1.0
	stripe.anchor_top = 0.36
	stripe.anchor_bottom = 0.56
	stripe.color = Color(0, 0, 0, 0.55)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(stripe)
	_banner_title = _label("GOOOL!", 78, Color(1.0, 0.86, 0.25))
	_banner_title.add_theme_constant_override("outline_size", 12)
	_banner_title.set_anchors_preset(Control.PRESET_CENTER)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner_title.offset_top = -95
	_banner_title.offset_bottom = -5
	_banner.add_child(_banner_title)
	_banner_team = _label("", 26, Color.WHITE)
	_banner_team.set_anchors_preset(Control.PRESET_CENTER)
	_banner_team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_team.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_team.offset_top = -10
	_banner_team.offset_bottom = 30
	_banner.add_child(_banner_team)


func _on_goal(team: int, _scorer: Node) -> void:
	_banner_team.text = Team.NAMES[team]
	_banner_team.add_theme_color_override("font_color", Team.COLORS[team].lightened(0.25))
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	_banner_title.pivot_offset = _banner_title.size * 0.5
	_banner_title.scale = Vector2(0.2, 0.2)
	_banner_title.rotation = -0.15
	var tw := create_tween()
	tw.tween_property(_banner, "modulate", Color.WHITE, 0.15)
	tw.parallel().tween_property(_banner_title, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_banner_title, "rotation", 0.04, 0.35)
	tw.tween_property(_banner_title, "scale", Vector2.ONE, 0.25)
	tw.parallel().tween_property(_banner_title, "rotation", 0.0, 0.25)
	# pulsa algumas vezes
	for i in 3:
		tw.tween_property(_banner_title, "scale", Vector2(1.08, 1.08), 0.22)
		tw.tween_property(_banner_title, "scale", Vector2.ONE, 0.22)
	tw.tween_interval(0.6)
	tw.tween_property(_banner, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(func(): _banner.visible = false)


# --- Minimapa / mensagens -------------------------------------------------------------

func _build_minimap() -> void:
	_minimap = Minimap.new()
	# Embaixo, no meio.
	_minimap.anchor_left = 0.5
	_minimap.anchor_right = 0.5
	_minimap.anchor_top = 1.0
	_minimap.anchor_bottom = 1.0
	_minimap.offset_left = -125
	_minimap.offset_right = 125
	_minimap.offset_top = -112
	_minimap.offset_bottom = -10
	add_child(_minimap)


## Dica rápida dos controles no começo da partida.
func _show_hints() -> void:
	var l := _label("Segure CHUTE e use o analógico para MIRAR  •  Arraste PASSE: toque por cima\nArraste CHUTE: cavadinha  •  Sem a bola: CARRINHO, TROCAR e DESARME", 18, Color(1, 1, 1, 0.95))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = 70
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate", Color(1, 1, 1, 0), 1.0)
	tw.tween_callback(l.queue_free)


func _build_fps() -> void:
	_fps_label = _label("60 FPS", 16, Color(1, 1, 1, 0.8))
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -110
	_fps_label.offset_right = -14
	_fps_label.offset_top = 8
	_fps_label.offset_bottom = 30
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fps_label)


func _on_message(text: String, duration: float) -> void:
	message_label.text = text
	message_label.visible = true
	_message_timer = duration


## Força do passe/chute: anel em volta do próprio botão.
func _on_charge_changed(value: float, kind: StringName) -> void:
	charge_bar.visible = false
	shoot_button.charge = value if kind == &"shoot" else 0.0
	pass_button.charge = value if kind == &"pass" else 0.0
