extends Node
## Testa as regras/mecânicas novas (rodar no PC):
##   godot --headless --path . res://tests/rules_test.tscn --fixed-fps 60
## 1) virar para o lado oposto mantendo a bola  2) chute mirado
## 3) reinício: travado, só passe  4) meio-fio devolve bola rasteira

const MAIN := preload("res://src/main/main.tscn")

var mm: MatchManager
var ball: Ball
var me: Player
var f := 0
var phase := 0
var results := {}
var _start_pos := Vector3.ZERO


func _ready() -> void:
	process_priority = -100
	var main := MAIN.instantiate()
	mm = main.get_node("MatchManager")
	add_child(main)
	ball = main.get_node("Ball")


func _physics_process(_d: float) -> void:
	f += 1
	if f == 3:
		for p in mm.players:
			if p != mm.controlled:
				p.set_physics_process(false)
				p.global_position = Vector3(0, -50, 0) # tira do caminho
		me = mm.controlled
	if f < 80:
		return
	match phase:
		0: _test_turn()
		1: _test_aim()
		2: _test_restart_lock()
		3: _test_curb()
		4:
			print("RESULTADOS: ", results)
			get_tree().quit()


func _setup_ball_at_feet(pos: Vector3, face: Vector3) -> void:
	me.set_frozen(false)
	me.teleport(pos, face)
	ball.in_play = true
	ball.restricted_team = -1
	ball.place_at(pos + face * 0.45 + Vector3(0, Ball.RADIUS, 0))
	ball.claim(me)
	mm.state = MatchManager.MatchState.PLAYING


var t0 := 0
func _test_turn() -> void:
	if t0 == 0:
		t0 = f
		_setup_ball_at_feet(Vector3(-4, 0, 0), Vector3(1, 0, 0))
		Input.action_press("move_right", 1.0)
	var t := f - t0
	if t == 60:
		Input.action_release("move_right")
		Input.action_press("move_left", 1.0) # vira para o lado oposto
	if t == 160:
		Input.action_release("move_left")
		var off := ball.global_position.x - me.global_position.x
		results["virar_mantem_bola"] = me.ball_control.has_ball()
		results["bola_a_frente_na_nova_direcao"] = off < 0.0
		results["dist_bola"] = snappedf(me.ball_control.ball_distance(), 0.01)
		phase = 1
		t0 = 0


func _test_aim() -> void:
	if t0 == 0:
		t0 = f
		_setup_ball_at_feet(Vector3(0, 0, 0), Vector3(1, 0, 0))
	var t := f - t0
	if t == 10:
		Input.action_press("shoot")
	if t == 14:
		Input.action_press("move_up", 1.0) # mira para "cima" da tela (-Z)
	if t == 40:
		Input.action_release("shoot")
		Input.action_release("move_up")
	if t == 80:
		var v := ball.linear_velocity
		var dir := Vector3(v.x, 0, v.z).normalized()
		results["chute_mirado_dir"] = dir
		results["chute_segue_mira"] = dir.dot(Vector3(0, 0, -1)) > 0.9
		results["chute_vel"] = snappedf(Vector3(v.x, 0, v.z).length(), 0.1)
		phase = 2
		t0 = 0


func _test_restart_lock() -> void:
	if t0 == 0:
		t0 = f
		_setup_ball_at_feet(Vector3(3, 0, 2), Vector3(1, 0, 0))
		me.set_restart_lock(true)
		_start_pos = me.global_position
		Input.action_press("move_right", 1.0)
	var t := f - t0
	if t == 40:
		Input.action_release("move_right")
		results["travado_nao_anda"] = me.global_position.distance_to(_start_pos) < 0.15
		Input.action_press("shoot")
	if t == 45:
		Input.action_release("shoot")
	if t == 80:
		results["travado_nao_chuta"] = me.ball_control.has_ball() and me.is_restart_locked()
		Input.action_press("pass")
	if t == 82:
		Input.action_release("pass")
	if t == 120:
		results["passe_libera"] = not me.is_restart_locked()
		phase = 3
		t0 = 0


func _test_curb() -> void:
	if t0 == 0:
		t0 = f
		me.global_position = Vector3(0, -50, 0)
		ball.release()
		ball.place_at(Vector3(5, Ball.RADIUS, 2.5))
		ball.kick(Vector3(0, 0, 9.0), Vector3.ZERO, null)
	var t := f - t0
	if t == 60:
		results["meio_fio_devolve"] = ball.linear_velocity.z < 0.0 and ball.global_position.z < Field.HALF_WIDTH
		results["sem_lateral"] = mm.state != MatchManager.MatchState.BALL_OUT
		phase = 4
