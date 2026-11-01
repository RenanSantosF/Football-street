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
	# defesa / quedas
	&"m_tackle": "Soccer Tackle (2)",
	&"m_trip": "Soccer Trip",
	&"m_fallen": "Fallen Idle caído depois da falta",
	&"m_jump": "Running Jump pulando fugindo do carrinho",
	# opcional: levantar do chão (se o arquivo existir no pack)
	&"m_getup": "Standing Up",
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
	&"m_kneeing": "Kneeing Soccerball",
	&"m_warmup": "Offensive Idle aquecimento",
}

## nome lógico -> "prefixo/clipe"
const CLIPS := {
	&"idle": &"m_soccer_idle/mixamo_com",
	&"idle_ball": &"m_offensive_idle/mixamo_com",
	&"walk": &"ual/Walk",
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
	&"spin": &"m_spin/mixamo_com",
	&"cut": &"m_cut/mixamo_com",
	&"tackle": &"m_tackle/mixamo_com",
	&"trip": &"m_trip/mixamo_com",
	&"fallen": &"m_fallen/mixamo_com",
	&"jump": &"m_jump/mixamo_com",
	&"getup": &"m_getup/mixamo_com",
	&"victory": &"m_victory/mixamo_com",
	&"victory_idle": &"m_victory_idle/mixamo_com",
	&"samba": &"m_samba/mixamo_com",
	&"defeated": &"m_defeated/mixamo_com",
	&"sad_run": &"m_sad_run/mixamo_com",
	&"gk_catch": &"m_gk_catch/mixamo_com",
	&"gk_pass": &"m_gk_pass/mixamo_com",
	&"gk_place": &"m_gk_place/mixamo_com",
	&"kick_up": &"m_kick_up/mixamo_com",
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
	&"idle", &"idle_ball", &"walk", &"slow_jog", &"jog", &"run", &"sprint", &"dribble",
	&"mark_idle", &"back", &"strafe_l_jog", &"strafe_r_jog", &"strafe_l_walk",
	&"strafe_l_fast", &"strafe_r_fast", &"diag_l", &"diag_r", &"fallen",
	&"victory_idle", &"samba", &"sad_run", &"kick_up", &"kneeing", &"warmup", &"talk",
]

## Instante (s) em que o pé encosta na bola e qual pé (+1 direito, -1 esquerdo).
## Conferido quadro a quadro (docs/ETAPA_04.md).
const CONTACTS := {
	&"pass_short": [0.50, 1.0],
	&"pass_long": [0.20, -1.0],
	&"shoot": [0.45, 1.0],
	&"shoot_power": [0.79, 1.0],
	&"receive": [0.29, 1.0],
	&"tackle": [0.36, -1.0],
	&"spin": [1.0, 1.0],
	&"gk_pass": [1.15, 1.0],
}

## Velocidade natural (m/s) da passada de cada clipe, normalizada para um
## quadril de 0,93 m (HumanoidCharacter.REF_HIPS_HEIGHT). Medida pelo
## deslocamento do quadril no clipe original (os clipes do Mixamo andam).
const LOCOMOTION_POINTS: Array = [
	[&"idle", 0.0], [&"walk", 1.05], [&"slow_jog", 1.96], [&"run", 4.04], [&"sprint", 5.65],
]
const LOCOMOTION_BALL_POINTS: Array = [
	[&"idle_ball", 0.0], [&"walk", 1.05], [&"dribble", 2.56], [&"run", 4.04], [&"sprint", 5.65],
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
const ROOT_MOTION: Array[StringName] = [&"tackle", &"trip", &"jump", &"spin"]
const ROOT_MOTION_FPS := 30.0

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
			if prefix != &"ual":
				lib = _make_in_place(prefix, lib)
			_libraries[prefix] = lib
		_apply_loops()
	return _libraries


static func _apply_loops() -> void:
	for logical in LOOPING:
		if has_clip(logical):
			var parts := String(CLIPS[logical]).split("/")
			var anim := (_libraries[StringName(parts[0])] as AnimationLibrary).get_animation(StringName(parts[1]))
			anim.loop_mode = Animation.LOOP_LINEAR


static func has_clip(logical: StringName) -> bool:
	if not CLIPS.has(logical):
		return false
	var parts := String(CLIPS[logical]).split("/")
	var libs := get_libraries()
	var prefix := StringName(parts[0])
	return libs.has(prefix) and (libs[prefix] as AnimationLibrary).has_animation(StringName(parts[1]))


static func clip(logical: StringName) -> StringName:
	return CLIPS.get(logical, &"")


static func clip_length(logical: StringName) -> float:
	if not has_clip(logical):
		return 0.0
	var parts := String(CLIPS[logical]).split("/")
	return (get_libraries()[StringName(parts[0])] as AnimationLibrary).get_animation(StringName(parts[1])).length


static func contact_time(logical: StringName) -> float:
	return CONTACTS[logical][0] if CONTACTS.has(logical) else 0.0


static func contact_foot(logical: StringName) -> float:
	return CONTACTS[logical][1] if CONTACTS.has(logical) else 1.0


static func _is_root_motion_prefix(prefix: StringName) -> bool:
	for logical in ROOT_MOTION:
		if String(CLIPS.get(logical, "")).begins_with(String(prefix) + "/"):
			return true
	return false


## Velocidade do root motion no instante t (alturas de quadril por segundo,
## no espaço do modelo: +Z = para a frente, +X = para a esquerda).
static func root_motion_velocity(logical: StringName, t: float) -> Vector3:
	var curve: PackedVector3Array = root_curves.get(String(CLIPS.get(logical, "")), PackedVector3Array())
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
