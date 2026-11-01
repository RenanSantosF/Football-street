class_name HumanoidCharacter
extends Node3D
## Personagem humanoide montado em tempo de execução a partir de UM corpo base
## e UM esqueleto compartilhado (SkeletonProfileHumanoid):
##   - roupa, cor de pele e sujeira = parâmetros do shader character_skin
##   - cabelo = malha separada presa ao mesmo esqueleto
##   - proporções de adolescente = escala de alguns ossos (sem modelo novo)
##   - animação = AnimationTree montado pelo AnimationTreeBuilder
##
## Se o modelo não carregar, cai para o manequim provisório (PlaceholderBody).
## O modelo olha para -Z, como o resto do jogo.

const BASE_MODEL := "res://assets/characters/base/Superhero_Male_FullBody.gltf"
const BODY_MESH_NAME := "SuperHero_Male"
const EYEBROWS_MESH_NAME := "Eyebrows"
const HAIR_MODELS: Array[String] = [
	"res://assets/characters/hair/Hair_SimpleParted.gltf",
	"res://assets/characters/hair/Hair_Buzzed.gltf",
	"res://assets/characters/hair/Hair_Long.gltf",
	"res://assets/characters/hair/Hair_Buzzed.gltf",
	"res://assets/characters/hair/Hair_SimpleParted.gltf",
]
const SKIN_SHADER := preload("res://src/shaders/character_skin.gdshader")

## Corpo base adulto de 1,81 m → adolescente de ~1,66 m.
const TEEN_SCALE := 0.92
## Proporções juvenis (escala por osso do perfil humanoide): tronco e ombros
## mais estreitos, cabeça proporcionalmente maior.
const TEEN_BONE_SCALES := {
	&"Chest": 0.95,
	&"UpperChest": 0.92,
	&"LeftUpperArm": 0.98,
	&"RightUpperArm": 0.98,
	&"Neck": 0.95,
	&"Head": 1.2,
}

var model: Node3D
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var anim_tree: AnimationTree
var placeholder: PlaceholderBody

var _material: ShaderMaterial
var _hair: MeshInstance3D
var _toe_bones: Array[int] = []


func apply_appearance(a: CharacterAppearance, team: int, role: int) -> void:
	if model == null and placeholder == null:
		_build()
	if placeholder != null:
		placeholder.apply_appearance(a, team, role)
		return
	_apply_materials(a, role)
	_apply_hair(a)


## Fator de tamanho para casar a passada da animação com a velocidade real.
func get_locomotion_scale() -> float:
	return TEEN_SCALE * scale.x


## Pontas dos pés (mundo), usadas para sincronizar os toques na bola.
func get_foot_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if skeleton == null:
		return out
	for idx in _toe_bones:
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin)
	return out


func _build() -> void:
	var scene := load(BASE_MODEL) as PackedScene
	if scene == null:
		push_warning("HumanoidCharacter: modelo base ausente, usando manequim provisório.")
		placeholder = PlaceholderBody.new()
		add_child(placeholder)
		return
	model = scene.instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI
	model.scale = Vector3.ONE * TEEN_SCALE
	add_child(model)
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	body_mesh = skeleton.find_child(BODY_MESH_NAME, false, false) as MeshInstance3D
	if body_mesh != null:
		var original := body_mesh.mesh.surface_get_material(0) as BaseMaterial3D
		body_mesh.mesh = ClothingMeshBaker.bake(body_mesh.mesh as ArrayMesh, skeleton)
		_material = ShaderMaterial.new()
		_material.shader = SKIN_SHADER
		if original != null:
			_material.set_shader_parameter("detail_tex", original.albedo_texture)
			_material.set_shader_parameter("normal_tex", original.normal_texture)
		body_mesh.material_override = _material
	for toe in [&"LeftToes", &"RightToes"]:
		var t := skeleton.find_bone(toe)
		if t >= 0:
			_toe_bones.append(t)
	for bone: StringName in TEEN_BONE_SCALES:
		var idx := skeleton.find_bone(bone)
		if idx >= 0:
			skeleton.set_bone_pose_scale(idx, Vector3.ONE * TEEN_BONE_SCALES[bone])

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model.add_child(anim_tree)
	anim_tree.root_node = NodePath("..")
	AnimationTreeBuilder.build(anim_tree)
	# O deslocamento do corpo vem da física do jogador; a trilha Root fica
	# separada (Etapa 3/4 usa root motion nos dribles e no carrinho).
	anim_tree.root_motion_track = NodePath("%GeneralSkeleton:Root")
	anim_tree.active = true


func _apply_materials(a: CharacterAppearance, role: int) -> void:
	if _material == null:
		return
	var shirt := a.shirt_color
	if role == Player.Role.GOALKEEPER and a.has_shirt:
		shirt = Color(0.12, 0.12, 0.13)
	_material.set_shader_parameter("skin_color", a.skin_color)
	_material.set_shader_parameter("has_shirt", 1.0 if a.has_shirt else 0.0)
	_material.set_shader_parameter("shirt_color", shirt)
	_material.set_shader_parameter("shorts_color", a.shorts_color)
	_material.set_shader_parameter("shoes_color", a.shoes_color)
	_material.set_shader_parameter("socks_color", Color(0.88, 0.87, 0.84).lerp(a.shoes_color, 0.15))
	_material.set_shader_parameter("dirt", a.dirt)
	_material.set_shader_parameter("seed", float(get_instance_id() % 97))
	var brows := skeleton.find_child(EYEBROWS_MESH_NAME, false, false) as MeshInstance3D
	if brows != null:
		brows.material_override = _hair_material(brows.mesh.surface_get_material(0), a.hair_color)


func _apply_hair(a: CharacterAppearance) -> void:
	if _hair != null:
		_hair.queue_free()
		_hair = null
	var path := HAIR_MODELS[clampi(a.hair_style, 0, HAIR_MODELS.size() - 1)]
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var inst := scene.instantiate()
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	var mi: MeshInstance3D = found[0] if found.size() > 0 else null
	if mi == null:
		inst.free()
		return
	mi.get_parent().remove_child(mi)
	mi.owner = null
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.material_override = _hair_material(mi.mesh.surface_get_material(0), a.hair_color)
	_hair = mi
	inst.free()


static func _hair_material(source: Material, color: Color) -> Material:
	var base := source as BaseMaterial3D
	if base == null:
		return source
	var m := base.duplicate() as BaseMaterial3D
	m.albedo_color = color * 2.2 # textura do cabelo é cinza-clara; o tom vem da cor
	m.albedo_color.a = 1.0
	return m
