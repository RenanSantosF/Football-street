class_name LeanModifier
extends SkeletonModifier3D
## Biomecânica corporal e de membros inferiores:
## 1) Postura ereta e atlética de jogador de futebol (remove a curvatura excessiva
##    do UpperChest nas corridas da UAL sem quebrar a coluna e mantém a cabeça
##    nivelada olhando para o campo, sem levantar para o céu).
## 2) Trava do pé de apoio no solo (Stance Foot Lock): impede que o pé plantado
##    deslize no gramado durante a passada.
## 3) Cinemática Inversa (IK) analítica de 2 ossos (coxa + canela) com preservação
##    do plano anatômico de flexão do joelho (zero torção axial) e orientação da
##    superfície do pé (chapa, peito do pé, parte externa, sola) no contato com a bola.

var amount := 0.0
var accel_lean := 0.0
var turn_lean := 0.0

const ACCEL_SPINE_DEG := 3.5
const TURN_BANK_DEG := 4.5
const TURN_YAW_DEG := 3.5

const STANCE_Y_MAX := 0.106
const MIN_ANKLE_Y := 0.058

var _hips := -2
var _spine := -2
var _chest := -2
var _upper_chest := -2
var _neck := -2
var _head := -2

var _hip_bones := {1.0: -1, -1.0: -1}
var _knee_bones := {1.0: -1, -1.0: -1}
var _foot_bones := {1.0: -1, -1.0: -1}
var _toe_bones := {1.0: -1, -1.0: -1}

## Alvo de contato do pé com a bola (mundo) e peso 0..1 por lado (+1 dir, -1 esq).
var _ball_target := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _ball_weight := {1.0: 0.0, -1.0: 0.0}
var _ball_mode := {1.0: 0, -1.0: 0}
var _ball_forward := {1.0: Vector3.FORWARD, -1.0: Vector3.FORWARD}

## Estado da trava do pé de apoio no chão (evita patinação/deslize no solo).
var _planted := {1.0: false, -1.0: false}
var _plant_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _stance_weight := {1.0: 0.0, -1.0: 0.0}
var _prev_skel_origin := Vector3.ZERO

## Posições da animação pura (antes da IK) em coordenadas de mundo.
var _raw_ankle_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _raw_toe_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _raw_hip_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}

var _raw_local_poses := {} # bone_idx -> Transform3D (pose pura da animação)
var _anim_just_applied := true
var _ik_dirty := false
var _applying := false


func notify_animation_applied() -> void:
	_anim_just_applied = true


func set_foot_ik(side: float, world_pos: Vector3, weight: float, forward: Vector3, mode: int = 0) -> void:
	var s := 1.0 if side >= 0.0 else -1.0
	var w := clampf(weight, 0.0, 1.0)
	if _ball_target[s].distance_squared_to(world_pos) > 0.00001 \
			or absf(_ball_weight[s] - w) > 0.0005 \
			or _ball_mode[s] != mode:
		_ik_dirty = true
	_ball_target[s] = world_pos
	_ball_weight[s] = w
	_ball_forward[s] = forward
	_ball_mode[s] = mode


func get_raw_ankle_world(side: float) -> Vector3:
	var s := 1.0 if side >= 0.0 else -1.0
	if _raw_local_poses.is_empty():
		ensure_updated()
	return _raw_ankle_world[s]


func get_raw_toe_world(side: float) -> Vector3:
	var s := 1.0 if side >= 0.0 else -1.0
	if _raw_local_poses.is_empty():
		ensure_updated()
	return _raw_toe_world[s]


func _cache_bones(sk: Skeleton3D) -> void:
	_hips = sk.find_bone("Hips")
	_spine = sk.find_bone("Spine")
	_chest = sk.find_bone("Chest")
	_upper_chest = sk.find_bone("UpperChest")
	_neck = sk.find_bone("Neck")
	_head = sk.find_bone("Head")
	for side in [1.0, -1.0]:
		var prefix := "Right" if side > 0.0 else "Left"
		_hip_bones[side] = sk.find_bone(prefix + "UpperLeg")
		_knee_bones[side] = sk.find_bone(prefix + "LowerLeg")
		_foot_bones[side] = sk.find_bone(prefix + "Foot")
		_toe_bones[side] = sk.find_bone(prefix + "Toes")


## Garante que a IK esteja atualizada quando o alvo do pé muda durante o passo físico.
func ensure_updated() -> void:
	if _applying:
		return
	if not _ik_dirty and not _raw_local_poses.is_empty():
		return
	var sk := get_skeleton()
	if sk == null:
		return
	_ik_dirty = false
	sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)


func _process_modification() -> void:
	if _applying:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	_applying = true
	if _spine == -2:
		_cache_bones(sk)

	var tracked_bones := [
		_hips, _spine, _chest, _upper_chest, _neck, _head,
		_hip_bones[1.0], _knee_bones[1.0], _foot_bones[1.0], _toe_bones[1.0],
		_hip_bones[-1.0], _knee_bones[-1.0], _foot_bones[-1.0], _toe_bones[-1.0],
	]
	var is_new_anim := _anim_just_applied or _raw_local_poses.is_empty()
	if is_new_anim:
		_anim_just_applied = false
		_raw_local_poses.clear()
		for b in tracked_bones:
			if b >= 0:
				_raw_local_poses[b] = sk.get_bone_pose(b)
	else:
		for b in tracked_bones:
			if b >= 0 and _raw_local_poses.has(b):
				sk.set_bone_pose(b, _raw_local_poses[b])

	# 1. Postura atlética do tronco e cabeça nivelada:
	#    Distribui a curvatura entre Spine, Chest e UpperChest (evitando a "quebra"
	#    no UpperChest das animações UAL) e compensa exatamente no Neck/Head para
	#    que a cabeça olhe sempre para a frente/campo, nunca levantada para o céu.
	_apply_athletic_posture(sk)

	# 2. Guarda as posições da animação antes de aplicar IK das pernas.
	var sk_xform := sk.global_transform
	var sk_inv := sk_xform.affine_inverse()
	var dt := 1.0 / float(max(Engine.physics_ticks_per_second, 30))
	var teleported := false
	if is_new_anim:
		teleported = _prev_skel_origin != Vector3.ZERO and sk_xform.origin.distance_to(_prev_skel_origin) > 0.45
		_prev_skel_origin = sk_xform.origin

	for side in [1.0, -1.0]:
		var f_idx: int = _foot_bones[side]
		var h_idx: int = _hip_bones[side]
		var t_idx: int = _toe_bones[side]
		if f_idx < 0 or h_idx < 0:
			continue
		var anim_ankle_w := sk_xform * sk.get_bone_global_pose(f_idx).origin
		var anim_hip_w := sk_xform * sk.get_bone_global_pose(h_idx).origin
		_raw_ankle_world[side] = anim_ankle_w
		_raw_hip_world[side] = anim_hip_w
		if t_idx >= 0:
			var tw := sk_xform * sk.get_bone_global_pose(t_idx).origin
			_raw_toe_world[side] = tw + (tw - anim_ankle_w).normalized() * 0.06
		else:
			_raw_toe_world[side] = anim_ankle_w

		var bw: float = _ball_weight[side]
		if is_new_anim:
			# Atualiza detecção de pé plantado no solo (Stance Foot Lock) 1x por avanço de animação.
			var in_stance := anim_ankle_w.y < STANCE_Y_MAX and not teleported
			if teleported or bw > 0.15:
				_planted[side] = false
				_stance_weight[side] = move_toward(_stance_weight[side], 0.0, dt * 18.0)
			elif in_stance:
				if not _planted[side]:
					_planted[side] = true
					_plant_world[side] = anim_ankle_w
				var hip_flat := Vector2(anim_hip_w.x, anim_hip_w.z)
				var plant_flat := Vector2(_plant_world[side].x, _plant_world[side].z)
				if plant_flat.distance_to(hip_flat) > 0.65:
					_plant_world[side] = anim_ankle_w
				_plant_world[side].y = maxf(anim_ankle_w.y, MIN_ANKLE_Y)
				_stance_weight[side] = 1.0
			else:
				_planted[side] = false
				_stance_weight[side] = move_toward(_stance_weight[side], 0.0, dt * 16.0)

		# 3. Determina o alvo final do tornozelo (combina trava de solo e IK da bola).
		var target_w := anim_ankle_w
		var total_w := 0.0
		var mode_use := 0
		if bw > 0.001:
			target_w = anim_ankle_w.lerp(_ball_target[side], bw)
			total_w = bw
			mode_use = _ball_mode[side]
		elif _stance_weight[side] > 0.001:
			var locked := Vector3(_plant_world[side].x, maxf(anim_ankle_w.y, MIN_ANKLE_Y), _plant_world[side].z)
			target_w = anim_ankle_w.lerp(locked, _stance_weight[side])
			total_w = _stance_weight[side]
		elif anim_ankle_w.y < MIN_ANKLE_Y:
			target_w.y = MIN_ANKLE_Y
			total_w = 1.0

		if total_w > 0.001:
			target_w.y = maxf(target_w.y, MIN_ANKLE_Y)
			_solve_two_bone_leg(sk, sk_inv, side, target_w, bw, mode_use)

	_ik_dirty = false
	_applying = false


func _apply_athletic_posture(sk: Skeleton3D) -> void:
	if _hips < 0 or _spine < 0 or _chest < 0 or _upper_chest < 0 or _neck < 0 or _head < 0:
		return
	var e_hips := sk.get_bone_pose_rotation(_hips).get_euler()
	var e_spine := sk.get_bone_pose_rotation(_spine).get_euler()
	var e_chest := sk.get_bone_pose_rotation(_chest).get_euler()
	var e_uchest := sk.get_bone_pose_rotation(_upper_chest).get_euler()

	# Em quedas/mergulhos (quadril inclinado mais de 42°), preserva a animação pura.
	if absf(e_hips.x) > deg_to_rad(42.0) or absf(e_hips.z) > deg_to_rad(42.0):
		return

	# Compartilha 30% da curvatura local do UpperChest com o Spine (soma líquida = 0)
	# para eliminar o vinco brusco no UpperChest mesmo parado/andando.
	var share_x := clampf(e_uchest.x * 0.30, deg_to_rad(-8.0), deg_to_rad(8.0))

	# Limita a inclinação frontal acumulada do tronco para postura ereta de jogador.
	var raw_torso_x := e_hips.x + e_spine.x + e_chest.x + e_uchest.x
	var target_max_x := deg_to_rad(14.0 + 5.0 * amount) + deg_to_rad(ACCEL_SPINE_DEG) * accel_lean
	var excess_x := maxf(0.0, raw_torso_x - target_max_x)
	var corr_x := excess_x * 0.82

	# Suaviza a torção lateral exagerada do UpperChest no trote/corrida.
	var corr_uc_y := -e_uchest.y * 0.42 if absf(e_uchest.y) > deg_to_rad(8.0) else 0.0
	var corr_uc_z := -e_uchest.z * 0.50 if absf(e_uchest.z) > deg_to_rad(3.0) else 0.0

	var bank_rad := deg_to_rad(TURN_BANK_DEG) * turn_lean
	var yaw_rad := deg_to_rad(TURN_YAW_DEG) * turn_lean

	_rotate_bone_local(sk, _spine,
		share_x - corr_x * 0.25,
		corr_uc_y * 0.20 + yaw_rad * 0.35,
		bank_rad * 0.35)
	_rotate_bone_local(sk, _chest,
		-corr_x * 0.30,
		corr_uc_y * 0.20 + yaw_rad * 0.35,
		bank_rad * 0.35)
	_rotate_bone_local(sk, _upper_chest,
		-share_x - corr_x * 0.45,
		corr_uc_y * 0.60 + yaw_rad * 0.30,
		corr_uc_z + bank_rad * 0.30)

	# Compensa no pescoço/cabeça na direção OPOSTA (+corr_x = olhar p/ baixo/frente)
	# para que erguer o tronco NUNCA jogue a cabeça para trás olhando para o céu.
	_rotate_bone_local(sk, _neck,
		corr_x * 0.55,
		-corr_uc_y * 0.50 - yaw_rad * 0.25,
		-corr_uc_z * 0.50 - bank_rad * 0.25)
	_rotate_bone_local(sk, _head,
		corr_x * 0.33,
		-corr_uc_y * 0.30 - yaw_rad * 0.25,
		-corr_uc_z * 0.30 - bank_rad * 0.25)


func _rotate_bone_local(sk: Skeleton3D, bone: int, pitch_x: float, yaw_y: float, roll_z: float) -> void:
	if bone < 0:
		return
	var cur_q := sk.get_bone_pose_rotation(bone)
	var delta_q := Quaternion.from_euler(Vector3(pitch_x, yaw_y, roll_z))
	sk.set_bone_pose_rotation(bone, (cur_q * delta_q).normalized())


## Solver analítico de 2 ossos (coxa + canela) com preservação do plano do joelho
## (zero torção axial) e orientação biomecânica do pé no contato com a bola.
func _solve_two_bone_leg(sk: Skeleton3D, sk_inv: Transform3D, side: float,
		target_world: Vector3, ball_w: float, mode: int) -> void:
	var h_idx: int = _hip_bones[side]
	var k_idx: int = _knee_bones[side]
	var f_idx: int = _foot_bones[side]
	if h_idx < 0 or k_idx < 0 or f_idx < 0:
		return

	var gp_hip := sk.get_bone_global_pose(h_idx)
	var gp_knee := sk.get_bone_global_pose(k_idx)
	var gp_foot := sk.get_bone_global_pose(f_idx)

	var H := gp_hip.origin
	var K := gp_knee.origin
	var A := gp_foot.origin
	var T := sk_inv * target_world

	var L1 := (K - H).length()
	var L2 := (A - K).length()
	if L1 < 0.05 or L2 < 0.05:
		return

	var to_target := T - H
	var raw_d := to_target.length()
	if raw_d < 0.01:
		return
	var min_d := absf(L1 - L2) + 0.02
	var max_d := (L1 + L2) - 0.006
	var d := clampf(raw_d, min_d, max_d)
	var u_new := to_target / raw_d
	var T_clamped := H + u_new * d

	var old_vec := A - H
	var old_d := maxf(old_vec.length(), 0.01)
	var u_old := old_vec / old_d

	# Direção atual do joelho perpendicular ao eixo quadril-tornozelo.
	var k_perp := (K - H) - u_old * (K - H).dot(u_old)
	if k_perp.length_squared() < 0.0004:
		# Perna quase reta: usa +Z (frente do esqueleto) como direção do joelho.
		k_perp = Vector3(0.0, 0.0, 1.0) - u_old * u_old.z
	var q_swing := Quaternion(u_old, u_new)
	var n_knee := (q_swing * k_perp).normalized()
	# Garante que o joelho sempre dobre para a frente (+Z no espaço do modelo).
	if n_knee.z < 0.08:
		var fwd_hint := (Vector3(side * -0.08, 0.1, 1.0) - u_new * Vector3(side * -0.08, 0.1, 1.0).dot(u_new))
		if fwd_hint.length_squared() > 0.001:
			n_knee = (n_knee * 0.35 + fwd_hint.normalized() * 0.65).normalized()

	var cos_a := clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -0.995, 0.995)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var K_new := H + u_new * (L1 * cos_a) + n_knee * (L1 * sin_a)

	# Rotaciona coxa (UpperLeg) pelo menor arco (sem torcer o fêmur).
	var d1_old := (K - H).normalized()
	var d1_new := (K_new - H).normalized()
	var q1 := Quaternion(d1_old, d1_new)
	gp_hip.basis = Basis(q1) * gp_hip.basis

	# Rotaciona canela (LowerLeg) a partir da rotação acumulada da coxa.
	var d2_after_q1 := (q1 * (A - K)).normalized()
	var d2_new := (T_clamped - K_new).normalized()
	var q2 := Quaternion(d2_after_q1, d2_new)
	gp_knee.basis = Basis(q2) * Basis(q1) * gp_knee.basis
	gp_knee.origin = K_new

	# Posiciona o tornozelo (Foot) e ajusta suavemente a orientação da superfície do pé.
	gp_foot.origin = T_clamped
	if ball_w > 0.01:
		var foot_euler := Vector3.ZERO
		match mode:
			0, 4: # INSIDE / CUSHION (chapa / amortecimento com a parte interna)
				foot_euler = Vector3(deg_to_rad(4.0), deg_to_rad(-18.0 * side), deg_to_rad(10.0 * side))
			1: # SOLE (sola em cima da bola: ponta do pé levemente levantada)
				foot_euler = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
			2: # KICK (peito do pé: ponta esticada para baixo no chute)
				foot_euler = Vector3(deg_to_rad(16.0), 0.0, 0.0)
			3: # CUSHION
				foot_euler = Vector3(deg_to_rad(3.0), deg_to_rad(-16.0 * side), deg_to_rad(8.0 * side))
			5: # OUTSIDE (três dedos / parte externa do pé)
				foot_euler = Vector3(deg_to_rad(6.0), deg_to_rad(15.0 * side), deg_to_rad(-8.0 * side))
		var rot_mod := Basis.from_euler(foot_euler * ball_w)
		gp_foot.basis = gp_foot.basis * rot_mod

	sk.set_bone_global_pose(h_idx, gp_hip)
	sk.set_bone_global_pose(k_idx, gp_knee)
	sk.set_bone_global_pose(f_idx, gp_foot)
