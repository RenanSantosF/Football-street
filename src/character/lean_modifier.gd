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

const ACCEL_SPINE_DEG := 6.5
const TURN_BANK_DEG := 12.0
const TURN_YAW_DEG := 14.5

const MIN_ANKLE_Y := 0.052

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
		var step_freq := lerpf(1.8, 3.3, clampf(_smooth_amount, 0.0, 1.0))
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

	# 1. Postura flexível com gingado, proteção de bola, ações procedurais e olhar independente.
	_apply_athletic_posture(sk)

	# 2. Nivelamento anatômico dos pés (elimina pé na ponta dos dedos) + IK de toque na bola.
	for side in [1.0, -1.0]:
		var f_idx: int = _foot_bones[side]
		var h_idx: int = _hip_bones[side]
		var t_idx: int = _toe_bones[side]
		if f_idx < 0 or h_idx < 0:
			continue
		# Antes de ler a posição bruta ou aplicar IK, nivela o pé/dedos para remover
		# a flexão plantar das animações do Mixamo (ponta do pé apontando para baixo).
		_level_foot_and_toes(sk, f_idx, t_idx, _ball_weight[side])

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


## Nivela a articulação do tornozelo (Foot) e dos dedos (Toes) em espaço do
## esqueleto para que o vetor tornozelo->dedos fique horizontal (toe.y == ankle.y)
## quando o pé apoia no solo, eliminando 100% da corrida/caminhada na ponta do pé.
func _level_foot_and_toes(sk: Skeleton3D, f_idx: int, t_idx: int, ball_w: float) -> void:
	if f_idx < 0 or t_idx < 0:
		return
	var gp_f := sk.get_bone_global_pose(f_idx)
	var gp_t := sk.get_bone_global_pose(t_idx)
	var vec := gp_t.origin - gp_f.origin
	if vec.length_squared() < 0.0001:
		return
	# Se os dedos estão mais baixos que o tornozelo (pé apontando para baixo na ponta do pé)
	# ou quando o pé está próximo ao solo, rotaciona pelo menor arco até a horizontal.
	var horiz := Vector3(vec.x, 0.0, vec.z)
	if horiz.length_squared() < 0.0001:
		horiz = Vector3(0.0, 0.0, 1.0)
	var ank_y := gp_f.origin.y
	# No apoio (ank_y <= 0.09 no espaço do esqueleto, ~14cm no mundo), nivelamento 100% plano.
	# No balanço aéreo, corrige 85% quando o pé aponta para baixo (vec.y < 0).
	var ground_k := clampf(1.0 - maxf(ank_y - 0.085, 0.0) / 0.16, 0.0, 1.0)
	var level_w := 1.0 if vec.y < 0.0 else ground_k * 0.85
	if ball_w > 0.01:
		level_w = 1.0 # parte de uma base neutra plana antes de esculpir o ângulo do toque
	if level_w > 0.001:
		var q_full := Quaternion(vec.normalized(), horiz.normalized())
		var q_apply := Quaternion.IDENTITY.slerp(q_full, level_w).normalized()
		gp_f.basis = Basis(q_apply) * gp_f.basis
		sk.set_bone_global_pose(f_idx, gp_f)
		# Mantém os dedos (Toes) alinhados à sola plana, sem dobrar para baixo nem para cima.
		var q_toe_rest := sk.get_bone_rest(t_idx).basis.get_rotation_quaternion()
		var q_toe_cur := sk.get_bone_pose_rotation(t_idx)
		sk.set_bone_pose_rotation(t_idx, q_toe_cur.slerp(q_toe_rest, clampf(level_w * 0.92, 0.0, 1.0)).normalized())
		sk.force_update_all_bone_transforms()


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

	# --- 1. Relaxa a curvatura excessiva dos dedos das mãos (evita punho fechado duro) ---
	for fb in _finger_bones:
		var q_rest := sk.get_bone_rest(fb).basis.get_rotation_quaternion()
		var q_anim := sk.get_bone_pose_rotation(fb)
		sk.set_bone_pose_rotation(fb, q_rest.slerp(q_anim, 0.42).normalized())

	# --- 1.1 Alinha clavículas/ombros para postura atlética natural (sem ombros caídos) ---
	for s_sh in [1.0, -1.0]:
		var sh_b: int = _shoulder_bones[s_sh]
		if sh_b >= 0:
			var q_sh_rest := sk.get_bone_rest(sh_b).basis.get_rotation_quaternion()
			var q_sh_anim := sk.get_bone_pose_rotation(sh_b)
			sk.set_bone_pose_rotation(sh_b, q_sh_rest.slerp(q_sh_anim, 0.65).normalized())

	# --- 2. Gingado, transferência de peso no quadril, finta e proteção de bola ---
	var move_factor := clampf(_smooth_amount * 1.4 + _smooth_gingado * 0.65, 0.0, 1.0)
	var gingado_amp := move_factor * (0.45 + 0.55 * _smooth_gingado)
	var sway_sin := sin(_gingado_phase)
	var sway_cos := cos(_gingado_phase)

	var combined_turn := clampf(_smooth_turn + _smooth_feint * 0.85, -1.35, 1.35)
	var bank_rad := deg_to_rad(TURN_BANK_DEG) * combined_turn
	var yaw_rad := deg_to_rad(TURN_YAW_DEG) * combined_turn

	# Proteção de bola / jogo de corpo contra marcador próximo:
	# No espaço do esqueleto (+Z = frente, -X = direita, +X = esquerda):
	# shield_side = +1 quando o marcador está à direita (-X), -1 quando à esquerda (+X).
	var shield_side := clampf(-_smooth_shield_local.x * 1.6, -1.0, 1.0)
	var shield_crouch := _smooth_shield * 0.020

	# Modulação procedural durante ações (chutes, passes, botes, recepções):
	var act_crouch := 0.0
	var act_pitch := 0.0
	var act_yaw := 0.0
	var act_roll := 0.0
	var act_arm_spread := 0.0
	if action_kind != &"":
		var pulse := sin(clampf(action_phase, 0.0, 1.0) * PI)
		match action_kind:
			&"pass", &"run_pass":
				act_crouch = 0.010 * pulse
				act_pitch = deg_to_rad(3.0) * pulse
				act_yaw = deg_to_rad(6.5 * action_side) * pulse
				act_arm_spread = 0.35 * pulse
			&"long_pass":
				act_crouch = 0.014 * pulse
				act_pitch = deg_to_rad(-3.5 if action_phase < 0.45 else 5.0) * pulse
				act_yaw = deg_to_rad(9.5 * action_side) * pulse
				act_arm_spread = 0.55 * pulse
			&"chip":
				act_crouch = 0.012 * pulse
				act_pitch = deg_to_rad(-4.5) * pulse
				act_arm_spread = 0.30 * pulse
			&"shoot", &"shoot_power":
				var pwr := clampf(action_power, 0.25, 1.0)
				if action_kind == &"shoot_power":
					pwr = maxf(pwr, 0.85)
				act_crouch = (0.012 + 0.012 * pwr) * pulse
				# Na preparação (phase < 0.42), abre o peito; na batida, inclina o tronco sobre a bola
				if action_phase < 0.42:
					act_pitch = deg_to_rad(-4.0 * pwr) * pulse
					act_yaw = deg_to_rad(-8.0 * action_side * pwr) * pulse
				else:
					act_pitch = deg_to_rad((4.5 + 6.5 * pwr)) * pulse
					act_yaw = deg_to_rad(10.0 * action_side * pwr) * pulse
				act_roll = deg_to_rad(-5.0 * action_side * pwr) * pulse
				act_arm_spread = (0.45 + 0.45 * pwr) * pulse
			&"tackle":
				# Bote de perna esticada: baixa a base e projeta o tronco firme à frente
				act_crouch = 0.026 * pulse
				act_pitch = deg_to_rad(8.5) * pulse
				act_yaw = deg_to_rad(7.0 * action_side) * pulse
				act_arm_spread = 0.60 * pulse
			&"recv_chest":
				# Domínio no peito: arqueia o tórax para trás amortecendo a bola e abre os braços
				act_crouch = 0.012 * pulse
				act_pitch = deg_to_rad(-9.5) * pulse
				act_arm_spread = 0.65 * pulse
			&"recv_knee", &"receive":
				# Recepção amortecida (coxa, sola ou chapa): absorve o impacto flexionando a base
				act_crouch = 0.016 * pulse
				act_pitch = deg_to_rad(3.5) * pulse
				act_arm_spread = 0.35 * pulse

	var cut_crouch := clampf(
		absf(combined_turn) * 0.020 + absf(_smooth_feint) * 0.015 + maxf(-_smooth_accel, 0.0) * 0.014
		+ _smooth_gingado * 0.008 + shield_crouch + act_crouch,
		0.0, 0.038
	)
	var hip_lat_shift := clampf(
		combined_turn * 0.022 + sway_sin * 0.009 * gingado_amp + shield_side * _smooth_shield * 0.016,
		-0.036, 0.036
	)
	var hips_pos := sk.get_bone_pose_position(_hips)
	hips_pos.y = maxf(hips_pos.y - cut_crouch, 0.15)
	hips_pos.x += hip_lat_shift
	sk.set_bone_pose_position(_hips, hips_pos)

	# Balanço pélvico (transferência de peso entre as pernas + giro de finta)
	var hip_roll := sway_sin * deg_to_rad(2.2) * gingado_amp + bank_rad * 0.18 + act_roll * 0.3
	var hip_yaw := sway_cos * deg_to_rad(2.5) * gingado_amp + yaw_rad * 0.20 + act_yaw * 0.25
	_rotate_bone_local(sk, _hips, 0.0, hip_yaw, hip_roll)

	var share_x := clampf(e_uchest.x * 0.30, deg_to_rad(-8.0), deg_to_rad(8.0))
	var raw_torso_x := e_hips.x + e_spine.x + e_chest.x + e_uchest.x
	var target_max_x := deg_to_rad(6.0 + 7.2 * _smooth_amount) + deg_to_rad(ACCEL_SPINE_DEG) * _smooth_accel \
		+ absf(combined_turn) * deg_to_rad(3.0) + deg_to_rad(5.5) * _smooth_shield + act_pitch
	var excess_x := maxf(0.0, raw_torso_x - target_max_x)
	var corr_x := excess_x * 0.80 - act_pitch * 0.65

	var corr_uc_y := -e_uchest.y * 0.22 if absf(e_uchest.y) > deg_to_rad(10.0) else 0.0
	var corr_uc_z := -e_uchest.z * 0.25 if absf(e_uchest.z) > deg_to_rad(5.5) else 0.0
	var gingado_torso_yaw := -sway_cos * deg_to_rad(3.4) * gingado_amp + act_yaw * 0.75
	var gingado_torso_roll := -sway_sin * deg_to_rad(2.6) * gingado_amp \
		+ shield_side * _smooth_shield * deg_to_rad(5.5) + act_roll * 0.70

	_rotate_bone_local(sk, _spine,
		share_x - corr_x * 0.25,
		corr_uc_y * 0.20 + yaw_rad * 0.26 + gingado_torso_yaw * 0.30,
		bank_rad * 0.28 + gingado_torso_roll * 0.30)
	_rotate_bone_local(sk, _chest,
		-corr_x * 0.30,
		corr_uc_y * 0.20 + yaw_rad * 0.32 + gingado_torso_yaw * 0.35,
		bank_rad * 0.34 + gingado_torso_roll * 0.35)
	_rotate_bone_local(sk, _upper_chest,
		-share_x - corr_x * 0.45,
		corr_uc_y * 0.60 + yaw_rad * 0.42 + gingado_torso_yaw * 0.35,
		corr_uc_z + bank_rad * 0.38 + gingado_torso_roll * 0.35)

	# --- 2.1 Contra-balanço dinâmico dos braços, proteção de bola e equilíbrio em chutes/botes ---
	for s_val in [1.0, -1.0]:
		var s: float = s_val
		var arm_b: int = _arm_bones[s]
		var fa_b: int = _forearm_bones[s]
		if arm_b >= 0:
			var lift: float = -s * combined_turn * deg_to_rad(12.0)
			if lift < 0.0:
				lift *= 0.35
			# Se o marcador está deste lado (s * shield_side > 0), ergue o braço/antebraço
			# em proteção ("jogo de corpo") para manter o adversário afastado da bola.
			var is_shield_arm := clampf(s * shield_side, 0.0, 1.0) * _smooth_shield
			lift += is_shield_arm * deg_to_rad(20.0) + act_arm_spread * deg_to_rad(16.0)
			var fwd: float = absf(combined_turn) * deg_to_rad(6.0) \
				+ maxf(-_smooth_accel, 0.0) * deg_to_rad(8.5) \
				+ is_shield_arm * deg_to_rad(14.0) \
				+ act_arm_spread * deg_to_rad(10.0 * (-s * action_side))
			_rotate_bone_local(sk, arm_b, fwd, 0.0, lift * s)
			if fa_b >= 0:
				var elbow: float = clampf(
					absf(combined_turn) * deg_to_rad(11.0)
					+ _smooth_gingado * deg_to_rad(6.0)
					+ is_shield_arm * deg_to_rad(26.0)
					+ act_arm_spread * deg_to_rad(14.0),
					0.0, deg_to_rad(38.0)
				)
				_rotate_bone_local(sk, fa_b, elbow, 0.0, 0.0)

	# --- 3. Olhar independente do tronco (bola ou companheiro de passe) ---
	q_hips = sk.get_bone_pose_rotation(_hips)
	var q_uchest_global := q_hips \
		* sk.get_bone_pose_rotation(_spine) \
		* sk.get_bone_pose_rotation(_chest) \
		* sk.get_bone_pose_rotation(_upper_chest)
	var q_neck_orig := sk.get_bone_pose_rotation(_neck)
	var q_head_orig := sk.get_bone_pose_rotation(_head)
	var q_head_anim_global := q_uchest_global * q_neck_orig * q_head_orig
	var anim_head_euler := q_head_anim_global.get_euler()

	var horizon_pitch := clampf(anim_head_euler.x * 0.25 + deg_to_rad(3.5), deg_to_rad(2.0), deg_to_rad(8.0))
	var horizon_yaw := clampf(anim_head_euler.y * 0.30 + yaw_rad * 0.85, deg_to_rad(-18.0), deg_to_rad(18.0))
	var horizon_roll := clampf(anim_head_euler.z * 0.20, deg_to_rad(-4.0), deg_to_rad(4.0))

	# Olhar direcionado para o alvo (bola ou companheiro para quem vai tocar,
	# girando apenas pescoço e rosto até ±48° sem virar o tronco).
	var head_origin_local := Vector3(0.0, 0.90, 0.04)
	var to_target := _smooth_ball_local - head_origin_local
	var horiz_dist := Vector2(to_target.x, to_target.z).length()
	var target_yaw := clampf(atan2(to_target.x, maxf(to_target.z, 0.20)), deg_to_rad(-48.0), deg_to_rad(48.0))
	var target_pitch := clampf(atan2(-to_target.y, maxf(horiz_dist, 0.42)) * 0.52, deg_to_rad(1.5), deg_to_rad(20.0))

	var final_pitch := lerpf(horizon_pitch, target_pitch, _smooth_gaze)
	var final_yaw := lerpf(horizon_yaw, target_yaw, _smooth_gaze)
	var final_roll := lerpf(horizon_roll, clampf(-final_yaw * 0.08, deg_to_rad(-4.5), deg_to_rad(4.5)), _smooth_gaze)

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

	var max_corr := 0.36 if mode == 2 else 0.30
	var delta_a := T - A
	if delta_a.length() > max_corr:
		T = A + delta_a.normalized() * max_corr

	var to_target := T - H
	var raw_d := to_target.length()
	if raw_d < 0.01:
		return
	var min_d := absf(L1 - L2) + 0.035
	var max_d := (L1 + L2) - 0.022
	var d := clampf(raw_d, min_d, max_d)
	var u_new := to_target / raw_d
	var T_clamped := H + u_new * d

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
				foot_euler = Vector3(deg_to_rad(12.0), deg_to_rad(-3.0 * side), 0.0)
			2: # KICK (peito do pé: dorso firme para chute forte / lançamento)
				foot_euler = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
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
