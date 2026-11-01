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
const MIXAMO_PACK := "res://assets/animations/mixamo/soccer_pack/%s.fbx"

## prefixo -> arquivo
const LIBRARY_SOURCES := {
	&"ual": UAL,
	&"m_pass_short": "kick soccerball (2)",
	&"m_pass_long": "kick soccerball",
	&"m_shoot": "strike foward jog",
	&"m_shoot_power": "soccer penalty kick",
	&"m_receive": "stall soccerball (2)",
}

## nome lógico -> "prefixo/clipe"
const CLIPS := {
	&"idle": &"ual/Idle",
	&"walk": &"ual/Walk",
	&"jog": &"ual/Jog_Fwd",
	&"sprint": &"ual/Sprint",
	&"stumble": &"ual/Hit_Chest",
	&"fall": &"ual/Death01",
	&"talk": &"ual/Idle_Talking",
	&"pickup": &"ual/PickUp_Table",
	&"jump_celebrate": &"ual/Jump",
	&"dance": &"ual/Dance",
	&"pass_short": &"m_pass_short/mixamo_com",
	&"pass_long": &"m_pass_long/mixamo_com",
	&"shoot": &"m_shoot/mixamo_com",
	&"shoot_power": &"m_shoot_power/mixamo_com",
	&"receive": &"m_receive/mixamo_com",
}

## Instante (s) em que o pé encosta na bola em cada clipe e qual pé
## (+1 direito, -1 esquerdo). Medido pelo pé mais à frente e rente ao chão
## e conferido visualmente (docs/ETAPA_03.md).
const CONTACTS := {
	&"pass_short": [0.20, 1.0],
	&"pass_long": [0.20, -1.0],
	&"shoot": [0.45, 1.0],
	&"shoot_power": [0.79, 1.0],
	&"receive": [0.29, 1.0],
}

## Velocidade natural (m/s) da passada de cada clipe de locomoção, medida no
## modelo em tamanho original pelo pé apoiado. O BlendSpace usa esses valores
## como posições: na velocidade do clipe, o pé não desliza.
const LOCOMOTION_SPEEDS := {
	&"idle": 0.0,
	&"walk": 1.05,
	&"jog": 5.2,
	&"sprint": 6.8,
}

const HIPS_POSITION_TRACK := "%GeneralSkeleton:Hips"

static var _libraries := {}
## clipe "prefixo/nome" -> deslocamento horizontal total retirado (root motion).
static var root_motion := {}


## Bibliotecas carregadas (cache compartilhado por todos os personagens).
static func get_libraries() -> Dictionary:
	if _libraries.is_empty():
		for prefix: StringName in LIBRARY_SOURCES:
			var src: String = LIBRARY_SOURCES[prefix]
			var path := src if src.begins_with("res://") else MIXAMO_PACK % src
			if not ResourceLoader.exists(path):
				continue
			var lib := _extract_library(path)
			if lib == null:
				continue
			if prefix != &"ual":
				lib = _make_in_place(prefix, lib)
			_libraries[prefix] = lib
	return _libraries


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
	inst.free()
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
			if contact >= 0.0:
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
