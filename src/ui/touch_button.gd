class_name TouchButton
extends Control
## Botão redondo de toque com suporte a multitoque (vários dedos ao mesmo
## tempo). Pressionar aciona a ação do InputMap; soltar libera.

@export var action: StringName = &"shoot"
@export var label := "CHUTE"
@export var color := Color(1, 1, 1, 0.3)
@export var font_size := 22

var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local := make_input_local(event) as InputEventScreenTouch
		if event.pressed and _touch_index == -1 and _hit(local.position):
			_touch_index = event.index
			Input.action_press(action)
			queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		# Dedo escorregou para fora com folga: solta.
		var local_drag := make_input_local(event) as InputEventScreenDrag
		if local_drag.position.distance_to(size * 0.5) > _radius() * 1.6:
			_release()


func _release() -> void:
	_touch_index = -1
	Input.action_release(action)
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) * 0.5


func _hit(p: Vector2) -> bool:
	return p.distance_to(size * 0.5) <= _radius() * 1.1


func _draw() -> void:
	var pressed := _touch_index != -1
	var c := size * 0.5
	var r := _radius()
	draw_circle(c, r, Color(color, color.a * (2.0 if pressed else 1.0)))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.6 if pressed else 0.4), 2.5, true)
	var font := get_theme_default_font()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(0.0, c.y + text_size.y * 0.3), label,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(1, 1, 1, 0.9))
