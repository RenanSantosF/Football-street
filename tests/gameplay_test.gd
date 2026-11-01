extends Node
## Testa jogabilidade da Etapa 8 (rodar no PC):
##   godot --headless --path . res://tests/gameplay_test.tscn --fixed-fps 60
## 1) saída de bola: adversário espera no próprio campo  2) passe da saída chega
## 3) passe em profundidade: alguém corre e domina  4) modo treino desliga rivais

const MAIN := preload("res://src/main/main.tscn")

var mm: MatchManager
var ball: Ball
var f := 0
var phase := 0
var t0 := 0
var results := {}
var _kick_speed := 0.0
var _target: Player = null
var _invaded := false
var _measure := 0
var _first_owner: Node = null
var _kicker: Node = null


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")
	GameEvents.ball_kicked.connect(func(_k, _kind, _p): _measure = 3)


func _physics_process(_d: float) -> void:
	f += 1
	if _measure > 0:
		_measure -= 1
		if _measure == 0:
			_kick_speed = ball.linear_velocity.length()
			_target = ball.pass_target
	if f == 5:
		mm.set_training_mode(false)
	if f < 10:
		return
	match phase:
		0: _test_kickoff_wait()
		1: _test_kickoff_pass()
		2: _test_training()
		3: _test_through_pass()
		4:
			mm.set_training_mode(false) # não deixa o ajuste salvo para os outros testes
			print("RESULTADOS: ", results)
			get_tree().quit()


func _test_kickoff_wait() -> void:
	if t0 == 0:
		t0 = f
	var t := f - t0
	for p in mm.get_team(1 - mm.human_team):
		var own := p.global_position.x * Field.attack_sign(p.team)
		if own > -0.9:
			_invaded = true
	if t == 300:
		results["rival_espera_no_campo"] = not _invaded
		results["bola_parada_na_saida"] = ball.global_position.distance_to(Vector3(0, Ball.RADIUS, 0)) < 0.3
		phase = 1
		t0 = 0


func _test_kickoff_pass() -> void:
	if t0 == 0:
		t0 = f
		_kick_speed = 0.0
		_kicker = ball.possessor
		Input.action_press("pass")
	var t := f - t0
	if ball.possessor == null and ball.linear_velocity.length() > _kick_speed:
		_kick_speed = ball.linear_velocity.length()
		_target = ball.pass_target
	if t > 6 and _first_owner == null and ball.possessor != null and ball.possessor != _kicker:
		_first_owner = ball.possessor
	if t == 4:
		Input.action_release("pass")
	if t == 240:
		results["passe_alvo"] = str(_target.name) if _target else "nenhum"
		results["passe_vel"] = snappedf(_kick_speed, 0.1)
		results["passe_rapido"] = _kick_speed >= 7.0
		results["controle_vai_pro_recebedor"] = _target != null and mm.controlled == _target
		results["dono_apos_passe"] = str(ball.possessor.name) if ball.possessor else "solta@" + str(ball.global_position)
		results["recebedor_dominou"] = _target != null and _first_owner == _target
		phase = 2
		t0 = 0


func _test_through_pass() -> void:
	if t0 == 0:
		t0 = f
		mm.ball_out_system.cancel()
		var me := mm.controlled
		var s := Field.attack_sign(me.team)
		me.set_frozen(false)
		me.teleport(Vector3(-6 * s, 0, 0), Vector3(s, 0, 0))
		ball.in_play = true
		ball.restricted_team = -1
		ball.restricted_player = null
		me.set_restart_lock(false)
		ball.place_at(me.global_position + Vector3(s * 0.45, Ball.RADIUS, 0))
		ball.claim(me)
		mm.state = MatchManager.MatchState.PLAYING
		_target = null
	var t := f - t0
	var s2 := Field.attack_sign(mm.human_team)
	if t == 20:
		# direção diagonal para o espaço vazio + passe médio
		Input.action_press("move_up" if s2 > 0 else "move_down", 1.0)
		Input.action_press("pass")
	if t == 34:
		Input.action_release("pass")
	if t == 40:
		Input.action_release("move_up")
		Input.action_release("move_down")
	if ball.pass_target != null:
		_target = ball.pass_target
	if t == 330:
		results["profundidade_recebedor"] = _target != null
		results["dono_apos_prof"] = str(ball.possessor.name) if ball.possessor else "solta@" + str(ball.global_position) + " st=" + str(mm.state)
		results["profundidade_dominou"] = _target != null and ball.possessor == _target
		phase = 4
		t0 = 0


func _test_training() -> void:
	if t0 == 0:
		t0 = f
		mm.set_training_mode(true)
	var t := f - t0
	if t == 30:
		results["treino_sem_rivais"] = mm.get_team(1 - mm.human_team).is_empty()
		var hidden := true
		for p in mm.players:
			if p.team != mm.human_team and p.visible:
				hidden = false
		results["treino_rivais_ocultos"] = hidden
		mm.set_training_mode(false)
	if t == 60:
		results["partida_volta_rivais"] = mm.get_team(1 - mm.human_team).size() > 0
		mm.set_training_mode(true) # profundidade testada no treino (determinístico)
	if t == 180:
		phase = 3
		t0 = 0
