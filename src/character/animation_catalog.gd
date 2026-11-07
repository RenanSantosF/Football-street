class_name AnimationCatalog
extends RefCounted
## Catálogo central de animações humanoides.
##
## Todas as bibliotecas passam pelo retarget para o SkeletonProfileHumanoid do
## Godot, então qualquer clipe toca em qualquer personagem. Cada arquivo entra
## com um prefixo; o resto do jogo usa só os NOMES LÓGICOS ("pass_short").
## Trocar um clipe por um melhor = mudar uma linha aqui.
##
## Clipes do Mixamo são opcionais: se o arquivo não estiver no projeto, o
## estado correspondente simplesmente não é criado e o jogo segue funcionando.

const UAL := "res://assets/animations/ual/AnimationLibrary_Godot_Standard.gltf"
const MIXAMO_PACK := "res://assets/animations/mixamo/pack/%s.fbx"
const TEEN_01 := "res://assets/characters/teen_01/teen_01.fbx"
## Pack de mocap de futebol (Anderson Rohr, esqueleto UE5 convertido). Livre
## para uso comercial; não redistribuir o pack sozinho (os FBX não vão para o git).
const ROHR := "res://assets/animations/rohr/%s.fbx"

## prefixo -> arquivo (nome do pack do Mixamo ou caminho res://)
const LIBRARY_SOURCES := {
	&"ual": UAL,
	# locomoção
	&"m_soccer_idle": "Soccer Idle",
	&"m_offensive_idle": "Offensive Idle",
	&"m_slow_jog": "Slow Jog",
	&"m_jog": "Jog Forward",
	&"m_run": "Standard Run",
	&"m_sprint": "Sprint",
	&"m_idle_to_sprint": "Idle To Sprint",
	&"m_dribble": "Dribble",
	# marcação (andar de lado / de costas)
	&"m_gk_idle": "Soccer Idle",
	&"m_back": "Run Backward",
	&"m_strafe_l_jog": "Jog Strafe Left",
	&"m_strafe_r_jog": "Jog Strafe Right",
	&"m_strafe_l_walk": "Left Strafe Walking",
	&"m_strafe_l_fast": "Left Strafe",
	&"m_strafe_r_fast": "Right Strafe",
	&"m_diag_l": "Jog Forward Diagonal (1)",
	&"m_diag_r": "Jog Forward Diagonal",
	# ações com bola
	&"m_pass_short": "Soccer Pass toque ",
	&"m_pass_long": "Kick Soccerball",
	&"m_shoot": "Strike Foward Jog",
	&"m_shoot_power": "Soccer Penalty Kick",
	&"m_receive": "Stall Soccerball (1)",
	&"m_spin": "Soccer Spin",
	&"m_cut": "Change Direction",
	# domínio no ar e cabeceio
	&"m_chest": "Receive",
	&"m_header": "Header",
	&"m_head_ctrl": "Header Soccerball",
	&"m_header_jump": "Soccer Header",
	# defesa / quedas
	&"m_tackle": "Soccer Tackle (2)",
	&"m_trip": "Soccer Trip",
	&"m_fallen": "Fallen Idle caído depois da falta",
	&"m_jump": "Running Jump pulando fugindo do carrinho",
	# opcional: levantar do chão (se o arquivo existir no pack)
	&"m_breathing": "Breathing Idle",
	&"m_walking": "Walking",
	&"m_turn_l": "Left Turn",
	&"m_turn_r": "Right Turn",
	&"m_turn180": "Running Turn 180",
	&"m_cut_r": "Running Right Turn",
	&"m_walk_turn180": "Walking Turn 180",
	&"m_stand_turn_r": "Standing Cover Turn",
	&"m_walk_stop": "Stop Walking",
	&"m_run_stop": "Run To Stop",
	&"m_argue": "Standing Arguing",
	&"m_getup": "Standing Up",
	&"m_getup_b": "Stand Up",
	&"m_getup_c": "Stand Up (1)",
	# reações
	&"m_victory": "Victory",
	&"m_victory_idle": "Victory Idle",
	&"m_samba": "Samba Dancing",
	&"m_defeated": "Defeated",
	&"m_sad_run": "Run Forward triste depois de errar correndo triste",
	# goleiro
	&"m_gk_catch": "Goalkeeper Catch",
	&"m_gk_pass": "Goalkeeper Pass",
	&"m_gk_place": "Goalkeeper Placing Ball (1)",
	# adolescentes esperando (Etapa 6): embaixadinhas e aquecimento
	&"m_kick_up": "Kick Up Soccerball",
	&"r_side_kick": ROHR % "08_Side_Foot_Kick_ue5",
	&"r_power_kick": ROHR % "09_Power_Kick_ue5",
	&"r_juggling": ROHR % "04_Juggling_01_ue5",
	&"m_kneeing": "Kneeing Soccerball",
	&"m_warmup": "Offensive Idle aquecimento",
	# animações adicionais catalogadas no pack Mixamo
	&"m_receive_ball": "Receive Soccerball",
	&"m_gk_dive": "Goalkeeper Diving Save",
	&"m_scissor": "Scissor Kick",
	&"m_sprint_turn": "Sprint Turn",
	&"m_run_to_turn": "Running To Turn",
	&"m_walk_turn_l": "Walking Left Turn",
	&"m_start_walk": "Start Walking",
	&"m_stand_tackle": "Soccer Tackle",
	&"m_walk_strafe_l": "Walk Strafe Left",
	&"m_diag_back_l": "Jog Forward Diagonal (2)",
	&"m_diag_back_r": "Jog Forward Diagonal (3)",
}

## nome lógico -> "prefixo/clipe"
const CLIPS := {
	&"idle": &"m_breathing/mixamo_com",
	&"soccer_idle": &"m_soccer_idle/mixamo_com",
	&"turn_l": &"m_turn_l/mixamo_com",
	&"turn_r": &"m_turn_r/mixamo_com",
	&"turn180": &"m_turn180/mixamo_com",
	&"cut_r": &"m_cut_r/mixamo_com",
	&"walk_turn180": &"m_walk_turn180/mixamo_com",
	&"stand_turn_r": &"m_stand_turn_r/mixamo_com",
	&"walk_stop": &"m_walk_stop/mixamo_com",
	&"run_stop": &"m_run_stop/mixamo_com",
	&"argue": &"m_argue/mixamo_com",
	&"idle_ball": &"m_offensive_idle/mixamo_com",
	&"walk": &"m_walking/mixamo_com",
	&"slow_jog": &"m_slow_jog/mixamo_com",
	&"jog": &"m_jog/mixamo_com",
	&"run": &"m_run/mixamo_com",
	&"sprint": &"m_sprint/mixamo_com",
	&"idle_to_sprint": &"m_idle_to_sprint/mixamo_com",
	&"dribble": &"m_dribble/mixamo_com",
	&"mark_idle": &"m_gk_idle/mixamo_com",
	&"back": &"m_back/mixamo_com",
	&"strafe_l_jog": &"m_strafe_l_jog/mixamo_com",
	&"strafe_r_jog": &"m_strafe_r_jog/mixamo_com",
	&"strafe_l_walk": &"m_strafe_l_walk/mixamo_com",
	&"strafe_l_fast": &"m_strafe_l_fast/mixamo_com",
	&"strafe_r_fast": &"m_strafe_r_fast/mixamo_com",
	&"diag_l": &"m_diag_l/mixamo_com",
	&"diag_r": &"m_diag_r/mixamo_com",
	&"pass_short": &"m_pass_short/mixamo_com",
	&"pass_long": &"m_pass_long/mixamo_com",
	&"shoot": &"m_shoot/mixamo_com",
	&"shoot_power": &"m_shoot_power/mixamo_com",
	&"receive": &"m_receive/mixamo_com",
	&"receive_ball": &"m_receive_ball/mixamo_com",
	&"spin": &"m_spin/mixamo_com",
	&"cut": &"m_cut/mixamo_com",
	&"recv_chest": &"m_chest/mixamo_com",
	&"recv_knee": &"m_kneeing/mixamo_com",
	&"header": &"m_header/mixamo_com",
	&"head_control": &"m_head_ctrl/mixamo_com",
	&"header_jump": &"m_header_jump/mixamo_com",
	&"tackle": &"m_tackle/mixamo_com",
	&"stand_tackle": &"m_stand_tackle/mixamo_com",
	&"trip": &"m_trip/mixamo_com",
	&"fallen": &"m_fallen/mixamo_com",
	&"jump": &"m_jump/mixamo_com",
	&"getup": &"m_getup/mixamo_com",
	&"getup_b": &"m_getup_b/mixamo_com",
	&"getup_c": &"m_getup_c/mixamo_com",
	&"victory": &"m_victory/mixamo_com",
	&"victory_idle": &"m_victory_idle/mixamo_com",
	&"samba": &"m_samba/mixamo_com",
	&"defeated": &"m_defeated/mixamo_com",
	&"sad_run": &"m_sad_run/mixamo_com",
	&"gk_catch": &"m_gk_catch/mixamo_com",
	&"gk_dive": &"m_gk_dive/mixamo_com",
	&"gk_pass": &"m_gk_pass/mixamo_com",
	&"gk_place": &"m_gk_place/mixamo_com",
	&"kick_up": &"m_kick_up/mixamo_com",
	&"kneeing": &"m_kneeing/mixamo_com",
	&"warmup": &"m_warmup/mixamo_com",
	&"scissor_kick": &"m_scissor/mixamo_com",
	&"sprint_turn": &"m_sprint_turn/mixamo_com",
	&"run_to_turn": &"m_run_to_turn/mixamo_com",
	&"walk_turn_l": &"m_walk_turn_l/mixamo_com",
	&"start_walk": &"m_start_walk/mixamo_com",
	# reserva (biblioteca UAL)
	&"ual_idle": &"ual/Idle",
	&"ual_walk": &"ual/Walk",
	&"ual_jog": &"ual/Jog_Fwd",
	&"ual_sprint": &"ual/Sprint",
	&"stumble": &"ual/Hit_Chest",
	&"talk": &"ual/Idle_Talking",
	&"pickup": &"ual/PickUp_Table",
}

## Clipes que repetem em ciclo (o FBX do Mixamo não marca loop).
const LOOPING: Array[StringName] = [
	&"idle", &"soccer_idle", &"argue", &"idle_ball", &"walk", &"slow_jog", &"jog", &"run", &"sprint", &"dribble",
	&"mark_idle", &"back", &"strafe_l_jog", &"strafe_r_jog", &"strafe_l_walk",
	&"strafe_l_fast", &"strafe_r_fast", &"diag_l", &"diag_r", &"fallen",
	&"victory_idle", &"samba", &"sad_run", &"kick_up", &"kneeing", &"warmup", &"talk",
]

## Instante (s) em que o pé encosta na bola e qual pé (+1 direito, -1 esquerdo).
## Conferido quadro a quadro (docs/ETAPA_04.md).
const CONTACTS := {
	&"pass_short": [0.50, 1.0],
	&"pass_long": [0.15, -1.0],
	&"shoot": [0.45, 1.0],
	&"shoot_power": [0.79, 1.0],
	&"receive": [0.29, 1.0],
	&"receive_ball": [0.28, 1.0],
	&"tackle": [0.36, -1.0],
	# (medido no esqueleto: extensão máxima da perna do bote ≈ 0,18 s)
	&"stand_tackle": [0.18, 1.0],
	&"spin": [1.0, 1.0],
	&"gk_pass": [1.15, 1.0],
	&"scissor_kick": [0.55, 1.0],
	# domínio no ar / cabeceio (0 = corpo/cabeça; -1 joelho esquerdo)
	&"recv_chest": [0.45, 0.0],
	&"recv_knee": [0.52, -1.0],
	&"header": [0.6, 0.0],
	&"head_control": [0.75, 0.0],
	&"header_jump": [1.2, 0.0],
}

## Trechos recortados das tomadas longas de mocap: prefixo -> {nome: [início, fim]} (s).
const SEGMENTS := {
	&"r_side_kick": {&"seg_pass": [0.90, 2.40]},
	&"r_power_kick": {&"seg_kick": [1.90, 3.60]},
	&"r_juggling": {&"seg_juggle": [1.0, 21.0]},
}


## Levantar do chão: trecho útil de cada clipe (o resto é deitado ou em pé
## parado) e velocidade de reprodução. getup = de bruços (depois do tropeço),
## getup_b = de costas (depois do carrinho).
const GETUP_SEGMENTS := {
	&"getup": [3.8, 8.6],
	&"getup_b": [3.4, 7.0],
}
const GETUP_SPEED := 2.4


static func getup_duration(logical: StringName) -> float:
	if not has_clip(logical) or not GETUP_SEGMENTS.has(logical):
		return 0.0
	var cpath := String(clip(logical))
	if cpath.begins_with("ual_fb/"):
		return clip_length(logical) / GETUP_SPEED
	var seg: Array = GETUP_SEGMENTS[logical]
	return (seg[1] - seg[0]) / GETUP_SPEED


## Velocidade natural (m/s) da passada de cada clipe, normalizada para um
## quadril de 0,93 m (HumanoidCharacter.REF_HIPS_HEIGHT). Sincronizada com a
## velocidade real do pé de apoio no solo para eliminar deslizamento (foot skating).
const LOCOMOTION_POINTS: Array = [
	[&"idle", 0.0], [&"walk", 1.35], [&"jog", 2.25], [&"run", 3.35], [&"sprint", 4.35],
]
## (Etapa 25: o clipe "Dribble" — passada natural ≈ 2,8 m/s — foi testado
##  aqui, mas o pé dele "chuta" uma bola imaginária e empurrava a bola de
##  verdade para longe nas viradas; ficou de fora.)
const LOCOMOTION_BALL_POINTS: Array = [
	[&"idle", 0.0], [&"walk", 1.35], [&"jog", 2.25], [&"run", 3.35], [&"sprint", 4.35],
]
## Marcação: velocidade local (x = para a direita, y = para a frente), m/s.
const MARK_POINTS: Array = [
	[&"mark_idle", Vector2(0.0, 0.0)],
	[&"jog", Vector2(0.0, 2.25)],
	# (Etapa 27) correndo para a frente enquanto marca: antes extrapolava o
	# trote e a passada não casava com a velocidade (pé "brigando" com o IK)
	[&"run", Vector2(0.0, 3.35)],
	[&"sprint", Vector2(0.0, 4.35)],
	# ("Run Backward" vem com o corpo virado 180°: misturado aos outros, o quadril
	#  "estalava". Recuar rápido = virar e correr; ver Player._compute_marking)
	[&"strafe_l_walk", Vector2(-1.45, 0.0)],
	[&"strafe_l_jog", Vector2(-2.35, 0.0)],
	[&"strafe_r_jog", Vector2(2.10, 0.0)],
	[&"strafe_l_fast", Vector2(-3.40, 0.0)],
	[&"strafe_r_fast", Vector2(3.40, 0.0)],
	[&"diag_l", Vector2(-1.65, 1.65)],
	[&"diag_r", Vector2(1.70, 1.70)],
]
## Mais rápido que isto, a passada acelera (TimeScale).
const TOP_SPEED := 4.35

## Compatibilidade com código antigo (velocidades por nome lógico).
const LOCOMOTION_SPEEDS := {&"sprint": 4.35}

const HIPS_POSITION_TRACK := "%GeneralSkeleton:Hips"
## Clipes cujo deslocamento do corpo vem da própria animação (root motion):
## a física do jogador segue a curva do quadril gravada no clipe.
const ROOT_MOTION: Array[StringName] = [&"tackle", &"trip", &"jump", &"spin", &"turn180", &"turn_l", &"turn_r", &"run_stop",
	&"cut_r", &"walk_turn180", &"stand_turn_r", &"walk_stop"]
## Ângulo (graus, + = esquerda) de cada virada, medido nos clipes. As versões
## "_m" (espelhadas) viram para o outro lado.
const TURN_ANGLES := {
	&"turn180": -180.0, &"turn_l": 90.0, &"turn_r": -90.0,
	&"cut_r": -40.0, &"walk_turn180": -180.0, &"stand_turn_r": -55.0,
}
const ROOT_MOTION_FPS := 30.0
## Clipes que levantam no lugar (quadril fixo na horizontal).
const IN_PLACE_FIXED: Array[StringName] = [&"getup", &"getup_b", &"getup_c", &"fallen"]

static var _libraries := {}
static var _fallback_clips := {}
## clipe "prefixo/nome" -> deslocamento horizontal total retirado (root motion).
static var root_motion := {}
## clipe "prefixo/nome" -> curva do deslocamento horizontal do quadril
## (PackedVector3Array, ROOT_MOTION_FPS amostras/s, em alturas de quadril).
static var root_curves := {}
## clipe -> giro acumulado do quadril (rad), ROOT_MOTION_FPS amostras/s.
static var root_yaw := {}


## Bibliotecas carregadas (cache compartilhado por todos os personagens).
static var _loaded := false


static func get_libraries() -> Dictionary:
	if not _loaded:
		_loaded = true # marca antes de carregar: nunca recarrega nem recursa
		for prefix: StringName in LIBRARY_SOURCES:
			var src: String = LIBRARY_SOURCES[prefix]
			var path := src if src.begins_with("res://") else MIXAMO_PACK % src
			if not ResourceLoader.exists(path):
				continue
			# No editor, um .import sem o arquivo de origem (clipe opcional ainda
			# não copiado) não é erro: só pula.
			if OS.has_feature("editor") and not FileAccess.file_exists(path):
				continue
			var lib := _extract_library(path)
			if lib == null:
				continue
			if SEGMENTS.has(prefix):
				lib = _with_segments(lib, SEGMENTS[prefix])
			if prefix != &"ual":
				lib = _make_in_place(prefix, lib)
			_libraries[prefix] = lib
		_build_ual_fallbacks()
		_apply_loops()
		_add_mirrored()
		_sync_cycles()
		_relax_stop_arms()
		_smooth_interpolation()
	return _libraries


## O clipe "Run To Stop" termina com os DOIS braços esticados para a frente na
## horizontal (pose de "zumbi" ao frear). Os braços desses clipes vão, ao
## longo da parada, para os braços relaxados da respiração parada (o freio
## continua no corpo e nas pernas; só os braços ficam naturais).
const STOP_CLIPS: Array[StringName] = [&"run_stop", &"walk_stop"]
const ARM_TRACK_BONES: Array[String] = ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]


static func _relax_stop_arms() -> void:
	if not has_clip(&"idle"):
		return
	var ip := String(clip(&"idle")).split("/")
	var idle: Animation = (_libraries[StringName(ip[0])] as AnimationLibrary).get_animation(StringName(ip[1]))
	for logical in STOP_CLIPS:
		if not has_clip(logical):
			continue
		var parts := String(clip(logical)).split("/")
		var lib: AnimationLibrary = _libraries.get(StringName(parts[0]))
		if lib == null or not lib.has_animation(StringName(parts[1])):
			continue
		var a := lib.get_animation(StringName(parts[1]))
		for bone in ARM_TRACK_BONES:
			var path := NodePath("%GeneralSkeleton:" + bone)
			var ti := a.find_track(path, Animation.TYPE_ROTATION_3D)
			var ri := idle.find_track(path, Animation.TYPE_ROTATION_3D)
			if ti < 0 or ri < 0:
				continue
			var q_rest: Quaternion = idle.rotation_track_interpolate(ri, 0.0)
			for k in a.track_get_key_count(ti):
				var t := a.track_get_key_time(ti, k)
				var w := clampf(0.35 + 0.55 * t / maxf(a.length, 0.01), 0.0, 0.9)
				var q: Quaternion = a.track_get_key_value(ti, k)
				a.track_set_key_value(ti, k, q.slerp(q_rest, w).normalized())


## --- Ciclos de passada em FASE (Etapa 27) ------------------------------------
## Os clipes de passada têm ciclos de durações diferentes (andar 1,23 s, trote
## 0,83 s, sprint 0,53 s, laterais 0,67–0,93 s) e o BlendSpace os misturava com
## fases desencontradas: entre duas velocidades uma perna de um clipe estava à
## frente enquanto a do outro estava atrás → pé "tremendo"/flutuando. Aqui
## cada clipe cíclico é reamostrado para o MESMO ciclo (SYNC_LEN) e alinhado
## pelo instante em que o pé direito pisa (medido no esqueleto). As poses não
## mudam; a cadência natural de cada velocidade passa a vir da escala de tempo
## (cycle_frequency()).
const CYCLE_SYNC: Array[StringName] = [&"walk", &"jog", &"run", &"sprint",
	&"strafe_l_walk", &"strafe_l_jog", &"strafe_r_jog", &"strafe_l_fast", &"strafe_r_fast",
	&"diag_l", &"diag_r"]
const SYNC_LEN := 1.0
const SYNC_KEYS := 60
## Fração da oscilação vertical original do quadril mantida na passada.
const BOB_KEEP := 0.45
## nome lógico -> duração natural do ciclo (s), antes da reamostragem
static var cycle_lengths := {}
static var _fk_skel: Skeleton3D


## Escala de tempo do BlendSpace de passadas na posição [param x] (m/s):
## interpola a FREQUÊNCIA natural entre os clipes vizinhos; parado volta a 1.
static func loco_cycle_mult(x: float) -> float:
	var pts: Array = []
	for p in LOCOMOTION_POINTS:
		var fq := cycle_frequency(p[0])
		if float(p[1]) > 0.0 and fq > 0.0:
			pts.append([float(p[1]), fq * SYNC_LEN])
	if pts.is_empty():
		return 1.0
	if x <= pts[0][0]:
		return lerpf(1.0, pts[0][1], clampf(x / pts[0][0], 0.0, 1.0))
	for i in range(1, pts.size()):
		if x <= pts[i][0]:
			var w: float = (x - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0])
			return lerpf(pts[i - 1][1], pts[i][1], w)
	return pts[-1][1]


## Frequência natural do ciclo (ciclos/s) do clipe [param logical].
static func cycle_frequency(logical: StringName) -> float:
	var l: float = cycle_lengths.get(logical, 0.0)
	return 1.0 / l if l > 0.05 else 0.0


static func _sync_cycles() -> void:
	if _fk_skel == null:
		return
	var done := {}
	for logical in CYCLE_SYNC:
		if not has_clip(logical):
			continue
		var cpath := String(clip(logical))
		if done.has(cpath):
			cycle_lengths[logical] = done[cpath]
			continue
		var parts := cpath.split("/")
		var lib: AnimationLibrary = _libraries.get(StringName(parts[0]))
		if lib == null or not lib.has_animation(StringName(parts[1])):
			continue
		var a := lib.get_animation(StringName(parts[1]))
		if a.length < 0.3 or a.length > 2.5:
			continue
		var plant := _right_plant_time(a)
		if plant < 0.0:
			continue
		done[cpath] = a.length
		cycle_lengths[logical] = a.length
		_resample_cycle(a, plant / a.length)


## Instante (s) em que o pé direito chega ao chão (início do apoio), por
## cinemática direta das trilhas do clipe no esqueleto de referência.
static func _right_plant_time(a: Animation) -> float:
	var sk := _fk_skel
	var foot := sk.find_bone("RightFoot")
	if foot < 0:
		return -1.0
	var tracks: Array = []
	for i in a.get_track_count():
		var ty := a.track_get_type(i)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var bone := sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if bone >= 0:
			tracks.append([i, bone, ty])
	sk.reset_bone_poses()
	var n := 120
	var ys: Array[float] = []
	for k in n:
		var t := a.length * k / n
		for tr in tracks:
			if tr[2] == Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(tr[1], a.rotation_track_interpolate(tr[0], t))
			else:
				sk.set_bone_pose_position(tr[1], a.position_track_interpolate(tr[0], t))
		ys.append(sk.get_bone_global_pose(foot).origin.y)
	var ymin: float = ys.min()
	var ymax: float = ys.max()
	var thr := ymin + (ymax - ymin) * 0.12
	for k in n:
		var prev := ys[(k - 1 + n) % n]
		if ys[k] <= thr and prev > thr:
			return a.length * k / n
	return 0.0


## Reamostra o clipe (todas as trilhas) para SYNC_LEN com SYNC_KEYS chaves
## uniformes, começando na fase [param phase] (0..1) do ciclo original.
static func _resample_cycle(a: Animation, phase: float) -> void:
	var l := a.length
	var data: Array = []
	for i in a.get_track_count():
		var ty := a.track_get_type(i)
		var vals: Array = []
		var ok := true
		for k in SYNC_KEYS:
			var t := fposmod(float(k) / SYNC_KEYS + phase, 1.0) * l
			match ty:
				Animation.TYPE_ROTATION_3D:
					vals.append(a.rotation_track_interpolate(i, t))
				Animation.TYPE_POSITION_3D:
					vals.append(a.position_track_interpolate(i, t))
				Animation.TYPE_SCALE_3D:
					vals.append(a.scale_track_interpolate(i, t))
				_:
					ok = false
		data.append(vals if ok else null)
	for i in a.get_track_count():
		if data[i] == null:
			continue
		while a.track_get_key_count(i) > 0:
			a.track_remove_key(i, 0)
		var vals: Array = data[i]
		for k in SYNC_KEYS:
			a.track_insert_key(i, SYNC_LEN * k / SYNC_KEYS, vals[k])
	a.length = SYNC_LEN


## Os clipes chegam a 30 quadros/s com interpolação LINEAR: a velocidade de
## cada osso muda de repente a cada 33 ms e, a 60 quadros/s, o pé e a mão
## "tremem" (zigue-zague). Interpolação cúbica passa uma curva suave pelas
## MESMAS poses (nenhuma pose muda), só some o solavanco entre elas.
static func _smooth_interpolation() -> void:
	for prefix in _libraries:
		var lib: AnimationLibrary = _libraries[prefix]
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			for i in a.get_track_count():
				var ty := a.track_get_type(i)
				if ty == Animation.TYPE_ROTATION_3D or ty == Animation.TYPE_POSITION_3D or ty == Animation.TYPE_SCALE_3D:
					if a.track_get_key_count(i) >= 3:
						a.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC)


## Quando os arquivos .fbx do Mixamo/Rohr não estão no disco (ex.: clone limpo
## do git ou build de CI), sintetiza/mapeia a partir da biblioteca UAL
## (AnimationLibrary_Godot_Standard.gltf) para que 100% dos clipes lógicos
## funcionem perfeitamente com o esqueleto humanoide.
static func _build_ual_fallbacks() -> void:
	if not _libraries.has(&"ual"):
		return
	var ual_lib := _libraries[&"ual"] as AnimationLibrary
	if ual_lib == null:
		return
	var idle_ref: Animation = ual_lib.get_animation(&"Idle") if ual_lib.has_animation(&"Idle") else null
	if idle_ref != null:
		_ensure_spine_track(idle_ref)
		if ual_lib.has_animation(&"Walk"):
			var w_ref := _refine_ual_locomotion(ual_lib.get_animation(&"Walk"), idle_ref, &"walk")
			ual_lib.remove_animation(&"Walk")
			ual_lib.add_animation(&"Walk", w_ref)
		if ual_lib.has_animation(&"Jog_Fwd"):
			var raw_jog := ual_lib.get_animation(&"Jog_Fwd")
			var d_ref := _refine_ual_locomotion(raw_jog, idle_ref, &"dribble")
			var j_ref := _refine_ual_locomotion(raw_jog, idle_ref, &"jog")
			ual_lib.remove_animation(&"Jog_Fwd")
			ual_lib.add_animation(&"Jog_Fwd", j_ref)
			ual_lib.add_animation(&"Jog_Dribble", d_ref)
		if ual_lib.has_animation(&"Sprint"):
			var s_ref := _refine_ual_locomotion(ual_lib.get_animation(&"Sprint"), idle_ref, &"sprint")
			ual_lib.remove_animation(&"Sprint")
			ual_lib.add_animation(&"Sprint", s_ref)
	for aname in ual_lib.get_animation_list():
		_ensure_spine_track(ual_lib.get_animation(aname))
	var fb_lib := AnimationLibrary.new()
	var map_source := {
		&"idle": ["Idle", 1.0],
		&"soccer_idle": ["Idle", 1.0],
		&"idle_ball": ["Idle", 1.0],
		&"mark_idle": ["Idle", 1.05],
		&"walk": ["Walk", 1.56],          # caminhada firme e natural sincronizada com 1,35 m/s
		&"slow_jog": ["Jog_Fwd", 0.92],
		&"dribble": ["Jog_Dribble", 1.08], # condução baixa com passadas próximas ao chão (2,05 m/s)
		&"jog": ["Jog_Fwd", 1.12],        # trote baixo e fluido sem deslizar no solo (2,25 m/s)
		&"run": ["Sprint", 0.96],         # corrida cadenciada e rente ao chão (3,35 m/s)
		&"sprint": ["Sprint", 1.22],      # sprint atlético progressivo e pesado (4,35 m/s)
		&"idle_to_sprint": ["Sprint", 1.15],
		&"sad_run": ["Jog_Fwd", 0.82],
		&"back": ["Walk", 1.18],
		&"strafe_l_walk": ["Walk", 1.28],
		&"strafe_l_jog": ["Jog_Fwd", 0.95],
		&"strafe_r_jog": ["Jog_Fwd", 0.95],
		&"strafe_l_fast": ["Sprint", 0.88],
		&"strafe_r_fast": ["Sprint", 0.88],
		&"diag_l": ["Jog_Fwd", 0.92],
		&"diag_r": ["Jog_Fwd", 0.92],
		&"pass_short": ["Walk", 1.25],
		&"pass_long": ["Jog_Fwd", 1.05],
		&"shoot": ["Jog_Fwd", 1.0],
		&"shoot_power": ["Sprint", 0.68],
		&"receive": ["Walk", 1.30],
		&"receive_ball": ["Walk", 1.30],
		&"spin": ["Jog_Fwd", 0.82],
		&"cut": ["Jog_Fwd", 1.05],
		&"cut_r": ["Jog_Fwd", 1.10],
		&"turn_l": ["Walk", 1.40],
		&"turn_r": ["Walk", 1.40],
		&"turn180": ["Jog_Fwd", 1.05],
		&"walk_turn180": ["Walk", 1.35],
		&"stand_turn_r": ["Walk", 1.40],
		&"walk_stop": ["Walk", 1.35],
		&"run_stop": ["Jog_Fwd", 1.05],
		&"recv_chest": ["Hit_Chest", 0.55],
		&"recv_knee": ["Jump_Start", 1.2],
		&"header": ["Jump_Start", 1.1],
		&"head_control": ["Jump_Start", 1.0],
		&"header_jump": ["Jump", 1.2],
		&"tackle": ["Roll_RM", 1.35],
		&"stand_tackle": ["Jog_Fwd", 1.15],
		&"trip": ["Death01", 1.35],
		&"fallen": ["Death01", 1.0],
		&"jump": ["Jump", 1.45],
		&"getup": ["Jump_Land", 0.9],
		&"getup_b": ["Jump_Land", 0.9],
		&"getup_c": ["Jump_Land", 0.9],
		&"victory": ["Jump", 1.2],
		&"victory_idle": ["Dance", 1.0],
		&"samba": ["Dance", 1.0],
		&"defeated": ["Crouch_Idle", 1.0],
		&"argue": ["Idle_Talking", 1.0],
		&"gk_catch": ["Interact", 1.4],
		&"gk_dive": ["Roll_RM", 1.3],
		&"gk_pass": ["Jog_Fwd", 0.7],
		&"gk_place": ["PickUp_Table", 1.0],
		&"kick_up": ["Jog_Fwd", 0.9],
		&"kneeing": ["Jog_Fwd", 0.9],
		&"warmup": ["Idle", 1.15],
		&"scissor_kick": ["Jump", 1.3],
		&"sprint_turn": ["Sprint", 1.05],
		&"run_to_turn": ["Jog_Fwd", 1.05],
		&"walk_turn_l": ["Walk", 1.35],
		&"start_walk": ["Walk", 1.35],
	}
	for logical: StringName in map_source:
		# Se o clipe original do Mixamo/Rohr já existe no disco, preserva-o!
		var primary_parts := String(CLIPS.get(logical, &"")).split("/")
		if primary_parts.size() == 2 and _libraries.has(StringName(primary_parts[0])) \
				and (_libraries[StringName(primary_parts[0])] as AnimationLibrary).has_animation(StringName(primary_parts[1])):
			continue
		var spec: Array = map_source[logical]
		var src_name := StringName(spec[0])
		var rate: float = float(spec[1])
		if not ual_lib.has_animation(src_name):
			continue
		var base_anim := ual_lib.get_animation(src_name)
		var anim := _scale_anim_time(base_anim, rate)
		_ensure_spine_track(anim)
		if CONTACTS.has(logical):
			var ct: float = float(CONTACTS[logical][0])
			var cf: float = float(CONTACTS[logical][1])
			anim = _sculpt_kick_or_contact(anim, logical, ct, cf)
		fb_lib.add_animation(logical, anim)
		var fb_key := "ual_fb/" + String(logical)
		_fallback_clips[logical] = StringName(fb_key)
		# Gera curvas suaves de root motion / root yaw para viradas e paradas.
		if TURN_ANGLES.has(logical):
			var total_rad := deg_to_rad(float(TURN_ANGLES[logical]))
			var n_samples := int(anim.length * ROOT_MOTION_FPS) + 1
			var y_curve := PackedFloat32Array()
			var r_curve := PackedVector3Array()
			for i in n_samples:
				var u := float(i) / float(max(n_samples - 1, 1))
				var s := u * u * (3.0 - 2.0 * u)
				y_curve.append(total_rad * s)
				r_curve.append(Vector3(0.0, 0.0, 0.18 * sin(u * PI)))
			root_yaw[fb_key] = y_curve
			root_curves[fb_key] = r_curve
		elif logical in ROOT_MOTION:
			var n_s := int(anim.length * ROOT_MOTION_FPS) + 1
			var rc := PackedVector3Array()
			var dist := 0.85 if logical in [&"tackle", &"run_stop", &"jump"] else 0.35
			for i in n_s:
				var u := float(i) / float(max(n_s - 1, 1))
				var ease_out := 1.0 - (1.0 - u) * (1.0 - u)
				rc.append(Vector3(0.0, 0.0, dist * ease_out))
			root_curves[fb_key] = rc
	if fb_lib.get_animation_list().size() > 0:
		_libraries[&"ual_fb"] = fb_lib


## Refina as animações de locomoção da UAL (Walk, Jog_Fwd, Sprint) para eliminar
## o "efeito canguru" (oscilação vertical de 22 cm no quadril e joelhos levantados
## a 88°) e a caminhada marchando, usando a pose neutra do Idle como referência
## anatômica. Preserva a fase, cadência e transferência de peso originais.
static func _refine_ual_locomotion(src: Animation, idle_anim: Animation, kind: StringName) -> Animation:
	var out := src.duplicate(true) as Animation
	var idle_rot := {}
	for i in idle_anim.get_track_count():
		if idle_anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			var bname := String(idle_anim.track_get_path(i)).get_slice(":", 1)
			idle_rot[bname] = idle_anim.rotation_track_interpolate(i, 0.0)

	var base_hip_y := 0.946
	var bounce_amp := 0.007
	var hip_rot_k := 0.65
	var hip_pitch_corr_deg := 0.0
	var spine_k := 0.58
	var uleg_k := 0.80
	var lleg_k := 0.56
	var foot_k := 0.80
	var arm_k := 0.50
	var hand_k := 0.50

	if kind == &"dribble":
		base_hip_y = 0.935
		bounce_amp = 0.008
		hip_rot_k = 0.62
		hip_pitch_corr_deg = -2.0
		spine_k = 0.56
		uleg_k = 0.72
		lleg_k = 0.54
		foot_k = 0.78
		arm_k = 0.52
		hand_k = 0.50
	elif kind == &"jog":
		base_hip_y = 0.938
		bounce_amp = 0.009
		hip_rot_k = 0.65
		hip_pitch_corr_deg = -3.0
		spine_k = 0.60
		uleg_k = 0.76
		lleg_k = 0.58
		foot_k = 0.80
		arm_k = 0.56
		hand_k = 0.54
	elif kind == &"sprint":
		base_hip_y = 0.934
		bounce_amp = 0.011
		hip_rot_k = 0.65
		hip_pitch_corr_deg = -13.0
		spine_k = 0.65
		uleg_k = 0.80
		lleg_k = 0.62
		foot_k = 0.82
		arm_k = 0.64
		hand_k = 0.58

	var hp_tr := out.find_track(NodePath(HIPS_POSITION_TRACK), Animation.TYPE_POSITION_3D)
	if hp_tr >= 0 and out.track_get_key_count(hp_tr) > 0:
		var sum_y := 0.0
		var max_dev := 0.001
		var n_k := out.track_get_key_count(hp_tr)
		for k in n_k:
			sum_y += (out.track_get_key_value(hp_tr, k) as Vector3).y
		var mean_y := sum_y / float(n_k)
		for k in n_k:
			var vy := (out.track_get_key_value(hp_tr, k) as Vector3).y
			max_dev = maxf(max_dev, absf(vy - mean_y))
		for k in n_k:
			var v: Vector3 = out.track_get_key_value(hp_tr, k)
			var norm_dy := clampf((v.y - mean_y) / max_dev, -1.0, 1.0)
			v.y = base_hip_y + norm_dy * bounce_amp
			v.x *= 0.75
			v.z *= 0.35
			out.track_set_key_value(hp_tr, k, v)

	for i in out.get_track_count():
		if out.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bname := String(out.track_get_path(i)).get_slice(":", 1)
		if not idle_rot.has(bname):
			continue
		var q_ref: Quaternion = idle_rot[bname]
		var blend_k := -1.0
		var extra_q := Quaternion.IDENTITY
		if bname == "Hips":
			blend_k = hip_rot_k
			if absf(hip_pitch_corr_deg) > 0.01:
				extra_q = Quaternion(Vector3.RIGHT, deg_to_rad(hip_pitch_corr_deg))
		elif bname in ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
			blend_k = spine_k
		elif bname in ["LeftUpperLeg", "RightUpperLeg"]:
			blend_k = uleg_k
		elif bname in ["LeftLowerLeg", "RightLowerLeg"]:
			blend_k = lleg_k
		elif bname in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
			blend_k = foot_k
		elif bname in ["LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"]:
			blend_k = arm_k
		elif bname in ["LeftHand", "RightHand"]:
			blend_k = hand_k

		if blend_k >= 0.0:
			for k in out.track_get_key_count(i):
				var q: Quaternion = out.track_get_key_value(i, k)
				var q_new := q_ref.slerp(q * extra_q, blend_k).normalized()
				out.track_set_key_value(i, k, q_new)
	return out


static func _ensure_spine_track(anim: Animation) -> void:
	if anim == null:
		return
	var sp_path := NodePath("%GeneralSkeleton:Spine")
	if anim.find_track(sp_path, Animation.TYPE_ROTATION_3D) < 0:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, sp_path)
		anim.rotation_track_insert_key(tr, 0.0, Quaternion.IDENTITY)


static func _scale_anim_time(src: Animation, rate: float) -> Animation:
	if absf(rate - 1.0) < 0.01 or rate <= 0.05:
		return src.duplicate(true) as Animation
	var out := Animation.new()
	out.length = maxf(src.length / rate, 0.15)
	for i in src.get_track_count():
		var ty := src.track_get_type(i)
		var j := out.add_track(ty)
		out.track_set_path(j, src.track_get_path(i))
		out.track_set_interpolation_type(j, src.track_get_interpolation_type(i))
		for k in src.track_get_key_count(i):
			var t := src.track_get_key_time(i, k) / rate
			var v = src.track_get_key_value(i, k)
			out.track_insert_key(j, t, v)
	return out


## Esculpe a biomecânica de passe/chute/domínio/bote na perna de ação, perna de
## apoio e tronco do clipe fallback, diferenciando claramente:
##  - Passe curto / domínio (`pass_short`, `receive`, `receive_ball`): toque de chapa
##    (parte interna do pé), preparação curta, rotação externa moderada do quadril.
##  - Chute colocado (`shoot`): batida controlada com equilíbrio corporal.
##  - Passe longo (`pass_long`): preparação média e alavanca firme da perna.
##  - Chute forte (`shoot_power`): preparação ampla com peito do pé, extensão
##    explosiva porém anatômica e follow-through natural com equilíbrio do tronco.
static func _sculpt_kick_or_contact(src: Animation, logical: StringName, contact_t: float, foot_side: float) -> Animation:
	var out := src.duplicate(true) as Animation
	var min_len := contact_t + 0.40
	if out.length < min_len:
		out.length = min_len
	if foot_side == 0.0:
		return out
	var prefix := "Right" if foot_side > 0.0 else "Left"
	var sup_prefix := "Left" if foot_side > 0.0 else "Right"
	var hip_tr := out.find_track(NodePath("%GeneralSkeleton:" + prefix + "UpperLeg"), Animation.TYPE_ROTATION_3D)
	var knee_tr := out.find_track(NodePath("%GeneralSkeleton:" + prefix + "LowerLeg"), Animation.TYPE_ROTATION_3D)
	var foot_tr := out.find_track(NodePath("%GeneralSkeleton:" + prefix + "Foot"), Animation.TYPE_ROTATION_3D)
	var sup_hip_tr := out.find_track(NodePath("%GeneralSkeleton:" + sup_prefix + "UpperLeg"), Animation.TYPE_ROTATION_3D)
	var sup_knee_tr := out.find_track(NodePath("%GeneralSkeleton:" + sup_prefix + "LowerLeg"), Animation.TYPE_ROTATION_3D)
	var spine_tr := out.find_track(NodePath("%GeneralSkeleton:Spine"), Animation.TYPE_ROTATION_3D)

	var prep_dt := 0.15
	var follow_dt := 0.16
	var prep_hip_x := 16.0
	var prep_hip_y := 0.0
	var prep_knee_x := 22.0
	var hit_hip_x := -20.0
	var hit_hip_y := 0.0
	var hit_knee_x := -12.0
	var hit_foot_euler := Vector3.ZERO
	var follow_mult := 1.12
	var spine_pitch_deg := -2.0
	var spine_yaw_deg := 4.0 * foot_side

	if logical in [&"pass_short", &"receive", &"receive_ball"]:
		# Passe curto / recepção de chapa: movimento curto, preciso, abrindo a parte interna do pé.
		prep_dt = 0.13
		follow_dt = 0.14
		prep_hip_x = 12.0
		prep_hip_y = -10.0 * foot_side
		prep_knee_x = 18.0
		hit_hip_x = -17.0
		hit_hip_y = -14.0 * foot_side
		hit_knee_x = -10.0
		hit_foot_euler = Vector3(deg_to_rad(4.0), deg_to_rad(-14.0 * foot_side), deg_to_rad(8.0 * foot_side))
		follow_mult = 1.08
		spine_pitch_deg = -1.5
		spine_yaw_deg = 3.0 * foot_side
	elif logical == &"shoot":
		# Chute colocado / controlado: batida equilibrada, finalização contida.
		prep_dt = 0.15
		follow_dt = 0.17
		prep_hip_x = 19.0
		prep_hip_y = -6.0 * foot_side
		prep_knee_x = 26.0
		hit_hip_x = -24.0
		hit_hip_y = -8.0 * foot_side
		hit_knee_x = -15.0
		hit_foot_euler = Vector3(deg_to_rad(8.0), deg_to_rad(-8.0 * foot_side), deg_to_rad(4.0 * foot_side))
		follow_mult = 1.14
		spine_pitch_deg = -2.5
		spine_yaw_deg = 5.0 * foot_side
	elif logical == &"pass_long":
		# Passe longo / lançamento: preparação mais ampla e transferência firme de peso.
		prep_dt = 0.16
		follow_dt = 0.19
		prep_hip_x = 23.0
		prep_hip_y = -4.0 * foot_side
		prep_knee_x = 30.0
		hit_hip_x = -28.0
		hit_hip_y = -5.0 * foot_side
		hit_knee_x = -17.0
		hit_foot_euler = Vector3(deg_to_rad(12.0), deg_to_rad(-5.0 * foot_side), 0.0)
		follow_mult = 1.18
		spine_pitch_deg = -3.5
		spine_yaw_deg = 6.5 * foot_side
	elif logical == &"shoot_power":
		# Chute forte de peito do pé: preparação clara da coxa/joelho e follow-through potente.
		prep_dt = 0.18
		follow_dt = 0.22
		prep_hip_x = 27.0
		prep_hip_y = 0.0
		prep_knee_x = 36.0
		hit_hip_x = -33.0
		hit_hip_y = 0.0
		hit_knee_x = -20.0
		hit_foot_euler = Vector3(deg_to_rad(15.0), 0.0, 0.0)
		follow_mult = 1.22
		spine_pitch_deg = -4.5
		spine_yaw_deg = 8.0 * foot_side
	elif logical in [&"stand_tackle", &"tackle"]:
		# Bote em pé: avanço firme da perna de desarme com centro de gravidade baixo.
		prep_dt = 0.12
		follow_dt = 0.15
		prep_hip_x = 10.0
		prep_knee_x = 20.0
		hit_hip_x = -25.0
		hit_hip_y = -8.0 * foot_side
		hit_knee_x = -12.0

	var t_prep := maxf(contact_t - prep_dt, 0.02)
	var t_follow := minf(contact_t + follow_dt, out.length - 0.02)
	if hip_tr >= 0 and knee_tr >= 0:
		var q_hip_prep := out.rotation_track_interpolate(hip_tr, t_prep) \
			* Quaternion.from_euler(Vector3(deg_to_rad(prep_hip_x), deg_to_rad(prep_hip_y), 0.0))
		var q_knee_prep := out.rotation_track_interpolate(knee_tr, t_prep) \
			* Quaternion(Vector3.RIGHT, deg_to_rad(prep_knee_x))
		var q_hip_hit := out.rotation_track_interpolate(hip_tr, contact_t) \
			* Quaternion.from_euler(Vector3(deg_to_rad(hit_hip_x), deg_to_rad(hit_hip_y), 0.0))
		var q_knee_hit := out.rotation_track_interpolate(knee_tr, contact_t) \
			* Quaternion(Vector3.RIGHT, deg_to_rad(hit_knee_x))
		var q_hip_fol := out.rotation_track_interpolate(hip_tr, t_follow) \
			* Quaternion.from_euler(Vector3(deg_to_rad(hit_hip_x * follow_mult), deg_to_rad(hit_hip_y * 0.8), 0.0))
		var q_knee_fol := out.rotation_track_interpolate(knee_tr, t_follow) \
			* Quaternion(Vector3.RIGHT, deg_to_rad(hit_knee_x * 0.6))
		out.rotation_track_insert_key(hip_tr, t_prep, q_hip_prep.normalized())
		out.rotation_track_insert_key(knee_tr, t_prep, q_knee_prep.normalized())
		out.rotation_track_insert_key(hip_tr, contact_t, q_hip_hit.normalized())
		out.rotation_track_insert_key(knee_tr, contact_t, q_knee_hit.normalized())
		out.rotation_track_insert_key(hip_tr, t_follow, q_hip_fol.normalized())
		out.rotation_track_insert_key(knee_tr, t_follow, q_knee_fol.normalized())
	if foot_tr >= 0 and hit_foot_euler.length_squared() > 0.0001:
		var q_foot_hit := out.rotation_track_interpolate(foot_tr, contact_t) * Quaternion.from_euler(hit_foot_euler)
		out.rotation_track_insert_key(foot_tr, contact_t, q_foot_hit.normalized())
	if sup_hip_tr >= 0 and sup_knee_tr >= 0:
		# Perna de apoio firme ao lado da bola com flexão natural do joelho (~14°).
		var q_sh := out.rotation_track_interpolate(sup_hip_tr, contact_t) * Quaternion(Vector3.RIGHT, deg_to_rad(-8.0))
		var q_sk := out.rotation_track_interpolate(sup_knee_tr, contact_t) * Quaternion(Vector3.RIGHT, deg_to_rad(14.0))
		out.rotation_track_insert_key(sup_hip_tr, contact_t, q_sh.normalized())
		out.rotation_track_insert_key(sup_knee_tr, contact_t, q_sk.normalized())
	if spine_tr >= 0:
		var q_sp_prep := out.rotation_track_interpolate(spine_tr, t_prep) \
			* Quaternion.from_euler(Vector3(deg_to_rad(2.0), deg_to_rad(-spine_yaw_deg * 0.7), 0.0))
		var q_sp_hit := out.rotation_track_interpolate(spine_tr, contact_t) \
			* Quaternion.from_euler(Vector3(deg_to_rad(spine_pitch_deg), deg_to_rad(spine_yaw_deg), 0.0))
		out.rotation_track_insert_key(spine_tr, t_prep, q_sp_prep.normalized())
		out.rotation_track_insert_key(spine_tr, contact_t, q_sp_hit.normalized())
	return out


## Chutes/passes com o OUTRO pé: o mesmo clipe espelhado (troca esquerda ↔
## direita). O esqueleto do retarget é simétrico, então o espelho é exato.
const MIRRORED: Array[StringName] = [&"pass_short", &"pass_long", &"shoot", &"shoot_power",
	&"stand_tackle", &"cut_r", &"walk_turn180", &"stand_turn_r"]


static func mirrored_name(logical: StringName) -> StringName:
	return StringName(String(logical) + "_m")


static func _add_mirrored() -> void:
	for logical in MIRRORED:
		if not has_clip(logical):
			continue
		var cpath := String(clip(logical))
		var parts := cpath.split("/")
		var lib := _libraries[StringName(parts[0])] as AnimationLibrary
		var src := lib.get_animation(StringName(parts[1]))
		var mname := StringName(parts[1] + "_m")
		if not lib.has_animation(mname):
			lib.add_animation(mname, _mirror(src))
		var key := cpath
		var mkey := parts[0] + "/" + String(mname)
		if root_curves.has(key):
			var c: PackedVector3Array = root_curves[key]
			var mc := PackedVector3Array()
			for v in c:
				mc.append(Vector3(-v.x, v.y, v.z))
			root_curves[mkey] = mc
		if root_yaw.has(key):
			var yc: PackedFloat32Array = root_yaw[key]
			var my := PackedFloat32Array()
			for y in yc:
				my.append(-y)
			root_yaw[mkey] = my
		_mirror_clips[mirrored_name(logical)] = StringName(mkey)


static var _mirror_clips := {}


static func _mirror(a: Animation) -> Animation:
	var m := a.duplicate(true) as Animation
	for i in m.get_track_count():
		var path := String(m.track_get_path(i))
		if path.contains(":Left"):
			path = path.replace(":Left", ":Right")
		elif path.contains(":Right"):
			path = path.replace(":Right", ":Left")
		m.track_set_path(i, NodePath(path))
		var ty := m.track_get_type(i)
		for k in m.track_get_key_count(i):
			if ty == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = m.track_get_key_value(i, k)
				m.track_set_key_value(i, k, Quaternion(q.x, -q.y, -q.z, q.w))
			elif ty == Animation.TYPE_POSITION_3D:
				var p: Vector3 = m.track_get_key_value(i, k)
				m.track_set_key_value(i, k, Vector3(-p.x, p.y, p.z))
	return m


static func _apply_loops() -> void:
	for logical in LOOPING:
		if has_clip(logical):
			var parts := String(clip(logical)).split("/")
			var anim := (_libraries[StringName(parts[0])] as AnimationLibrary).get_animation(StringName(parts[1]))
			anim.loop_mode = Animation.LOOP_LINEAR


static func has_clip(logical: StringName) -> bool:
	var libs := get_libraries()
	if String(logical).ends_with("_m"):
		return _mirror_clips.has(logical)
	if _fallback_clips.has(logical):
		return true
	if not CLIPS.has(logical):
		return false
	var parts := String(CLIPS[logical]).split("/")
	var prefix := StringName(parts[0])
	return libs.has(prefix) and (libs[prefix] as AnimationLibrary).has_animation(StringName(parts[1]))


static func clip(logical: StringName) -> StringName:
	get_libraries()
	if _mirror_clips.has(logical):
		return _mirror_clips[logical]
	if _fallback_clips.has(logical):
		return _fallback_clips[logical]
	return CLIPS.get(logical, &"")


static func _base(logical: StringName) -> StringName:
	var s := String(logical)
	return StringName(s.substr(0, s.length() - 2)) if s.ends_with("_m") else logical


static func clip_length(logical: StringName) -> float:
	logical = _base(logical)
	if not has_clip(logical):
		return 0.0
	var parts := String(clip(logical)).split("/")
	return (get_libraries()[StringName(parts[0])] as AnimationLibrary).get_animation(StringName(parts[1])).length


static func turn_angle(logical: StringName) -> float:
	var mirrored := String(logical).ends_with("_m")
	var a: float = TURN_ANGLES.get(_base(logical), 0.0)
	return -a if mirrored else a


static func contact_time(logical: StringName) -> float:
	logical = _base(logical)
	return CONTACTS[logical][0] if CONTACTS.has(logical) else 0.0


static func contact_foot(logical: StringName) -> float:
	var mirrored := String(logical).ends_with("_m")
	logical = _base(logical)
	var f: float = CONTACTS[logical][1] if CONTACTS.has(logical) else 1.0
	return -f if mirrored else f


static func has_contact(logical: StringName) -> bool:
	return CONTACTS.has(_base(logical))


static func _is_root_motion_prefix(prefix: StringName) -> bool:
	for logical in ROOT_MOTION + IN_PLACE_FIXED:
		if String(CLIPS.get(logical, "")).begins_with(String(prefix) + "/"):
			return true
	return false


## Velocidade do root motion no instante t (alturas de quadril por segundo,
## no espaço do modelo: +Z = para a frente, +X = para a esquerda).
static func root_motion_velocity(logical: StringName, t: float) -> Vector3:
	var curve: PackedVector3Array = root_curves.get(String(clip(logical)), PackedVector3Array())
	if curve.size() < 2:
		return Vector3.ZERO
	if t >= float(curve.size() - 1) / ROOT_MOTION_FPS:
		return Vector3.ZERO # clipe acabou (ex.: caído no chão): não desliza
	var i := clampi(int(t * ROOT_MOTION_FPS), 0, curve.size() - 2)
	return (curve[i + 1] - curve[i]) * ROOT_MOTION_FPS


## Deslocamento do quadril (alturas de quadril, espaço do modelo) no instante t.
static func root_offset_at(logical: StringName, t: float) -> Vector3:
	var curve: PackedVector3Array = root_curves.get(String(clip(logical)), PackedVector3Array())
	if curve.is_empty():
		return Vector3.ZERO
	var x := clampf(t * ROOT_MOTION_FPS, 0.0, float(curve.size() - 1))
	var i := int(x)
	if i >= curve.size() - 1:
		return curve[curve.size() - 1]
	return curve[i].lerp(curve[i + 1], x - i)


## Tempo de contato do clipe lógico que usa este prefixo (-1 se não houver).
static func _contact_for_prefix(prefix: StringName) -> float:
	for logical: StringName in CLIPS:
		if String(CLIPS[logical]).begins_with(String(prefix) + "/") and CONTACTS.has(logical):
			return CONTACTS[logical][0]
	return -1.0


static func _extract_library(path: String) -> AnimationLibrary:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("AnimationCatalog: não foi possível carregar " + path)
		return null
	var inst := scene.instantiate()
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib: AnimationLibrary = null
	if player != null and player.has_animation_library(&""):
		lib = player.get_animation_library(&"")
		var sk := inst.find_child("GeneralSkeleton", true, false) as Skeleton3D
		if _fk_skel == null and sk != null and path.contains("mixamo"):
			_fk_skel = sk.duplicate(0) as Skeleton3D
			for c in _fk_skel.get_children():
				_fk_skel.remove_child(c)
				c.free()
		var fix := _position_scale_fix(sk)
		if absf(fix - 1.0) > 0.1:
			lib = _rescale_hips(lib, fix)
	inst.free()
	return lib


## Alguns FBX (ex.: personagem gerado por IA e rigado no Mixamo) chegam com a
## pose de descanso deslocada da malha. O retarget então normaliza a trilha de
## posição do quadril pela altura ERRADA do quadril (motion_scale). Calculamos
## a altura real pela própria pose (quadril → ponta do pé mais baixa) e
## devolvemos o fator de correção da trilha.
static func _position_scale_fix(sk: Skeleton3D) -> float:
	if sk == null:
		return 1.0
	var hips := sk.find_bone("Hips")
	if hips < 0:
		return 1.0
	var hips_y := sk.get_bone_global_rest(hips).origin.y
	var lowest := INF
	for b in ["LeftToes", "RightToes", "LeftFoot", "RightFoot"]:
		var i := sk.find_bone(b)
		if i >= 0:
			lowest = minf(lowest, sk.get_bone_global_rest(i).origin.y)
	if lowest == INF:
		return 1.0
	var leg_span := hips_y - lowest
	if leg_span <= 0.00001 or sk.motion_scale <= 0.00001:
		return 1.0
	var true_height := leg_span * 1.022
	return sk.motion_scale / true_height


## Recorta trechos [início, fim] da primeira animação da biblioteca
## (reamostra a 30 qps) e devolve uma biblioteca só com os trechos.
static func _with_segments(source: AnimationLibrary, segs: Dictionary) -> AnimationLibrary:
	var src := source.get_animation(source.get_animation_list()[0])
	var lib := AnimationLibrary.new()
	for seg_name: StringName in segs:
		var r: Array = segs[seg_name]
		lib.add_animation(seg_name, _trim(src, r[0], minf(r[1], src.length)))
	return lib


static func _trim(a: Animation, t0: float, t1: float) -> Animation:
	var out := Animation.new()
	out.length = t1 - t0
	var fps := 30.0
	var n := int((t1 - t0) * fps)
	for i in a.get_track_count():
		var ty := a.track_get_type(i)
		if ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_SCALE_3D:
			continue
		# O osso "Root" do UE5 carrega a conversão de eixos e o deslocamento da
		# tomada: no nosso personagem ele fica parado (quem anda é a física).
		if String(a.track_get_path(i)).ends_with(":Root"):
			continue
		var j := out.add_track(ty)
		out.track_set_path(j, a.track_get_path(i))
		for k in n + 1:
			var t := t0 + k / fps
			var lt := k / fps
			match ty:
				Animation.TYPE_POSITION_3D:
					out.position_track_insert_key(j, lt, a.position_track_interpolate(i, t))
				Animation.TYPE_ROTATION_3D:
					out.rotation_track_insert_key(j, lt, a.rotation_track_interpolate(i, t))
				Animation.TYPE_SCALE_3D:
					out.scale_track_insert_key(j, lt, a.scale_track_interpolate(i, t))
	return out


static func _rescale_hips(source: AnimationLibrary, factor: float) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for anim_name in source.get_animation_list():
		var anim := source.get_animation(anim_name).duplicate(true) as Animation
		var track := anim.find_track(NodePath(HIPS_POSITION_TRACK), Animation.TYPE_POSITION_3D)
		if track >= 0:
			for k in anim.track_get_key_count(track):
				anim.track_set_key_value(track, k, (anim.track_get_key_value(track, k) as Vector3) * factor)
		lib.add_animation(anim_name, anim)
	return lib


static func _is_turn_prefix(prefix: StringName) -> bool:
	for logical in TURN_ANGLES:
		if String(CLIPS.get(logical, "")).begins_with(String(prefix) + "/"):
			return true
	return false


## Viradas: o giro do corpo sai do quadril do clipe e vira GIRO DO JOGADOR
## ao longo da animação (root motion de rotação). Sem isso o jogo aplicava o
## giro inteiro no último quadro e o corpo "pulava" 90–180°.
static func _strip_yaw(anim: Animation, key: String) -> void:
	var tr := anim.find_track(NodePath(HIPS_POSITION_TRACK), Animation.TYPE_ROTATION_3D)
	if tr < 0 or anim.track_get_key_count(tr) == 0:
		return
	var q0: Quaternion = anim.track_get_key_value(tr, 0)
	var ref := q0.inverse() * Vector3(0, 0, 1) # direção do quadril que começa em +Z
	var yaw_at := func(q: Quaternion) -> float:
		var d: Vector3 = q * ref
		return atan2(d.x, d.z)
	var curve := PackedFloat32Array()
	var n := int(anim.length * ROOT_MOTION_FPS) + 1
	var prev := 0.0
	var acc := 0.0
	for i in n:
		var q := anim.rotation_track_interpolate(tr, minf(i / ROOT_MOTION_FPS, anim.length))
		var y: float = yaw_at.call(q)
		if i > 0:
			acc += wrapf(y - prev, -PI, PI) # contínuo (passa de 180°)
		prev = y
		curve.append(acc)
	root_yaw[key] = curve
	prev = 0.0
	acc = 0.0
	for k in anim.track_get_key_count(tr):
		var q: Quaternion = anim.track_get_key_value(tr, k)
		var y: float = yaw_at.call(q)
		if k > 0:
			acc += wrapf(y - prev, -PI, PI)
		prev = y
		anim.track_set_key_value(tr, k, Quaternion(Vector3.UP, -acc) * q)


## Giro do corpo (rad, + = esquerda) acumulado no instante t de uma virada.
static func root_yaw_at(logical: StringName, t: float) -> float:
	var curve: PackedFloat32Array = root_yaw.get(String(clip(logical)), PackedFloat32Array())
	if curve.is_empty():
		return 0.0
	var x := clampf(t * ROOT_MOTION_FPS, 0.0, float(curve.size() - 1))
	var i := int(x)
	if i >= curve.size() - 1:
		return curve[curve.size() - 1]
	return lerpf(curve[i], curve[i + 1], x - i)


static func has_root_yaw(logical: StringName) -> bool:
	return root_yaw.has(String(clip(logical)))


const STEADY_LOCOMOTION_PREFIXES: Array[StringName] = [
	&"m_breathing", &"m_soccer_idle", &"m_offensive_idle", &"m_gk_idle",
	&"m_walking", &"m_slow_jog", &"m_jog", &"m_run", &"m_sprint", &"m_idle_to_sprint",
	&"m_dribble", &"m_back", &"m_strafe_l_jog", &"m_strafe_r_jog", &"m_strafe_l_walk",
	&"m_strafe_l_fast", &"m_strafe_r_fast", &"m_diag_l", &"m_diag_r",
	&"m_diag_back_l", &"m_diag_back_r", &"m_walk_strafe_l", &"m_warmup", &"m_argue",
	&"m_sad_run", &"m_start_walk", &"m_walk_stop", &"m_run_stop",
	&"m_turn_l", &"m_turn_r", &"m_turn180", &"m_cut_r", &"m_walk_turn180",
	&"m_stand_turn_r", &"m_cut", &"m_sprint_turn", &"m_run_to_turn", &"m_walk_turn_l",
]

const UPRIGHT_ACTION_PREFIXES: Array[StringName] = [
	&"m_pass_short", &"m_pass_long", &"m_shoot", &"m_shoot_power",
	&"m_receive", &"m_receive_ball", &"m_spin", &"m_chest", &"m_kneeing",
	&"m_header", &"m_head_ctrl", &"m_gk_pass", &"m_kick_up", &"m_victory", &"m_victory_idle", &"m_defeated", &"m_samba",
]


## Clipes do Mixamo deslocam o quadril pelo chão (até 4 m). O deslocamento do
## corpo no jogo vem da física, então retiramos o movimento horizontal do
## quadril (o clipe passa a ser "no lugar") e normalizamos a altura vertical
## (Hips.y) para eliminar pulos/flutuação entre clipes de escalas distintas.
static func _make_in_place(prefix: StringName, source: AnimationLibrary) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for anim_name in source.get_animation_list():
		var anim := source.get_animation(anim_name).duplicate(true) as Animation
		# Remove trilhas órfãs de nó raiz (ex.: "Armature" com escala 100x de clipes VRoid)
		for ti in range(anim.get_track_count() - 1, -1, -1):
			var tpath := String(anim.track_get_path(ti))
			if not tpath.begins_with("%GeneralSkeleton:"):
				anim.remove_track(ti)
		_ensure_spine_track(anim)
		var track := anim.find_track(NodePath(HIPS_POSITION_TRACK), Animation.TYPE_POSITION_3D)
		if track < 0:
			track = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(track, NodePath(HIPS_POSITION_TRACK))
			anim.position_track_insert_key(track, 0.0, Vector3(0.0, 0.938, 0.0))
			anim.position_track_insert_key(track, maxf(anim.length, 0.1), Vector3(0.0, 0.938, 0.0))
		if track >= 0 and anim.track_get_key_count(track) > 0:
			var first: Vector3 = anim.track_get_key_value(track, 0)
			var last: Vector3 = anim.track_get_key_value(track, anim.track_get_key_count(track) - 1)
			var drift := Vector3(last.x - first.x, 0.0, last.z - first.z)
			var contact := _contact_for_prefix(prefix)
			var key := String(prefix) + "/" + String(anim_name)
			var curve := PackedVector3Array()
			var n := int(anim.length * ROOT_MOTION_FPS) + 1
			for i in n:
				var v: Vector3 = anim.position_track_interpolate(track, minf(i / ROOT_MOTION_FPS, anim.length))
				curve.append(Vector3(v.x - first.x, 0.0, v.z - first.z))
			root_curves[key] = curve
			for k in anim.track_get_key_count(track):
				var v: Vector3 = anim.track_get_key_value(track, k)
				anim.track_set_key_value(track, k, Vector3(0.0, v.y, 0.0))
			_normalize_hips_vertical(prefix, anim, track)
			root_motion[String(prefix) + "/" + String(anim_name)] = Vector3(last.x - first.x, 0.0, last.z - first.z)
		if _is_turn_prefix(prefix):
			_strip_yaw(anim, String(prefix) + "/" + String(anim_name))
		lib.add_animation(anim_name, anim)
	return lib


## Normaliza Hips.y (em unidades de motion_scale, onde 1.0 = altura de descanso
## com a sola rente ao chão) para que todos os clipes de locomoção, condução e
## espera mantenham os pés na altura exata do solo sem afundar e sem saltos.
static func _normalize_hips_vertical(prefix: StringName, anim: Animation, track: int) -> void:
	var n_k := anim.track_get_key_count(track)
	if n_k == 0:
		return
	var sum_y := 0.0
	var min_y := INF
	var max_y := -INF
	for k in n_k:
		var vy := (anim.track_get_key_value(track, k) as Vector3).y
		sum_y += vy
		min_y = minf(min_y, vy)
		max_y = maxf(max_y, vy)
	var mean_y := sum_y / float(n_k)
	var max_dev := maxf(max_y - mean_y, mean_y - min_y)
	max_dev = maxf(max_dev, 0.001)

	if prefix in STEADY_LOCOMOTION_PREFIXES:
		var base_y := 0.985
		var amp := 0.006
		if prefix in [&"m_breathing", &"m_soccer_idle", &"m_offensive_idle", &"m_gk_idle", &"m_warmup", &"m_argue"]:
			base_y = 0.992
			amp = 0.002
		elif prefix in [&"m_walking", &"m_strafe_l_walk", &"m_walk_strafe_l", &"m_start_walk", &"m_walk_stop"]:
			base_y = 0.988
			amp = 0.005
		elif prefix in [&"m_dribble", &"m_slow_jog", &"m_jog", &"m_strafe_l_jog", &"m_strafe_r_jog", &"m_diag_l", &"m_diag_r"]:
			base_y = 0.982
			amp = 0.006
		elif prefix in [&"m_run", &"m_sprint", &"m_idle_to_sprint", &"m_strafe_l_fast", &"m_strafe_r_fast"]:
			base_y = 0.976
			amp = 0.008
		# Etapa 27: o quadril volta a subir e descer com a passada (PESO). Fica
		# 45% da oscilação do PRÓPRIO clipe, na fase dele (coerente com as
		# pernas): ~2 cm andando, ~4 cm no trote. Antes era achatada (±0,6 cm)
		# e o corpo "flutuava".
		var own := (max_y - min_y) * 0.5
		var bob_k := BOB_KEEP if own > 0.004 else 0.0
		for k in n_k:
			var v: Vector3 = anim.track_get_key_value(track, k)
			var norm_dy := clampf((v.y - mean_y) / max_dev, -1.0, 1.0)
			if bob_k > 0.0 and not prefix in [&"m_breathing", &"m_soccer_idle", &"m_offensive_idle", &"m_gk_idle", &"m_warmup", &"m_argue"]:
				v.y = base_y + clampf((v.y - mean_y) * bob_k, -0.03, 0.03)
			else:
				v.y = base_y + norm_dy * amp
			anim.track_set_key_value(track, k, v)
	elif prefix in UPRIGHT_ACTION_PREFIXES:
		var base_y := 0.984
		var amp := 0.018
		for k in n_k:
			var v: Vector3 = anim.track_get_key_value(track, k)
			var norm_dy := clampf((v.y - mean_y) / max_dev, -1.0, 1.0)
			v.y = base_y + norm_dy * amp
			anim.track_set_key_value(track, k, v)
	elif max_y > 1.35:
		# Clipes de queda/carrinho/salto que vieram com escala residual alta
		var scale_y := 0.985 / maxf(max_y, 0.985)
		for k in n_k:
			var v: Vector3 = anim.track_get_key_value(track, k)
			v.y *= scale_y
			anim.track_set_key_value(track, k, v)

