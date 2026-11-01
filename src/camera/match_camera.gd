class_name MatchCamera
extends Camera3D
## Câmera elevada de transmissão, do lado da rua, acompanhando a jogada.
## Mira um ponto entre a bola e o jogador controlado, com antecipação na
## direção em que a bola corre. Inclinação ~40° (não é vista de cima).

@export var height := 8.5
@export var distance := 10.5
@export var follow_speed := 3.0
## 0 = segue só o jogador, 1 = segue só a bola.
@export_range(0.0, 1.0) var ball_weight := 0.65
@export var lookahead := 0.3
@export var max_focus_x := 9.0

var ball: Ball
var focus_player: Player

var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 50.0
	near = 0.1
	far = 150.0


func _physics_process(delta: float) -> void:
	_focus = _focus.lerp(_target_focus(), 1.0 - exp(-follow_speed * delta))
	_apply()


func snap() -> void:
	_focus = _target_focus()
	_apply()


func _target_focus() -> Vector3:
	if ball == null:
		return Vector3.ZERO
	var target := ball.global_position
	if focus_player != null:
		target = focus_player.global_position.lerp(ball.global_position, ball_weight)
	target += ball.flat_velocity() * lookahead
	target.x = clampf(target.x, -max_focus_x, max_focus_x)
	target.z = clampf(target.z * 0.3, -1.0, 1.0)
	target.y = 0.0
	return target


func _apply() -> void:
	global_position = _focus + Vector3(0.0, height, distance)
	look_at(_focus + Vector3(0.0, 0.6, 0.0), Vector3.UP)
