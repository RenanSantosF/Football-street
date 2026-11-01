class_name MatchManager
extends Node
## Regras da pelada: cria os jogadores, controla saída de bola, gols, bola
## fora e reinícios, placar e troca do jogador controlado.

enum MatchState { KICKOFF, PLAYING, GOAL, BALL_OUT, RESTART }

const PLAYERS_PER_TEAM := 3
const GOAL_CELEBRATION_TIME := 5.0
## Posições base do time que ataca para +X (o outro time é espelhado).
## Índice 0 = goleiro.
## Sem goleiro: três jogadores de linha (fixo, ala, ala).
const FORMATION: Array[Vector3] = [
	Vector3(-8.5, 0.0, 0.0),   # fixo (atrás, no meio)
	Vector3(-4.0, 0.0, -2.8),  # ala esquerda
	Vector3(-4.0, 0.0, 2.8),   # ala direita
]

@export var player_scene: PackedScene
@export var ball: Ball
@export var goal_left: GoalController
@export var goal_right: GoalController
@export var players_root: Node3D
@export var human_input: HumanInput
@export var camera: MatchCamera
@export var ball_out_system: BallOutSystem
@export var human_team := Team.SHIRTS
## Todos controlados pela IA (teste automático / modo demonstração).
@export var autoplay := false
@export var match_seed := 0

var players: Array[Player] = []
var score: Array[int] = [0, 0]
var state: MatchState = MatchState.KICKOFF
var controlled: Player = null

var _state_timer := 0.0
## Saída de bola esperando o primeiro toque (cada time no seu campo).
var waiting_kickoff := false
## Modo TREINO: só o time do jogador (sem adversários) para treinar toque,
## condução e chute. Modo PARTIDA: com adversários.
var training_mode := false
const SETTINGS_PATH := "user://settings.cfg"
var _prev_ball_pos := Vector3.ZERO
var _last_goal_team := Team.SHIRTS
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# O painel de ajustes saiu do jogo: apaga ajustes antigos (volta ao padrão).
	if FileAccess.file_exists("user://dev_tools.cfg"):
		DirAccess.remove_absolute("user://dev_tools.cfg")
	if OS.get_cmdline_user_args().has("--autoplay"):
		autoplay = true
	if match_seed != 0:
		_rng.seed = match_seed
	else:
		_rng.randomize()
	ball_out_system.setup(self)
	human_input.switch_requested.connect(_on_switch_requested)
	GameEvents.possession_changed.connect(_on_possession_changed)
	GameEvents.ball_kicked.connect(_on_ball_kicked)
	camera.ball = ball
	_spawn_players()
	var cfg := ConfigFile.new()
	if not autoplay and cfg.load(SETTINGS_PATH) == OK and cfg.get_value("game", "training", false):
		_apply_training(true)
	_start_kickoff(Team.SHIRTS)
	camera.snap()


func _spawn_players() -> void:
	for team in [Team.SHIRTS, Team.SKINS]:
		for i in PLAYERS_PER_TEAM:
			var p := player_scene.instantiate() as Player
			p.team = team
			p.role = Player.Role.FIELD # pelada sem goleiro
			p.formation_index = i
			p.shirt_number = 7 + i
			p.appearance = CharacterAppearance.random_for_team(team, _rng)
			p.name = "%s_%d" % ["Camisa" if team == Team.SHIRTS else "SemCamisa", i]
			players_root.add_child(p)
			p.setup(self, ball)
			players.append(p)


# --- Consultas -------------------------------------------------------------------

func get_team(team: int) -> Array[Player]:
	var result: Array[Player] = []
	for p in players:
		if p.team == team and p.active:
			result.append(p)
	return result


## Liga/desliga o modo TREINO (salvo para a próxima vez) e recomeça.
func set_training_mode(on: bool) -> void:
	_apply_training(on)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "training", on)
	cfg.save(SETTINGS_PATH)
	score = [0, 0]
	GameEvents.score_changed.emit(0, 0)
	_start_kickoff(human_team)


func _apply_training(on: bool) -> void:
	training_mode = on
	for p in players:
		if p.team != human_team:
			p.set_active(not on)


func get_goalkeeper(team: int) -> Player:
	for p in players:
		if p.team == team and p.is_goalkeeper():
			return p
	return null


## Bola em jogo (inclui o instante de reinício com a bola já posicionada).
func is_ball_live() -> bool:
	return state == MatchState.PLAYING or state == MatchState.RESTART


func formation_position(team: int, index: int, ball_x := 0.0) -> Vector3:
	var s := Field.attack_sign(team)
	var base := FORMATION[clampi(index, 0, FORMATION.size() - 1)]
	var p := Vector3(base.x * s, 0.0, base.z * s)
	if index > 0:
		p.x += clampf(ball_x * 0.5, -5.0, 5.0)
	return p


# --- Ciclo da partida --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_state_timer -= delta
	if ball.held and (ball.restricted_player == null or not ball.restricted_player.is_restart_locked()):
		ball.held = false # segurança: a trava do batedor acabou
	match state:
		MatchState.KICKOFF:
			if _state_timer <= 0.0:
				for p in players:
					p.set_frozen(false)
				ball.in_play = true
				_set_state(MatchState.PLAYING)
		MatchState.PLAYING:
			_check_ball()
		MatchState.GOAL:
			if _state_timer <= 0.0:
				_start_kickoff(Team.other(_last_goal_team))
		MatchState.RESTART:
			if _state_timer <= 0.0:
				_set_state(MatchState.PLAYING)
			else:
				_check_ball()
		MatchState.BALL_OUT:
			pass # aguardando o BallOutSystem
	_prev_ball_pos = ball.global_position


func _check_ball() -> void:
	var cur := ball.global_position
	for goal in [goal_left, goal_right]:
		if goal.check_goal(_prev_ball_pos, cur):
			_on_goal(Team.other(goal.defending_team))
			return
	if absf(cur.x) > Field.HALF_LENGTH + Ball.RADIUS:
		_on_ball_out(BallOutSystem.Kind.END_LINE, cur)
	elif absf(cur.z) > Field.HALF_WIDTH + Field.SIDELINE_OUT_MARGIN:
		# Passou por cima do meio-fio e caiu na calçada.
		_on_ball_out(BallOutSystem.Kind.SIDELINE, cur)
	elif cur.y < -2.0:
		_start_kickoff(Team.SHIRTS) # segurança: nunca deveria acontecer


func _on_goal(team: int) -> void:
	score[team] += 1
	_last_goal_team = team
	ball.in_play = false
	ball.release()
	GameEvents.goal_scored.emit(team, ball.last_toucher)
	GameEvents.score_changed.emit(score[0], score[1])
	# Quem marcou comemora (samba ou vitória), os companheiros vibram e o
	# time que sofreu lamenta.
	var scorer := ball.last_toucher
	for p in players:
		if p.team == team:
			p.play_reaction(&"samba" if p == scorer and _rng.randf() < 0.5 else &"celebrate")
		else:
			p.play_reaction(&"defeated")
	if camera != null and scorer != null:
		camera.start_celebration(scorer, GOAL_CELEBRATION_TIME)
	_state_timer = GOAL_CELEBRATION_TIME
	_set_state(MatchState.GOAL)


func _on_ball_out(kind: BallOutSystem.Kind, pos: Vector3) -> void:
	ball.in_play = false
	ball.release()
	var last_team := ball.last_toucher.team if ball.last_toucher != null else -1
	_set_state(MatchState.BALL_OUT)
	GameEvents.ball_out.emit(kind, pos, last_team)
	ball_out_system.handle_out(kind, pos, last_team)


## Chamado pelo BallOutSystem quando a bola está pronta para voltar ao jogo.
## Na lateral, no escanteio e no tiro de meta quem bate fica PARADO com a bola
## e é obrigado a tocar para um companheiro (não pode sair conduzindo).
func begin_restart(team: int, kind: BallOutSystem.Kind, pos: Vector3) -> void:
	if get_team(team).is_empty():
		team = human_team # modo treino: todo reinício é do meu time
	ball.place_at(pos)
	_prev_ball_pos = ball.global_position
	var into_field := (Vector3(0.0, 0.0, 0.0) - Vector3(pos.x * 0.4, 0.0, pos.z)).normalized()
	if kind == BallOutSystem.Kind.SIDELINE:
		into_field = Vector3(0.0, 0.0, -signf(pos.z) if absf(pos.z) > 0.1 else 1.0)
	elif kind == BallOutSystem.Kind.FREE_KICK:
		into_field = Vector3(Field.attack_sign(team), 0.0, 0.0)
	var taker := _closest_field_player(team, pos)
	taker.teleport(pos - into_field * 0.45, into_field)
	# Adversários afastados da bola.
	for p in get_team(Team.other(team)):
		var off := p.global_position - pos
		off.y = 0.0
		if off.length() < 3.0:
			var dir := off.normalized() if off.length() > 0.1 else into_field
			p.teleport(Field.clamp_inside(pos + dir * 3.1, 0.4), -dir)
	ball.restrict_to(team, 60.0)
	ball.in_play = true
	ball.claim(taker)
	ball.hold_here() # parada no lugar: girar o corpo não mexe na bola
	ball.restricted_player = taker # só o batedor toca até passar
	taker.set_restart_lock(true)
	if team == human_team and not autoplay:
		set_controlled(taker)
	GameEvents.restart_started.emit(team, kind, pos)
	_state_timer = 0.5
	_set_state(MatchState.RESTART)


## Falta: bola parada no local para o time que sofreu (batedor obrigado a tocar).
func award_free_kick(team: int, pos: Vector3) -> void:
	if not is_ball_live():
		return
	ball.in_play = false
	ball.release()
	GameEvents.match_message.emit("FALTA!", 1.4)
	_set_state(MatchState.BALL_OUT)
	var spot := Field.clamp_inside(Vector3(pos.x, Ball.RADIUS, pos.z), 0.6)
	spot.y = Ball.RADIUS
	ball_out_system.schedule_restart(team, BallOutSystem.Kind.FREE_KICK, spot)


func _start_kickoff(team: int) -> void:
	if get_team(team).is_empty():
		team = human_team # modo treino: a saída é sempre do meu time
	ball_out_system.cancel()
	ball.place_at(Vector3(0.0, Ball.RADIUS, 0.0))
	ball.in_play = false
	_prev_ball_pos = ball.global_position
	var s := Field.attack_sign(team)
	for p in players:
		if not p.active:
			continue
		var pos := formation_position(p.team, p.formation_index)
		if p.team == team and p.formation_index == 2:
			pos = Vector3(-0.45 * s, 0.0, 0.0) # quem dá a saída
		p.teleport(pos, Vector3(Field.attack_sign(p.team), 0.0, 0.0))
		p.set_frozen(true)
	ball.restrict_to(team, 60.0)
	# Saída de bola: quem dá a saída tem que tocar (não sai conduzindo) e
	# ninguém mais pode pegar a bola antes do passe.
	ball.hold_here()
	for p in get_team(team):
		if p.formation_index == 2:
			p.set_restart_lock(true)
			ball.restricted_player = p
	if not autoplay:
		var start := _closest_field_player(human_team, ball.global_position)
		set_controlled(start)
	waiting_kickoff = true
	GameEvents.restart_started.emit(team, -1, ball.global_position)
	GameEvents.match_message.emit("SAÍDA DE BOLA", 1.0)
	_state_timer = 1.2
	_set_state(MatchState.KICKOFF)


func _set_state(s: MatchState) -> void:
	if state == s:
		return
	state = s
	GameEvents.match_state_changed.emit(s)


# --- Jogador controlado ----------------------------------------------------------

func set_controlled(p: Player) -> void:
	if p == controlled or p == null:
		return
	if controlled != null:
		controlled.set_human(false, null)
	controlled = p
	p.set_human(true, human_input)
	human_input.current_player = p
	camera.focus_player = p
	GameEvents.controlled_player_changed.emit(p)


func _on_switch_requested() -> void:
	if autoplay:
		return
	# Com a bola no pé não troca de jogador.
	if controlled != null and controlled.ball_control.has_ball():
		return
	# Passe vindo para o controlado: não troca até ele dominar.
	if controlled != null and ball.possessor == null and ball.pass_target == controlled:
		return
	var best: Player = null
	var best_d := INF
	for p in get_team(human_team):
		if p == controlled or p.is_goalkeeper():
			continue
		var d := p.global_position.distance_to(ball.global_position)
		if d < best_d:
			best_d = d
			best = p
	set_controlled(best)


func _on_possession_changed(new_owner: Node, _old_owner: Node) -> void:
	if autoplay:
		return
	var p := new_owner as Player
	if p == null:
		return
	if p.team == human_team:
		# Quem recebeu o passe passa a ser controlado (exceto goleiro).
		if not p.is_goalkeeper():
			set_controlled(p)
	elif controlled != null:
		# Adversário pegou a bola: trocar para quem está bem mais perto dela.
		var closest := _closest_field_player(human_team, ball.global_position)
		var gain := controlled.global_position.distance_to(ball.global_position) \
			- closest.global_position.distance_to(ball.global_position)
		if gain > 3.0:
			set_controlled(closest)


## Passe do time humano: o controle vai para quem vai receber já no toque,
## para você poder se mexer ao encontro da bola.
func _on_ball_kicked(kicker: Node, kind: StringName, _power: float) -> void:
	waiting_kickoff = false
	if autoplay or not (kind == &"pass" or kind == &"long_pass"):
		return
	var k := kicker as Player
	if k != null and k.team == human_team and ball.pass_target != null and ball.pass_target.team == human_team:
		set_controlled(ball.pass_target)


func _closest_field_player(team: int, point: Vector3) -> Player:
	var best: Player = null
	var best_d := INF
	for p in get_team(team):
		if p.is_goalkeeper():
			continue
		var d := p.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = p
	return best
