extends Node
## Teste automático (rodar no PC/servidor, não precisa no celular):
##   godot --headless --path . res://tests/autoplay_test.tscn --fixed-fps 60
## Simula uma partida IA x IA e imprime estatísticas e falhas de lógica.

const MAIN := preload("res://src/main/main.tscn")
const SECONDS := 240.0

var _mm: MatchManager
var _ball: Ball
var _time := 0.0
var _stats := {"goals": 0, "outs_side": 0, "outs_end": 0, "possessions": 0,
	"passes": 0, "shots": 0, "tackles": 0, "restarts": 0}
var _max_ball_speed := 0.0
var _ball_escaped := false
var _stuck_time := 0.0
var _max_stuck := 0.0
var _hold_owner: Node = null
var _hold_time := 0.0
var _max_hold := 0.0
var _max_hold_name := ""


func _ready() -> void:
	var main := MAIN.instantiate()
	_mm = main.get_node("MatchManager")
	_mm.autoplay = true
	_mm.match_seed = 12345
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			_mm.match_seed = int(a.substr(7))
	add_child(main)
	_ball = main.get_node("Ball")
	GameEvents.goal_scored.connect(func(_t, _s): _stats.goals += 1)
	GameEvents.ball_out.connect(func(k, _p, _l): _stats["outs_side" if k == 0 else "outs_end"] += 1)
	GameEvents.possession_changed.connect(func(n, _o): if n != null: _stats.possessions += 1)
	GameEvents.restart_started.connect(func(_t, _k, _p): _stats.restarts += 1)
	GameEvents.ball_kicked.connect(_on_kick)


func _on_kick(_k: Node, kind: StringName, _p: float) -> void:
	match kind:
		&"pass", &"long_pass": _stats.passes += 1
		&"shoot": _stats.shots += 1
		&"tackle": _stats.tackles += 1


func _physics_process(delta: float) -> void:
	_time += delta
	var bp := _ball.global_position
	_max_ball_speed = maxf(_max_ball_speed, _ball.linear_velocity.length())
	if absf(bp.x) > Field.STREET_HALF_LENGTH + 1.0 or absf(bp.z) > 8.0 or bp.y < -0.5:
		if not _ball_escaped:
			print("!! bola fora do mundo em t=%.1f pos=%s vel=%s estado=%d" % [_time, bp, _ball.linear_velocity, _mm.state])
		_ball_escaped = true
	# Bola parada em jogo sem ninguém pegar = IA travada.
	if _mm.state == MatchManager.MatchState.PLAYING and _ball.possessor == null and _ball.linear_velocity.length() < 0.05:
		_stuck_time += delta
		_max_stuck = maxf(_max_stuck, _stuck_time)
	elif _mm.state == MatchManager.MatchState.PLAYING and _ball.possessor != null and _ball.distance_to_possessor() > 1.0 and _ball.linear_velocity.length() < 0.05:
		_stuck_time += delta
		_max_stuck = maxf(_max_stuck, _stuck_time)
	else:
		_stuck_time = 0.0
	if _ball.possessor != null and _ball.possessor == _hold_owner:
		_hold_time += delta
		if _hold_time > _max_hold:
			_max_hold = _hold_time
			_max_hold_name = _hold_owner.name
	else:
		_hold_owner = _ball.possessor
		_hold_time = 0.0
	if int(_time * 60.0) % 1800 == 0:
		print("t=%5.1fs placar %d x %d estado=%d bola=(%.1f, %.2f, %.1f) posse=%s" % [
			_time, _mm.score[0], _mm.score[1], _mm.state, bp.x, bp.y, bp.z,
			_ball.possessor.name if _ball.possessor else "-"])
	if _time >= SECONDS:
		print("RESULTADO: ", _stats)
		print("vel. máx bola: %.1f m/s | bola escapou do mundo: %s | maior tempo bola parada sem dono: %.1fs" % [
			_max_ball_speed, _ball_escaped, _max_stuck])
		print("maior posse contínua: %.1fs (%s)" % [_max_hold, _max_hold_name])
		get_tree().quit()
