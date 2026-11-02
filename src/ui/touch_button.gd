class_name TouchButton
extends Control
## Botão redondo de toque (multitoque), com:
##  - rótulo que muda conforme o contexto (com/sem a bola), definido pela UI
##  - ARRASTAR o dedo além de um limite aciona a ação alternativa
##    (ex.: passe arrastado = passe por cima; chute arrastado = cavadinha)
##  - anel de força em volta (charge 0..1) e animação ao apertar

@export var action: StringName = &"shoot"
@export var alt_action: StringName = &""
@export var label := "CHUTE"
@export var color := Color(0.9, 0.3, 0.25)
@export var font_size := 22
## Distância (px) de arraste para acionar a ação alternativa.
@export var drag_threshold := 38.0

var charge := 0.0:
	set(v):
		charge = v
		queue_redraw()
var alt_hint := "":
	set(v):
		if v != alt_hint:
			alt_hint = v
			queue_redraw()

var _touch_index := -1
var _press_pos := Vector2.ZERO
var _alt_on := false
var _press_anim := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_label(text: String) -> void:
	if text != label:
		label = text
		queue_redraw()


func _process(delta: float) -> void:
	var target := 1.0 if _touch_index != -1 else 0.0
	var prev := _press_anim
	_press_anim = move_toward(_press_anim, target, delta * 10.0)
	if prev != _press_anim:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local := make_input_local(event) as InputEventScreenTouch
		if event.pressed and _touch_index == -1 and _hit(local.position):
			_touch_index = event.index
			_press_pos = local.position
			_alt_on = false
			Input.action_press(action)
			queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var local_drag := make_input_local(event) as InputEventScreenDrag
		if alt_action != &"" and not _alt_on and local_drag.position.distance_to(_press_pos) > drag_threshold:
			_alt_on = true
			Input.action_press(alt_action)
			queue_redraw()


func _release() -> void:
	_touch_index = -1
	Input.action_release(action)
	if _alt_on:
		# A ação alternativa fica "pressionada" até o próximo quadro de física,
		# para quem lê o soltar do botão principal saber que foi arrastado.
		get_tree().create_timer(0.06, true, true).timeout.connect(func(): Input.action_release(alt_action))
	_alt_on = false
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) * 0.5


func _hit(p: Vector2) -> bool:
	return p.distance_to(size * 0.5) <= _radius() * 1.15


func _draw() -> void:
	var c := size * 0.5
	var r := _radius() * (1.0 - 0.06 * _press_anim)
	# Sombra, corpo com "gradiente" (anéis concêntricos) e brilho no topo.
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.25))
	var base := Color(color.r, color.g, color.b, 0.55 + 0.25 * _press_anim)
	draw_circle(c, r, base.darkened(0.25))
	draw_circle(c, r * 0.9, base)
	draw_circle(c - Vector2(0, r * 0.25), r * 0.55, Color(1, 1, 1, 0.08))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)
	if _alt_on:
		draw_arc(c, r + 4.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 3.0, true)
	# Anel de força.
	if charge > 0.0:
		var col := Color(1.0, lerpf(0.9, 0.25, charge), 0.15, 0.95)
		draw_arc(c, r + 9.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, col, 10.0, true)
	var font := get_theme_default_font()
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string_outline(font, Vector2(0.0, c.y + ts.y * 0.28), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(0.0, c.y + ts.y * 0.28), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(1, 1, 1, 0.95))
	if alt_hint != "":
		var hs := maxi(font_size - 9, 10)
		draw_string(font, Vector2(0.0, c.y + ts.y * 0.28 + hs + 4), alt_hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, hs, Color(1, 1, 1, 0.7))
