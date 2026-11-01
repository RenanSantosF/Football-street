class_name MatchCamera
extends Camera3D
## Câmera do jogo.
##
## Jogo: próxima e elevada (não mostra a rua toda; o minimapa mostra o resto),
## acompanhando o jogador controlado com um pouco de antecipação da bola.
## Gol: modo "cinegrafista" — vai para perto de quem marcou, na altura dos
## ombros, gira devagar em volta da comemoração com leve balanço de câmera na mão.

@export var height := 4.6
@export var distance := 6.4
@export var follow_speed := 2.6
## 0 = segue só o jogador, 1 = segue só a bola.
@export_range(0.0, 1.0) var ball_weight := 0.35
@export var lookahead := 0.35
@export var max_focus_x := 13.0

var ball: Ball
var focus_player: Player

var _focus := Vector3.ZERO
var _celebrating: Player = null
var _celebration_time := 0.0
var _celebration_total := 0.0
var _cam_pos := Vector3.ZERO
var _orbit := 0.0
var _noise_t := 0.0


func _ready() -> void:
	fov = 52.0
	near = 0.05
	far = 120.0


func start_celebration(scorer: Player, duration: float) -> void:
	_celebrating = scorer
	_celebration_time = 0.0
	_celebration_total = duration
	# Começa do lado da câmera do jogo e gira em volta.
	var to_cam := global_position - scorer.global_position
	_orbit = atan2(to_cam.x, to_cam.z)


func _physics_process(delta: float) -> void:
	_noise_t += delta
	if _celebrating != null and is_instance_valid(_celebrating):
		_celebration_time += delta
		if _celebration_time >= _celebration_total:
			_celebrating = null
		else:
			_update_celebration(delta)
			return
	_focus = _focus.lerp(_target_focus(), 1.0 - exp(-follow_speed * delta))
	var target_pos := _focus + Vector3(0.0, height, distance)
	_cam_pos = _cam_pos.lerp(target_pos, 1.0 - exp(-6.0 * delta)) if _cam_pos != Vector3.ZERO else target_pos
	global_position = _cam_pos
	look_at(_focus + Vector3(0.0, 0.7, 0.0), Vector3.UP)


func snap() -> void:
	_focus = _target_focus()
	_cam_pos = _focus + Vector3(0.0, height, distance)
	global_position = _cam_pos
	look_at(_focus + Vector3(0.0, 0.7, 0.0), Vector3.UP)


func _update_celebration(delta: float) -> void:
	var p := _celebrating.global_position
	_orbit += delta * 0.35
	var radius := lerpf(4.0, 2.6, clampf(_celebration_time / 1.5, 0.0, 1.0))
	var want := p + Vector3(sin(_orbit) * radius, 1.45, cos(_orbit) * radius)
	# Não atravessar a cerca do fundo nem sair da rua.
	want.z = clampf(want.z, -Field.HALF_WIDTH - 1.5, Field.HALF_WIDTH + 2.0)
	_cam_pos = _cam_pos.lerp(want, 1.0 - exp(-3.0 * delta))
	# Balanço de câmera na mão.
	var shake := Vector3(sin(_noise_t * 1.7) * 0.025 + sin(_noise_t * 4.3) * 0.01,
		sin(_noise_t * 2.1) * 0.02, cos(_noise_t * 1.3) * 0.02)
	global_position = _cam_pos + shake
	look_at(p + Vector3(0.0, 1.1, 0.0), Vector3.UP)


func _target_focus() -> Vector3:
	if ball == null:
		return Vector3.ZERO
	var target := ball.global_position
	if focus_player != null:
		target = focus_player.global_position.lerp(ball.global_position, ball_weight)
	target += ball.flat_velocity() * lookahead
	target.x = clampf(target.x, -max_focus_x, max_focus_x)
	target.z = clampf(target.z * 0.6, -Field.HALF_WIDTH + 1.0, Field.HALF_WIDTH - 1.0)
	target.y = 0.0
	return target
