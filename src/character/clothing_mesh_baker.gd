class_name ClothingMeshBaker
extends RefCounted
## Gera, uma única vez por malha base, uma cópia com MÁSCARAS DE ROUPA nas
## cores de vértice, calculadas na pose de repouso a partir das posições dos
## ossos (independe de UV e funciona para qualquer corpo humanoide):
##   R = camiseta   G = bermuda   B = tênis   A = meia
## O shader character_skin usa essas máscaras para pintar e "inflar"
## levemente o tecido (bermuda folgada, camiseta). Toda a variedade de roupas
## sai de parâmetros de material: nenhum modelo novo por jogador.

static var _cache := {}


static func bake(mesh: ArrayMesh, skeleton: Skeleton3D) -> ArrayMesh:
	var key := mesh.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var lm := _landmarks(skeleton)
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			colors[i] = _mask(verts[i], lm)
		arrays[Mesh.ARRAY_COLOR] = colors
		var blend_shapes := mesh.surface_get_blend_shape_arrays(s)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, blend_shapes)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	out.blend_shape_mode = mesh.blend_shape_mode
	_cache[key] = out
	return out


static func _landmarks(sk: Skeleton3D) -> Dictionary:
	var p := func(bone: String) -> Vector3:
		var idx := sk.find_bone(bone)
		return sk.get_bone_global_rest(idx).origin if idx >= 0 else Vector3.ZERO
	var hips: Vector3 = p.call("Hips")
	var knee: Vector3 = p.call("LeftLowerLeg")
	var ankle: Vector3 = p.call("LeftFoot")
	var neck: Vector3 = p.call("Neck")
	var shoulder: Vector3 = p.call("LeftUpperArm")
	var elbow: Vector3 = p.call("LeftLowerArm")
	return {
		"hips_y": hips.y,
		"knee_y": knee.y,
		"ankle_y": ankle.y,
		"neck_y": neck.y,
		"shoulder_y": shoulder.y,
		"shoulder_x": absf(shoulder.x),
		"elbow_x": absf(elbow.x),
		"torso_half": absf(shoulder.x) * 0.9,
	}


static func _mask(v: Vector3, lm: Dictionary) -> Color:
	var shirt := 0.0
	var shorts := 0.0
	var shoes := 0.0
	var socks := 0.0
	var ax := absf(v.x)
	var is_arm: bool = ax > lm.torso_half and v.y > lm.shoulder_y - 0.2
	if is_arm:
		# Manga curta: do ombro até ~40% do braço.
		var sleeve_end: float = lm.shoulder_x + (lm.elbow_x - lm.shoulder_x) * 0.42
		if ax < sleeve_end:
			shirt = 1.0
	else:
		# Gola: cobre ombros/trapézio; na frente desce um pouco (gola careca).
		var collar_y: float = lm.neck_y + 0.03 if ax > 0.08 else lm.neck_y - 0.03
		if v.z > 0.0 and ax < 0.08:
			collar_y = lm.neck_y - 0.06
		if v.y > lm.hips_y - 0.02 and v.y < collar_y:
			shirt = 1.0
		# Bermuda: da cintura até um palmo acima do joelho... um pouco abaixo (bermuda de rua).
		if v.y < lm.hips_y + 0.1 and v.y > lm.knee_y + 0.02:
			shorts = 1.0
		if v.y < lm.ankle_y + 0.035:
			shoes = 1.0
		elif v.y < lm.ankle_y + 0.13:
			socks = 1.0
	return Color(shirt, shorts, shoes, socks)
