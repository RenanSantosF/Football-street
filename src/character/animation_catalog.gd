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
	&"m_shoved": TEEN_01,
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
	&"shoved": &"m_shoved/seg_shoved",
	&"back": &"m_back/mixamo_com",
	&"strafe_l_jog": &"m_strafe_l_jog/mixamo_com",
	&"strafe_r_jog": &"m_strafe_r_jog/mixamo_com",
	&"strafe_l_walk": &"m_strafe_l_walk/mixamo_com",
	&"strafe_l_fast": &"m_strafe_l_fast/mixamo_com",
	&"strafe_r_fast": &"m_strafe_r_fast/mixamo_com",
	&"diag_l": &"m_diag_l/mixamo_com",
	&"diag_r": &"m_diag_r/mixamo_com",
	&"pass_short": &"r_side_kick/seg_pass",
	&"pass_long": &"m_pass_long/mixamo_com",
	&"shoot": &"m_shoot/mixamo_com",
	&"shoot_power": &"r_power_kick/seg_kick",
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
	&"kick_up": &"r_juggling/seg_juggle",
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
	&"pass_short": [0.55, 1.0],   # passe de chapa (mocap): contato ~1,45 s no take
	&"pass_long": [0.15, -1.0],
	&"shoot": [0.45, 1.0],
	&"shoot_power": [0.70, -1.0], # chute forte (mocap, pé esquerdo): contato 2,60 s
	&"receive": [0.29, 1.0],
	&"receive_ball": [0.28, 1.0],
	&"tackle": [0.36, -1.0],
	&"stand_tackle": [0.22, 1.0],
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
	&"m_shoved": {&"seg_shoved": [1.15, 2.75]},
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
## quadril de 0,93 m (HumanoidCharacter.REF_HIPS_HEIGHT). Medida pelo
## deslocamento do quadril no clipe original (os clipes do Mixamo andam).
const LOCOMOTION_POINTS: Array = [
	# (trote = "Jog Forward": o "Slow Jog" vinha com o quadril torto ~40°)
	[&"idle", 0.0], [&"walk", 1.64], [&"jog", 2.37], [&"run", 4.04], [&"sprint", 5.65],
]
const LOCOMOTION_BALL_POINTS: Array = [
	[&"idle_ball", 0.0], [&"walk", 1.64], [&"dribble", 2.1], [&"run", 4.04], [&"sprint", 5.65],
]
## Marcação: velocidade local (x = para a direita, y = para a frente), m/s.
const MARK_POINTS: Array = [
	[&"mark_idle", Vector2(0.0, 0.0)],
	[&"jog", Vector2(0.0, 2.37)],
	# ("Run Backward" vem com o corpo virado 180°: misturado aos outros, o quadril
	#  "estalava". Recuar rápido = virar e correr; ver Player._compute_marking)
	[&"strafe_l_walk", Vector2(-1.59, 0.0)],
	[&"strafe_l_jog", Vector2(-2.75, 0.0)],
	[&"strafe_r_jog", Vector2(2.21, 0.0)],
	[&"strafe_l_fast", Vector2(-4.15, 0.0)],
	[&"strafe_r_fast", Vector2(4.15, 0.0)],
	[&"diag_l", Vector2(-1.79, 1.77)],
	[&"diag_r", Vector2(1.88, 1.88)],
]
## Mais rápido que isto, a passada acelera (TimeScale).
const TOP_SPEED := 5.65

## Compatibilidade com código antigo (velocidades por nome lógico).
const LOCOMOTION_SPEEDS := {&"sprint": 5.65}

const HIPS_POSITION_TRACK := "%GeneralSkeleton:Hips"
## Clipes cujo deslocamento do corpo vem da própria animação (root motion):
## a física do jogador segue a curva do quadril gravada no clipe.
const ROOT_MOTION: Array[StringName] = [&"tackle", &"trip", &"jump", &"spin", &"turn180", &"turn_l", &"turn_r", &"run_stop",
	&"cut_r", &"walk_turn180", &"stand_turn_r", &"walk_stop", &"shoved"]
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
			if prefix == &"m_shoved" and lib.has_animation(&"seg_shoved"):
				_normalize_shoved_spin(lib.get_animation(&"seg_shoved"))
			_libraries[prefix] = lib
		_build_ual_fallbacks()
		_apply_loops()
		_add_mirrored()
	return _libraries


## No clipe Shoved Reaction With Spin, o personagem leva um tranco, gira 360°
## mantendo o eixo final alinhado com a frente do jogador (sem estalo ao sair).
static func _normalize_shoved_spin(anim: Animation) -> void:
	var tr := anim.find_track(NodePath(HIPS_POSITION_TRACK), Animation.TYPE_ROTATION_3D)
	if tr < 0 or anim.track_get_key_count(tr) == 0:
		return
	var len := maxf(anim.length, 0.01)
	for k in anim.track_get_key_count(tr):
		var t := anim.track_get_key_time(tr, k)
		var u := clampf(t / len, 0.0, 1.0)
		var q: Quaternion = anim.track_get_key_value(tr, k)
		var e := q.get_euler()
		var target_yaw := lerpf(e.y, 0.0, u * u)
		var pitch := clampf(e.x * 0.65, deg_to_rad(-10.0), deg_to_rad(14.0))
		var roll := clampf(e.z * 0.65, deg_to_rad(-8.0), deg_to_rad(8.0))
		anim.track_set_key_value(tr, k, Quaternion.from_euler(Vector3(pitch, target_yaw, roll)))
	for bname in ["Spine", "Chest", "UpperChest"]:
		var btr := anim.find_track(NodePath("%GeneralSkeleton:" + bname), Animation.TYPE_ROTATION_3D)
		if btr >= 0:
			for k in anim.track_get_key_count(btr):
				var q: Quaternion = anim.track_get_key_value(btr, k)
				var e := q.get_euler() * 0.6
				anim.track_set_key_value(btr, k, Quaternion.from_euler(e))


## Quando os arquivos .fbx do Mixamo/Rohr não estão no disco (ex.: clone limpo
## do git ou build de CI), sintetiza/mapeia a partir da biblioteca UAL
## (AnimationLibrary_Godot_Standard.gltf) para que 100% dos clipes lógicos
## funcionem perfeitamente com o esqueleto humanoide e postura ereta de jogador.
static func _build_ual_fallbacks() -> void:
	if not _libraries.has(&"ual"):
		return
	var ual_lib := _libraries[&"ual"] as AnimationLibrary
	if ual_lib == null:
		return
	if ual_lib.has_animation(&"Hit_Chest"):
		var hc := _apply_footballer_posture(ual_lib.get_animation(&"Hit_Chest").duplicate(true) as Animation, &"stumble")
		ual_lib.remove_animation(&"Hit_Chest")
		ual_lib.add_animation(&"Hit_Chest", hc)
	var fb_lib := AnimationLibrary.new()
	var map_source := {
		&"idle": ["Idle", 1.0],
		&"soccer_idle": ["Idle", 1.0],
		&"idle_ball": ["Idle", 1.0],
		&"mark_idle": ["Idle", 1.05],     # postura de marcação ereta e equilibrada
		&"walk": ["Walk", 1.50],          # escala p/ casar passada a 1,64 m/s
		&"slow_jog": ["Jog_Fwd", 0.78],
		&"dribble": ["Jog_Fwd", 0.88],    # condução próxima a 2,10 m/s
		&"jog": ["Jog_Fwd", 1.0],         # trote a 2,37 m/s
		&"run": ["Jog_Fwd", 1.22],        # corrida a 4,04 m/s com postura atlética ereta
		&"sprint": ["Sprint", 1.18],      # sprint a 5,65 m/s (corrigido p/ postura de jogador)
		&"idle_to_sprint": ["Sprint", 1.2],
		&"sad_run": ["Jog_Fwd", 0.85],
		&"back": ["Walk", 1.2],
		&"strafe_l_walk": ["Walk", 1.35],
		&"strafe_l_jog": ["Jog_Fwd", 1.0],
		&"strafe_r_jog": ["Jog_Fwd", 1.0],
		&"strafe_l_fast": ["Jog_Fwd", 1.15],
		&"strafe_r_fast": ["Jog_Fwd", 1.15],
		&"diag_l": ["Jog_Fwd", 0.95],
		&"diag_r": ["Jog_Fwd", 0.95],
		&"pass_short": ["Jog_Fwd", 0.95],
		&"pass_long": ["Jog_Fwd", 1.1],
		&"shoot": ["Jog_Fwd", 1.05],
		&"shoot_power": ["Jog_Fwd", 0.95],
		&"receive": ["Walk", 1.4],
		&"receive_ball": ["Walk", 1.4],
		&"spin": ["Jog_Fwd", 0.8],
		&"cut": ["Jog_Fwd", 1.1],
		&"cut_r": ["Jog_Fwd", 1.15],
		&"turn_l": ["Walk", 1.5],
		&"turn_r": ["Walk", 1.5],
		&"turn180": ["Jog_Fwd", 1.1],
		&"walk_turn180": ["Walk", 1.4],
		&"stand_turn_r": ["Walk", 1.5],
		&"walk_stop": ["Walk", 1.5],
		&"run_stop": ["Jog_Fwd", 1.1],
		&"recv_chest": ["Hit_Chest", 0.55],
		&"recv_knee": ["Jump_Start", 1.2],
		&"header": ["Jump_Start", 1.1],
		&"head_control": ["Jump_Start", 1.0],
		&"header_jump": ["Jump", 1.2],
		&"tackle": ["Roll_RM", 1.4],
		&"stand_tackle": ["Jog_Fwd", 1.25],
		&"trip": ["Death01", 1.4],
		&"fallen": ["Death01", 1.0],
		&"jump": ["Jump", 1.5],
		&"getup": ["Jump_Land", 0.9],
		&"getup_b": ["Jump_Land", 0.9],
		&"getup_c": ["Jump_Land", 0.9],
		&"victory": ["Jump", 1.2],
		&"victory_idle": ["Dance", 1.0],
		&"samba": ["Dance", 1.0],
		&"defeated": ["Idle", 0.9],
		&"argue": ["Idle_Talking", 1.0],
		&"gk_catch": ["Interact", 1.4],
		&"gk_dive": ["Roll_RM", 1.3],
		&"gk_pass": ["Jog_Fwd", 0.7],
		&"gk_place": ["PickUp_Table", 1.0],
		&"kick_up": ["Jog_Fwd", 0.9],
		&"kneeing": ["Jog_Fwd", 0.9],
		&"warmup": ["Idle", 1.15],
		&"scissor_kick": ["Jump", 1.3],
		&"sprint_turn": ["Jog_Fwd", 1.15],
		&"run_to_turn": ["Jog_Fwd", 1.1],
		&"walk_turn_l": ["Walk", 1.4],
		&"start_walk": ["Walk", 1.4],
		&"shoved": ["Hit_Chest", 0.85],
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
		anim = _apply_footballer_posture(anim, logical)
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


## Corrige a postura da biblioteca UAL para postura real de jogador de futebol:
## - Remove a curvatura exagerada (45°–52° no UpperChest/Hips) e a torção
##   assimétrica que deixava a coluna "quebrada" ou torta.
## - Distribui a inclinação suave e natural do tronco pelos 3 ossos da coluna
##   (Spine 42%, Chest 33%, UpperChest 25%), exatamente como no Mixamo.
## - Mantém o pescoço e a cabeça erguidos olhando para o jogo.
static func _apply_footballer_posture(src: Animation, logical: StringName) -> Animation:
	if logical in [&"tackle", &"trip", &"fallen", &"gk_dive", &"getup", &"getup_b", &"getup_c"]:
		return src
	var out := src.duplicate(true) as Animation
	var fps := 30.0
	var n_keys := maxi(int(round(out.length * fps)), 2)

	var hip_pitch_deg := 1.5
	var torso_pitch_deg := 3.2
	if logical in [&"idle", &"soccer_idle", &"idle_ball", &"warmup", &"talk", &"argue", &"defeated", &"victory_idle"]:
		hip_pitch_deg = 0.5
		torso_pitch_deg = 2.0
	elif logical == &"mark_idle":
		hip_pitch_deg = 2.0
		torso_pitch_deg = 4.0
	elif logical in [&"walk", &"strafe_l_walk", &"turn_l", &"turn_r", &"walk_turn180", &"stand_turn_r", &"walk_stop", &"receive", &"receive_ball", &"walk_turn_l", &"start_walk"]:
		hip_pitch_deg = 1.0
		torso_pitch_deg = 2.8
	elif logical in [&"slow_jog", &"dribble", &"jog", &"sad_run", &"back", &"strafe_l_jog", &"strafe_r_jog", &"diag_l", &"diag_r", &"pass_short", &"pass_long", &"spin", &"cut", &"cut_r", &"gk_pass", &"kick_up", &"kneeing"]:
		hip_pitch_deg = 2.0
		torso_pitch_deg = 4.5
	elif logical in [&"run", &"shoot", &"stand_tackle"]:
		hip_pitch_deg = 2.8
		torso_pitch_deg = 5.5
	elif logical in [&"sprint", &"idle_to_sprint", &"strafe_l_fast", &"strafe_r_fast", &"shoot_power", &"sprint_turn", &"run_to_turn", &"run_stop"]:
		hip_pitch_deg = 3.5
		torso_pitch_deg = 6.5

	# 1. Alinha o quadril (Hips): sem torção lateral nem inclinação exagerada.
	var tr_hips := out.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_ROTATION_3D)
	var hip_eulers: Array[Vector3] = []
	var avg_hip := Vector3.ZERO
	if tr_hips >= 0:
		for i in n_keys + 1:
			var t := minf(float(i) / fps, out.length)
			var e := out.rotation_track_interpolate(tr_hips, t).get_euler()
			hip_eulers.append(e)
			avg_hip += e
		avg_hip /= float(n_keys + 1)
		out.remove_track(tr_hips)
	tr_hips = out.add_track(Animation.TYPE_ROTATION_3D)
	out.track_set_path(tr_hips, NodePath("%GeneralSkeleton:Hips"))
	for i in n_keys + 1:
		var t := minf(float(i) / fps, out.length)
		var raw_e := hip_eulers[i] if i < hip_eulers.size() else Vector3.ZERO
		var de := raw_e - avg_hip
		var hx := deg_to_rad(hip_pitch_deg) + clampf(de.x * 0.35, deg_to_rad(-3.0), deg_to_rad(3.0))
		var hy := clampf(de.y * 0.45, deg_to_rad(-5.0), deg_to_rad(5.0))
		var hz := clampf(de.z * 0.45, deg_to_rad(-3.0), deg_to_rad(3.0))
		out.rotation_track_insert_key(tr_hips, t, Quaternion.from_euler(Vector3(hx, hy, hz)))

	# 2. Redistribui a coluna (Spine, Chest, UpperChest) sem "quebrar" o tronco.
	var tr_spine := out.find_track(NodePath("%GeneralSkeleton:Spine"), Animation.TYPE_ROTATION_3D)
	var tr_chest := out.find_track(NodePath("%GeneralSkeleton:Chest"), Animation.TYPE_ROTATION_3D)
	var tr_uchest := out.find_track(NodePath("%GeneralSkeleton:UpperChest"), Animation.TYPE_ROTATION_3D)
	var comb_eulers: Array[Vector3] = []
	var avg_comb := Vector3.ZERO
	for i in n_keys + 1:
		var t := minf(float(i) / fps, out.length)
		var ec := out.rotation_track_interpolate(tr_chest, t).get_euler() if tr_chest >= 0 else Vector3.ZERO
		var eu := out.rotation_track_interpolate(tr_uchest, t).get_euler() if tr_uchest >= 0 else Vector3.ZERO
		var es := out.rotation_track_interpolate(tr_spine, t).get_euler() if tr_spine >= 0 else Vector3.ZERO
		var c := es + ec + eu
		comb_eulers.append(c)
		avg_comb += c
	avg_comb /= float(n_keys + 1)

	for bname in ["Spine", "Chest", "UpperChest"]:
		var old_tr := out.find_track(NodePath("%GeneralSkeleton:" + bname), Animation.TYPE_ROTATION_3D)
		if old_tr >= 0:
			out.remove_track(old_tr)
	tr_spine = out.add_track(Animation.TYPE_ROTATION_3D)
	out.track_set_path(tr_spine, NodePath("%GeneralSkeleton:Spine"))
	tr_chest = out.add_track(Animation.TYPE_ROTATION_3D)
	out.track_set_path(tr_chest, NodePath("%GeneralSkeleton:Chest"))
	tr_uchest = out.add_track(Animation.TYPE_ROTATION_3D)
	out.track_set_path(tr_uchest, NodePath("%GeneralSkeleton:UpperChest"))

	# 3. Pescoço e Cabeça (Neck, Head) erguidos, olhando para o campo.
	for bname in ["Neck", "Head"]:
		var old_nh := out.find_track(NodePath("%GeneralSkeleton:" + bname), Animation.TYPE_ROTATION_3D)
		if old_nh >= 0:
			out.remove_track(old_nh)
	var tr_neck := out.add_track(Animation.TYPE_ROTATION_3D)
	out.track_set_path(tr_neck, NodePath("%GeneralSkeleton:Neck"))
	var tr_head := out.add_track(Animation.TYPE_ROTATION_3D)
	out.track_set_path(tr_head, NodePath("%GeneralSkeleton:Head"))

	for i in n_keys + 1:
		var t := minf(float(i) / fps, out.length)
		var dc := comb_eulers[i] - avg_comb
		var tot_x := deg_to_rad(torso_pitch_deg) + clampf(dc.x * 0.22, deg_to_rad(-3.5), deg_to_rad(3.5))
		var tot_y := clampf(dc.y * 0.26, deg_to_rad(-10.5), deg_to_rad(10.5))
		var tot_z := clampf(dc.z * 0.22, deg_to_rad(-3.5), deg_to_rad(3.5))
		var tot := Vector3(tot_x, tot_y, tot_z)
		out.rotation_track_insert_key(tr_spine, t, Quaternion.from_euler(tot * 0.42))
		out.rotation_track_insert_key(tr_chest, t, Quaternion.from_euler(tot * 0.33))
		out.rotation_track_insert_key(tr_uchest, t, Quaternion.from_euler(tot * 0.25))

		var head_comp_x := -(deg_to_rad(hip_pitch_deg) + tot_x) + deg_to_rad(1.2)
		var head_comp_y := -tot_y * 0.55
		var head_comp_z := -tot_z * 0.65
		var nh := Vector3(head_comp_x, head_comp_y, head_comp_z)
		out.rotation_track_insert_key(tr_neck, t, Quaternion.from_euler(nh * 0.45))
		out.rotation_track_insert_key(tr_head, t, Quaternion.from_euler(nh * 0.55))

	# 4. Simetriza os braços no Idle/Mark (evita um ombro/braço caído torto).
	if logical in [&"idle", &"soccer_idle", &"idle_ball", &"mark_idle", &"warmup", &"defeated"]:
		var tr_la := out.find_track(NodePath("%GeneralSkeleton:LeftUpperArm"), Animation.TYPE_ROTATION_3D)
		var tr_ra := out.find_track(NodePath("%GeneralSkeleton:RightUpperArm"), Animation.TYPE_ROTATION_3D)
		var tr_ll := out.find_track(NodePath("%GeneralSkeleton:LeftLowerArm"), Animation.TYPE_ROTATION_3D)
		var tr_rl := out.find_track(NodePath("%GeneralSkeleton:RightLowerArm"), Animation.TYPE_ROTATION_3D)
		var base_arm_p := deg_to_rad(64.0 if logical == &"mark_idle" else 70.0)
		var base_fore_p := deg_to_rad(38.0 if logical == &"mark_idle" else 28.0)
		if tr_la >= 0 and tr_ra >= 0:
			for k in out.track_get_key_count(tr_la):
				out.track_set_key_value(tr_la, k, Quaternion.from_euler(Vector3(base_arm_p, deg_to_rad(172.0), deg_to_rad(-12.0))))
			for k in out.track_get_key_count(tr_ra):
				out.track_set_key_value(tr_ra, k, Quaternion.from_euler(Vector3(base_arm_p, deg_to_rad(-172.0), deg_to_rad(12.0))))
		if tr_ll >= 0 and tr_rl >= 0:
			for k in out.track_get_key_count(tr_ll):
				out.track_set_key_value(tr_ll, k, Quaternion.from_euler(Vector3(base_fore_p, deg_to_rad(-88.0), 0.0)))
			for k in out.track_get_key_count(tr_rl):
				out.track_set_key_value(tr_rl, k, Quaternion.from_euler(Vector3(base_fore_p, deg_to_rad(88.0), 0.0)))

	return out


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


## Esculpe a mecânica de chute/passe/domínio/bote na perna de contato do clipe fallback.
static func _sculpt_kick_or_contact(src: Animation, logical: StringName, contact_t: float, foot_side: float) -> Animation:
	var out := src.duplicate(true) as Animation
	var min_len := contact_t + 0.38
	if out.length < min_len:
		out.length = min_len
	if foot_side == 0.0:
		return out
	var prefix := "Right" if foot_side > 0.0 else "Left"
	var hip_path := NodePath("%GeneralSkeleton:" + prefix + "UpperLeg")
	var knee_path := NodePath("%GeneralSkeleton:" + prefix + "LowerLeg")
	var hip_tr := out.find_track(hip_path, Animation.TYPE_ROTATION_3D)
	var knee_tr := out.find_track(knee_path, Animation.TYPE_ROTATION_3D)
	if hip_tr >= 0 and knee_tr >= 0:
		var t_prep := maxf(contact_t - 0.16, 0.02)
		var t_follow := minf(contact_t + 0.16, out.length - 0.02)
		var back_deg := 14.0 if logical == &"stand_tackle" else 22.0
		var q_hip_prep := out.rotation_track_interpolate(hip_tr, t_prep) * Quaternion(Vector3.RIGHT, deg_to_rad(back_deg))
		var q_knee_prep := out.rotation_track_interpolate(knee_tr, t_prep) * Quaternion(Vector3.RIGHT, deg_to_rad(28.0))
		var swing_deg := -32.0 if logical in [&"shoot", &"shoot_power", &"pass_long", &"stand_tackle"] else -20.0
		var q_hip_hit := out.rotation_track_interpolate(hip_tr, contact_t) * Quaternion(Vector3.RIGHT, deg_to_rad(swing_deg))
		var q_knee_hit := out.rotation_track_interpolate(knee_tr, contact_t) * Quaternion(Vector3.RIGHT, deg_to_rad(-18.0))
		var q_hip_fol := out.rotation_track_interpolate(hip_tr, t_follow) * Quaternion(Vector3.RIGHT, deg_to_rad(swing_deg * 1.1))
		out.rotation_track_insert_key(hip_tr, t_prep, q_hip_prep)
		out.rotation_track_insert_key(knee_tr, t_prep, q_knee_prep)
		out.rotation_track_insert_key(hip_tr, contact_t, q_hip_hit)
		out.rotation_track_insert_key(knee_tr, contact_t, q_knee_hit)
		out.rotation_track_insert_key(hip_tr, t_follow, q_hip_fol)
	return out


## Chutes/passes/botes com o OUTRO pé: o mesmo clipe espelhado (troca esquerda ↔
## direita). O esqueleto do retarget é simétrico, então o espelho é exato.
const MIRRORED: Array[StringName] = [&"pass_short", &"pass_long", &"shoot", &"shoot_power",
	&"cut_r", &"walk_turn180", &"stand_turn_r", &"stand_tackle"]


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
	var true_height := hips_y - lowest + 0.02
	if true_height < 0.1 or sk.motion_scale <= 0.0:
		return 1.0
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


## Clipes do Mixamo deslocam o quadril pelo chão (até 4 m). O deslocamento do
## corpo no jogo vem da física, então retiramos o movimento horizontal do
## quadril (o clipe passa a ser "no lugar") e guardamos o total para uso como
## root motion nas etapas seguintes.
static func _make_in_place(prefix: StringName, source: AnimationLibrary) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for anim_name in source.get_animation_list():
		var anim := source.get_animation(anim_name).duplicate(true) as Animation
		var track := anim.find_track(NodePath(HIPS_POSITION_TRACK), Animation.TYPE_POSITION_3D)
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
			if contact >= 0.0 or _is_root_motion_prefix(prefix):
				# Clipes com contato na bola (corrida de aproximação + chute): o
				# quadril fica centrado na origem do jogador o tempo todo; quem
				# leva o corpo até a bola é a física (Player._update_action).
				for k in anim.track_get_key_count(track):
					var v: Vector3 = anim.track_get_key_value(track, k)
					anim.track_set_key_value(track, k, Vector3(first.x, v.y, first.z))
			else:
				for k in anim.track_get_key_count(track):
					# Remove só a tendência de avanço; o balanço natural do quadril fica.
					var v: Vector3 = anim.track_get_key_value(track, k)
					var f := anim.track_get_key_time(track, k) / maxf(anim.length, 0.001)
					anim.track_set_key_value(track, k, v - drift * f)
			root_motion[String(prefix) + "/" + String(anim_name)] = Vector3(last.x - first.x, 0.0, last.z - first.z)
		if _is_turn_prefix(prefix):
			_strip_yaw(anim, String(prefix) + "/" + String(anim_name))
		lib.add_animation(anim_name, anim)
	return lib
