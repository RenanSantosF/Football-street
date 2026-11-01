class_name AnimationCatalog
extends RefCounted
## Catálogo central de animações humanoides.
##
## Todas as bibliotecas passam pelo retarget para o SkeletonProfileHumanoid do
## Godot, então qualquer clipe toca em qualquer personagem. Cada biblioteca
## entra com um prefixo ("ual/", e na Etapa 3 "mixamo/"...). O resto do jogo
## usa só os NOMES LÓGICOS abaixo; trocar um clipe por um melhor é mudar uma
## linha aqui.

## prefixo -> cena importada que contém um AnimationPlayer com os clipes.
const LIBRARY_SOURCES := {
	&"ual": "res://assets/animations/ual/AnimationLibrary_Godot_Standard.gltf",
}

## nome lógico -> "biblioteca/clipe"
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
}

## Velocidade natural (m/s) da passada de cada clipe de locomoção, medida no
## modelo em tamanho original pelo pé apoiado (tests/ e docs/ETAPA_02.md).
## O BlendSpace usa esses valores como posições: na velocidade do clipe, o pé
## não desliza.
const LOCOMOTION_SPEEDS := {
	&"idle": 0.0,
	&"walk": 1.05,
	&"jog": 5.2,
	&"sprint": 6.8,
}

static var _libraries := {}


## Bibliotecas carregadas (cache compartilhado por todos os personagens).
static func get_libraries() -> Dictionary:
	if _libraries.is_empty():
		for prefix: StringName in LIBRARY_SOURCES:
			var lib := _extract_library(LIBRARY_SOURCES[prefix])
			if lib != null:
				_libraries[prefix] = lib
	return _libraries


static func has_clip(logical: StringName) -> bool:
	if not CLIPS.has(logical):
		return false
	var parts := String(CLIPS[logical]).split("/")
	var libs := get_libraries()
	return libs.has(StringName(parts[0])) and (libs[StringName(parts[0])] as AnimationLibrary).has_animation(StringName(parts[1]))


static func clip(logical: StringName) -> StringName:
	return CLIPS.get(logical, &"")


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
