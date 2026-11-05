class_name LeanModifier
extends SkeletonModifier3D
## Biomecânica corporal e de membros inferiores:
## 1) Postura ereta e atlética de jogador de futebol (remove a curvatura excessiva
##    do UpperChest, adiciona gingado, proteção de bola com o corpo e braço de
##    proteção contra o marcador, e reação de tronco/braços em chutes, passes,
##    botes e recepções amortecidas).
## 2) Nivelamento anatômico dos pés e dedos (Foot & Toe Leveling): elimina o viés
##    plantar das animações do Mixamo para que a sola e o calcanhar apoiem 100%
##    planos no asfalto (zero corrida na ponta dos pés).
## 3) Olhar humano independente do tronco (Head/Neck Gaze): vira apenas o pescoço
##    e o rosto para olhar a bola ou o companheiro no passe sem girar o tórax.
## 4) Cinemática Inversa (IK) analítica de 2 ossos (coxa + canela) com preservação
##    do plano anatômico de flexão do joelho e orientação da superfície do pé
##    (chapa, três dedos, peito do pé, sola e amortecimento).

var amount := 0.0
var accel_lean := 0.0
var turn_lean := 0.0
var feint_lean := 0.0
var dribble_gingado := 0.0
var gaze_weight := 0.0
var gaze_world_pos := Vector3.ZERO

var shield_weight := 0.0
var shield_dir_world := Vector3.ZERO

var action_kind: StringName = &""
var action_phase := 0.0
var action_power := 0.0
var action_side := 1.0

const ACCEL_SPINE_DEG := 5.0
const TURN_BANK_DEG := 5.0
const TURN_YAW_DEG := 6.5

const MIN_ANKLE_Y := 0.095

var _smooth_amount := 0.0
var _smooth_accel := 0.0
var _smooth_turn := 0.0
var _smooth_feint := 0.0
var _smooth_gingado := 0.0
var _gingado_phase := 0.0
var _smooth_gaze := 0.0
var _smooth_ball_local := Vector3(0.0, 0.11, 1.2)
var _smooth_shield := 0.0
var _smooth_shield_local := Vector3(1.0, 0.0, 0.0)

var _hips := -2
var _spine := -2
var _chest := -2
var _upper_chest := -2
var _neck := -2
var _head := -2
var _shoulder_bones := {1.0: -1, -1.0: -1}
var _finger_bones: Array[int] = []

var _arm_bones := {1.0: -1, -1.0: -1}
var _forearm_bones := {1.0: -1, -1.0: -1}
var _hip_bones := {1.0: -1, -1.0: -1}
var _knee_bones := {1.0: -1, -1.0: -1}
var _foot_bones := {1.0: -1, -1.0: -1}
var _toe_bones := {1.0: -1, -1.0: -1}
var _foot_bind := {1.0: Transform3D.IDENTITY, -1.0: Transform3D.IDENTITY}
var _toe_bind := {1.0: Transform3D.IDENTITY, -1.0: Transform3D.IDENTITY}

## Alvo de contato do pé com a bola (mundo) e peso 0..1 por lado (+1 dir, -1 esq).
var _ball_target := {1.0: Vector3.ZERO, -1.0: Vector3.ZERO}
var _ball_weight := {1.0: 0.0, -1.0: 0.0}
var _ball_mode := {1.0: 0, -1.0: 0}
var _ball_forward := {1.0: Vector3.FORWARD, -1.0: Vector3.FORWARD}

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
	_ik_dirty = true


func set_ball_gaze(world_pos: Vector3, weight: float) -> void:
	gaze_world_pos = world_pos
	gaze_weight = clampf(weight, 0.0, 1.0)


func set_shield_posture(dir_world: Vector3, weight: float) -> void:
	shield_dir_world = dir_world
	shield_weight = clampf(weight, 0.0, 1.0)


func set_action_posture(kind: StringName, phase_ratio: float, power: float, side: float = 1.0) -> void:
	action_kind = kind
	action_phase = clampf(phase_ratio, 0.0, 1.0)
	action_power = clampf(power, 0.0, 1.0)
	action_side = 1.0 if side >= 0.0 else -1.0


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
	ensure_updated()
	return _raw_ankle_world[s]


func get_raw_toe_world(side: float) -> Vector3:
	var s := 1.0 if side >= 0.0 else -1.0
	ensure_updated()
	return _raw_toe_world[s]


func _cache_bones(sk: Skeleton3D) -> void:
	_hips = sk.find_bone("Hips")
	_spine = sk.find_bone("Spine")
	_chest = sk.find_bone("Chest")
	_upper_chest = sk.find_bone("UpperChest")
	_neck = sk.find_bone("Neck")
	_head = sk.find_bone("Head")
	_finger_bones.clear()
	for side_prefix in ["Left", "Right"]:
		for finger in [
			"ThumbMetacarpal", "ThumbProximal", "ThumbDistal",
			"IndexProximal", "IndexIntermediate", "IndexDistal",
			"MiddleProximal", "MiddleIntermediate", "MiddleDistal",
			"RingProximal", "RingIntermediate", "RingDistal",
			"LittleProximal", "LittleIntermediate", "LittleDistal",
		]:
			var fb := sk.find_bone(side_prefix + finger)
			if fb >= 0:
				_finger_bones.append(fb)
	var skin: Skin = null
	for child in sk.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).skin != null:
			skin = (child as MeshInstance3D).skin
			break
	for side in [1.0, -1.0]:
		var prefix := "Right" if side > 0.0 else "Left"
		_shoulder_bones[side] = sk.find_bone(prefix + "Shoulder")
		_arm_bones[side] = sk.find_bone(prefix + "UpperArm")
		if _arm_bones[side] < 0:
			_arm_bones[side] = sk.find_bone(prefix + "Arm")
		_forearm_bones[side] = sk.find_bone(prefix + "LowerArm")
		if _forearm_bones[side] < 0:
			_forearm_bones[side] = sk.find_bone(prefix + "ForeArm")
		_hip_bones[side] = sk.find_bone(prefix + "UpperLeg")
		_knee_bones[side] = sk.find_bone(prefix + "LowerLeg")
		_foot_bones[side] = sk.find_bone(prefix + "Foot")
		_toe_bones[side] = sk.find_bone(prefix + "Toes")
		if _foot_bones[side] >= 0:
			_foot_bind[side] = sk.get_bone_global_rest(_foot_bones[side]).affine_inverse()
		if _toe_bones[side] >= 0:
			_toe_bind[side] = sk.get_bone_global_rest(_toe_bones[side]).affine_inverse()
		if skin != null:
			for i in skin.get_bind_count():
				var bn := String(skin.get_bind_name(i))
				if bn == prefix + "Foot":
					_foot_bind[side] = skin.get_bind_pose(i)
				elif bn == prefix + "Toes":
					_toe_bind[side] = skin.get_bind_pose(i)


var _last_sk_origin := Vector3(INF, INF, INF)


## Garante que a IK esteja atualizada quando o alvo do pé muda durante o passo físico.
func ensure_updated() -> void:
	if _applying:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var moved := sk.global_transform.origin.distance_squared_to(_last_sk_origin) > 0.00001
	if not _ik_dirty and not _anim_just_applied and not _raw_local_poses.is_empty() and not moved:
		return
	_ik_dirty = false
	_last_sk_origin = sk.global_transform.origin
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

	var tracked_bones := [
		_hips, _spine, _chest, _upper_chest, _neck, _head,
		_shoulder_bones[1.0], _shoulder_bones[-1.0],
		_arm_bones[1.0], _forearm_bones[1.0], _arm_bones[-1.0], _forearm_bones[-1.0],
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
		for fb in _finger_bones:
			_raw_local_poses[fb] = sk.get_bone_pose(fb)
		var smooth_k := 1.0 - exp(-11.0 * dt)
		_smooth_amount = lerpf(_smooth_amount, amount, smooth_k)
		_smooth_accel = lerpf(_smooth_accel, accel_lean, smooth_k)
		_smooth_turn = lerpf(_smooth_turn, turn_lean, smooth_k)
		_smooth_feint = lerpf(_smooth_feint, feint_lean, 1.0 - exp(-15.0 * dt))
		_smooth_gingado = lerpf(_smooth_gingado, dribble_gingado, smooth_k)
		var step_freq := lerpf(1.3, 2.3, clampf(_smooth_amount, 0.0, 1.0))
		_gingado_phase = wrapf(_gingado_phase + dt * step_freq * TAU, 0.0, TAU)
		var gaze_k := 1.0 - exp(-8.5 * dt)
		_smooth_gaze = lerpf(_smooth_gaze, gaze_weight, gaze_k)
		if gaze_world_pos != Vector3.ZERO:
			var target_local := sk_inv * gaze_world_pos
			_smooth_ball_local = _smooth_ball_local.lerp(target_local, 1.0 - exp(-12.0 * dt))
		_smooth_shield = lerpf(_smooth_shield, shield_weight, 1.0 - exp(-10.0 * dt))
		if shield_dir_world.length_squared() > 0.001:
			var s_loc := (sk_inv.basis * shield_dir_world).normalized()
			s_loc.y = 0.0
			if s_loc.length_squared() > 0.001:
				_smooth_shield_local = _smooth_shield_local.lerp(s_loc.normalized(), 1.0 - exp(-10.0 * dt))
	else:
		for b in tracked_bones:
			if b >= 0 and _raw_local_poses.has(b):
				sk.set_bone_pose(b, _raw_local_poses[b])
		for fb in _finger_bones:
			if _raw_local_poses.has(fb):
				sk.set_bone_pose(fb, _raw_local_poses[fb])

	# 1. Postura atlética solta, gingado brasileiro, braços leves e abertura natural das pernas.
	_apply_athletic_posture(sk)

	# 2. Nivelamento anatômico dos pés em espaço da malha (sem deformar os dedos).
	for side in [1.0, -1.0]:
		var f_idx: int = _foot_bones[side]
		var t_idx: int = _toe_bones[side]
		var k_idx: int = _knee_bones[side]
		if f_idx >= 0 and k_idx >= 0:
			_level_foot_and_toes(sk, side, k_idx, f_idx, t_idx, _ball_weight[side])

	# 3. Ancoragem exata da sola no chão (impede que o pé afunde no piso).
	_anchor_feet_above_ground(sk)

	# 4. Leitura da pose base e IK analítica de toque na bola / bote.
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
		if bw > 0.001:
			var target_w: Vector3 = anim_ankle_w.lerp(_ball_target[side], bw)
			target_w.y = maxf(target_w.y, MIN_ANKLE_Y)
			_solve_two_bone_leg(sk, sk_inv, side, target_w, bw, _ball_mode[side])

	_ik_dirty = false
	_applying = false


## Garante que a sola da malha 3D do pé apoiado fique exatamente na superfície
## do chão (Y = 0.0) e nunca afunde para dentro do piso.
func _anchor_feet_above_ground(sk: Skeleton3D) -> void:
	if _hips < 0 or _foot_bones[1.0] < 0 or _foot_bones[-1.0] < 0:
		return
	var gp_hips := sk.get_bone_global_pose(_hips)
	var e_hips := gp_hips.basis.get_euler()
	if absf(e_hips.x) > deg_to_rad(42.0) or absf(e_hips.z) > deg_to_rad(42.0):
		return # caído/carrinho: não desloca o quadril
	var min_sole_y := INF
	for side in [1.0, -1.0]:
		var f_idx: int = _foot_bones[side]
		var t_idx: int = _toe_bones[side]
		if f_idx >= 0:
			var mf: Transform3D = sk.get_bone_global_pose(f_idx) * _foot_bind[side]
			var v_heel := Vector3(-side * 0.08, 0.004, -0.075)
			var v_mid := Vector3(-side * 0.08, 0.004, 0.015)
			min_sole_y = minf(min_sole_y, (mf * v_heel).y)
			min_sole_y = minf(min_sole_y, (mf * v_mid).y)
		if t_idx >= 0:
			var mt: Transform3D = sk.get_bone_global_pose(t_idx) * _toe_bind[side]
			var v_toe := Vector3(-side * 0.08, 0.004, 0.075)
			min_sole_y = minf(min_sole_y, (mt * v_toe).y)
	if min_sole_y == INF:
		return
	var target_sole_y := 0.004
	if min_sole_y < target_sole_y:
		gp_hips.origin.y += (target_sole_y - min_sole_y)
		sk.set_bone_global_pose(_hips, gp_hips)
		sk.force_update_all_bone_transforms()
	elif min_sole_y < target_sole_y + 0.022 and not (action_kind in [&"jump", &"header_jump"]):
		gp_hips.origin.y -= (min_sole_y - target_sole_y) * 0.72
		sk.set_bone_global_pose(_hips, gp_hips)
		sk.force_update_all_bone_transforms()


## Nivela a orientação real da malha 3D do pé (gp_f * _foot_bind[side]) sem
## entortar ou deformar os dedos (Toes acompanha o Foot solidariamente como uma
## peça anatômica única, sem saltos bruscos de fase).
func _level_foot_and_toes(sk: Skeleton3D, side: float, k_idx: int, f_idx: int, t_idx: int, ball_w: float) -> void:
	if f_idx < 0 or k_idx < 0:
		return
	# 1. Mantém a articulação dos dedos (Toes) suave e alinhada com o pé da malha
	# (em Mixamo, Quaternion(0, 1, 0, 0) é o ângulo neutro 0° entre Foot e Toes).
	if t_idx >= 0:
		var q_t_cur := sk.get_bone_pose_rotation(t_idx)
		var q_t_neutral := Quaternion(0.0, 1.0, 0.0, 0.0)
		if q_t_cur.dot(q_t_neutral) < 0.0:
			q_t_neutral = -q_t_neutral
		# Reduz dobras exageradas dos dedos (> 8°) mantendo flexão orgânica sutil
		sk.set_bone_pose_rotation(t_idx, q_t_cur.slerp(q_t_neutral, 0.65).normalized())
		sk.force_update_all_bone_transforms()

	var gp_f := sk.get_bone_global_pose(f_idx)
	var mf: Transform3D = gp_f * _foot_bind[side]
	var fwd := mf.basis.z.normalized()
	var horiz := Vector3(fwd.x, 0.0, fwd.z)
	if horiz.length_squared() < 0.001:
		return
	horiz = horiz.normalized()
	var ank_y := gp_f.origin.y
	var ground_k := clampf(1.0 - maxf(ank_y - 0.064, 0.0) / 0.12, 0.0, 1.0)
	var q_to_flat := Quaternion(fwd, horiz)
	var pitch_down_deg := rad_to_deg(asin(clampf(-fwd.y, -1.0, 1.0)))
	var air_excess_w := 0.0
	if pitch_down_deg > 18.0:
		air_excess_w = clampf((pitch_down_deg - 18.0) / maxf(pitch_down_deg, 1.0), 0.0, 0.72)
	var w := maxf(ground_k * 0.92, air_excess_w) if fwd.y < 0.0 else ground_k * 0.35
	if ball_w > 0.01:
		w = maxf(w, clampf(ball_w * 0.90, 0.0, 0.90))
	if w > 0.001:
		var q_world_corr := Quaternion.IDENTITY.slerp(q_to_flat, w).normalized()
		var gp_parent := sk.get_bone_global_pose(k_idx)
		var new_global_basis := Basis(q_world_corr) * gp_f.basis
		var new_local_q := (gp_parent.basis.inverse() * new_global_basis).get_rotation_quaternion().normalized()
		sk.set_bone_pose_rotation(f_idx, new_local_q)
		sk.force_update_all_bone_transforms()


func _apply_athletic_posture(sk: Skeleton3D) -> void:
	if _hips < 0 or _spine < 0 or _chest < 0 or _upper_chest < 0 or _neck < 0 or _head < 0:
		return
	var q_hips := sk.get_bone_pose_rotation(_hips)
	var e_hips := q_hips.get_euler()

	# Em quedas/mergulhos (quadril inclinado mais de 42°), preserva a animação pura.
	if absf(e_hips.x) > deg_to_rad(42.0) or absf(e_hips.z) > deg_to_rad(42.0):
		return

	# --- 1. Relaxa a curvatura excessiva dos dedos das mãos ---
	for fb in _finger_bones:
		var q_rest := sk.get_bone_rest(fb).basis.get_rotation_quaternion()
		var q_anim := sk.get_bone_pose_rotation(fb)
		sk.set_bone_pose_rotation(fb, q_rest.slerp(q_anim, 0.45).normalized())

	# --- 1.1 Mantém ombros vivos e soltos (sem travar a clavícula) ---
	for s_sh in [1.0, -1.0]:
		var sh_b: int = _shoulder_bones[s_sh]
		if sh_b >= 0:
			var q_sh_rest := sk.get_bone_rest(sh_b).basis.get_rotation_quaternion()
			var q_sh_anim := sk.get_bone_pose_rotation(sh_b)
			sk.set_bone_pose_rotation(sh_b, q_sh_rest.slerp(q_sh_anim, 0.82).normalized())

	# --- 1.2 Limpa apenas inclinação torta residual na coluna preservando o giro atlético ---
	for sp_b in [_spine, _chest, _upper_chest]:
		var e_b := sk.get_bone_pose_rotation(sp_b).get_euler()
		var e_rest := sk.get_bone_rest(sp_b).basis.get_euler()
		var clean_y := lerpf(e_b.y, e_rest.y, 0.16)
		var clean_z := lerpf(e_b.z, e_rest.z, 0.28)
		sk.set_bone_pose_rotation(sp_b, Quaternion.from_euler(Vector3(e_b.x, clean_y, clean_z)))

	# --- 1.3 Abertura natural e ampla da passada das pernas na corrida ---
	var move_factor := clampf(_smooth_amount * 1.25 + _smooth_gingado * 0.45, 0.0, 1.0)
	var stride_phase := 0.0
	if _hip_bones[1.0] >= 0 and _hip_bones[-1.0] >= 0:
		var q_ul_r := sk.get_bone_pose_rotation(_hip_bones[1.0])
		var q_ul_l := sk.get_bone_pose_rotation(_hip_bones[-1.0])
		var e_ul_r := q_ul_r.get_euler()
		var e_ul_l := q_ul_l.get_euler()
		stride_phase = clampf((e_ul_r.x - e_ul_l.x) / deg_to_rad(50.0), -1.0, 1.0)
		# Postura de pernas abertas atlética e proteção de bola com o corpo:
		var shield_spread := _smooth_shield * deg_to_rad(7.5)
		for s_leg in [1.0, -1.0]:
			var ul_b: int = _hip_bones[s_leg]
			var ll_b: int = _knee_bones[s_leg]
			if ul_b >= 0:
				var e_ul := sk.get_bone_pose_rotation(ul_b).get_euler()
				var spread_z := s_leg * shield_spread
				if _smooth_amount > 0.04 and action_kind == &"":
					var stride_boost := 0.24 * clampf(_smooth_amount * 1.35, 0.15, 1.0)
					var neutral_x := deg_to_rad(-11.0)
					var swing_dx := e_ul.x - neutral_x
					var ext_bonus := deg_to_rad(5.5) * _smooth_amount if swing_dx > 0.0 else deg_to_rad(-2.5) * _smooth_amount
					var new_ul_x := clampf(neutral_x + swing_dx * (1.0 + stride_boost) + ext_bonus, deg_to_rad(-82.0), deg_to_rad(28.0))
					sk.set_bone_pose_rotation(ul_b, Quaternion.from_euler(Vector3(new_ul_x, e_ul.y, e_ul.z + spread_z)))
					if ll_b >= 0 and swing_dx > deg_to_rad(4.0):
						_rotate_bone_local(sk, ll_b, deg_to_rad(-8.0) * _smooth_amount, 0.0, 0.0)
				elif shield_spread > 0.001:
					sk.set_bone_pose_rotation(ul_b, Quaternion.from_euler(Vector3(e_ul.x, e_ul.y, e_ul.z + spread_z)))

	var e_spine := sk.get_bone_pose_rotation(_spine).get_euler()
	var e_chest := sk.get_bone_pose_rotation(_chest).get_euler()
	var e_uchest := sk.get_bone_pose_rotation(_upper_chest).get_euler()

	# --- 2. Gingado brasileiro, jogo de corpo e dinâmica expressiva de chutes/passes/botes ---
	var gingado_amp := clampf(move_factor * 0.65 + 0.12, 0.12, 0.78)
	var sway_sin := sin(_gingado_phase)
	var sway_cos := cos(_gingado_phase)
	var stride_sway := stride_phase * 0.75 + sway_sin * 0.25

	var combined_turn := clampf(_smooth_turn * 0.85 + _smooth_feint * 0.55, -1.0, 1.0)
	var bank_rad := deg_to_rad(TURN_BANK_DEG * 1.25) * combined_turn
	var yaw_rad := deg_to_rad(TURN_YAW_DEG * 1.25) * combined_turn

	var shield_side := clampf(-_smooth_shield_local.x * 1.4, -1.0, 1.0)

	# Modulação corporal completa durante ações (chutes com gingado, passes, botes, dribles):
	var act_pitch := 0.0
	var act_yaw := 0.0
	var act_roll := 0.0
	var act_hip_yaw := 0.0
	var act_hip_roll := 0.0
	var act_arm_spread := 0.0
	var act_arm_swing := 0.0
	var act_sup_knee := 0.0
	if action_kind != &"":
		var pulse := sin(clampf(action_phase, 0.0, 1.0) * PI)
		var windup := sin(clampf(action_phase / 0.38, 0.0, 1.0) * PI) if action_phase < 0.38 else 0.0
		var strike := sin(clampf((action_phase - 0.32) / 0.68, 0.0, 1.0) * PI) if action_phase >= 0.32 else 0.0
		match action_kind:
			&"pass", &"run_pass":
				act_pitch = deg_to_rad(-2.5 * windup + 4.5 * strike)
				act_yaw = deg_to_rad((-6.0 * windup + 11.0 * strike) * action_side)
				act_roll = deg_to_rad(-4.5 * action_side) * pulse
				act_hip_yaw = deg_to_rad((-5.0 * windup + 10.0 * strike) * action_side)
				act_arm_spread = 0.52 * pulse
				act_arm_swing = (-0.35 * windup + 0.75 * strike)
				act_sup_knee = deg_to_rad(9.0) * pulse
			&"long_pass":
				act_pitch = deg_to_rad(-6.5 * windup + 7.5 * strike)
				act_yaw = deg_to_rad((-10.0 * windup + 16.0 * strike) * action_side)
				act_roll = deg_to_rad(-7.5 * action_side) * pulse
				act_hip_yaw = deg_to_rad((-8.0 * windup + 14.0 * strike) * action_side)
				act_hip_roll = deg_to_rad(-4.5 * action_side) * strike
				act_arm_spread = 0.78 * pulse
				act_arm_swing = (-0.55 * windup + 1.0 * strike)
				act_sup_knee = deg_to_rad(13.0) * pulse
			&"chip":
				act_pitch = deg_to_rad(-5.5) * pulse
				act_yaw = deg_to_rad(7.0 * action_side) * pulse
				act_arm_spread = 0.48 * pulse
				act_arm_swing = 0.45 * pulse
			&"shoot", &"shoot_power":
				var pwr := clampf(action_power, 0.35, 1.0)
				if action_kind == &"shoot_power":
					pwr = maxf(pwr, 0.90)
				act_pitch = deg_to_rad((-8.5 * windup + (7.5 + 6.5 * pwr) * strike) * pwr)
				act_yaw = deg_to_rad((-12.0 * windup + (15.0 + 7.0 * pwr) * strike) * action_side * pwr)
				act_roll = deg_to_rad((-7.5 * action_side * pwr) * pulse)
				act_hip_yaw = deg_to_rad((-9.0 * windup + 16.0 * strike) * action_side * pwr)
				act_hip_roll = deg_to_rad(-5.5 * action_side * pwr) * strike
				act_arm_spread = (0.62 + 0.45 * pwr) * pulse
				act_arm_swing = (-0.65 * windup + 1.15 * strike) * pwr
				act_sup_knee = deg_to_rad(12.0 + 5.0 * pwr) * pulse
			&"dribble", &"spin", &"cut_r", &"cut_l":
				act_pitch = deg_to_rad(5.5) * pulse
				act_yaw = deg_to_rad(11.0 * action_side) * pulse
				act_roll = deg_to_rad(7.0 * action_side) * pulse
				act_hip_yaw = deg_to_rad(8.0 * action_side) * pulse
				act_arm_spread = 0.65 * pulse
				act_arm_swing = 0.60 * pulse
			&"tackle":
				act_pitch = deg_to_rad(11.0) * pulse
				act_yaw = deg_to_rad(12.0 * action_side) * pulse
				act_roll = deg_to_rad(-5.0 * action_side) * pulse
				act_hip_yaw = deg_to_rad(10.0 * action_side) * pulse
				act_arm_spread = 0.72 * pulse
				act_arm_swing = 0.85 * pulse
				act_sup_knee = deg_to_rad(16.0) * pulse
			&"recv_chest":
				act_pitch = deg_to_rad(-11.0) * pulse
				act_arm_spread = 0.68 * pulse
			&"recv_knee", &"receive":
				act_pitch = deg_to_rad(4.5) * pulse
				act_arm_spread = 0.42 * pulse

	# Flexão firme do joelho da perna de apoio durante passes, chutes e botes
	if act_sup_knee > 0.001:
		var sup_side := -action_side
		var sup_ul: int = _hip_bones[sup_side]
		var sup_ll: int = _knee_bones[sup_side]
		if sup_ul >= 0 and sup_ll >= 0:
			_rotate_bone_local(sk, sup_ul, -act_sup_knee * 0.55, 0.0, 0.0)
			_rotate_bone_local(sk, sup_ll, act_sup_knee, 0.0, 0.0)

	# Quadril com gingado sutil lateral e rotação pélvica viva
	var hips_pos := sk.get_bone_pose_position(_hips)
	hips_pos.x = clampf(stride_sway * 0.012 * move_factor, -0.015, 0.015)
	sk.set_bone_pose_position(_hips, hips_pos)

	var hip_roll := stride_sway * deg_to_rad(2.2) * gingado_amp + bank_rad * 0.22 + act_hip_roll
	var hip_yaw := -stride_sway * deg_to_rad(3.2) * gingado_amp + yaw_rad * 0.24 + act_hip_yaw
	_rotate_bone_local(sk, _hips, 0.0, hip_yaw, hip_roll)

	var share_x := clampf(e_uchest.x * 0.28, deg_to_rad(-6.0), deg_to_rad(6.0))
	var raw_torso_x := e_hips.x + e_spine.x + e_chest.x + e_uchest.x
	var target_max_x := deg_to_rad(5.0 + 6.5 * _smooth_amount) + deg_to_rad(ACCEL_SPINE_DEG) * _smooth_accel \
		+ absf(combined_turn) * deg_to_rad(2.8) + deg_to_rad(4.5) * _smooth_shield + act_pitch
	var excess_x := maxf(0.0, raw_torso_x - target_max_x)
	var corr_x := excess_x * 0.78 - act_pitch * 0.75

	# Contra-rotação torácica natural (quando o quadril gira para um lado, o peito compensa solto)
	var gingado_torso_yaw := stride_sway * deg_to_rad(4.2) * gingado_amp + act_yaw * 0.85
	var gingado_torso_roll := -stride_sway * deg_to_rad(2.6) * gingado_amp \
		+ shield_side * _smooth_shield * deg_to_rad(4.5) + act_roll * 0.75

	_rotate_bone_local(sk, _spine,
		share_x - corr_x * 0.25,
		yaw_rad * 0.28 + gingado_torso_yaw * 0.32,
		bank_rad * 0.28 + gingado_torso_roll * 0.32)
	_rotate_bone_local(sk, _chest,
		-corr_x * 0.30,
		yaw_rad * 0.34 + gingado_torso_yaw * 0.36,
		bank_rad * 0.32 + gingado_torso_roll * 0.36)
	_rotate_bone_local(sk, _upper_chest,
		-share_x - corr_x * 0.45,
		yaw_rad * 0.40 + gingado_torso_yaw * 0.38,
		bank_rad * 0.36 + gingado_torso_roll * 0.38)

	# --- 2.1 Braços leves, soltos na corrida e expressivos nos chutes/passes/botes ---
	for s_val in [1.0, -1.0]:
		var s: float = s_val
		var arm_b: int = _arm_bones[s]
		var fa_b: int = _forearm_bones[s]
		if arm_b >= 0:
			# Balanço cruzado com a perna oposta (s * stride_sway) + reação de chute/passe
			var run_arm_swing := (s * stride_sway * deg_to_rad(14.0) + s * sway_cos * deg_to_rad(5.0)) * move_factor
			var is_balance_arm := 1.0 if (s * action_side < 0.0) else 0.0
			var is_kick_arm := 1.0 - is_balance_arm
			var lift: float = -s * combined_turn * deg_to_rad(8.0) + deg_to_rad(4.5) * move_factor \
				+ absf(stride_sway) * deg_to_rad(4.0) * move_factor
			if lift < 0.0:
				lift *= 0.35
			var is_shield_arm := clampf(s * shield_side, 0.0, 1.0) * _smooth_shield
			lift += is_shield_arm * deg_to_rad(20.0) \
				+ act_arm_spread * deg_to_rad(24.0 * is_balance_arm + 11.0 * is_kick_arm)
			var action_fwd := act_arm_swing * deg_to_rad(24.0 * is_balance_arm - 18.0 * is_kick_arm)
			var fwd: float = run_arm_swing \
				+ absf(combined_turn) * deg_to_rad(5.0) \
				+ is_shield_arm * deg_to_rad(12.0) \
				+ action_fwd
			_rotate_bone_local(sk, arm_b, fwd, 0.0, lift * s)
			if fa_b >= 0:
				# Solta os cotovelos rígidos do Jog/Dribble (abre ~16° para deixar o braço leve)
				var relax_elbow := -deg_to_rad(16.0) * clampf(move_factor, 0.25, 1.0) \
					+ s * stride_sway * deg_to_rad(7.0) * move_factor
				var action_elbow := is_shield_arm * deg_to_rad(18.0) \
					+ act_arm_spread * deg_to_rad(-12.0 * is_balance_arm + 10.0 * is_kick_arm)
				_rotate_bone_local(sk, fa_b, relax_elbow + action_elbow, 0.0, 0.0)

	# --- 3. Olhar para a frente (campo) ou para o companheiro no passe ---
	q_hips = sk.get_bone_pose_rotation(_hips)
	var q_uchest_global := q_hips \
		* sk.get_bone_pose_rotation(_spine) \
		* sk.get_bone_pose_rotation(_chest) \
		* sk.get_bone_pose_rotation(_upper_chest)
	var q_neck_orig := sk.get_bone_pose_rotation(_neck)
	var q_head_orig := sk.get_bone_pose_rotation(_head)
	var q_head_anim_global := q_uchest_global * q_neck_orig * q_head_orig
	var anim_head_euler := q_head_anim_global.get_euler()

	var horizon_pitch := clampf(anim_head_euler.x * 0.20 + deg_to_rad(2.0), deg_to_rad(0.5), deg_to_rad(5.5))
	var horizon_yaw := clampf(anim_head_euler.y * 0.25 + yaw_rad * 0.65, deg_to_rad(-16.0), deg_to_rad(16.0))
	var horizon_roll := clampf(anim_head_euler.z * 0.15, deg_to_rad(-3.5), deg_to_rad(3.5))

	var head_origin_local := Vector3(0.0, 0.90, 0.04)
	var to_target := _smooth_ball_local - head_origin_local
	var horiz_dist := Vector2(to_target.x, to_target.z).length()
	var target_yaw := clampf(atan2(to_target.x, maxf(to_target.z, 0.20)), deg_to_rad(-46.0), deg_to_rad(46.0))
	var target_pitch := clampf(atan2(-to_target.y, maxf(horiz_dist, 0.45)) * 0.40, deg_to_rad(0.5), deg_to_rad(12.0))

	var final_pitch := lerpf(horizon_pitch, target_pitch, _smooth_gaze)
	var final_yaw := lerpf(horizon_yaw, target_yaw, _smooth_gaze)
	var final_roll := lerpf(horizon_roll, clampf(-final_yaw * 0.06, deg_to_rad(-3.5), deg_to_rad(3.5)), _smooth_gaze)

	var q_target_head_global := Quaternion.from_euler(Vector3(final_pitch, final_yaw, final_roll))
	var q_rel_total := (q_uchest_global.inverse() * q_target_head_global).normalized()
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
## preserva os comprimentos originais dos ossos, permite esticar a perna no
## bote/chute e orienta a superfície anatômica do pé sem deformar os dedos.
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
	var rest_foot_y := sk.get_bone_global_rest(f_idx).origin.y
	T.y = maxf(T.y, rest_foot_y)

	var L1 := (K - H).length()
	var L2 := (A - K).length()
	if L1 < 0.05 or L2 < 0.05:
		return

	var is_lunge := mode == 2 or action_kind == &"tackle"
	var max_corr := 0.48 if is_lunge else 0.34
	var delta_a := T - A
	if delta_a.length() > max_corr:
		T = A + delta_a.normalized() * max_corr
	T.y = maxf(T.y, rest_foot_y)

	var to_target := T - H
	var raw_d := to_target.length()
	if raw_d < 0.01:
		return
	var min_d := absf(L1 - L2) + 0.035
	var max_d := (L1 + L2) - (0.008 if action_kind == &"tackle" else 0.018)
	var d := clampf(raw_d, min_d, max_d)
	var u_new := to_target / raw_d
	var T_clamped := H + u_new * d
	T_clamped.y = maxf(T_clamped.y, rest_foot_y)

	var old_vec := A - H
	var old_d := maxf(old_vec.length(), 0.01)
	var u_old := old_vec / old_d

	var k_perp := (K - H) - u_old * (K - H).dot(u_old)
	if k_perp.length_squared() < 0.0004:
		k_perp = Vector3(0.0, 0.0, 1.0) - u_old * u_old.z
	var q_swing := Quaternion(u_old, u_new)
	var n_knee := (q_swing * k_perp).normalized()
	if n_knee.z < 0.12:
		var fwd_hint := (Vector3(side * -0.06, 0.1, 1.0) - u_new * Vector3(side * -0.06, 0.1, 1.0).dot(u_new))
		if fwd_hint.length_squared() > 0.001:
			n_knee = (n_knee * 0.30 + fwd_hint.normalized() * 0.70).normalized()

	var cos_a := clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -0.995, 0.995)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var K_new := H + u_new * (L1 * cos_a) + n_knee * (L1 * sin_a)

	var d1_old := (K - H).normalized()
	var d1_new := (K_new - H).normalized()
	var q1 := Quaternion(d1_old, d1_new)
	gp_hip.basis = Basis(q1) * gp_hip.basis

	var d2_after_q1 := (q1 * (A - K)).normalized()
	var d2_new := (T_clamped - K_new).normalized()
	var q2 := Quaternion(d2_after_q1, d2_new)
	gp_knee.basis = Basis(q2) * Basis(q1) * gp_knee.basis
	gp_knee.origin = K_new

	gp_foot.basis = Basis(q2) * Basis(q1) * gp_foot.basis
	gp_foot.origin = T_clamped
	if ball_w > 0.01:
		var foot_euler := Vector3.ZERO
		match mode:
			0, 4: # INSIDE (chapa: tornozelo abre mostrando a face interna firme)
				foot_euler = Vector3(deg_to_rad(2.0), deg_to_rad(-22.0 * side), deg_to_rad(10.0 * side))
			1: # SOLE (sola em cima da bola: ponta do pé levemente erguida pisando na bola)
				foot_euler = Vector3(deg_to_rad(10.0), deg_to_rad(-3.0 * side), 0.0)
			2: # KICK (peito do pé: dorso firme para chute forte / lançamento)
				foot_euler = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
			3: # CUSHION (amortecimento macio de recepção)
				foot_euler = Vector3(deg_to_rad(3.0), deg_to_rad(-18.0 * side), deg_to_rad(8.5 * side))
			5: # OUTSIDE (três dedos: tornozelo vira para dentro mostrando a face externa)
				foot_euler = Vector3(deg_to_rad(-4.0), deg_to_rad(19.0 * side), deg_to_rad(-9.5 * side))
		var rot_mod := Basis.from_euler(foot_euler * clampf(ball_w * 1.12, 0.0, 0.96))
		gp_foot.basis = gp_foot.basis * rot_mod

	sk.set_bone_global_pose(h_idx, gp_hip)
	sk.set_bone_global_pose(k_idx, gp_knee)
	sk.set_bone_global_pose(f_idx, gp_foot)
	sk.force_update_all_bone_transforms()
