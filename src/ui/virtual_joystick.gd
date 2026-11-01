class_name VirtualJoystick
extends Control
## Analógico virtual flutuante: aparece onde o polegar toca dentro da área
## esquerda da tela. Aciona as ações move_* do InputMap com intensidade
## proporcional, então o resto do jogo não sabe se é toque, teclado ou controle.

@export var radius := 90.0
@export var dead_zone := 0.12
@export var base_color := Color(1, 1, 1, 0.18)
@export var knob_color := Color(1, 1, 1, 0.55)

var output := Vector2.ZERO

var _touch_index := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_base()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local := make_input_local(event) as InputEventScreenTouch
		if event.pressed and _touch_index == -1 and Rect2(Vector2.ZERO, size).has_point(local.position):
			_touch_index = event.index
			_base = local.position
			_knob = _base
			_update_output()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_reset_base()
			_update_output()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var local_drag := make_input_local(event) as InputEventScreenDrag
		_knob = _base + (local_drag.position - _base).limit_length(radius)
		_update_output()


func _reset_base() -> void:
	_base = Vector2(radius + 60.0, size.y - radius - 50.0)
	_knob = _base


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _touch_index == -1:
		_reset_base()
		queue_redraw()


func _update_output() -> void:
	var v := (_knob - _base) / radius
	if v.length() < dead_zone:
		v = Vector2.ZERO
	output = v
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_up", maxf(-v.y, 0.0))
	_set_action("move_down", maxf(v.y, 0.0))
	queue_redraw()


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	var active := _touch_index != -1
	draw_circle(_base, radius, base_color if active else Color(base_color, base_color.a * 0.6))
	draw_arc(_base, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(_knob, radius * 0.42, knob_color if active else Color(knob_color, knob_color.a * 0.6))
