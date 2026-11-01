class_name BallOutSystem
extends Node
## Decide o que acontece quando a bola sai e entrega o reinício ao MatchManager.
##
## Etapa 1: espera um instante e repõe a bola (lateral ou tiro de meta).
## Etapa 6: quando a bola sair pela linha de fundo, este sistema vai
## identificar o adolescente esperando atrás daquela trave, fazê-lo correr,
## pegar a bola e devolvê-la — e só então chamar begin_restart(). A interface
## com o MatchManager (handle_out → begin_restart) já é a definitiva.

enum Kind { SIDELINE, END_LINE, FREE_KICK }

@export var restart_delay := 2.2

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
	var inset := 0.45
	if kind == Kind.SIDELINE:
		_restart_team = Team.other(last_touch_team) if last_touch_team >= 0 else Team.SHIRTS
		_restart_pos = Vector3(
			clampf(exit_pos.x, -Field.HALF_LENGTH + 1.0, Field.HALF_LENGTH - 1.0),
			Ball.RADIUS,
			signf(exit_pos.z) * (Field.HALF_WIDTH - inset))
		GameEvents.match_message.emit("LATERAL", 1.2)
	else:
		# Linha de fundo: quem defende aquela trave repõe (tiro de meta) se o
		# último toque foi do ataque; se foi da defesa, é ESCANTEIO.
		var defending := Team.SHIRTS if exit_pos.x < 0.0 else Team.SKINS
		if last_touch_team == defending:
			_restart_team = Team.other(defending)
			_restart_pos = Vector3(
				signf(exit_pos.x) * (Field.HALF_LENGTH - inset),
				Ball.RADIUS,
				(1.0 if exit_pos.z >= 0.0 else -1.0) * (Field.HALF_WIDTH - inset))
			GameEvents.match_message.emit("ESCANTEIO", 1.2)
		else:
			_restart_team = defending
			_restart_pos = Vector3(
				Field.goal_line_x(defending) + Field.attack_sign(defending) * 1.6,
				Ball.RADIUS, 0.0)
			GameEvents.match_message.emit("TIRO DE META", 1.2)
	_timer = restart_delay
	_waiting = true


## Reinício já decidido (ex.: falta) depois do atraso padrão.
func schedule_restart(team: int, kind: Kind, pos: Vector3) -> void:
	_restart_team = team
	_restart_kind = kind
	_restart_pos = pos
	_timer = restart_delay
	_waiting = true


func _physics_process(delta: float) -> void:
	if not _waiting:
		return
	_timer -= delta
	if _timer <= 0.0:
		_waiting = false
		match_manager.begin_restart(_restart_team, _restart_kind, _restart_pos)
