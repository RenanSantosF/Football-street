extends Node
## Teste do controle humano: simula analógico/botões e mede a condução.
##   godot --headless --path . res://tests/human_input_test.tscn --fixed-fps 60

const MAIN := preload("res://src/main/main.tscn")

var _mm: MatchManager
var _ball: Ball
var _frame := 0
var _touches := 0
var _dist_samples: Array[float] = []
var _kicks: Array[String] = []
var _had_ball_frames := 0
var _switches := 0


func _ready() -> void:
	# Roda antes do HumanInput, como eventos reais de toque (senão o
	# is_action_just_pressed() do mesmo frame seria perdido).
	process_priority = -100
	var main := MAIN.instantiate()
	_mm = main.get_node("MatchManager")
	_mm.match_seed = 99
	add_child(main)
	_ball = main.get_node("Ball")
	GameEvents.ball_kicked.connect(func(k, kind, p): _kicks.append("%s:%s(%.2f)" % [k.name, kind, p]))
	GameEvents.controlled_player_changed.connect(func(_p): _switches += 1)
	# Os adversários de linha ficam parados (goleiro ativo) para isolar a condução.
	for p in _mm.get_team(Team.SKINS):
		if not p.is_goalkeeper():
			p.set_physics_process(false)


func _physics_process(_delta: float) -> void:
	_frame += 1
	var me := _mm.controlled
	if _frame == 2:
		me.ball_touched.connect(func(kind): if kind == &"dribble_touch": _touches += 1)
	# 0-1,2s: saída (congelado). Depois: ir até a bola e conduzir para +X.
	if _frame == 80:
		Input.action_press("move_right", 1.0)
	if _frame > 80 and _frame < 140:
		if me.ball_control.has_ball():
			_had_ball_frames += 1
			_dist_samples.append(me.ball_control.ball_distance())
	if _frame == 120:
		Input.action_press("sprint")
	if _frame == 150:
		Input.action_release("sprint")
		Input.action_press("move_up", 0.7)  # diagonal: mudar de direção com a bola
	if _frame == 140:
		Input.action_release("move_up")
		Input.action_press("shoot")
	if _frame == 160:
		Input.action_release("shoot")
	if _frame == 162:
		Input.action_release("move_right")
	if _frame == 420:
		Input.action_press("switch_player")
	if _frame == 422:
		Input.action_release("switch_player")
	if _frame == 480:
		_dist_samples.sort()
		var n := _dist_samples.size()
		var avg := 0.0
		for d in _dist_samples:
			avg += d
		print("frames com posse: %d/%d | toques de condução: %d" % [_had_ball_frames, 59, _touches])
		if n > 0:
			print("distância bola-jogador: min %.2f  mediana %.2f  máx %.2f  média %.2f" % [
				_dist_samples[0], _dist_samples[n / 2], _dist_samples[n - 1], avg / n])
		print("chutes/passes: ", _kicks)
		print("trocas de jogador controlado: ", _switches, " | placar ", _mm.score)
		get_tree().quit()
