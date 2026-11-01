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

const MAX_CHARGE_TIME := 0.6

@export var camera: Camera3D

var current_player: Player = null

var _move := Vector3.ZERO
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
var _last_dribble_tap := -10.0
## Segurando BUSCAR (sem a bola): o jogador corre sozinho atrás da bola.
var chasing := false
var _chase_sprint := false
## Direção suavizada do analógico (girar rápido de um lado para o outro não
## deixa o jogador "perdido": o corpo acompanha numa velocidade humana).
var _smooth := Vector3.ZERO
var _raw_dir := Vector3.ZERO
var _raw_steady := 0.0
var _last_auto_poke := -10.0


func _ready() -> void:
	process_priority = -10 # roda antes dos jogadores


func _physics_process(delta: float) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_move = _smooth_input(_to_world(v), delta)
	_sprint = Input.is_action_pressed("sprint")
	# Segurando CHUTE com a bola (ou perto dela): o analógico vira a MIRA e o
	# jogador para; a direção escolhida é exatamente para onde a bola vai.
	var was_aiming := _aiming
	_aiming = _shoot_hold >= 0.0 and current_player != null and _near_ball()
	if _aiming:
		if not was_aiming:
			_aim = current_player.facing
		if _move.length() > 0.25:
			_aim = _move.normalized()
		_move = Vector3.ZERO
		aim_changed.emit(true, _aim, clampf(_shoot_hold / MAX_CHARGE_TIME, 0.0, 1.0))
	elif was_aiming:
		aim_changed.emit(false, _aim, 0.0)

	if Input.is_action_just_pressed("switch_player"):
		switch_requested.emit()
	var now := Time.get_ticks_msec() / 1000.0
	if Input.is_action_just_pressed("dribble"):
		if has_ball_context():
			_queue(PlayerIntent.Action.DRIBBLE, 1.0)
		elif now - _last_dribble_tap < 0.35:
			# Dois toques em BUSCAR = BOTE (estica o pé; errar e acertar o
			# adversário é falta).
			_queue(PlayerIntent.Action.DRIBBLE, 1.0)
		_last_dribble_tap = now
	chasing = not has_ball_context() and Input.is_action_pressed("dribble")
	if chasing and current_player != null and current_player.ball != null:
		var auto := _chase_direction()
		if _move.length() > 0.3 and auto.length() > 0.05:
			# Analógico junto com BUSCAR: escolhe por onde chegar (ex.: dar a
			# volta e pegar o adversário de frente, não por trás).
			var mix := (auto.normalized() * 0.55 + _move.normalized() * 0.45).normalized()
			_move = mix * maxf(auto.length(), 0.6)
		else:
			_move = auto
		_sprint = _sprint or _chase_sprint
		# Chegou no adversário com a bola: dá o bote sozinho (de frente é mais fácil).
		var b := current_player.ball
		if b.possessor != null and b.possessor.team != current_player.team \
				and now - _last_auto_poke > 0.9 and current_player.state == Player.State.MOVE:
			var dd := b.possessor.global_position - current_player.global_position
			dd.y = 0.0
			if dd.length() < 1.05:
				_last_auto_poke = now
				_queue(PlayerIntent.Action.DRIBBLE, 1.0)

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


func fill_intent(_player: Player, intent: PlayerIntent, _delta: float) -> void:
	intent.move = _move
	intent.sprint = _sprint
	if _queued != PlayerIntent.Action.NONE:
		if _queued == PlayerIntent.Action.SHOOT and _aim != Vector3.ZERO and _queued_power > 0.0:
			intent.set_action(_queued, _queued_power, _aim)
			intent.precise = true
		else:
			intent.set_action(_queued, _queued_power, _move if _move.length() > 0.2 else Vector3.ZERO)
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
		var c := b.possessor.global_position
		var own_goal := Field.goal_center(p.team)
		target = c + (own_goal - c).normalized() * 0.9
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
