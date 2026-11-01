class_name BallOutSystem
extends Node
## Decide o que acontece quando a bola sai e entrega o reinício ao MatchManager.
##
## Etapa 1: espera um instante e repõe a bola (lateral ou tiro de meta).
## Etapa 6: quando a bola sair pela linha de fundo, este sistema vai
## identificar o adolescente esperando atrás daquela trave, fazê-lo correr,
## pegar a bola e devolvê-la — e só então chamar begin_restart(). A interface
## com o MatchManager (handle_out → begin_restart) já é a definitiva.

enum Kind { SIDELINE, END_LINE }

@export var restart_delay := 1.4

var match_manager: MatchManager

var _waiting := false
var _timer := 0.0
var _restart_team := 0
var _restart_kind: Kind = Kind.SIDELINE
var _restart_pos := Vector3.ZERO


func setup(mm: MatchManager) -> void:
	match_manager = mm


func is_busy() -> bool:
	return _waiting


func cancel() -> void:
	_waiting = false


func handle_out(kind: Kind, exit_pos: Vector3, last_touch_team: int) -> void:
	_restart_kind = kind
	if kind == Kind.SIDELINE:
		_restart_team = Team.other(last_touch_team) if last_touch_team >= 0 else Team.SHIRTS
		_restart_pos = Vector3(
			clampf(exit_pos.x, -Field.HALF_LENGTH + 1.0, Field.HALF_LENGTH - 1.0),
			Ball.RADIUS,
			signf(exit_pos.z) * (Field.HALF_WIDTH - 0.25))
		GameEvents.match_message.emit("LATERAL", 1.2)
	else:
		# Na rua não tem escanteio: quem defende aquela trave repõe.
		_restart_team = Team.SHIRTS if exit_pos.x < 0.0 else Team.SKINS
		_restart_pos = Vector3(
			Field.goal_line_x(_restart_team) + Field.attack_sign(_restart_team) * 1.6,
			Ball.RADIUS, 0.0)
		GameEvents.match_message.emit("TIRO DE META", 1.2)
	_timer = restart_delay
	_waiting = true


func _physics_process(delta: float) -> void:
	if not _waiting:
		return
	_timer -= delta
	if _timer <= 0.0:
		_waiting = false
		match_manager.begin_restart(_restart_team, _restart_kind, _restart_pos)
