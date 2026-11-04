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
var gaze_weight := 0.0
var gaze_world_pos := Vector3.ZERO

const ACCEL_SPINE_DEG := 3.0
const TURN_BANK_DEG := 3.8
const TURN_YAW_DEG := 4.5

const STANCE_Y_MAX := 0.095
const MIN_ANKLE_Y := 0.056

var _smooth_amount := 0.0
var _smooth_accel := 0.0
var _smooth_turn := 0.0
var _smooth_gaze := 0.0
var _smooth_ball_local := Vector3(0.0, 0.11, 1.2)

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

## Estado da estabilização firme do pé de apoio no solo (sem deslizar).
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


func set_ball_gaze(world_pos: Vector3, weight: float) -> void:
	gaze_world_pos = world_pos
	gaze_weight = clampf(weight, 0.0, 1.0)


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
	var dt := 1.0 / float(max(Engine.physics_ticks_per_second, 30))
	var sk_xform := sk.global_transform
	var sk_inv := sk_xform.affine_inverse()
	if is_new_anim:
		_anim_just_applied = false
		_raw_local_poses.clear()
		for b in tracked_bones:
			if b >= 0:
				_raw_local_poses[b] = sk.get_bone_pose(b)
		var smooth_k := 1.0 - exp(-9.0 * dt)
		_smooth_amount = lerpf(_smooth_amount, amount, smooth_k)
		_smooth_accel = lerpf(_smooth_accel, accel_lean, smooth_k)
		_smooth_turn = lerpf(_smooth_turn, turn_lean, smooth_k)
		var gaze_k := 1.0 - exp(-6.5 * dt)
		_smooth_gaze = lerpf(_smooth_gaze, gaze_weight, gaze_k)
		if gaze_world_pos != Vector3.ZERO:
			var target_local := sk_inv * gaze_world_pos
			_smooth_ball_local = _smooth_ball_local.lerp(target_local, 1.0 - exp(-10.0 * dt))
	else:
		for b in tracked_bones:
			if b >= 0 and _raw_local_poses.has(b):
				sk.set_bone_pose(b, _raw_local_poses[b])

	# 1. Postura ereta do tronco e olhar natural para a bola (Cabeça/Pescoço).
	_apply_athletic_posture(sk)

	# 2. Guarda as posições da animação antes de aplicar IK das pernas.
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
			# Estabilização firme do pé de apoio no solo: impede deslize no campo.
			var in_stance := anim_ankle_w.y < STANCE_Y_MAX and not teleported
			if teleported or bw > 0.10:
				_planted[side] = false
				_stance_weight[side] = move_toward(_stance_weight[side], 0.0, dt * 14.0)
			elif in_stance:
				if not _planted[side]:
					_planted[side] = true
					_plant_world[side] = anim_ankle_w
				var drift := Vector2(anim_ankle_w.x - _plant_world[side].x, anim_ankle_w.z - _plant_world[side].z).length()
				if drift > 0.10:
					_plant_world[side] = anim_ankle_w.lerp(_plant_world[side], 0.10 / drift)
				_plant_world[side].y = maxf(anim_ankle_w.y, MIN_ANKLE_Y)
				_stance_weight[side] = move_toward(_stance_weight[side], 0.48, dt * 12.0)
			else:
				_planted[side] = false
				_stance_weight[side] = move_toward(_stance_weight[side], 0.0, dt * 14.0)

		# 3. Determina o alvo final do tornozelo (combina estabilização de solo e IK da bola).
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
	var q_hips := sk.get_bone_pose_rotation(_hips)
	var e_hips := q_hips.get_euler()
	var e_spine := sk.get_bone_pose_rotation(_spine).get_euler()
	var e_chest := sk.get_bone_pose_rotation(_chest).get_euler()
	var e_uchest := sk.get_bone_pose_rotation(_upper_chest).get_euler()

	# Em quedas/mergulhos (quadril inclinado mais de 42°), preserva a animação pura.
	if absf(e_hips.x) > deg_to_rad(42.0) or absf(e_hips.z) > deg_to_rad(42.0):
		return

	# Compartilha 30% da curvatura local do UpperChest com o Spine (soma líquida = 0)
	# para eliminar o vinco no UpperChest mantendo a coluna alinhada.
	var share_x := clampf(e_uchest.x * 0.30, deg_to_rad(-8.0), deg_to_rad(8.0))

	# Postura ereta de jogador: em pé/andando o tronco fica quase vertical (~5,5°),
	# inclinando-se de forma natural e equilibrada até ~12,5° na corrida.
	var raw_torso_x := e_hips.x + e_spine.x + e_chest.x + e_uchest.x
	var target_max_x := deg_to_rad(5.5 + 7.0 * _smooth_amount) + deg_to_rad(ACCEL_SPINE_DEG) * _smooth_accel
	var excess_x := maxf(0.0, raw_torso_x - target_max_x)
	var corr_x := excess_x * 0.85

	# Suaviza a torção lateral exagerada do UpperChest no trote/corrida.
	var corr_uc_y := -e_uchest.y * 0.45 if absf(e_uchest.y) > deg_to_rad(6.5) else 0.0
	var corr_uc_z := -e_uchest.z * 0.50 if absf(e_uchest.z) > deg_to_rad(2.5) else 0.0

	var bank_rad := deg_to_rad(TURN_BANK_DEG) * _smooth_turn
	var yaw_rad := deg_to_rad(TURN_YAW_DEG) * _smooth_turn

	_rotate_bone_local(sk, _spine,
		share_x - corr_x * 0.25,
		corr_uc_y * 0.20 + yaw_rad * 0.25,
		bank_rad * 0.30)
	_rotate_bone_local(sk, _chest,
		-corr_x * 0.30,
		corr_uc_y * 0.20 + yaw_rad * 0.32,
		bank_rad * 0.35)
	_rotate_bone_local(sk, _upper_chest,
		-share_x - corr_x * 0.45,
		corr_uc_y * 0.60 + yaw_rad * 0.38,
		corr_uc_z + bank_rad * 0.35)

	# --- Olhar natural para a bola e nivelamento da cabeça em espaço do esqueleto ---
	# Calcula a orientação acumulada do UpperChest após o ajuste postural da coluna.
	var q_uchest_global := q_hips \
		* sk.get_bone_pose_rotation(_spine) \
		* sk.get_bone_pose_rotation(_chest) \
		* sk.get_bone_pose_rotation(_upper_chest)
	var q_neck_orig := sk.get_bone_pose_rotation(_neck)
	var q_head_orig := sk.get_bone_pose_rotation(_head)
	var q_head_anim_global := q_uchest_global * q_neck_orig * q_head_orig
	var anim_head_euler := q_head_anim_global.get_euler()

	# Olhar neutro para o horizonte: preserva micro-oscilação natural da animação
	# mantendo o rosto nivelado (+3,5° para baixo em direção ao gramado, nunca para o céu).
	var horizon_pitch := clampf(anim_head_euler.x * 0.25 + deg_to_rad(3.5), deg_to_rad(2.0), deg_to_rad(8.0))
	var horizon_yaw := clampf(anim_head_euler.y * 0.30 + yaw_rad * 0.85, deg_to_rad(-18.0), deg_to_rad(18.0))
	var horizon_roll := clampf(anim_head_euler.z * 0.20, deg_to_rad(-4.0), deg_to_rad(4.0))

	# Olhar direcionado para a bola (mesmo correndo para a frente, o rosto vira
	# anatomicamente para acompanhar a bola quando ela está no campo de visão).
	var head_origin_local := Vector3(0.0, 0.90, 0.04)
	var to_ball := _smooth_ball_local - head_origin_local
	var horiz_dist := Vector2(to_ball.x, to_ball.z).length()
	var ball_yaw := clampf(atan2(to_ball.x, maxf(to_ball.z, 0.22)), deg_to_rad(-38.0), deg_to_rad(38.0))
	var ball_pitch := clampf(atan2(-to_ball.y, maxf(horiz_dist, 0.42)) * 0.52, deg_to_rad(3.5), deg_to_rad(20.0))

	var final_pitch := lerpf(horizon_pitch, ball_pitch, _smooth_gaze)
	var final_yaw := lerpf(horizon_yaw, ball_yaw, _smooth_gaze)
	var final_roll := lerpf(horizon_roll, clampf(-final_yaw * 0.08, deg_to_rad(-4.0), deg_to_rad(4.0)), _smooth_gaze)

	var q_target_head_global := Quaternion.from_euler(Vector3(final_pitch, final_yaw, final_roll))
	var q_rel_total := (q_uchest_global.inverse() * q_target_head_global).normalized()
	# Distribui a rotação cervical suavemente: 42% no Neck e 58% na Head.
	var q_neck_new := Quaternion.IDENTITY.slerp(q_rel_total, 0.42).normalized()
	var q_head_new := (q_neck_new.inverse() * q_rel_total).normalized()
	sk.set_bone_pose_rotation(_neck, q_neck_new)
	sk.set_bone_pose_rotation(_head, q_head_new)
	sk.force_update_all_bone_transforms()


func _rotate_bone_local(sk: Skeleton3D, bone: int, pitch_x: float, yaw_y: float, roll_z: float) -> void:
	if bone < 0:
		return
	var cur_q := sk.get_bone_pose_rotation(bone)
	var delta_q := Quaternion.from_euler(Vector3(pitch_x, yaw_y, roll_z))
	sk.set_bone_pose_rotation(bone, (cur_q * delta_q).normalized())


## Solver analítico de 2 ossos (coxa + canela) com estritos limites anatômicos:
## preserva os comprimentos originais dos ossos, mantém flexão mínima natural
## no joelho (nunca estica a perna como uma barra rígida), limita o deslocamento
## máximo a partir da animação e evita qualquer torção axial do quadril/joelho.
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

	# Limita o deslocamento máximo do tornozelo em relação à animação gravada
	# para que a IK faça apenas correções anatômicas graduais sem deformar a postura.
	var max_corr := 0.34 if mode == 2 else 0.26
	var delta_a := T - A
	if delta_a.length() > max_corr:
		T = A + delta_a.normalized() * max_corr

	var to_target := T - H
	var raw_d := to_target.length()
	if raw_d < 0.01:
		return
	# Mantém margem de 2,2 cm abaixo de (L1 + L2) para que o joelho sempre
	# conserve uma micro-flexão anatômica (~15°) e nunca hiperestenda.
	var min_d := absf(L1 - L2) + 0.035
	var max_d := (L1 + L2) - 0.022
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
	# Garante que o joelho sempre aponte naturalmente para a frente (+Z no espaço do modelo).
	if n_knee.z < 0.12:
		var fwd_hint := (Vector3(side * -0.06, 0.1, 1.0) - u_new * Vector3(side * -0.06, 0.1, 1.0).dot(u_new))
		if fwd_hint.length_squared() > 0.001:
			n_knee = (n_knee * 0.30 + fwd_hint.normalized() * 0.70).normalized()

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
				foot_euler = Vector3(deg_to_rad(3.5), deg_to_rad(-15.0 * side), deg_to_rad(8.0 * side))
			1: # SOLE (sola em cima da bola: ponta do pé levemente levantada)
				foot_euler = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
			2: # KICK (peito do pé: ponta esticada para baixo no chute)
				foot_euler = Vector3(deg_to_rad(14.0), 0.0, 0.0)
			3: # CUSHION
				foot_euler = Vector3(deg_to_rad(2.5), deg_to_rad(-14.0 * side), deg_to_rad(7.0 * side))
			5: # OUTSIDE (três dedos / parte externa do pé)
				foot_euler = Vector3(deg_to_rad(5.0), deg_to_rad(13.0 * side), deg_to_rad(-7.0 * side))
		var rot_mod := Basis.from_euler(foot_euler * clampf(ball_w, 0.0, 0.85))
		gp_foot.basis = gp_foot.basis * rot_mod

	sk.set_bone_global_pose(h_idx, gp_hip)
	sk.set_bone_global_pose(k_idx, gp_knee)
	sk.set_bone_global_pose(f_idx, gp_foot)
