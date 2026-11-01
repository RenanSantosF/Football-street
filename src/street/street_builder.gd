@tool
class_name StreetBuilder
extends Node3D
## Rua de periferia calçada com bloquete, sem casas "bonitas": quintais dos
## dois lados separados por cerca de tábua velha e de arame, um portão de ferro
## enferrujado, um pedaço de muro de bloco sem reboco, postes de madeira com
## fios, mangueiras e uma bananeira aparecendo por cima das cercas, cadeira de
## plástico na calçada, pneu velho, bicicleta encostada...
##
## Tudo gerado por código a partir das medidas de Field, com materiais
## procedurais (sem texturas grandes) e as tábuas em MultiMesh (leve no celular).
## É @tool para aparecer no editor; os nós gerados não são salvos na cena.

@export var seed_value := 11:
	set(v):
		seed_value = v
		if is_inside_tree():
			rebuild()

const SURFACE_SHADER := preload("res://src/shaders/street_surface.gdshader")
const PAINT_SHADER := preload("res://src/shaders/paint_line.gdshader")
const PAVER_SHADER := preload("res://src/shaders/paver_blocks.gdshader")
const WOOD_SHADER := preload("res://src/shaders/weathered_wood.gdshader")
const BARK_SHADER := preload("res://src/shaders/tree_bark.gdshader")
const FOLIAGE_SHADER := preload("res://src/shaders/foliage.gdshader")
const IRON_SHADER := preload("res://src/shaders/old_iron.gdshader")
const BRICK_SHADER := preload("res://src/shaders/bricks.gdshader")

## Cores de fachada de periferia, desbotadas pelo sol.
const HOUSE_COLORS: Array[Color] = [
	Color(0.90, 0.84, 0.66), Color(0.86, 0.70, 0.56), Color(0.70, 0.80, 0.68),
	Color(0.92, 0.90, 0.84), Color(0.80, 0.66, 0.50), Color(0.72, 0.78, 0.84),
	Color(0.88, 0.76, 0.48),
]

## Onde começa a cerca (fim da calçada).
var FENCE_Z: float = Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH

var _rng := RandomNumberGenerator.new()
var _materials := {}
var _curb_physics: PhysicsMaterial
var _soft_physics: PhysicsMaterial
var _planks: Array[Transform3D] = []
var _posts: Array[Transform3D] = []


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	var old := get_node_or_null("Generated")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "Generated"
	add_child(root)
	_rng.seed = seed_value
	_planks.clear()
	_posts.clear()
	_curb_physics = PhysicsMaterial.new()
	_curb_physics.friction = 0.5
	_curb_physics.bounce = 0.35 # meio-fio devolve a bola rasteira para a rua
	_soft_physics = PhysicsMaterial.new()
	_soft_physics.friction = 0.7
	_soft_physics.bounce = 0.1

	_build_ground(root)
	_build_sidewalks(root)
	_build_lines(root)
	for side in [-1.0, 1.0]:
		_build_fence_line(root, side)
		_build_yard(root, side)
		_build_houses(root, side)
	_build_street_ends(root)
	_build_poles(root)
	_build_props(root)
	_flush_multimeshes(root)
	_build_boundary(root)


# --- Chão --------------------------------------------------------------------------

func _build_ground(root: Node3D) -> void:
	var length := Field.STREET_HALF_LENGTH * 2.0 + 8.0
	var paver := ShaderMaterial.new()
	paver.shader = PAVER_SHADER
	_mesh_box(root, Vector3(0, -0.05, 0), Vector3(length, 0.1, Field.ASPHALT_HALF_WIDTH * 2.0), paver)
	var body := _static_body(root, _soft_physics)
	_box_shape(body, Vector3(0, -0.5, 0), Vector3(length + 20.0, 1.0, 60.0))


func _build_sidewalks(root: Node3D) -> void:
	var length := Field.STREET_HALF_LENGTH * 2.0 + 8.0
	var walk := _surface("sidewalk", Color(0.52, 0.48, 0.42), 0.22, 0.6, 0.9, 0.0)
	var curb := _surface("curb", Color(0.62, 0.60, 0.56), 0.18, 0.6, 0.6, 0.0)
	var dirt := _surface("dirt_strip", Color(0.36, 0.29, 0.21), 0.25, 0.4, 0.0, 0.0)
	var grass := _surface("grass_strip", Color(0.27, 0.32, 0.14), 0.3, 0.3, 0.0, 0.0)
	var h := Field.CURB_HEIGHT
	for side in [-1.0, 1.0]:
		var zc: float = side * (Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH * 0.5)
		_mesh_box(root, Vector3(0, h * 0.5, zc), Vector3(length, h, Field.SIDEWALK_WIDTH), walk)
		_mesh_box(root, Vector3(0, h * 0.5 + 0.003, side * (Field.ASPHALT_HALF_WIDTH + 0.07)),
			Vector3(length, h + 0.006, 0.14), curb)
		# Faixa de terra/mato junto da cerca (ninguém varre ali).
		var x := -length * 0.5
		while x < length * 0.5:
			var w := _rng.randf_range(1.5, 5.0)
			var mat := grass if _rng.randf() < 0.55 else dirt
			_mesh_box(root, Vector3(x + w * 0.5, h + 0.004, side * (FENCE_Z - 0.35)),
				Vector3(w, 0.008, _rng.randf_range(0.4, 0.8)), mat)
			x += w + _rng.randf_range(0.0, 2.0)
		var body := _static_body(root, _curb_physics)
		_box_shape(body, Vector3(0, h * 0.5, zc), Vector3(length, h, Field.SIDEWALK_WIDTH))


func _build_lines(root: Node3D) -> void:
	# Só as linhas de fundo e o meio, riscadas a giz (laterais = meio-fio).
	var paint := ShaderMaterial.new()
	paint.shader = PAINT_SHADER
	paint.set_shader_parameter("wear", 0.42)
	var W := Field.HALF_WIDTH
	for sx in [-1.0, 1.0]:
		_mesh_box(root, Vector3(sx * Field.HALF_LENGTH, 0.004, 0), Vector3(0.07, 0.004, W * 2.0), paint)
	_mesh_box(root, Vector3(0, 0.004, 0), Vector3(0.06, 0.004, W * 2.0), paint)


# --- Cercas -----------------------------------------------------------------------

func _build_fence_line(root: Node3D, side: float) -> void:
	var x := -Field.STREET_HALF_LENGTH
	var gate_done := false
	var wall_done := false
	var body := _static_body(root, _soft_physics)
	while x < Field.STREET_HALF_LENGTH:
		var r := _rng.randf()
		var w: float
		if not gate_done and r < 0.12 and absf(x) < 18.0:
			w = 3.0
			_iron_gate(root, x, side, w)
			gate_done = true
		elif not wall_done and r < 0.22 and side < 0.0:
			w = _rng.randf_range(3.0, 4.5)
			_block_wall(root, x, side, w)
			wall_done = true
		elif r < 0.5:
			w = _rng.randf_range(4.0, 7.0)
			_wire_fence(root, x, side, w)
		else:
			w = _rng.randf_range(4.0, 8.0)
			_wood_fence(root, x, side, w, side > 0.0)
		w = minf(w, Field.STREET_HALF_LENGTH - x)
		_box_shape(body, Vector3(x + w * 0.5, 0.9, side * (FENCE_Z + 0.05)), Vector3(w, 1.8, 0.12))
		x += w


func _wood_fence(root: Node3D, x0: float, side: float, w: float, low: bool) -> void:
	var z := side * (FENCE_Z + 0.06)
	var base_h := _rng.randf_range(1.0, 1.25) if low else _rng.randf_range(1.5, 1.9)
	var x := x0
	while x < x0 + w:
		var pw := _rng.randf_range(0.11, 0.19)
		if _rng.randf() > 0.06: # algumas tábuas faltando
			var ph := base_h + _rng.randf_range(-0.18, 0.12)
			var t := Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.03, 0.03), 0, _rng.randf_range(-0.05, 0.05))),
				Vector3(x + pw * 0.5, ph * 0.5 + Field.CURB_HEIGHT * 0.5, z))
			t = t.scaled_local(Vector3(pw - 0.01, ph, 0.022))
			_planks.append(t)
		x += pw + _rng.randf_range(0.0, 0.035)
	# Travessas e mourões.
	var wood := _wood_mat()
	for y in [0.35, base_h - 0.25]:
		_mesh_box(root, Vector3(x0 + w * 0.5, y, z + side * 0.03), Vector3(w, 0.07, 0.035), wood)
	var px := x0
	while px <= x0 + w:
		_posts.append(Transform3D(Basis(), Vector3(px, base_h * 0.5, z + side * 0.06)).scaled_local(Vector3(0.09, base_h + 0.1, 0.09)))
		px += 2.4


func _wire_fence(root: Node3D, x0: float, side: float, w: float) -> void:
	var z := side * (FENCE_Z + 0.05)
	var wire := _flat_mat("wire", Color(0.32, 0.30, 0.28), 0.45, 0.6)
	var px := x0
	var tops: Array[Vector3] = []
	while px <= x0 + w + 0.01:
		var lean := _rng.randf_range(-0.06, 0.06)
		var ph := _rng.randf_range(1.35, 1.55)
		var t := Transform3D(Basis.from_euler(Vector3(lean, 0, _rng.randf_range(-0.05, 0.05))), Vector3(px, ph * 0.5, z))
		_posts.append(t.scaled_local(Vector3(0.08, ph, 0.08)))
		tops.append(Vector3(px, ph, z))
		px += _rng.randf_range(2.0, 2.6)
	for i in tops.size() - 1:
		var a := tops[i]
		var b := tops[i + 1]
		for k in 4:
			var y := 0.3 + k * 0.32
			_sag_wire(root, Vector3(a.x, y, z), Vector3(b.x, y, z), 0.04 + 0.02 * k, wire, 0.004)


func _iron_gate(root: Node3D, x0: float, side: float, w: float) -> void:
	var z := side * (FENCE_Z + 0.05)
	var iron := ShaderMaterial.new()
	iron.shader = IRON_SHADER
	iron.set_shader_parameter("rust_amount", 0.85)
	iron.set_shader_parameter("paint_color", Color(0.18, 0.30, 0.22))
	var h := 1.8
	for y in [0.15, h * 0.5, h - 0.05]:
		_mesh_box(root, Vector3(x0 + w * 0.5, y, z), Vector3(w, 0.05, 0.04), iron)
	var bx := x0 + 0.05
	while bx < x0 + w:
		_mesh_box(root, Vector3(bx, h * 0.5, z), Vector3(0.022, h, 0.022), iron)
		bx += 0.12
	var concrete := _surface("gate_pillar", Color(0.55, 0.53, 0.5), 0.2, 0.6, 0.5, 0.6)
	for px in [x0, x0 + w]:
		_mesh_box(root, Vector3(px, 1.05, z), Vector3(0.3, 2.1, 0.3), concrete)


func _block_wall(root: Node3D, x0: float, side: float, w: float) -> void:
	var z := side * (FENCE_Z + 0.1)
	var block := ShaderMaterial.new()
	block.shader = BRICK_SHADER
	var h := _rng.randf_range(1.6, 2.0)
	_mesh_box(root, Vector3(x0 + w * 0.5, h * 0.5, z), Vector3(w, h, 0.15), block)
	# Fileira de cima incompleta (obra parada).
	var bx := x0
	while bx < x0 + w * 0.6:
		_mesh_box(root, Vector3(bx + 0.2, h + 0.1, z), Vector3(0.38, 0.19, 0.15), block)
		bx += 0.4


# --- Quintais e árvores -----------------------------------------------------------

func _build_yard(root: Node3D, side: float) -> void:
	var yard := _surface("yard_%d" % int(side), Color(0.24, 0.30, 0.13), 0.6, 0.6, 0.0, 0.0)
	var depth := 16.0
	_mesh_box(root, Vector3(0, 0.0, side * (FENCE_Z + depth * 0.5)), Vector3(Field.STREET_HALF_LENGTH * 2.0 + 8.0, 0.02, depth), yard)
	var bark := ShaderMaterial.new()
	bark.shader = BARK_SHADER
	var leaves := _leaves_mat()
	# Arbustos e mato alto junto da cerca (do lado de dentro dos quintais).
	var bx := -Field.STREET_HALF_LENGTH + _rng.randf_range(0.0, 3.0)
	while bx < Field.STREET_HALF_LENGTH:
		_foliage(root, Vector3(bx, 0.35, side * (FENCE_Z + _rng.randf_range(0.5, 1.2))), _rng.randf_range(0.45, 0.8), leaves)
		bx += _rng.randf_range(3.0, 7.0)
	var count := 7 if side < 0.0 else 4
	for i in count:
		var tx := _rng.randf_range(-Field.STREET_HALF_LENGTH + 2.0, Field.STREET_HALF_LENGTH - 2.0)
		var tz := side * (FENCE_Z + _rng.randf_range(1.2, 4.5))
		if side > 0.0:
			continue # do lado da câmera não tem árvore (a câmera entrava na copa)
		if i == 2 and side < 0.0:
			_banana_tree(root, Vector3(tx, 0.0, tz))
		else:
			_tree(root, Vector3(tx, 0.0, tz), bark, leaves)


func _tree(root: Node3D, base: Vector3, bark: Material, leaves: Material) -> void:
	var trunk_h := _rng.randf_range(2.6, 3.8)
	var r := _rng.randf_range(0.16, 0.28)
	var lean := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.08, 0.08))
	_cylinder_between(root, base, base + Vector3(lean.x, trunk_h, lean.z), r, r * 0.75, bark)
	var top := base + Vector3(lean.x, trunk_h, lean.z)
	var n := _rng.randi_range(3, 5)
	for i in n:
		var ang := _rng.randf() * TAU
		var start := base + Vector3(lean.x, trunk_h * _rng.randf_range(0.55, 0.95), lean.z)
		var length := _rng.randf_range(1.3, 2.4)
		var end := start + Vector3(cos(ang) * length, _rng.randf_range(0.6, 1.4), sin(ang) * length * 0.7)
		_cylinder_between(root, start, end, r * 0.45, r * 0.18, bark)
		_foliage(root, end + Vector3(0, 0.4, 0), _rng.randf_range(1.0, 1.6), leaves)
	_foliage(root, top + Vector3(0, 0.9, 0), _rng.randf_range(1.8, 2.4), leaves)


func _banana_tree(root: Node3D, base: Vector3) -> void:
	var stem := _flat_mat("banana_stem", Color(0.36, 0.38, 0.20), 0.85)
	var leaf := _flat_mat("banana_leaf", Color(0.24, 0.40, 0.13), 0.75)
	for k in 3:
		var p := base + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.4, 0.4))
		var h := _rng.randf_range(1.8, 2.6)
		_cylinder_between(root, p, p + Vector3(0, h, 0), 0.13, 0.09, stem)
		for i in 6:
			var ang := i * TAU / 6.0 + _rng.randf()
			var mi := _mesh_box(root, p + Vector3(cos(ang) * 0.6, h + 0.15, sin(ang) * 0.6), Vector3(1.4, 0.02, 0.38), leaf)
			mi.rotation = Vector3(0, -ang, _rng.randf_range(-0.6, -0.2))


func _foliage(root: Node3D, center: Vector3, radius: float, leaves: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.6
	mesh.radial_segments = 10
	mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = leaves
	mi.position = center
	# Copas não projetam sombra (o recorte das folhas é caro no passe de sombra).
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _leaves_mat() -> ShaderMaterial:
	if _materials.has("leaves"):
		return _materials["leaves"]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	_materials["leaves"] = m
	return m


# --- Casas do fundo ----------------------------------------------------------------

## Casas de periferia atrás dos quintais: reboco pintado e desbotado, telhado de
## barro, janelas com vidro, caixa d'água azul na laje, às vezes o andar de cima
## de tijolo à mostra (obra que nunca terminou), varal com roupas.
func _build_houses(root: Node3D, side: float) -> void:
	var x := -Field.STREET_HALF_LENGTH - 2.0
	while x < Field.STREET_HALF_LENGTH + 2.0:
		var w := _rng.randf_range(6.5, 10.0)
		var d := _rng.randf_range(6.0, 8.0)
		var z0 := side * (FENCE_Z + _rng.randf_range(6.0, 8.5))
		if side > 0.0 and absf(x + w * 0.5) < 9.0:
			x += w + _rng.randf_range(1.0, 3.0)
			continue # do lado da câmera, só nas pontas
		_house(root, Vector3(x + w * 0.5, 0.0, z0 + side * d * 0.5), w, d, side)
		x += w + _rng.randf_range(1.5, 4.0)


func _house(root: Node3D, c: Vector3, w: float, d: float, side: float) -> void:
	var color := HOUSE_COLORS[_rng.randi_range(0, HOUSE_COLORS.size() - 1)]
	var wall := _surface("house_%d" % color.to_rgba32(), color, 0.12, 0.55, 0.25, 0.7)
	var h := _rng.randf_range(2.8, 3.1)
	_mesh_box(root, c + Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	var front_z := c.z - side * d * 0.5  # face voltada para a rua
	var two_floors := _rng.randf() < 0.45
	var top := h
	if two_floors:
		# Laje + segundo andar (às vezes de tijolo à mostra).
		var slab := _surface("slab", Color(0.62, 0.60, 0.57), 0.15, 0.6, 0.3, 0.0)
		_mesh_box(root, c + Vector3(0, h + 0.07, 0), Vector3(w + 0.3, 0.14, d + 0.3), slab)
		var w2 := w * _rng.randf_range(0.55, 0.85)
		var h2 := _rng.randf_range(2.5, 2.8)
		var bricks := _rng.randf() < 0.6
		var upper: Material
		if bricks:
			var bm := ShaderMaterial.new()
			bm.shader = BRICK_SHADER
			upper = bm
		else:
			upper = wall
		var ux := c.x + _rng.randf_range(-(w - w2) * 0.5, (w - w2) * 0.5)
		_mesh_box(root, Vector3(ux, h + 0.14 + h2 * 0.5, c.z), Vector3(w2, h2, d * 0.8), upper)
		top = h + 0.14 + h2
		_roof(root, Vector3(ux, top, c.z), w2 + 0.5, d * 0.8 + 0.6)
		# Caixa d'água azul na laje.
		_water_tank(root, Vector3(c.x + (w * 0.35 if ux < c.x else -w * 0.35), h + 0.14, c.z))
		_window(root, Vector3(ux, h + 1.6, front_z - side * 0.06 + side * d * 0.1), 1.2, 1.0, side)
	else:
		_roof(root, Vector3(c.x, h, c.z), w + 0.6, d + 0.6)
		if _rng.randf() < 0.5:
			_water_tank(root, Vector3(c.x + _rng.randf_range(-w * 0.3, w * 0.3), h + 0.9, c.z))
	# Porta e janelas na frente.
	var door := _flat_mat("door_%d" % _rng.randi_range(0, 2), [Color(0.35, 0.22, 0.14), Color(0.20, 0.28, 0.22), Color(0.55, 0.55, 0.52)][_rng.randi_range(0, 2)], 0.6, 0.2)
	_mesh_box(root, Vector3(c.x - w * 0.25, 1.05, front_z - side * 0.03), Vector3(0.9, 2.1, 0.06), door)
	_window(root, Vector3(c.x + w * 0.2, 1.5, front_z - side * 0.03), 1.4, 1.1, side)
	if _rng.randf() < 0.5:
		_clothesline(root, Vector3(c.x, 0, front_z - side * 2.2), w * 0.7)


## Telhado de duas águas com telha de barro.
func _roof(root: Node3D, base: Vector3, w: float, d: float) -> void:
	var tile := _surface("roof_tile", Color(0.58, 0.28, 0.17), 0.2, 0.55, 0.0, 0.0)
	var rise := d * 0.22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	var hd := d * 0.5
	var a := Vector3(-hw, 0, -hd)
	var b := Vector3(hw, 0, -hd)
	var cc := Vector3(hw, rise, 0)
	var dd := Vector3(-hw, rise, 0)
	var e := Vector3(-hw, 0, hd)
	var f := Vector3(hw, 0, hd)
	for tri in [[a, dd, cc], [a, cc, b], [e, f, cc], [e, cc, dd], [a, e, dd], [b, cc, f]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = tile
	mi.position = base
	root.add_child(mi)


func _window(root: Node3D, c: Vector3, w: float, h: float, side: float) -> void:
	var frame := _flat_mat("win_frame", Color(0.85, 0.85, 0.82), 0.5, 0.3)
	var glass := _flat_mat("glass", Color(0.12, 0.16, 0.2), 0.08, 0.3)
	_mesh_box(root, c, Vector3(w + 0.1, h + 0.1, 0.05), frame)
	_mesh_box(root, c - Vector3(0, 0, side * 0.02), Vector3(w, h, 0.05), glass)
	_mesh_box(root, c - Vector3(0, 0, side * 0.035), Vector3(0.04, h, 0.03), frame)
	# Grade de ferro (comum na periferia).
	var bar := _flat_mat("win_bar", Color(0.18, 0.18, 0.18), 0.5, 0.5)
	var bx := -w * 0.5 + 0.15
	while bx < w * 0.5:
		_mesh_box(root, c + Vector3(bx, 0, -side * 0.06), Vector3(0.015, h, 0.015), bar)
		bx += 0.15


func _water_tank(root: Node3D, base: Vector3) -> void:
	var blue := _flat_mat("water_tank", Color(0.12, 0.30, 0.62), 0.45)
	_cylinder_between(root, base, base + Vector3(0, 0.75, 0), 0.62, 0.68, blue)
	_cylinder_between(root, base + Vector3(0, 0.75, 0), base + Vector3(0, 0.85, 0), 0.7, 0.55, blue)


func _clothesline(root: Node3D, base: Vector3, length: float) -> void:
	var wire := _flat_mat("wire", Color(0.32, 0.30, 0.28), 0.45, 0.6)
	var a := base + Vector3(-length * 0.5, 1.8, 0)
	var b := base + Vector3(length * 0.5, 1.8, 0)
	_cylinder_between(root, base + Vector3(-length * 0.5, 0, 0), a, 0.03, 0.03, _wood_mat())
	_cylinder_between(root, base + Vector3(length * 0.5, 0, 0), b, 0.03, 0.03, _wood_mat())
	_sag_wire(root, a, b, 0.12, wire, 0.004)
	var colors: Array[Color] = [Color(0.8, 0.15, 0.15), Color(0.9, 0.9, 0.85), Color(0.2, 0.35, 0.7), Color(0.95, 0.75, 0.2)]
	var cx := -length * 0.4
	while cx < length * 0.4:
		var cloth := _flat_mat("cloth_%d" % _rng.randi_range(0, 3), colors[_rng.randi_range(0, 3)], 0.9)
		var cw := _rng.randf_range(0.35, 0.6)
		var ch := _rng.randf_range(0.4, 0.7)
		var t := (cx + length * 0.5) / length
		var y := 1.8 - 0.12 * 4.0 * t * (1.0 - t)
		_mesh_box(root, base + Vector3(cx, y - ch * 0.5, 0), Vector3(cw, ch, 0.01), cloth)
		cx += cw + _rng.randf_range(0.1, 0.4)


# --- Postes, fios, pontas da rua e objetos ------------------------------------------

func _build_poles(root: Node3D) -> void:
	var wood := _wood_mat()
	var wire := _flat_mat("power_wire", Color(0.08, 0.08, 0.08), 0.5)
	var body := _static_body(root, _soft_physics)
	var tops: Array[Vector3] = []
	var px := -Field.STREET_HALF_LENGTH + 4.0
	while px < Field.STREET_HALF_LENGTH:
		var z := -(FENCE_Z - 0.25)
		var h := 7.0
		var base := Vector3(px + _rng.randf_range(-1.0, 1.0), 0.0, z)
		var tilt := Vector3(_rng.randf_range(-0.05, 0.05), 0, _rng.randf_range(-0.03, 0.03))
		_cylinder_between(root, base, base + Vector3(tilt.x * h, h, tilt.z * h), 0.13, 0.1, wood)
		var top := base + Vector3(tilt.x * h, h - 0.4, tilt.z * h)
		_mesh_box(root, top, Vector3(0.1, 0.1, 1.4), wood)
		tops.append(top)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.13
		shape.height = h
		cs.shape = shape
		cs.position = base + Vector3(0, h * 0.5, 0)
		body.add_child(cs)
		px += _rng.randf_range(15.0, 20.0)
	for i in tops.size() - 1:
		for dz in [-0.6, 0.0, 0.6]:
			_sag_wire(root, tops[i] + Vector3(0, 0, dz), tops[i + 1] + Vector3(0, 0, dz), 0.45, wire, 0.012)


func _build_street_ends(root: Node3D) -> void:
	var body := _static_body(root, _soft_physics)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (Field.STREET_HALF_LENGTH + 0.3)
		var width := FENCE_Z * 2.0
		var z := -FENCE_Z
		while z < FENCE_Z:
			var pw := _rng.randf_range(0.12, 0.18)
			var ph := _rng.randf_range(1.5, 1.9)
			var t := Transform3D(Basis.from_euler(Vector3(0, PI * 0.5, _rng.randf_range(-0.04, 0.04))), Vector3(x, ph * 0.5, z + pw * 0.5))
			_planks.append(t.scaled_local(Vector3(pw - 0.01, ph, 0.022)))
			z += pw + _rng.randf_range(0.0, 0.04)
		_box_shape(body, Vector3(x, 0.9, 0), Vector3(0.15, 1.8, width))


func _build_props(root: Node3D) -> void:
	var h := Field.CURB_HEIGHT
	var sz := -(Field.ASPHALT_HALF_WIDTH + 1.4)
	# Cadeira de plástico branca na calçada.
	var plastic := _flat_mat("plastic", Color(0.86, 0.86, 0.82), 0.45)
	var cx := 6.5
	_mesh_box(root, Vector3(cx, h + 0.42, sz), Vector3(0.42, 0.04, 0.42), plastic)
	var back := _mesh_box(root, Vector3(cx, h + 0.68, sz - 0.2), Vector3(0.42, 0.5, 0.04), plastic)
	back.rotation.x = -0.15
	for lx in [-0.18, 0.18]:
		for lz in [-0.18, 0.18]:
			_cylinder_between(root, Vector3(cx + lx, h, sz + lz), Vector3(cx + lx * 0.8, h + 0.42, sz + lz * 0.8), 0.018, 0.018, plastic)
	# Pneu velho deitado e tijolos soltos.
	var rubber := _flat_mat("rubber", Color(0.06, 0.06, 0.06), 0.9)
	var tire := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.32
	tire.mesh = tm
	tire.material_override = rubber
	tire.position = Vector3(-11.0, h + 0.07, -(FENCE_Z - 0.5))
	tire.scale = Vector3(1, 0.7, 1)
	root.add_child(tire)
	var brick := _flat_mat("brick", Color(0.6, 0.3, 0.2), 0.9)
	for b in [Vector3(-17.0, h + 0.05, sz + 0.4), Vector3(-16.7, h + 0.05, sz + 0.55), Vector3(17.5, 0.05, Field.HALF_WIDTH + 0.6)]:
		var bm := _mesh_box(root, b, Vector3(0.19, 0.09, 0.09), brick)
		bm.rotation.y = _rng.randf() * PI
	# Bicicleta encostada na cerca.
	var bike_x := -4.0
	var bz := -(FENCE_Z - 0.18)
	var frame := _flat_mat("bike", Color(0.55, 0.1, 0.08), 0.5, 0.4)
	for wx in [-0.5, 0.5]:
		var wheel := MeshInstance3D.new()
		var wm := TorusMesh.new()
		wm.inner_radius = 0.3
		wm.outer_radius = 0.33
		wheel.mesh = wm
		wheel.material_override = rubber
		wheel.position = Vector3(bike_x + wx, h + 0.33, bz)
		wheel.rotation = Vector3(PI * 0.5, 0, 0.12)
		root.add_child(wheel)
	_cylinder_between(root, Vector3(bike_x - 0.5, h + 0.33, bz), Vector3(bike_x, h + 0.75, bz - 0.03), 0.02, 0.02, frame)
	_cylinder_between(root, Vector3(bike_x + 0.5, h + 0.33, bz), Vector3(bike_x, h + 0.75, bz - 0.03), 0.02, 0.02, frame)
	_cylinder_between(root, Vector3(bike_x - 0.5, h + 0.33, bz), Vector3(bike_x + 0.5, h + 0.33, bz), 0.02, 0.02, frame)
	# Saco de lixo.
	var bag := MeshInstance3D.new()
	var bagm := SphereMesh.new()
	bagm.radius = 0.28
	bagm.height = 0.45
	bag.mesh = bagm
	bag.material_override = _flat_mat("bag", Color(0.05, 0.05, 0.06), 0.35)
	bag.position = Vector3(12.5, h + 0.2, -(FENCE_Z - 0.35))
	root.add_child(bag)


## Paredes invisíveis altas: a bola não sai do mundo por cima das cercas
## (bola no quintal do vizinho vira evento na Etapa 6).
func _build_boundary(root: Node3D) -> void:
	var body := _static_body(root, _soft_physics)
	body.name = "InvisibleBoundary"
	var hgt := 16.0
	for side in [-1.0, 1.0]:
		_box_shape(body, Vector3(0, hgt * 0.5, side * (FENCE_Z + 0.25)), Vector3(Field.STREET_HALF_LENGTH * 2.0 + 2.0, hgt, 0.5))
		_box_shape(body, Vector3(side * (Field.STREET_HALF_LENGTH + 0.55), hgt * 0.5, 0), Vector3(0.5, hgt, FENCE_Z * 2.0 + 1.0))


func _flush_multimeshes(root: Node3D) -> void:
	_multimesh(root, _planks, _wood_mat())
	var post_mat := _wood_mat()
	_multimesh(root, _posts, post_mat)


func _multimesh(root: Node3D, transforms: Array[Transform3D], mat: Material) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)


# --- Utilitários ------------------------------------------------------------------

func _sag_wire(root: Node3D, a: Vector3, b: Vector3, sag: float, mat: Material, radius: float) -> void:
	var segs := 6
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_cylinder_between(root, prev, p, radius, radius, mat)
		prev = p


func _cylinder_between(root: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var length := d.length()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r0
	mesh.top_radius = r1
	mesh.height = length
	mesh.radial_segments = 8 if r0 > 0.05 else 4
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)
	var y := d / maxf(length, 0.0001)
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	if r0 < 0.03:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _wood_mat() -> ShaderMaterial:
	if _materials.has("wood"):
		return _materials["wood"]
	var m := ShaderMaterial.new()
	m.shader = WOOD_SHADER
	_materials["wood"] = m
	return m


func _surface(key: String, color: Color, variation: float, stains: float, cracks: float, dirt_bottom := 0.0) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("stain_color", color * 0.55)
	m.set_shader_parameter("variation", variation)
	m.set_shader_parameter("stain_amount", stains)
	m.set_shader_parameter("crack_amount", cracks)
	m.set_shader_parameter("dirt_bottom", dirt_bottom)
	_materials[key] = m
	return m


func _flat_mat(key: String, color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_materials[key] = m
	return m


func _mesh_box(root: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


func _static_body(root: Node3D, phys: PhysicsMaterial) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = phys
	root.add_child(body)
	return body


func _box_shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
