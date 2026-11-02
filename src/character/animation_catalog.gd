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
	&"m_gk_idle": TEEN_01,
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
	&"pass_short": &"r_side_kick/seg_pass",
	&"pass_long": &"m_pass_long/mixamo_com",
	&"shoot": &"m_shoot/mixamo_com",
	&"shoot_power": &"r_power_kick/seg_kick",
	&"receive": &"m_receive/mixamo_com",
	&"spin": &"m_spin/mixamo_com",
	&"cut": &"m_cut/mixamo_com",
	&"recv_chest": &"m_chest/mixamo_com",
	&"recv_knee": &"m_kneeing/mixamo_com",
	&"header": &"m_header/mixamo_com",
	&"head_control": &"m_head_ctrl/mixamo_com",
	&"header_jump": &"m_header_jump/mixamo_com",
	&"tackle": &"m_tackle/mixamo_com",
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
	&"gk_pass": &"m_gk_pass/mixamo_com",
	&"gk_place": &"m_gk_place/mixamo_com",
	&"kick_up": &"r_juggling/seg_juggle",
	&"kneeing": &"m_kneeing/mixamo_com",
	&"warmup": &"m_warmup/mixamo_com",
	# reserva (biblioteca UAL)
	&"ual_idle": &"ual/Idle",
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
	&"tackle": [0.36, -1.0],
	&"spin": [1.0, 1.0],
	&"gk_pass": [1.15, 1.0],
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
	&"getup_b": [1.6, 7.0],
}
const GETUP_SPEED := 1.7


static func getup_duration(logical: StringName) -> float:
	if not has_clip(logical) or not GETUP_SEGMENTS.has(logical):
		return 0.0
	var seg: Array = GETUP_SEGMENTS[logical]
	return (seg[1] - seg[0]) / GETUP_SPEED


## Velocidade natural (m/s) da passada de cada clipe, normalizada para um
## quadril de 0,93 m (HumanoidCharacter.REF_HIPS_HEIGHT). Medida pelo
## deslocamento do quadril no clipe original (os clipes do Mixamo andam).
const LOCOMOTION_POINTS: Array = [
	[&"idle", 0.0], [&"walk", 1.64], [&"slow_jog", 1.96], [&"run", 4.04], [&"sprint", 5.65],
]
const LOCOMOTION_BALL_POINTS: Array = [
	[&"idle_ball", 0.0], [&"walk", 1.64], [&"dribble", 2.56], [&"run", 4.04], [&"sprint", 5.65],
]
## Marcação: velocidade local (x = para a direita, y = para a frente), m/s.
const MARK_POINTS: Array = [
	[&"mark_idle", Vector2(0.0, 0.0)],
	[&"jog", Vector2(0.0, 2.37)],
	[&"back", Vector2(0.0, -2.91)],
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
## clipe "prefixo/nome" -> deslocamento horizontal total retirado (root motion).
static var root_motion := {}
## clipe "prefixo/nome" -> curva do deslocamento horizontal do quadril
## (PackedVector3Array, ROOT_MOTION_FPS amostras/s, em alturas de quadril).
static var root_curves := {}


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
		_apply_loops()
		_add_mirrored()
	return _libraries


## Chutes/passes com o OUTRO pé: o mesmo clipe espelhado (troca esquerda ↔
## direita). O esqueleto do retarget é simétrico, então o espelho é exato.
const MIRRORED: Array[StringName] = [&"pass_short", &"pass_long", &"shoot", &"shoot_power",
	&"cut_r", &"walk_turn180", &"stand_turn_r"]


static func mirrored_name(logical: StringName) -> StringName:
	return StringName(String(logical) + "_m")


static func _add_mirrored() -> void:
	for logical in MIRRORED:
		if not has_clip(logical):
			continue
		var parts := String(CLIPS[logical]).split("/")
		var lib := _libraries[StringName(parts[0])] as AnimationLibrary
		var src := lib.get_animation(StringName(parts[1]))
		var mname := StringName(parts[1] + "_m")
		if not lib.has_animation(mname):
			lib.add_animation(mname, _mirror(src))
		var key := String(CLIPS[logical])
		var mkey := parts[0] + "/" + String(mname)
		if root_curves.has(key):
			var c: PackedVector3Array = root_curves[key]
			var mc := PackedVector3Array()
			for v in c:
				mc.append(Vector3(-v.x, v.y, v.z))
			root_curves[mkey] = mc
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
			var parts := String(CLIPS[logical]).split("/")
			var anim := (_libraries[StringName(parts[0])] as AnimationLibrary).get_animation(StringName(parts[1]))
			anim.loop_mode = Animation.LOOP_LINEAR


static func has_clip(logical: StringName) -> bool:
	if String(logical).ends_with("_m"):
		get_libraries()
		return _mirror_clips.has(logical)
	if not CLIPS.has(logical):
		return false
	var parts := String(CLIPS[logical]).split("/")
	var libs := get_libraries()
	var prefix := StringName(parts[0])
	return libs.has(prefix) and (libs[prefix] as AnimationLibrary).has_animation(StringName(parts[1]))


static func clip(logical: StringName) -> StringName:
	if _mirror_clips.has(logical):
		return _mirror_clips[logical]
	return CLIPS.get(logical, &"")


static func _base(logical: StringName) -> StringName:
	var s := String(logical)
	return StringName(s.substr(0, s.length() - 2)) if s.ends_with("_m") else logical


static func clip_length(logical: StringName) -> float:
	logical = _base(logical)
	if not has_clip(logical):
		return 0.0
	var parts := String(CLIPS[logical]).split("/")
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
	var i := clampi(int(t * ROOT_MOTION_FPS), 0, curve.size() - 2)
	return (curve[i + 1] - curve[i]) * ROOT_MOTION_FPS


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
		lib.add_animation(anim_name, anim)
	return lib
