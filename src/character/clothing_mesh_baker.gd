class_name ClothingMeshBaker
extends RefCounted
## Gera, uma única vez por malha base, uma cópia com MÁSCARAS DE ROUPA nas
## cores de vértice:
##   R = camiseta   G = bermuda   B = tênis (1,0) ou meia (0,5)   A = cabeça
##
## A classificação usa os PESOS DE SKIN de cada vértice (a que ossos ele
## pertence) e, nos membros, a posição ao longo do osso. Assim funciona com
## qualquer corpo humanoide e qualquer pose de descanso (T, A...).
## Toda a variedade de roupas sai de parâmetros de material.

## Osso -> categoria. Para membros: [categoria, início, fim] ao longo do osso
## (0 = começo do osso, 1 = começo do osso filho).
const TORSO := [&"Spine", &"Chest", &"UpperChest", &"LeftShoulder", &"RightShoulder"]
const HEAD := [&"Head", &"LeftEye", &"RightEye", &"Jaw"]
const SLEEVE_END := 0.45      # manga curta: até 45% do braço
const SHORTS_END := 0.95      # bermuda: até a altura do joelho (cobre a barra do jeans)
const SOCK_START := 0.72      # meia: último trecho da canela
const SHOE_START := 0.93

static var _cache := {}


static func bake(mesh: ArrayMesh, skeleton: Skeleton3D, skin: Skin = null) -> ArrayMesh:
	var key := mesh.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	var bind_names := _bind_names(skin, skeleton)
	var seg := _segments(skeleton)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var per := 4
		if bones != null and verts.size() > 0 and bones.size() >= verts.size() * 8:
			per = 8
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			colors[i] = _mask(verts[i], i, per, bones, weights, bind_names, seg)
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays,
			mesh.surface_get_blend_shape_arrays(s), {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	out.blend_shape_mode = mesh.blend_shape_mode
	_cache[key] = out
	return out


## Índice de bind (usado em ARRAY_BONES) -> nome do osso.
static func _bind_names(skin: Skin, skeleton: Skeleton3D) -> Array[StringName]:
	var names: Array[StringName] = []
	if skin != null:
		for i in skin.get_bind_count():
			var n := skin.get_bind_name(i)
			if n == &"" and skin.get_bind_bone(i) >= 0:
				n = skeleton.get_bone_name(skin.get_bind_bone(i))
			names.append(n)
	else:
		for i in skeleton.get_bone_count():
			names.append(StringName(skeleton.get_bone_name(i)))
	return names


## Segmentos dos membros (início/fim na pose de descanso) para medir a
## posição de um vértice ao longo do osso.
static func _segments(sk: Skeleton3D) -> Dictionary:
	var pos := func(bone: String) -> Vector3:
		var i := sk.find_bone(bone)
		return sk.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO
	var d := {}
	for side in ["Left", "Right"]:
		d[StringName(side + "UpperArm")] = [pos.call(side + "UpperArm"), pos.call(side + "LowerArm")]
		d[StringName(side + "UpperLeg")] = [pos.call(side + "UpperLeg"), pos.call(side + "LowerLeg")]
		d[StringName(side + "LowerLeg")] = [pos.call(side + "LowerLeg"), pos.call(side + "Foot")]
	d[&"Neck"] = [pos.call("Neck"), pos.call("Head")]
	return d


static func _along(v: Vector3, seg: Array) -> float:
	var a: Vector3 = seg[0]
	var b: Vector3 = seg[1]
	var ab := b - a
	var l2 := ab.length_squared()
	return 0.0 if l2 < 1e-6 else clampf((v - a).dot(ab) / l2, -0.5, 1.5)


static func _mask(v: Vector3, i: int, per: int, bones, weights, names: Array[StringName], seg: Dictionary) -> Color:
	var shirt := 0.0
	var shorts := 0.0
	var shoes := 0.0
	var socks := 0.0
	var head := 0.0
	if bones == null or weights == null:
		return Color(0, 0, 0, 0)
	for k in per:
		var w: float = weights[i * per + k]
		if w <= 0.0:
			continue
		var bi: int = bones[i * per + k]
		if bi < 0 or bi >= names.size():
			continue
		var n: StringName = names[bi]
		if n in TORSO:
			shirt += w
		elif n in HEAD:
			head += w
		elif n == &"Neck":
			if _along(v, seg[&"Neck"]) > 0.55:
				head += w
		elif n == &"LeftUpperArm" or n == &"RightUpperArm":
			if _along(v, seg[n]) < SLEEVE_END:
				shirt += w
		elif n == &"Hips":
			shorts += w
		elif n == &"LeftUpperLeg" or n == &"RightUpperLeg":
			if _along(v, seg[n]) < SHORTS_END:
				shorts += w
		elif n == &"LeftLowerLeg" or n == &"RightLowerLeg":
			var t := _along(v, seg[n])
			if t > SHOE_START:
				shoes += w
			elif t > SOCK_START:
				socks += w
		elif String(n).ends_with("Foot") or String(n).ends_with("Toes"):
			shoes += w
	var b := 1.0 if shoes > 0.5 else (0.5 if socks > 0.5 else 0.0)
	return Color(1.0 if shirt > 0.5 else 0.0, 1.0 if shorts > 0.5 else 0.0, b, 1.0 if head > 0.5 else 0.0)
