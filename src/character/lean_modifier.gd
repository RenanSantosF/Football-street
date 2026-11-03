class_name LeanModifier
extends SkeletonModifier3D
## Biomecânica corporal e de pernas/pés em tempo real:
##   1. Postura dinâmica do tronco, quadril, cabeça e braços na corrida,
##      aceleração, desaceleração e inclinação lateral (banking) nas curvas.
##   2. Cinemática Inversa (IK) analítica de 2 ossos (coxa + canela + tornozelo)
##      sem torção axial (zero-twist) para levar o pé exatamente até a bola
##      com a superfície correta (chapa, três dedos, sola, peito do pé, domínio).
##   3. Trava biomecânica do pé de apoio no solo (Stance Foot Lock): impede que
##      o pé apoiado deslize pelo chão na passada ou atravesse o solo.

var amount := 0.0
var accel_lean := 0.0
var turn_lean := 0.0

const SPINE_DEG := 4.0
const HEAD_DEG := 5.0
const ACCEL_SPINE_DEG := 6.5
const TURN_BANK_DEG := 7.5
const TURN_YAW_DEG := 5.0

const STANCE_Y_MAX := 0.106
const STANCE_DY_MAX := 0.18
const STANCE_MAX_HIP_DIST := 0.46
const MIN_ANKLE_Y := 0.058

var _spine := -2
var _chest := -2
var _head := -2
var _hips := -2
var _l_arm := -2
var _r_arm := -2

var _hip_bones := {1.0: -1, -1.0: -1}
var _knee_bones := {1.0: -1, -1.0: -1}
var _foot_bones := {1.0: -1, -1.0: -1}
var _toe_bones := {1.0: -1, -1.0: -1}

## Estado da IK de contato com a bola por pé (+1 direito, -1 esquerdo).
var _ball_target := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _ball_weight := {1.0: 0.0, -1.0: 0.0}
var _ball_mode := {1.0: 0, -1.0: 0}
var _ball_forward := {1.0: Vector3.FORWARD, -1.0: Vector3.FORWARD}

## Estado da trava do pé de apoio no chão (evita patinação/deslize no solo).
var _planted := {1.0: false, -1.0: false}
var _plant_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _stance_weight := {1.0: 0.0, -1.0: 0.0}
var _prev_anim_ankle := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _prev_skel_origin := Vector3.ZERO

## Poses puras da animação no quadro atual (antes da IK/trava).
var _raw_ankle_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _raw_toe_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _raw_hip_world := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _cached_frame := -1
var _raw_local_poses := {}
var _applying := false


func set_foot_ik(side: float, world_pos: Vector3, weight: float, forward: Vector3, mode: int = 0) -> void:
	var s := 1.0 if side > 0.0 else -1.0
	_ball_target[s] = world_pos
	_ball_weight[s] = clampf(weight, 0.0, 1.0)
	_ball_forward[s] = forward
	_ball_mode[s] = mode


func get_raw_ankle_world(side: float) -> Vector3:
	ensure_updated()
	var s := 1.0 if side > 0.0 else -1.0
	return _raw_ankle_world[s]


func get_raw_toe_world(side: float) -> Vector3:
	ensure_updated()
	var s := 1.0 if side > 0.0 else -1.0
	return _raw_toe_world[s]


func get_raw_hip_world(side: float) -> Vector3:
	ensure_updated()
	var s := 1.0 if side > 0.0 else -1.0
	return _raw_hip_world[s]


func _cache_bones(sk: Skeleton3D) -> void:
	_spine = sk.find_bone("Spine")
	_chest = sk.find_bone("Chest")
	_head = sk.find_bone("Head")
	_hips = sk.find_bone("Hips")
	_l_arm = sk.find_bone("LeftUpperArm")
	_r_arm = sk.find_bone("RightUpperArm")
	for side in [1.0, -1.0]:
		var prefix := "Right" if side > 0.0 else "Left"
		_hip_bones[side] = sk.find_bone(prefix + "UpperLeg")
		_knee_bones[side] = sk.find_bone(prefix + "LowerLeg")
		_foot_bones[side] = sk.find_bone(prefix + "Foot")
		_toe_bones[side] = sk.find_bone(prefix + "Toes")


## Garante que a trava de pé de apoio e a IK estejam aplicadas no quadro físico
## atual mesmo antes do flush diferido de NOTIFICATION_UPDATE_SKELETON.
func ensure_updated() -> void:
	if _applying:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	_process_modification()


func _process_modification() -> void:
	if _applying:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	_applying = true
	if _spine == -2:
		_cache_bones(sk)

	var cur_frame := Engine.get_physics_frames()
	var is_new_frame := (_cached_frame != cur_frame)
	var tracked_bones := [
		_spine, _chest, _head,
		_hip_bones[1.0], _knee_bones[1.0], _foot_bones[1.0], _toe_bones[1.0],
		_hip_bones[-1.0], _knee_bones[-1.0], _foot_bones[-1.0], _toe_bones[-1.0],
	]

	if is_new_frame:
		_cached_frame = cur_frame
		_raw_local_poses.clear()
		for b in tracked_bones:
			if b >= 0:
				_raw_local_poses[b] = sk.get_bone_pose(b)
	else:
		for b in tracked_bones:
			if b >= 0 and _raw_local_poses.has(b):
				sk.set_bone_pose(b, _raw_local_poses[b])

	# 1. Postura dinâmica do tronco e cabeça (corrida, aceleração e curvas).
	var pitch_spine := -deg_to_rad(SPINE_DEG) * amount + deg_to_rad(ACCEL_SPINE_DEG) * accel_lean
	var pitch_head := -deg_to_rad(HEAD_DEG) * amount - deg_to_rad(ACCEL_SPINE_DEG * 0.45) * accel_lean
	var bank_rad := deg_to_rad(TURN_BANK_DEG) * turn_lean
	var yaw_rad := deg_to_rad(TURN_YAW_DEG) * turn_lean

	if absf(pitch_spine) > 0.001 or absf(bank_rad) > 0.001:
		_rotate_local_axes(sk, _spine, pitch_spine * 0.6, yaw_rad * 0.5, bank_rad * 0.6)
		_rotate_local_axes(sk, _chest, pitch_spine * 0.4, yaw_rad * 0.5, bank_rad * 0.4)
	if absf(pitch_head) > 0.001 or absf(bank_rad) > 0.001:
		_rotate_local_axes(sk, _head, pitch_head, -yaw_rad * 0.3, -bank_rad * 0.35)

	# 2. Guarda as posições da animação antes de aplicar IK das pernas.
	var sk_xform := sk.global_transform
	var sk_inv := sk_xform.affine_inverse()
	var dt := 1.0 / float(max(Engine.physics_ticks_per_second, 30))
	var teleported := false
	if is_new_frame:
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
		if is_new_frame:
			# Atualiza detecção de pé plantado no solo (Stance Foot Lock) 1x por quadro.
			_prev_anim_ankle[side] = anim_ankle_w
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
	_applying = false


func _rotate_local_axes(sk: Skeleton3D, bone: int, pitch_x: float, yaw_y: float, roll_z: float) -> void:
	if bone < 0:
		return
	var gp := sk.get_bone_global_pose(bone)
	var rot := Basis.from_euler(Vector3(pitch_x, yaw_y, roll_z))
	gp.basis = rot * gp.basis
	sk.set_bone_global_pose(bone, gp)


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
			1: #SOLE (sola em cima da bola: ponta do pé levemente levantada)
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

