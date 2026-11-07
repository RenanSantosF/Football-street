class_name PlayerContactSolver
extends Node
## CONTATO CORPO A CORPO entre jogadores (roda depois que todos se moveram).
##
## Antes as cápsulas dos CharacterBody3D colidiam entre si: uma subia na outra
## (micro-saltos), travavam lado a lado e, por cima disso, cada jogador se
## teletransportava 52% da sobreposição (104% no total → tremor). Agora as
## cápsulas só colidem com o cenário e o contato é resolvido aqui, uma vez por
## par, como dois corpos com massa:
##  - impulso na direção do contato (troca de quantidade de movimento, quase
##    inelástico: corpo humano não quica);
##  - atrito tangencial leve (ombro a ombro: um arrasta um pouco o outro);
##  - correção de posição suave, dividida pela massa e respeitando paredes
##    (move_and_collide), sem atravessar e sem grudar;
##  - o impulso recebido tira o EQUILÍBRIO: trombada forte = desequilíbrio,
##    tropeço e, para quem conduz, bola espirrando do pé.

const RESTITUTION := 0.06
const TANGENT_FRICTION := 0.18
## Folga de sobreposição tolerada (m) e fração corrigida por quadro.
const SLOP := 0.008
const POSITION_FIX := 0.5
const MAX_FIX_PER_FRAME := 0.06

var match_manager: MatchManager


func _physics_process(delta: float) -> void:
	if match_manager == null:
		return
	var ps := match_manager.players
	var n := ps.size()
	for i in n:
		var a: Player = ps[i]
		if not _solid(a):
			continue
		for j in range(i + 1, n):
			var b: Player = ps[j]
			if _solid(b):
				_solve_pair(a, b, delta)


static func _solid(p: Player) -> bool:
	return p != null and p.active and p.is_physics_processing() and p.is_body_solid()


func _solve_pair(a: Player, b: Player, _delta: float) -> void:
	var d := a.global_position - b.global_position
	if absf(d.y) > 1.0:
		return
	d.y = 0.0
	var min_d := a.body_radius() + b.body_radius()
	var dist_sq := d.length_squared()
	if dist_sq >= min_d * min_d:
		return
	var dist := sqrt(dist_sq)
	var nrm: Vector3 # de B para A
	if dist > 0.0001:
		nrm = d / dist
	else:
		nrm = a.facing.cross(Vector3.UP).normalized()
	# direção "do outro para mim": nrm para A, -nrm para B
	var ma := a.effective_mass(nrm)
	var mb := b.effective_mass(-nrm)
	var inv_a := 1.0 / ma
	var inv_b := 1.0 / mb
	var inv_sum := inv_a + inv_b

	# --- Impulso normal (velocidades no plano) ---
	var va := a.get_flat_velocity()
	var vb := b.get_flat_velocity()
	var rel := va - vb
	var vn := rel.dot(nrm)
	var dv_a := 0.0
	var dv_b := 0.0
	if vn < 0.0:
		var j := -(1.0 + RESTITUTION) * vn / inv_sum
		var ja := nrm * (j * inv_a)
		var jb := -nrm * (j * inv_b)
		# Atrito tangencial (ombro a ombro): limitado pelo cone de Coulomb.
		var vt := rel - nrm * vn
		var vt_len := vt.length()
		if vt_len > 0.05:
			var jt := minf(vt_len / inv_sum, j * TANGENT_FRICTION)
			var t_dir := vt / vt_len
			ja -= t_dir * (jt * inv_a)
			jb += t_dir * (jt * inv_b)
		a.velocity.x += ja.x
		a.velocity.z += ja.z
		b.velocity.x += jb.x
		b.velocity.z += jb.z
		dv_a = ja.length()
		dv_b = jb.length()

	# --- Separação de posição (sem teletransporte brusco) ---
	var overlap := min_d - dist
	if overlap > SLOP:
		var fix := minf((overlap - SLOP) * POSITION_FIX, MAX_FIX_PER_FRAME)
		a.push_body(nrm * (fix * inv_a / inv_sum))
		b.push_body(-nrm * (fix * inv_b / inv_sum))

	# --- Equilíbrio: quem recebeu mais impulso sente a trombada ---
	if dv_a > 0.25:
		a.receive_body_impact(dv_a, nrm, b)
	if dv_b > 0.25:
		b.receive_body_impact(dv_b, -nrm, a)
	a.note_body_contact(b, nrm)
	b.note_body_contact(a, -nrm)
