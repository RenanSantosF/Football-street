class_name HumanoidCharacter
extends Node3D
## Personagem humanoide montado em tempo de execução a partir de um CORPO BASE
## e de um esqueleto compartilhado (SkeletonProfileHumanoid):
##   - roupa, tom de pele, cabelo e sujeira = parâmetros de shader
##   - proporções = escala de alguns ossos; altura = escala do modelo
##   - animação = AnimationTree montado pelo AnimationTreeBuilder
##
## Corpos base (BASES): o primeiro disponível na ordem é o padrão. Para um
## personagem novo (ex.: gerado por IA e rigado no Mixamo), basta colocar o FBX
## em assets/characters/<nome>/ e registrar aqui. Se nada carregar, cai para o
## manequim provisório. O modelo olha para -Z, como o resto do jogo.

const BASES := {
	&"teen_01": {
		"path": "res://assets/characters/teen_01/teen_01.fbx",
		"textured": true,
		## cor média da pele na textura (medida), referência da troca de tom
		"skin_ref": Color(0.479, 0.313, 0.227),
		"bone_scales": {},
		"hair_meshes": false,
	},
	&"superhero": {
		"path": "res://assets/characters/base/Superhero_Male_FullBody.gltf",
		"textured": false,
		"body_mesh": "SuperHero_Male",
		"eyebrows_mesh": "Eyebrows",
		# corpo adulto → proporções juvenis
		"bone_scales": {&"Chest": 0.95, &"UpperChest": 0.92, &"LeftUpperArm": 0.98,
			&"RightUpperArm": 0.98, &"Neck": 0.95, &"Head": 1.2},
		"hair_meshes": true,
	},
}
const BASE_ORDER: Array[StringName] = [&"teen_01", &"superhero"]

const HAIR_MODELS: Array[String] = [
	"res://assets/characters/hair/Hair_SimpleParted.gltf",
	"res://assets/characters/hair/Hair_Buzzed.gltf",
	"res://assets/characters/hair/Hair_Long.gltf",
	"res://assets/characters/hair/Hair_Buzzed.gltf",
	"res://assets/characters/hair/Hair_SimpleParted.gltf",
]
const SKIN_SHADER := preload("res://src/shaders/character_skin.gdshader")
const TEXTURED_SHADER := preload("res://src/shaders/character_textured.gdshader")

## Altura de um adolescente de 14–15 anos (antes da variação individual).
const TARGET_HEIGHT := 1.64
## Altura de quadril de referência das velocidades de passada do catálogo.
const REF_HIPS_HEIGHT := 0.93

var base_id: StringName = &""
var model: Node3D
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var anim_tree: AnimationTree
var placeholder: PlaceholderBody

var _material: ShaderMaterial
var _hair: MeshInstance3D
var _toe_bones: Array[int] = []
var _model_scale := 1.0
var _hips_rest_height := 0.9


func apply_appearance(a: CharacterAppearance, team: int, role: int) -> void:
	if model == null and placeholder == null:
		_build(a.base_id)
	if placeholder != null:
		placeholder.apply_appearance(a, team, role)
		return
	_apply_body_variation(a)
	_apply_materials(a, role)
	if BASES[base_id].get("hair_meshes", false):
		_apply_hair(a)


## Fator para casar a passada da animação com a velocidade real: altura do
## quadril deste personagem (no mundo) / altura de referência do catálogo.
func get_locomotion_scale() -> float:
	return _hips_rest_height * _model_scale * scale.x / REF_HIPS_HEIGHT


## Altura do quadril no mundo (para converter root motion em metros).
func get_hips_height() -> float:
	return _hips_rest_height * _model_scale * scale.x


## Pontas dos pés (mundo), usadas para sincronizar os toques na bola.
func get_foot_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if skeleton == null:
		return out
	for idx in _toe_bones:
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin)
	return out


func _build(wanted: StringName) -> void:
	var order: Array[StringName] = []
	if wanted != &"" and BASES.has(wanted):
		order.append(wanted)
	order.append_array(BASE_ORDER)
	var scene: PackedScene = null
	for id in order:
		var path: String = BASES[id]["path"]
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
			if scene != null:
				base_id = id
				break
	if scene == null:
		push_warning("HumanoidCharacter: nenhum corpo base disponível, usando manequim provisório.")
		placeholder = PlaceholderBody.new()
		add_child(placeholder)
		return
	var cfg: Dictionary = BASES[base_id]
	model = scene.instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI
	add_child(model)
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free() # o AnimationTree próprio cuida da animação
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	body_mesh = _find_body_mesh(cfg)
	_fix_rest_offset()
	var hips := skeleton.find_bone("Hips")
	_hips_rest_height = maxf(skeleton.get_bone_global_rest(hips).origin.y, 0.1)
	skeleton.motion_scale = _hips_rest_height

	# Altura: normaliza qualquer corpo base para TARGET_HEIGHT.
	var height := body_mesh.get_aabb().size.y if body_mesh != null else 1.8
	_model_scale = TARGET_HEIGHT / maxf(height, 0.1)
	model.scale = Vector3.ONE * _model_scale

	if body_mesh != null:
		var original := body_mesh.mesh.surface_get_material(0) as BaseMaterial3D
		body_mesh.mesh = ClothingMeshBaker.bake(body_mesh.mesh as ArrayMesh, skeleton, body_mesh.skin)
		_material = ShaderMaterial.new()
		if cfg.get("textured", false):
			_material.shader = TEXTURED_SHADER
			if original != null:
				_material.set_shader_parameter("albedo_tex", original.albedo_texture)
			_material.set_shader_parameter("skin_ref", cfg.get("skin_ref", Color(0.5, 0.35, 0.25)))
		else:
			_material.shader = SKIN_SHADER
			if original != null:
				_material.set_shader_parameter("detail_tex", original.albedo_texture)
				_material.set_shader_parameter("normal_tex", original.normal_texture)
		body_mesh.material_override = _material
	for toe in [&"LeftToes", &"RightToes"]:
		var t := skeleton.find_bone(toe)
		if t >= 0:
			_toe_bones.append(t)

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model.add_child(anim_tree)
	anim_tree.root_node = NodePath("..")
	# Animação no passo da física: o pé e a bola ficam sincronizados mesmo
	# quando o celular cai de FPS (a física é limitada por quadro).
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	AnimationTreeBuilder.build(anim_tree)
	# O deslocamento do corpo vem da física do jogador.
	anim_tree.root_motion_track = NodePath("%GeneralSkeleton:Root")
	anim_tree.active = true


func _find_body_mesh(cfg: Dictionary) -> MeshInstance3D:
	if cfg.has("body_mesh"):
		return skeleton.find_child(cfg["body_mesh"], false, false) as MeshInstance3D
	# Sem nome definido: a maior malha com skin presa ao esqueleto.
	var best: MeshInstance3D = null
	var best_size := 0
	for mi in skeleton.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.skin != null and m.mesh.surface_get_array_len(0) > best_size:
			best_size = m.mesh.surface_get_array_len(0)
			best = m
	return best


## Corrige corpos cuja pose de descanso está deslocada da malha (comum em
## personagens gerados por IA e rigados no Mixamo): compara a pose de "bind"
## da malha com o descanso do osso raiz e move o descanso para onde a malha está.
func _fix_rest_offset() -> void:
	if body_mesh == null or body_mesh.skin == null:
		return
	var skin := body_mesh.skin
	for i in skin.get_bind_count():
		var bone := skeleton.find_bone(skin.get_bind_name(i))
		if bone < 0 or skeleton.get_bone_parent(bone) != -1:
			continue
		var mesh_space := skin.get_bind_pose(i).affine_inverse().origin
		var offset := mesh_space - skeleton.get_bone_global_rest(bone).origin
		if offset.length() > 0.01:
			var rest := skeleton.get_bone_rest(bone)
			rest.origin += offset
			skeleton.set_bone_rest(bone, rest)
			skeleton.set_bone_pose_position(bone, rest.origin)
		return


func _apply_body_variation(a: CharacterAppearance) -> void:
	var scales: Dictionary = BASES[base_id].get("bone_scales", {}).duplicate()
	# Variação individual de porte: ombros/tronco um pouco mais largos ou estreitos.
	var b := clampf(a.build, -1.0, 1.0)
	scales[&"UpperChest"] = scales.get(&"UpperChest", 1.0) * (1.0 + 0.05 * b)
	scales[&"Head"] = scales.get(&"Head", 1.0) * (1.0 - 0.02 * b)
	for bone: StringName in scales:
		var idx := skeleton.find_bone(bone)
		if idx >= 0:
			skeleton.set_bone_pose_scale(idx, Vector3.ONE * scales[bone])


func _apply_materials(a: CharacterAppearance, role: int) -> void:
	if _material == null:
		return
	var shirt := a.shirt_color
	var has_shirt := a.has_shirt
	if role == Player.Role.GOALKEEPER and has_shirt:
		shirt = Color(0.12, 0.12, 0.13)
	_material.set_shader_parameter("skin_color", a.skin_color)
	_material.set_shader_parameter("hair_color", a.hair_color)
	_material.set_shader_parameter("has_shirt", 1.0 if has_shirt else 0.0)
	_material.set_shader_parameter("shirt_color", shirt)
	_material.set_shader_parameter("shorts_color", a.shorts_color)
	_material.set_shader_parameter("recolor_shorts", 0.0 if a.keep_original_shorts else 1.0)
	_material.set_shader_parameter("has_shoes", 0.0 if a.barefoot else 1.0)
	_material.set_shader_parameter("shoes_color", a.shoes_color)
	_material.set_shader_parameter("socks_color", Color(0.88, 0.87, 0.84).lerp(a.shoes_color, 0.15))
	_material.set_shader_parameter("dirt", a.dirt)
	_material.set_shader_parameter("seed", float(get_instance_id() % 97))
	var cfg: Dictionary = BASES[base_id]
	if cfg.has("eyebrows_mesh"):
		var brows := skeleton.find_child(cfg["eyebrows_mesh"], false, false) as MeshInstance3D
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
