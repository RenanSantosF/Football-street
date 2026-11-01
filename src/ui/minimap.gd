class_name Minimap
extends Control
## Minimapa da rua: campo, traves, jogadores (cor do time), bola e o jogador
## controlado destacado. A câmera fica próxima; o minimapa mostra o resto.

var match_manager: MatchManager
var ball: Ball

const MARGIN := 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var w := size.x - MARGIN * 2.0
	var h := size.y - MARGIN * 2.0
	return Vector2(MARGIN + (p.x / (Field.HALF_LENGTH * 2.0) + 0.5) * w,
		MARGIN + (p.z / (Field.HALF_WIDTH * 2.0) + 0.5) * h)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.05, 0.06, 0.07, 0.55))
	var field := Rect2(_to_map(Vector3(-Field.HALF_LENGTH, 0, -Field.HALF_WIDTH)),
		_to_map(Vector3(Field.HALF_LENGTH, 0, Field.HALF_WIDTH)) - _to_map(Vector3(-Field.HALF_LENGTH, 0, -Field.HALF_WIDTH)))
	draw_rect(field, Color(0.45, 0.42, 0.38, 0.35))
	draw_rect(field, Color(1, 1, 1, 0.5), false, 1.5)
	draw_line(_to_map(Vector3(0, 0, -Field.HALF_WIDTH)), _to_map(Vector3(0, 0, Field.HALF_WIDTH)), Color(1, 1, 1, 0.35), 1.0)
	for sx in [-1.0, 1.0]:
		var a := _to_map(Vector3(sx * Field.HALF_LENGTH, 0, -Field.GOAL_HALF_WIDTH))
		var b := _to_map(Vector3(sx * Field.HALF_LENGTH, 0, Field.GOAL_HALF_WIDTH))
		draw_line(a, b, Color(1, 1, 1, 0.95), 3.0)
	if match_manager != null:
		for p in match_manager.players:
			if not p.active:
				continue
			var c := Team.COLORS[p.team]
			var mp := _to_map(p.global_position)
			if p == match_manager.controlled:
				draw_circle(mp, 6.0, Color(1, 1, 1, 0.95))
			draw_circle(mp, 4.2, c)
	if ball != null:
		var bp := _to_map(ball.global_position)
		draw_circle(bp, 3.4, Color(0, 0, 0, 0.8))
		draw_circle(bp, 2.5, Color(1, 1, 1))
