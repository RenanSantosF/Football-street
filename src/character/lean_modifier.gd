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

## (a arrancada/freada já inclina o corpo inteiro em _apply_body_lean)
const ACCEL_SPINE_DEG := 2.5
## (a inclinação nas curvas agora vem do corpo inteiro: _apply_body_lean;
##  aqui fica só um resto pequeno no tronco)
const TURN_BANK_DEG := 2.0
const TURN_YAW_DEG := 6.5

const MIN_ANKLE_Y := 0.095

## Aceleração horizontal REAL do corpo (mundo, m/s²) e desequilíbrio (0..1)
## com a direção para onde o corpo está sendo jogado (mundo).
var body_accel_world := Vector3.ZERO
var imbalance := 0.0
var imbalance_dir_world := Vector3.ZERO
## Estilo individual (variação entre jogadores): amplitude do balanço dos
## braços (0,85..1) e postura do tronco (graus extras de inclinação).
var style_arm := 1.0
## Inércia dos braços (pêndulo): ângulo máximo (graus) e estado da mola.
const ARM_INERTIA_MAX := 11.0
var _arm_swing := Vector2.ZERO
var _arm_swing_v := Vector2.ZERO
var style_torso_deg := 0.0
## Abertura da base (proteção de bola): 0..1.
var stance_wide := 0.0

## Inclinação do corpo inteiro: fração da inclinação física atan(a/g) e teto.
const LEAN_GAIN := 0.42
const LEAN_MAX_DEG := 11.0
## Quanto da inclinação a cabeça compensa (olhar fica mais nivelado).
const HEAD_LEVEL := 0.6
var _smooth_lean := Vector3.ZERO
var _smooth_imb := 0.0
var _smooth_wide := 0.0

## Referência do chão (HumanoidCharacter: origem no chão, sob os pés).
var ground_ref: Node3D = null
## Pontos da sola (HumanoidCharacter._extract_sole_points): lado -> [[osso, local]].
var sole_points := {1.0: [], -1.0: []}

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


func set_body_dynamics(accel_world: Vector3, imb: float, imb_dir_world: Vector3) -> void:
	body_accel_world = Vector3(accel_world.x, 0.0, accel_world.z)
	imbalance = clampf(imb, 0.0, 1.0)
	imbalance_dir_world = Vector3(imb_dir_world.x, 0.0, imb_dir_world.z)


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
		# Inclinação física: o corpo pende para a direção da aceleração
		# (curva = para dentro, freada = para trás, arrancada = para a frente).
		var lean_target := Vector3.ZERO
		var a_len := body_accel_world.length()
		if a_len > 0.05:
			var d_sk := sk_inv.basis * (body_accel_world / a_len)
			d_sk.y = 0.0
			if d_sk.length_squared() > 0.0001:
				var ang := minf(atan(a_len / 9.8) * LEAN_GAIN, deg_to_rad(LEAN_MAX_DEG))
				lean_target = d_sk.normalized() * ang
		if imbalance > 0.01 and imbalance_dir_world.length_squared() > 0.0001:
			var id_sk := sk_inv.basis * imbalance_dir_world.normalized()
			id_sk.y = 0.0
			if id_sk.length_squared() > 0.0001:
				lean_target += id_sk.normalized() * deg_to_rad(6.0) * imbalance
		# o corpo tem massa: a inclinação acompanha com um pequeno atraso
		_smooth_lean = _smooth_lean.lerp(lean_target, 1.0 - exp(-7.0 * dt))
		_smooth_imb = lerpf(_smooth_imb, imbalance, 1.0 - exp(-6.0 * dt))
		_smooth_wide = lerpf(_smooth_wide, stance_wide, 1.0 - exp(-6.0 * dt))
		# Braços com INÉRCIA (Etapa 27): cada braço é um pêndulo amortecido
		# (~1,6 Hz). Arrancando, ele fica para trás; freando, vai à frente;
		# na curva, abre para fora — e balança um pouco antes de assentar.
		var a_sk := sk_inv.basis * body_accel_world
		var arm_target := Vector2(
			clampf(-a_sk.z * deg_to_rad(1.6), -deg_to_rad(ARM_INERTIA_MAX), deg_to_rad(ARM_INERTIA_MAX)),
			clampf(-a_sk.x * deg_to_rad(1.3), -deg_to_rad(ARM_INERTIA_MAX), deg_to_rad(ARM_INERTIA_MAX)))
		var w0 := TAU * 1.6
		var acc2 := (arm_target - _arm_swing) * (w0 * w0) - _arm_swing_v * (2.0 * 0.32 * w0)
		_arm_swing_v += acc2 * dt
		_arm_swing += _arm_swing_v * dt
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

	# 1. Postura atlética alinhada, centrada e natural (sem entortar o tronco).
	_apply_athletic_posture(sk)

	# 2. (Etapa 25) Sem "nivelar o pé": com a pele correta (HumanoidCharacter.
	#    _fix_arm_binds) o pé da animação já apoia plano e rola naturalmente.
	#    Inclinação do corpo inteiro (a partir do apoio no chão) e acomodação
	#    do pé de apoio: calcanhar desce no trote, sola acompanha o chão.
	var ground_y_sk := (sk_inv * ground_ref.global_position).y if ground_ref != null else 0.0
	_apply_body_lean(sk, ground_y_sk)
	_settle_stance_feet(sk, ground_y_sk)
	_apply_wide_stance(sk, sk_inv)

	# 3. Ancoragem exata da sola no chão (impede que o pé afunde no piso).
	_anchor_feet_above_ground(sk)

	# 4. Leitura da pose base e IK analítica de toque na bola.
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


func _skip_procedural(sk: Skeleton3D) -> bool:
	if _hips < 0:
		return true
	if action_kind in [&"slide", &"trip", &"jump", &"header_jump"]:
		return true
	var e := sk.get_bone_global_pose(_hips).basis.get_euler()
	return absf(e.x) > deg_to_rad(42.0) or absf(e.z) > deg_to_rad(42.0)


## INCLINAÇÃO COORDENADA: o corpo inteiro gira em torno do ponto de apoio no
## chão (não do quadril), na direção da aceleração. A cabeça compensa parte
## (o olhar fica mais nivelado) e o pé apoiado acompanha o chão (tornozelo).
func _apply_body_lean(sk: Skeleton3D, ground_y_sk: float) -> void:
	var ang := _smooth_lean.length()
	if ang < 0.002 or _skip_procedural(sk):
		return
	var axis := Vector3.UP.cross(_smooth_lean / ang)
	if axis.length_squared() < 0.0001:
		return
	axis = axis.normalized()
	var r := Basis(axis, ang)
	var gp := sk.get_bone_global_pose(_hips)
	var pivot := Vector3(gp.origin.x, ground_y_sk, gp.origin.z)
	gp.origin = pivot + r * (gp.origin - pivot)
	gp.basis = r * gp.basis
	sk.set_bone_global_pose(_hips, gp)
	sk.force_update_all_bone_transforms()
	if _head >= 0:
		var gh := sk.get_bone_global_pose(_head)
		gh.basis = Basis(axis, -ang * HEAD_LEVEL) * gh.basis
		sk.set_bone_global_pose(_head, gh)
	for side in [1.0, -1.0]:
		var f_idx: int = _foot_bones[side]
		if f_idx < 0 or _ball_weight[side] > 0.05:
			continue
		var gf := sk.get_bone_global_pose(f_idx)
		var h := (gf.origin.y - ground_y_sk) * sk.global_transform.basis.get_scale().y
		var near := clampf(1.0 - (h - 0.06) / 0.08, 0.0, 1.0)
		if near > 0.0:
			gf.basis = Basis(axis, -ang * 0.75 * near) * gf.basis
			sk.set_bone_global_pose(f_idx, gf)
	sk.force_update_all_bone_transforms()


## PROTEÇÃO DE BOLA: base mais aberta e centro de massa um pouco mais baixo.
## O quadril desce e cada pé (que não está na bola) se afasta um pouco para o
## lado; a IK de 2 ossos dobra os joelhos mantendo os pés onde pisam.
func _apply_wide_stance(sk: Skeleton3D, sk_inv: Transform3D) -> void:
	var w := _smooth_wide
	if w < 0.02 or _skip_procedural(sk):
		return
	var to_sk := 1.0 / maxf(sk.global_transform.basis.get_scale().y, 0.0001)
	var feet := {}
	for side in [1.0, -1.0]:
		var f_idx: int = _foot_bones[side]
		if f_idx >= 0 and _ball_weight[side] < 0.05:
			feet[side] = sk.global_transform * sk.get_bone_global_pose(f_idx).origin
	var gp := sk.get_bone_global_pose(_hips)
	gp.origin.y -= 0.045 * w * to_sk
	sk.set_bone_global_pose(_hips, gp)
	sk.force_update_all_bone_transforms()
	for side in feet:
		# +X do esqueleto = esquerda do personagem (o modelo olha para +Z)
		var out_world := sk.global_transform.basis * Vector3(-side, 0.0, 0.0)
		out_world.y = 0.0
		var tgt: Vector3 = feet[side] + out_world.normalized() * 0.045 * w
		_solve_two_bone_leg(sk, sk_inv, side, tgt, 1.0, -1)


## Pé de APOIO no trote/andando: o calcanhar acomoda no chão (a passada dos
## clipes de trote pisa só com o antepé = "ponta dos pés"). Correndo forte o
## apoio no antepé é o natural, então o ajuste quase some.
func _settle_stance_feet(sk: Skeleton3D, ground_y_sk: float) -> void:
	if _skip_procedural(sk):
		return
	var sc := sk.global_transform.basis.get_scale().y
	var k := lerpf(0.55, 0.12, clampf(_smooth_amount, 0.0, 1.0))
	for side in [1.0, -1.0]:
		var pts: Array = sole_points[side]
		var f_idx: int = _foot_bones[side]
		if pts.size() < 3 or f_idx < 0 or _ball_weight[side] > 0.05:
			continue
		var heel: Vector3 = sk.get_bone_global_pose(pts[0][0]) * (pts[0][1] as Vector3)
		var mid: Vector3 = sk.get_bone_global_pose(pts[1][0]) * (pts[1][1] as Vector3)
		var tip: Vector3 = sk.get_bone_global_pose(pts[2][0]) * (pts[2][1] as Vector3)
		var contact_h := (minf(mid.y, tip.y) - ground_y_sk) * sc
		if contact_h > 0.03:
			continue # pé no ar: a animação manda
		var sole := tip - heel
		if sole.y >= 0.0:
			continue # calcanhar já embaixo (pisada de calcanhar)
		var horiz := Vector3(sole.x, 0.0, sole.z)
		if horiz.length_squared() < 0.000001:
			continue
		var w := k * clampf(1.0 - contact_h / 0.03, 0.0, 1.0)
		var q := Quaternion(sole.normalized(), horiz.normalized())
		var full := q.get_angle()
		if full < 0.01:
			continue
		var apply_ang := minf(full * w, deg_to_rad(14.0))
		var qa := Quaternion(q.get_axis().normalized(), apply_ang)
		var gf := sk.get_bone_global_pose(f_idx)
		gf.basis = Basis(qa) * gf.basis
		sk.set_bone_global_pose(f_idx, gf)
	sk.force_update_all_bone_transforms()


## Apoio pela SOLA de verdade: o ponto mais baixo das solas (calcanhar, meio
## e ponta, extraídos da malha) não pode entrar no chão; com os dois pés quase
## no chão, encosta a sola (sem flutuar). Só move o quadril na vertical.
func _anchor_feet_above_ground(sk: Skeleton3D) -> void:
	if _hips < 0 or ground_ref == null:
		return
	if sole_points[1.0].is_empty() and sole_points[-1.0].is_empty():
		return
	var gp_hips := sk.get_bone_global_pose(_hips)
	var e_hips := gp_hips.basis.get_euler()
	if absf(e_hips.x) > deg_to_rad(42.0) or absf(e_hips.z) > deg_to_rad(42.0):
		return # caído/carrinho: não desloca o quadril
	var sk_xform := sk.global_transform
	var ground_y := ground_ref.global_position.y
	var lowest := INF
	for side in [1.0, -1.0]:
		for sp in sole_points[side]:
			var w: Vector3 = sk_xform * (sk.get_bone_global_pose(sp[0]) * (sp[1] as Vector3))
			lowest = minf(lowest, w.y - ground_y)
	if lowest == INF:
		return
	# metros (mundo) -> unidades do esqueleto
	var to_sk := 1.0 / maxf(sk_xform.basis.get_scale().y, 0.0001)
	var shift := 0.0
	if lowest < 0.0:
		shift = -lowest # entrou no chão: sobe
	elif lowest < 0.014 and not (action_kind in [&"jump", &"header_jump"]):
		shift = -lowest * 0.65 # quase apoiado: encosta a sola
	if absf(shift) > 0.0002:
		gp_hips.origin.y += shift * to_sk
		sk.set_bone_global_pose(_hips, gp_hips)
		sk.force_update_all_bone_transforms()


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
	var horiz := Vector3(vec.x, 0.0, vec.z)
	if horiz.length_squared() < 0.0001:
		horiz = Vector3(0.0, 0.0, 1.0)
	var ank_y := gp_f.origin.y
	var ground_k := clampf(1.0 - maxf(ank_y - 0.095, 0.0) / 0.16, 0.0, 1.0)
	var level_w := 1.0 if vec.y < 0.0 else ground_k * 0.85
	if ball_w > 0.01:
		level_w = 1.0
	if level_w > 0.001:
		var q_full := Quaternion(vec.normalized(), horiz.normalized())
		var q_apply := Quaternion.IDENTITY.slerp(q_full, level_w).normalized()
		gp_f.basis = Basis(q_apply) * gp_f.basis
		sk.set_bone_global_pose(f_idx, gp_f)
		var q_toe_rest := sk.get_bone_rest(t_idx).basis.get_rotation_quaternion()
		var q_toe_cur := sk.get_bone_pose_rotation(t_idx)
		sk.set_bone_pose_rotation(t_idx, q_toe_cur.slerp(q_toe_rest, clampf(level_w * 0.92, 0.0, 1.0)).normalized())
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
		sk.set_bone_pose_rotation(fb, q_rest.slerp(q_anim, 0.42).normalized())

	# --- 1.1 Alinha clavículas/ombros para postura atlética simétrica ---
	for s_sh in [1.0, -1.0]:
		var sh_b: int = _shoulder_bones[s_sh]
		if sh_b >= 0:
			var q_sh_rest := sk.get_bone_rest(sh_b).basis.get_rotation_quaternion()
			var q_sh_anim := sk.get_bone_pose_rotation(sh_b)
			sk.set_bone_pose_rotation(sh_b, q_sh_rest.slerp(q_sh_anim, 0.55).normalized())

	# --- 1.2 Endireita inclinações laterais/torções tortas vindas de clipes brutos na coluna ---
	for sp_b in [_spine, _chest, _upper_chest]:
		var e_b := sk.get_bone_pose_rotation(sp_b).get_euler()
		var e_rest := sk.get_bone_rest(sp_b).basis.get_euler()
		# Mantém o giro natural da corrida mas remove inclinação lateral torta (roll Z) e excesso de torção (yaw Y)
		var clean_y := lerpf(e_b.y, e_rest.y, 0.45)
		var clean_z := lerpf(e_b.z, e_rest.z, 0.65)
		sk.set_bone_pose_rotation(sp_b, Quaternion.from_euler(Vector3(e_b.x, clean_y, clean_z)))

	var e_spine := sk.get_bone_pose_rotation(_spine).get_euler()
	var e_chest := sk.get_bone_pose_rotation(_chest).get_euler()
	var e_uchest := sk.get_bone_pose_rotation(_upper_chest).get_euler()

	# --- 2. Postura centrada, equilibrada e fluida ---
	var move_factor := clampf(_smooth_amount * 1.2 + _smooth_gingado * 0.4, 0.0, 1.0)
	var gingado_amp := move_factor * 0.35
	var sway_sin := sin(_gingado_phase)
	var sway_cos := cos(_gingado_phase)

	var combined_turn := clampf(_smooth_turn * 0.75 + _smooth_feint * 0.45, -1.0, 1.0)
	var bank_rad := deg_to_rad(TURN_BANK_DEG) * combined_turn
	var yaw_rad := deg_to_rad(TURN_YAW_DEG) * combined_turn

	var shield_side := clampf(-_smooth_shield_local.x * 1.4, -1.0, 1.0)

	# Modulação procedural durante ações (chutes, passes, botes, recepções):
	var act_pitch := 0.0
	var act_yaw := 0.0
	var act_roll := 0.0
	var act_arm_spread := 0.0
	if action_kind != &"":
		var pulse := sin(clampf(action_phase, 0.0, 1.0) * PI)
		match action_kind:
			&"pass", &"run_pass":
				act_pitch = deg_to_rad(2.5) * pulse
				act_yaw = deg_to_rad(5.0 * action_side) * pulse
				act_arm_spread = 0.28 * pulse
			&"touch_pass":
				# toque leve na passada: tronco e braços só acompanham
				act_yaw = deg_to_rad(2.5 * action_side) * pulse
				act_arm_spread = 0.12 * pulse
			&"long_pass", &"through", &"firm_pass":
				act_pitch = deg_to_rad(-3.0 if action_phase < 0.45 else 4.5) * pulse
				act_yaw = deg_to_rad(8.0 * action_side) * pulse
				act_arm_spread = 0.45 * pulse
			&"chip":
				act_pitch = deg_to_rad(-3.5) * pulse
				act_arm_spread = 0.25 * pulse
			&"shoot", &"shoot_b", &"shoot_power":
				var pwr := clampf(action_power, 0.25, 1.0)
				if action_kind == &"shoot_power":
					pwr = maxf(pwr, 0.85)
				if action_phase < 0.42:
					act_pitch = deg_to_rad(-3.5 * pwr) * pulse
					act_yaw = deg_to_rad(-6.5 * action_side * pwr) * pulse
				else:
					act_pitch = deg_to_rad((4.0 + 5.0 * pwr)) * pulse
					act_yaw = deg_to_rad(8.0 * action_side * pwr) * pulse
				act_roll = deg_to_rad(-3.5 * action_side * pwr) * pulse
				act_arm_spread = (0.35 + 0.35 * pwr) * pulse
			&"tackle":
				act_pitch = deg_to_rad(6.5) * pulse
				act_yaw = deg_to_rad(5.5 * action_side) * pulse
				act_arm_spread = 0.45 * pulse
			&"recv_chest":
				act_pitch = deg_to_rad(-8.0) * pulse
				act_arm_spread = 0.50 * pulse
			&"recv_knee", &"receive":
				act_pitch = deg_to_rad(3.0) * pulse
				act_arm_spread = 0.25 * pulse

	# Quadril centrado horizontalmente (X = 0) para nunca deixar o corpo torto
	var hips_pos := sk.get_bone_pose_position(_hips)
	hips_pos.x = 0.0
	sk.set_bone_pose_position(_hips, hips_pos)

	# Balanço pélvico discreto e anatômico
	var hip_roll := sway_sin * deg_to_rad(1.0) * gingado_amp + bank_rad * 0.15
	var hip_yaw := sway_cos * deg_to_rad(1.2) * gingado_amp + yaw_rad * 0.18
	_rotate_bone_local(sk, _hips, 0.0, hip_yaw, hip_roll)

	var share_x := clampf(e_uchest.x * 0.28, deg_to_rad(-6.0), deg_to_rad(6.0))
	var raw_torso_x := e_hips.x + e_spine.x + e_chest.x + e_uchest.x
	var target_max_x := deg_to_rad(4.5 + 5.5 * _smooth_amount + style_torso_deg) + deg_to_rad(ACCEL_SPINE_DEG) * _smooth_accel \
		+ absf(combined_turn) * deg_to_rad(2.0) + deg_to_rad(3.5) * _smooth_shield + act_pitch
	var excess_x := maxf(0.0, raw_torso_x - target_max_x)
	var corr_x := excess_x * 0.82 - act_pitch * 0.65

	var gingado_torso_yaw := -sway_cos * deg_to_rad(1.6) * gingado_amp + act_yaw * 0.70
	var gingado_torso_roll := -sway_sin * deg_to_rad(1.2) * gingado_amp \
		+ shield_side * _smooth_shield * deg_to_rad(3.0) + act_roll * 0.60

	_rotate_bone_local(sk, _spine,
		share_x - corr_x * 0.25,
		yaw_rad * 0.25 + gingado_torso_yaw * 0.30,
		bank_rad * 0.25 + gingado_torso_roll * 0.30)
	_rotate_bone_local(sk, _chest,
		-corr_x * 0.30,
		yaw_rad * 0.32 + gingado_torso_yaw * 0.35,
		bank_rad * 0.30 + gingado_torso_roll * 0.35)
	_rotate_bone_local(sk, _upper_chest,
		-share_x - corr_x * 0.45,
		yaw_rad * 0.38 + gingado_torso_yaw * 0.35,
		bank_rad * 0.35 + gingado_torso_roll * 0.35)

	# --- 2.1 Braços naturais na corrida e proteção quando encostado no marcador ---
	if style_arm < 0.999:
		# estilo individual: uns balançam os braços menos que outros
		for s_st in [1.0, -1.0]:
			for ab in [_arm_bones[s_st], _forearm_bones[s_st]]:
				if ab >= 0:
					var q_r := sk.get_bone_rest(ab).basis.get_rotation_quaternion()
					sk.set_bone_pose_rotation(ab, q_r.slerp(sk.get_bone_pose_rotation(ab), style_arm).normalized())
	for s_val in [1.0, -1.0]:
		var s: float = s_val
		var arm_b: int = _arm_bones[s]
		var fa_b: int = _forearm_bones[s]
		if arm_b >= 0:
			var lift: float = -s * combined_turn * deg_to_rad(6.0)
			if lift < 0.0:
				lift *= 0.35
			var is_shield_arm := clampf(s * shield_side, 0.0, 1.0) * _smooth_shield
			lift += is_shield_arm * deg_to_rad(16.0) + act_arm_spread * deg_to_rad(12.0)
			# equilíbrio: o braço de FORA da curva abre um pouco; desequilibrado,
			# os dois braços abrem para segurar o corpo (sem exagero)
			lift += clampf(_smooth_lean.x * s * 0.9, 0.0, deg_to_rad(10.0))
			lift += _smooth_imb * deg_to_rad(18.0)
			# inércia: abre para fora da curva (para dentro, pouco: não entra no tronco)
			var in_roll := _arm_swing.y * s
			lift += in_roll if in_roll > 0.0 else in_roll * 0.3
			var fwd: float = _arm_swing.x + absf(combined_turn) * deg_to_rad(4.0) \
				+ is_shield_arm * deg_to_rad(10.0) \
				+ act_arm_spread * deg_to_rad(8.0 * (-s * action_side))
			_rotate_bone_local(sk, arm_b, fwd, 0.0, lift * s)
			if fa_b >= 0:
				var elbow: float = clampf(
					absf(combined_turn) * deg_to_rad(7.0)
					+ is_shield_arm * deg_to_rad(20.0)
					+ act_arm_spread * deg_to_rad(10.0),
					0.0, deg_to_rad(28.0)
				)
				_rotate_bone_local(sk, fa_b, elbow, 0.0, 0.0)

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
	var horizon_yaw := clampf(anim_head_euler.y * 0.25 + yaw_rad * 0.65, deg_to_rad(-14.0), deg_to_rad(14.0))
	var horizon_roll := clampf(anim_head_euler.z * 0.15, deg_to_rad(-3.0), deg_to_rad(3.0))

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
	var rest_foot_y := sk.get_bone_global_rest(f_idx).origin.y
	T.y = maxf(T.y, rest_foot_y)

	var L1 := (K - H).length()
	var L2 := (A - K).length()
	if L1 < 0.05 or L2 < 0.05:
		return

	var max_corr := 0.34 if mode == 2 else (0.52 if mode == 7 else 0.28)
	var delta_a := T - A
	if delta_a.length() > max_corr:
		T = A + delta_a.normalized() * max_corr
	T.y = maxf(T.y, rest_foot_y)

	var to_target := T - H
	var raw_d := to_target.length()
	if raw_d < 0.01:
		return
	var min_d := absf(L1 - L2) + 0.035
	var max_d := (L1 + L2) - 0.022
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
	# Abrir/fechar o pé (chapa, amortecer, três dedos) é uma rotação da PERNA
	# INTEIRA no quadril — o tornozelo quase não torce (antes 22° só no
	# tornozelo = malha "torcida" na canela).
	var twist_deg := 0.0
	match mode:
		0, 4:
			twist_deg = 30.0
		3:
			twist_deg = 24.0
		5:
			twist_deg = -12.0
	if ball_w > 0.01 and twist_deg != 0.0:
		var up_axis := (H - T_clamped).normalized()
		var q_tw := Quaternion(up_axis, deg_to_rad(-side * twist_deg) * clampf(ball_w, 0.0, 1.0))
		gp_hip.basis = Basis(q_tw) * gp_hip.basis
		gp_knee.origin = H + q_tw * (gp_knee.origin - H)
		gp_knee.basis = Basis(q_tw) * gp_knee.basis
		gp_foot.basis = Basis(q_tw) * gp_foot.basis
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
		if mode in [0, 3, 4, 5]:
			foot_euler *= 0.4 # o resto do giro já veio do quadril
		var rot_mod := Basis.from_euler(foot_euler * clampf(ball_w * 1.12, 0.0, 0.96))
		gp_foot.basis = gp_foot.basis * rot_mod

	sk.set_bone_global_pose(h_idx, gp_hip)
	sk.set_bone_global_pose(k_idx, gp_knee)
	sk.set_bone_global_pose(f_idx, gp_foot)
	sk.force_update_all_bone_transforms()
