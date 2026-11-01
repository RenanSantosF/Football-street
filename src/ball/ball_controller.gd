class_name Ball
extends RigidBody3D
## Bola com física própria (RigidBody3D).
##
## A bola NUNCA é presa ao pé: o jogador só altera sua velocidade através de
## toques (touch), chutes (kick) e desvios. Entre um toque e outro ela rola,
## quica e colide livremente com asfalto, meio-fio, muros e traves.
##
## "possessor" é apenas uma informação de regra (quem está conduzindo), não um
## vínculo físico.

const RADIUS := 0.11

@export_group("Física")
## Desaceleração ao rolar nos bloquinhos (m/s²): piso irregular segura a bola.
@export var rolling_resistance := 1.45
## Arrasto do ar (quadrático): a = k * v².
@export var air_drag := 0.012
## Efeito Magnus (curva por rotação).
@export var magnus_strength := 0.0025
## Quanto a rotação converge para a rolagem sem deslizar quando no chão.
@export var roll_alignment := 8.0

var possessor: Player = null
var last_toucher: Player = null
var in_play := true
var restricted_team := -1
## Reinício: só este jogador pode tocar na bola até ela ser passada.
var restricted_player: Player = null
var grounded := false

var _restrict_timer := 0.0
var _ignore_player: Player = null
var _ignore_timer := 0.0
var _pending_velocity := false
var _new_linear := Vector3.ZERO
var _new_angular := Vector3.ZERO
var _pending_teleport := false
var _teleport_position := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _ignore_timer > 0.0:
		_ignore_timer -= delta
		if _ignore_timer <= 0.0:
			_ignore_player = null
	if _restrict_timer > 0.0:
		_restrict_timer -= delta
		if _restrict_timer <= 0.0:
			restricted_team = -1


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		_pending_teleport = false
		var t := state.transform
		t.origin = _teleport_position
		state.transform = t
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
	if _pending_velocity:
		_pending_velocity = false
		state.linear_velocity = _new_linear
		state.angular_velocity = _new_angular

	grounded = false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y > 0.7:
			grounded = true
			break

	var dt := state.step
	var v := state.linear_velocity
	var w := state.angular_velocity
	var speed := v.length()

	# Arrasto do ar.
	if speed > 0.05:
		v -= v / speed * air_drag * speed * speed * dt

	if grounded and absf(v.y) < 0.6:
		# Resistência ao rolamento.
		var h := Vector3(v.x, 0.0, v.z)
		var hs := h.length()
		var dec := rolling_resistance * dt
		h = Vector3.ZERO if hs <= dec else h - h / hs * dec
		v.x = h.x
		v.z = h.z
		# Rotação tende à rolagem pura (ω = UP × v / r).
		var roll_w := Vector3.UP.cross(h) / RADIUS
		w = w.lerp(roll_w, clampf(roll_alignment * dt, 0.0, 1.0))
	elif not grounded:
		# Efeito Magnus no ar.
		v += w.cross(v) * magnus_strength * dt

	state.linear_velocity = v
	state.angular_velocity = w


## Velocidade atual, já considerando um toque/chute aplicado neste frame.
func velocity_now() -> Vector3:
	return _new_linear if _pending_velocity else linear_velocity


func flat_velocity() -> Vector3:
	var v := velocity_now()
	return Vector3(v.x, 0.0, v.z)


## Chute/passe: a bola fica livre e o chutador não pode reaver por um instante.
func kick(velocity: Vector3, spin: Vector3, by: Player, ignore_time := 0.3) -> void:
	release()
	last_toucher = by
	if by != null:
		set_ignore(by, ignore_time)
		if restricted_team >= 0 and by.team == restricted_team:
			restricted_team = -1
			_restrict_timer = 0.0
		if restricted_player == by:
			restricted_player = null
	_set_velocity(velocity, spin)


## Toque de condução/domínio/desvio: muda a velocidade sem alterar a posse.
func touch(velocity: Vector3, by: Player) -> void:
	last_toucher = by
	var h := Vector3(velocity.x, 0.0, velocity.z)
	_set_velocity(velocity, Vector3.UP.cross(h) / RADIUS)


func claim(player: Player) -> void:
	if possessor == player:
		return
	var old := possessor
	possessor = player
	last_toucher = player
	GameEvents.possession_changed.emit(player, old)


func release() -> void:
	if possessor == null:
		return
	var old := possessor
	possessor = null
	GameEvents.possession_changed.emit(null, old)


## Coloca a bola parada num ponto (reinícios de jogo).
func place_at(pos: Vector3) -> void:
	release()
	restricted_player = null
	_pending_velocity = false
	_new_linear = Vector3.ZERO
	_teleport_position = Vector3(pos.x, maxf(pos.y, RADIUS), pos.z)
	_pending_teleport = true
	global_position = _teleport_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Só [param team] pode tocar na bola por [param time] segundos (ou até chutar).
func restrict_to(team: int, time: float) -> void:
	restricted_team = team
	_restrict_timer = time


func set_ignore(player: Player, time: float) -> void:
	_ignore_player = player
	_ignore_timer = time


func is_ignoring(player: Player) -> bool:
	return _ignore_timer > 0.0 and _ignore_player == player


func distance_to_possessor() -> float:
	if possessor == null:
		return INF
	var d := global_position - possessor.global_position
	return Vector2(d.x, d.z).length()


func can_be_claimed_by(player: Player) -> bool:
	if not in_play or is_ignoring(player):
		return false
	if restricted_player != null and player != restricted_player:
		return false
	if restricted_team >= 0 and player.team != restricted_team:
		return false
	if possessor == null or possessor == player:
		return true
	# Bola "espirrada" longe de quem conduzia pode ser roubada.
	return distance_to_possessor() > 1.1


func can_be_kicked_by(player: Player) -> bool:
	return can_be_claimed_by(player)


## Previsão simples da posição no chão daqui a [param t] segundos (para a IA).
func predict_ground_position(t: float) -> Vector3:
	var p := global_position
	var h := flat_velocity()
	var s := h.length()
	var base := Vector3(p.x, 0.0, p.z)
	if s < 0.01:
		return base
	var tt := minf(t, s / rolling_resistance)
	return base + h / s * (s * tt - 0.5 * rolling_resistance * tt * tt)


func _set_velocity(linear: Vector3, angular: Vector3) -> void:
	_new_linear = linear
	_new_angular = angular
	_pending_velocity = true
