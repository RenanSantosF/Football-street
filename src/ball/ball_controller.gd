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
const LOSE_TEAMMATE_DIST := 2.4

## A bola bateu em algo (chão, meio-fio, cerca, trave): [param strength] é a
## variação de velocidade do choque (m/s), [param surface] o material
## ("ground", "curb", "wood", "wire", "iron", "brick", "post", "other").
signal impact(position: Vector3, strength: float, surface: StringName)

@export_group("Física")
## Desaceleração ao rolar nos bloquinhos (m/s²): piso irregular segura a bola.
## Bola de rua pesada + bloquinhos com atrito: rola menos e para com firmeza.
@export var rolling_resistance := 2.22
## Bola no pé de alguém (conduzindo): rola menos, como na grama — o jogador
## tem mais domínio e a bola não "foge" entre os toques.
@export var possessed_rolling_factor := 1.28


func current_rolling() -> float:
	return rolling_resistance * (possessed_rolling_factor if possessor != null else 1.0)
## Arrasto do ar (quadrático): a = k * v².
@export var air_drag := 0.016
## Efeito Magnus (curva por rotação).
@export var magnus_strength := 0.0025
## Quanto a rotação converge para a rolagem sem deslizar quando no chão.
@export var roll_alignment := 9.0

var possessor: Player = null
var last_toucher: Player = null
var in_play := true
var restricted_team := -1
## Reinício: só este jogador pode tocar na bola até ela ser passada.
var restricted_player: Player = null
## Companheiro para quem o último passe foi feito (ele vem ao encontro).
var pass_target: Player = null
## O último passe foi em PROFUNDIDADE (o recebedor segue correndo para a
## frente em vez de voltar ao encontro da bola).
var through_pass := false
## Ponto de encontro planejado do passe em profundidade.
var through_dest := Vector3.ZERO
var grounded := false
## Reinício: bola parada no lugar até o batedor passar (ninguém empurra).
var held := false
var _hold_pos := Vector3.ZERO

var _restrict_timer := 0.0
var _ignore_player: Player = null
var _ignore_timer := 0.0
var _pending_velocity := false
var _new_linear := Vector3.ZERO
var _new_angular := Vector3.ZERO
var _pending_teleport := false
var _teleport_position := Vector3.ZERO
var _last_out_v := Vector3.ZERO
var _impact_cd := 0.0
## Variação de velocidade do último toque/chute (m/s), para o som.
var last_touch_dv := 0.0


func _physics_process(delta: float) -> void:
	if _ignore_timer > 0.0:
		_ignore_timer -= delta
		if _ignore_timer <= 0.0:
			_ignore_player = null
	# Passe que morreu longe de quem ia receber: bola livre para todos.
	if pass_target != null and possessor == null and flat_velocity().length() < 0.4:
		var d := pass_target.global_position - global_position
		if Vector2(d.x, d.z).length() > 1.5:
			pass_target = null
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
	var touched := false
	if _pending_velocity:
		_pending_velocity = false
		touched = true
		state.linear_velocity = _new_linear
		state.angular_velocity = _new_angular
	if held:
		var th := state.transform
		th.origin = _hold_pos
		state.transform = th
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return

	grounded = false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y > 0.7:
			grounded = true
			break
	if touched:
		_last_out_v = state.linear_velocity # toque/chute não é choque
	else:
		_detect_impact(state)

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
		var dec := current_rolling() * dt
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
	_last_out_v = v


## Choque com o cenário: a velocidade que o motor de física devolveu é bem
## diferente da que saiu do passo anterior e há contato (quique, batida).
func _detect_impact(state: PhysicsDirectBodyState3D) -> void:
	_impact_cd = maxf(_impact_cd - state.step, 0.0)
	var v := state.linear_velocity
	var dv := v - _last_out_v
	if state.get_contact_count() == 0 or _impact_cd > 0.0:
		return
	var best := -1
	var best_n := Vector3.UP
	for i in state.get_contact_count():
		best = i
		best_n = state.get_contact_local_normal(i)
		if best_n.y < 0.7:
			break # cerca/trave tem prioridade sobre o chão
	var strength := 0.0
	if best_n.y > 0.7:
		# quique: só conta a componente vertical que inverteu
		if _last_out_v.y < -0.7 and v.y > _last_out_v.y + 0.5:
			strength = v.y - _last_out_v.y
	else:
		strength = dv.length()
		if strength < 0.6:
			return
	if strength < 0.6:
		return
	_impact_cd = 0.06
	impact.emit(state.get_contact_collider_position(best), strength, _surface_of(state, best))


func _surface_of(state: PhysicsDirectBodyState3D, i: int) -> StringName:
	var col := state.get_contact_collider_object(i)
	if col is CollisionObject3D:
		var co := col as CollisionObject3D
		var owner_id := co.shape_find_owner(state.get_contact_collider_shape(i))
		var shape_node := co.shape_owner_get_owner(owner_id) as Node
		if shape_node != null and shape_node.has_meta("surface"):
			return StringName(shape_node.get_meta("surface"))
	return &"ground" if state.get_contact_local_normal(i).y > 0.7 else &"other"


## Velocidade atual, já considerando um toque/chute aplicado neste frame.
func velocity_now() -> Vector3:
	return _new_linear if _pending_velocity else linear_velocity


func flat_velocity() -> Vector3:
	var v := velocity_now()
	return Vector3(v.x, 0.0, v.z)


## Chute/passe: a bola fica livre e o chutador não pode reaver por um instante.
func kick(velocity: Vector3, spin: Vector3, by: Player, ignore_time := 0.3) -> void:
	held = false
	through_pass = false
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
	if held:
		return # reinício: a bola só sai com o passe
	last_toucher = by
	var h := Vector3(velocity.x, 0.0, velocity.z)
	_set_velocity(velocity, Vector3.UP.cross(h) / RADIUS)


func claim(player: Player) -> void:
	pass_target = null
	through_pass = false
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
	held = false
	release()
	restricted_player = null
	pass_target = null
	_pending_velocity = false
	_new_linear = Vector3.ZERO
	_teleport_position = Vector3(pos.x, maxf(pos.y, RADIUS), pos.z)
	_pending_teleport = true
	global_position = _teleport_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Trava a bola parada onde está (reinício) até o próximo chute/passe.
func hold_here() -> void:
	held = true
	_hold_pos = Vector3(_teleport_position.x, RADIUS, _teleport_position.z) if _pending_teleport \
		else Vector3(global_position.x, RADIUS, global_position.z)
	_new_linear = Vector3.ZERO
	_pending_velocity = false


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
	if possessor == null and pass_target != null and pass_target != player \
			and pass_target.team == player.team and pass_target.active:
		return false # passe para um companheiro: só ele pega (adversário pode cortar)
	if possessor == null or possessor == player:
		return true
	# Bola "espirrada" longe de quem conduzia pode ser roubada (companheiro
	# só pega se ela escapou de vez).
	if possessor.team == player.team:
		return distance_to_possessor() > LOSE_TEAMMATE_DIST
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
	var rr := current_rolling()
	var tt := minf(t, s / rr)
	return base + h / s * (s * tt - 0.5 * rr * tt * tt)


func _set_velocity(linear: Vector3, angular: Vector3) -> void:
	last_touch_dv = (linear - velocity_now()).length()
	_new_linear = linear
	_new_angular = angular
	_pending_velocity = true
