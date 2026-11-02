class_name HumanInput
extends Node
## Lê toque/teclado/controle e transforma em PlayerIntent para o jogador
## controlado. Botões de passe e chute carregam força enquanto pressionados.
##
## Passe: toque rápido = passe curto rasteiro; segurar = passe longo/alto.
## Chute: segurar = mais força. Sem a bola, o botão de chute faz o desarme.

signal switch_requested
## Carga atual do botão (0..1) para a barra de força. kind = &"" quando solto.
signal charge_changed(value: float, kind: StringName)
## Mira do chute: ativa enquanto o botão de chute está segurado.
signal aim_changed(active: bool, direction: Vector3, power: float)
## Seta do PASSE: para quem (ou para onde) a bola vai, enquanto segura PASSE.
signal pass_aim_changed(active: bool, direction: Vector3, power: float, assisted: bool)

const MAX_CHARGE_TIME := 0.6

@export var camera: Camera3D

var current_player: Player = null

var _move := Vector3.ZERO
var _raw := Vector3.ZERO
var _pass_target: Player = null
var _pass_dir := Vector3.ZERO
var _pass_aiming := false
var _sprint := false
var _pass_hold := -1.0
var _shoot_hold := -1.0
var _queued: PlayerIntent.Action = PlayerIntent.Action.NONE
var _queued_power := 0.0
var _last_charge := -1.0
var _aim := Vector3.ZERO
var _aiming := false
var _lob_pending := false
var _chip_pending := false
var _queued_lofted := false
## Segurando CORRER sem a bola (BUSCAR): o jogador corre sozinho atrás da bola
## ou cerca quem está com ela.
var chasing := false
var _chase_sprint := false
## Direção suavizada do analógico (girar rápido de um lado para o outro não
## deixa o jogador "perdido": o corpo acompanha numa velocidade humana).
var _smooth := Vector3.ZERO
var _raw_dir := Vector3.ZERO
var _raw_steady := 0.0


func _ready() -> void:
	process_priority = -10 # roda antes dos jogadores


func _physics_process(delta: float) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_raw = _to_world(v)
	_move = _smooth_input(_raw, delta)
	_sprint = Input.is_action_pressed("sprint")
	# Segurando CHUTE com a bola (ou perto dela): o analógico vira a MIRA e o
	# jogador para; a direção escolhida é exatamente para onde a bola vai.
	var was_aiming := _aiming
	_aiming = _shoot_hold >= 0.0 and current_player != null and _near_ball()
	if _aiming:
		if not was_aiming:
			_aim = current_player.facing
		if _raw.length() > 0.25:
			_aim = _raw.normalized() # mira pelo analógico cru (sem atraso)
		_move = Vector3.ZERO
		aim_changed.emit(true, _aim, clampf(_shoot_hold / MAX_CHARGE_TIME, 0.0, 1.0))
	elif was_aiming:
		aim_changed.emit(false, _aim, 0.0)

	if Input.is_action_just_pressed("switch_player"):
		switch_requested.emit()
	if Input.is_action_just_pressed("dribble"):
		# Com a bola: DRIBLE. Sem a bola: DESARME (bote com o pé na bola).
		_queue(PlayerIntent.Action.DRIBBLE, 1.0)
	# Sem a bola, CORRER = BUSCAR: corre na bola solta ou no adversário que a
	# tem. Com um companheiro com a bola, CORRER é só correr (desmarque).
	chasing = false
	var loose_mine := current_player != null and current_player.ball != null \
		and current_player.ball.possessor == null and current_player.ball.pass_target != current_player
	if (not has_ball_context() or loose_mine) and _sprint and current_player != null and current_player.ball != null:
		var b := current_player.ball
		var chase_ok := b.possessor == null or b.possessor.team != current_player.team
		var auto := _chase_direction() if chase_ok else Vector3.ZERO
		# analógico apontando para longe da bola: o jogador quer correr para lá
		if chase_ok and not (_move.length() > 0.5 and auto.length() > 0.05 and _move.normalized().dot(auto.normalized()) < -0.2):
			chasing = true
			if _move.length() > 0.3 and auto.length() > 0.05:
				# Analógico junto: escolhe por onde chegar (ex.: dar a volta e
				# pegar o adversário de frente, não por trás).
				var mix := (auto.normalized() * 0.6 + _move.normalized() * 0.4).normalized()
				_move = mix * maxf(auto.length(), 0.6)
			else:
				_move = auto
			_sprint = _chase_sprint

	if has_ball_context():
		_shoot_hold = _update_charge("shoot", _shoot_hold, delta, PlayerIntent.Action.SHOOT)
		_pass_hold = _update_charge("pass", _pass_hold, delta, PlayerIntent.Action.PASS)
		if Input.is_action_pressed("pass_lob") and _pass_hold >= 0.0:
			_lob_pending = true
		if Input.is_action_pressed("shoot_chip") and _shoot_hold >= 0.0:
			_chip_pending = true
	else:
		# Sem a bola: CHUTE vira CARRINHO e PASSE vira TROCAR de jogador.
		_shoot_hold = -1.0
		_pass_hold = -1.0
		if Input.is_action_just_pressed("shoot"):
			_queue(PlayerIntent.Action.SHOOT, 0.0)
		if Input.is_action_just_pressed("pass"):
			switch_requested.emit()

	_update_pass_aim()
	var charge := -1.0
	var kind: StringName = &""
	if _shoot_hold >= 0.0:
		charge = _shoot_hold / MAX_CHARGE_TIME
		kind = &"shoot"
	elif _pass_hold >= 0.0:
		charge = _pass_hold / MAX_CHARGE_TIME
		kind = &"pass"
	if charge != _last_charge:
		_last_charge = charge
		charge_changed.emit(clampf(charge, 0.0, 1.0), kind)
		if current_player != null:
			current_player.set_charge(charge, kind)


## Seta do passe com ASSISTÊNCIA: o analógico aponta e o passe vai no
## companheiro mais próximo dessa direção (cone de 45°). Ninguém no cone →
## passe em profundidade, para o espaço apontado.
func _update_pass_aim() -> void:
	var active := _pass_hold >= 0.0 and current_player != null and current_player.ball != null
	if active:
		var dir := _raw.normalized() if _raw.length() > 0.25 else current_player.facing
		var mate := current_player.ball_control.pick_pass_target(dir, 45.0)
		if mate == null and _raw.length() <= 0.25:
			mate = current_player.ball_control.pick_pass_target(dir, 180.0)
		_pass_target = mate
		if mate != null:
			var to := mate.global_position - current_player.ball.global_position
			to.y = 0.0
			_pass_dir = to.normalized()
		else:
			_pass_dir = dir
		_pass_aiming = true
		pass_aim_changed.emit(true, _pass_dir, clampf(_pass_hold / MAX_CHARGE_TIME, 0.0, 1.0), mate != null)
	elif _pass_aiming:
		_pass_aiming = false
		pass_aim_changed.emit(false, _pass_dir, 0.0, false)


func fill_intent(_player: Player, intent: PlayerIntent, _delta: float) -> void:
	intent.move = _move
	intent.sprint = _sprint
	if _queued != PlayerIntent.Action.NONE:
		if _queued == PlayerIntent.Action.SHOOT and _aim != Vector3.ZERO and _queued_power > 0.0:
			intent.set_action(_queued, _queued_power, _aim)
			intent.precise = true
		elif _queued == PlayerIntent.Action.PASS:
			# Passe: exatamente o que a seta mostrou.
			var aim := _pass_dir if _pass_dir != Vector3.ZERO else (_raw if _raw.length() > 0.2 else Vector3.ZERO)
			intent.set_action(_queued, _queued_power, aim, _pass_target)
			_pass_target = null
			_pass_dir = Vector3.ZERO
		else:
			intent.set_action(_queued, _queued_power, _raw if _raw.length() > 0.2 else Vector3.ZERO)
		intent.lofted = _queued_lofted
		_queued = PlayerIntent.Action.NONE
		_queued_lofted = false
		_aim = Vector3.ZERO


func _update_charge(action: StringName, hold: float, delta: float, kind: PlayerIntent.Action) -> float:
	if Input.is_action_just_pressed(action):
		hold = 0.0
	elif hold >= 0.0 and Input.is_action_pressed(action):
		hold += delta
		if hold >= MAX_CHARGE_TIME:
			_queue(kind, 1.0)
			return -1.0
	if hold >= 0.0 and not Input.is_action_pressed(action):
		_queue(kind, clampf(hold / MAX_CHARGE_TIME, 0.0, 1.0))
		return -1.0
	return hold


func _queue(a: PlayerIntent.Action, power: float) -> void:
	_queued = a
	_queued_power = power
	_queued_lofted = false
	if a == PlayerIntent.Action.PASS and _lob_pending:
		_queued_lofted = true
	if a == PlayerIntent.Action.SHOOT and _chip_pending:
		_queued_lofted = true
	if a == PlayerIntent.Action.PASS:
		_lob_pending = false
	if a == PlayerIntent.Action.SHOOT:
		_chip_pending = false


## O jogador controlado está com a bola (ou com ela ao alcance do pé, ou com
## um passe vindo para ele)? Define o significado dos botões.
func has_ball_context() -> bool:
	if current_player == null or current_player.ball == null:
		return true
	var bc := current_player.ball_control
	var b := current_player.ball
	if b.possessor == null and b.pass_target == current_player and b.in_play:
		return true # passe a caminho: PASSE/CHUTE de primeira, sem trocar
	if b.possessor == null and b.in_play and b.last_toucher != null \
			and b.last_toucher.team == current_player.team and b.flat_velocity().length() > 1.0:
		return true # bola do MEU time rolando (passe ainda não chegou): botões de ataque
	return bc.has_ball() or (bc.can_kick() and b.possessor == null)


## Suaviza a direção do analógico: inversões claras (> 135°, mantidas um
## instante) passam direto — viram "puxada" de sola; o resto gira numa
## velocidade natural, então chacoalhar o analógico não embaralha o corpo.
func _smooth_input(raw: Vector3, delta: float) -> Vector3:
	var l := raw.length()
	if l < 0.1:
		_smooth = Vector3.ZERO
		_raw_steady = 0.0
		return Vector3.ZERO
	var dir := raw / l
	if _raw_dir != Vector3.ZERO and dir.dot(_raw_dir) > 0.94:
		_raw_steady += delta
	else:
		_raw_steady = 0.0
		_raw_dir = dir
	if _smooth == Vector3.ZERO:
		_smooth = dir
	else:
		var ang := _smooth.signed_angle_to(dir, Vector3.UP)
		if absf(ang) > deg_to_rad(135.0):
			if _raw_steady > 0.06:
				_smooth = dir # inversão de verdade
		else:
			var with_ball := current_player != null and current_player.ball_control.has_ball()
			var rate := (7.5 if with_ball else 12.0) * delta
			_smooth = _smooth.rotated(Vector3.UP, clampf(ang, -rate, rate)).normalized()
	return _smooth * l


## BUSCAR: para onde correr. Bola livre → ponto onde ela vai estar (corre
## forte longe, desacelera perto para dominar). Adversário com a bola → fica na
## frente dele, entre a bola e o meu gol.
func _chase_direction() -> Vector3:
	var p := current_player
	var b := p.ball
	var target: Vector3
	if b.possessor != null and b.possessor.team != p.team:
		# CERCAR: chega rápido e, perto, fica na frente dele (entre a bola e o
		# meu gol) acompanhando de lado, sem dar o bote sozinho — o bote é no
		# DESARME, na hora certa.
		var c := b.possessor.global_position
		var own_goal := Field.goal_center(p.team)
		var bp := b.global_position
		bp.y = 0.0
		var goal_dir := (own_goal - c)
		goal_dir.y = 0.0
		goal_dir = goal_dir.normalized()
		target = c + goal_dir * 1.15 + b.possessor.get_flat_velocity() * 0.25
		var dd := Vector2(c.x - p.global_position.x, c.z - p.global_position.z).length()
		if dd < 2.6:
			var dir := target - p.global_position
			dir.y = 0.0
			_chase_sprint = false
			if dir.length() < 0.15:
				return Vector3.ZERO
			# acompanha na velocidade dele (contenção)
			var need := clampf(dir.length() / 0.6, 0.0, 1.0)
			var follow := b.possessor.get_flat_velocity().length() / maxf(p.jog_speed, 0.1)
			return dir.normalized() * clampf(maxf(need, follow), 0.25, 1.0)
	else:
		target = b.predict_ground_position(0.0)
		for i in 4:
			var t := p.global_position.distance_to(target) / maxf(p.sprint_speed, 0.1)
			target = b.predict_ground_position(t)
	var d := target - p.global_position
	d.y = 0.0
	if d.length() < 0.25:
		return Vector3.ZERO
	_chase_sprint = d.length() > 1.4
	# Perto: devagar para dominar sem atropelar a bola.
	return d.normalized() * clampf(d.length() / 1.0, 0.4, 1.0)


func _near_ball() -> bool:
	return current_player.ball != null and current_player.ball_control.ball_distance() < 2.0


func _wants_tackle() -> bool:
	if current_player == null or current_player.ball == null:
		return false
	return not current_player.ball_control.has_ball() and current_player.ball_control.find_tackle_target() != null


## Converte o analógico (tela) em direção no mundo, relativa à câmera.
func _to_world(v: Vector2) -> Vector3:
	if v.length() < 0.01:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera != null:
		right = camera.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		forward = Vector3.UP.cross(right).normalized()
	var w := right * v.x + forward * (-v.y)
	return w.limit_length(1.0)
