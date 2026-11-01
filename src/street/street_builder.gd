@tool
class_name StreetBuilder
extends Node3D
## Gera a rua de bairro (versão "graybox" da Etapa 1) a partir das medidas de
## Field: asfalto com imperfeições, calçadas com meio-fio, casas e muros
## coloridos e gastos, linhas riscadas e alguns objetos de bairro.
##
## Todos os materiais são procedurais (shader com ruído), sem texturas: leve
## para Android. Na Etapa 7 as caixas das casas são trocadas por modelos
## modulares (.glb) reaproveitando os mesmos materiais.
##
## É @tool para aparecer no editor; os nós gerados não são salvos na cena.

@export var seed_value := 7:
	set(v):
		seed_value = v
		if is_inside_tree():
			rebuild()

const SURFACE_SHADER := preload("res://src/shaders/street_surface.gdshader")
const PAINT_SHADER := preload("res://src/shaders/paint_line.gdshader")

## Cores de fachada típicas (desbotadas): creme, verde-água, salmão, azul,
## amarelo queimado, chapisco cinza, branco encardido.
const WALL_COLORS: Array[Color] = [
	Color(0.86, 0.80, 0.66), Color(0.60, 0.76, 0.70), Color(0.85, 0.62, 0.52),
	Color(0.58, 0.68, 0.80), Color(0.85, 0.70, 0.40), Color(0.55, 0.55, 0.53),
	Color(0.84, 0.83, 0.79), Color(0.75, 0.55, 0.60),
]
const GATE_COLORS: Array[Color] = [
	Color(0.22, 0.24, 0.26), Color(0.15, 0.32, 0.22), Color(0.45, 0.12, 0.10),
	Color(0.62, 0.62, 0.60),
]

var _rng := RandomNumberGenerator.new()
var _materials := {}
var _ground_physics: PhysicsMaterial
var _wall_physics: PhysicsMaterial


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
	_ground_physics = PhysicsMaterial.new()
	_ground_physics.friction = 0.8
	_wall_physics = PhysicsMaterial.new()
	_wall_physics.friction = 0.5
	_wall_physics.bounce = 0.1

	_build_ground(root)
	_build_sidewalks(root)
	_build_lines(root)
	_build_houses(root, -1.0, true)
	_build_houses(root, 1.0, false)
	_build_street_ends(root)
	_build_props(root)
	_build_boundary(root)


# --- Chão ---------------------------------------------------------------------

func _build_ground(root: Node3D) -> void:
	var length := Field.STREET_HALF_LENGTH * 2.0 + 4.0
	var asphalt := _surface("asphalt", Color(0.27, 0.265, 0.26), 0.14, 0.45, 0.8)
	_mesh_box(root, Vector3(0, -0.05, 0), Vector3(length, 0.1, Field.ASPHALT_HALF_WIDTH * 2.0 + 0.2), asphalt)
	# Remendos de asfalto mais novo (mais escuros) espalhados.
	var patch := _surface("patch", Color(0.23, 0.23, 0.235), 0.08, 0.2, 0.0)
	for i in 5:
		var px := _rng.randf_range(-Field.STREET_HALF_LENGTH + 3.0, Field.STREET_HALF_LENGTH - 3.0)
		var pz := _rng.randf_range(-Field.ASPHALT_HALF_WIDTH + 1.0, Field.ASPHALT_HALF_WIDTH - 1.0)
		_mesh_box(root, Vector3(px, 0.003, pz), Vector3(_rng.randf_range(0.5, 1.3), 0.006, _rng.randf_range(0.4, 1.0)), patch)
	# Colisão única do chão (bola e jogadores).
	var body := _static_body(root, _ground_physics)
	_box_shape(body, Vector3(0, -0.5, 0), Vector3(length + 20.0, 1.0, 60.0))


func _build_sidewalks(root: Node3D) -> void:
	var length := Field.STREET_HALF_LENGTH * 2.0
	var concrete := _surface("sidewalk", Color(0.62, 0.60, 0.56), 0.15, 0.45, 0.5)
	var curb := _surface("curb", Color(0.70, 0.69, 0.66), 0.1, 0.5, 0.2)
	var body := _static_body(root, _wall_physics)
	for side in [-1.0, 1.0]:
		var zc: float = side * (Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH * 0.5)
		var size := Vector3(length, Field.CURB_HEIGHT, Field.SIDEWALK_WIDTH)
		_mesh_box(root, Vector3(0, Field.CURB_HEIGHT * 0.5, zc), size, concrete)
		_mesh_box(root, Vector3(0, Field.CURB_HEIGHT * 0.5 + 0.002, side * (Field.ASPHALT_HALF_WIDTH + 0.06)),
			Vector3(length, Field.CURB_HEIGHT + 0.004, 0.12), curb)
		_box_shape(body, Vector3(0, Field.CURB_HEIGHT * 0.5, zc), size)


func _build_lines(root: Node3D) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = PAINT_SHADER
	var y := 0.004
	var t := 0.08
	var L := Field.HALF_LENGTH
	var W := Field.HALF_WIDTH
	for side in [-1.0, 1.0]:
		_mesh_box(root, Vector3(0, y, side * W), Vector3(L * 2.0 + t, 0.004, t), paint)   # laterais
		_mesh_box(root, Vector3(side * L, y, 0), Vector3(t, 0.004, W * 2.0 + t), paint)   # fundos
	_mesh_box(root, Vector3(0, y, 0), Vector3(t, 0.004, W * 2.0), paint)                   # meio
	_mesh_box(root, Vector3(0, y, 0), Vector3(0.3, 0.004, 0.3), paint)                     # marca central


# --- Casas e muros ------------------------------------------------------------

## side = -1 (fundo da tela, casas altas) ou +1 (lado da câmera, muros baixos).
func _build_houses(root: Node3D, side: float, tall: bool) -> void:
	var front_z := side * (Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH)
	var x := -Field.STREET_HALF_LENGTH
	var body := _static_body(root, _wall_physics)
	var low_wall := _surface("block_wall", Color(0.58, 0.57, 0.55), 0.18, 0.5, 0.15, 0.6)
	var roof := _surface("roof", Color(0.55, 0.27, 0.18), 0.15, 0.3, 0.0)
	var dark := _flat_mat(Color(0.08, 0.08, 0.09), 0.4)
	while x < Field.STREET_HALF_LENGTH:
		var w := _rng.randf_range(6.0, 9.5)
		w = minf(w, Field.STREET_HALF_LENGTH - x)
		if w < 2.0:
			break
		var cx := x + w * 0.5
		var color := WALL_COLORS[_rng.randi_range(0, WALL_COLORS.size() - 1)]
		var wall_mat := _surface("wall_%d" % color.to_rgba32(), color, 0.12, 0.4, 0.08, 0.5)
		if tall:
			var h := _rng.randf_range(2.9, 3.4) * (2.0 if _rng.randf() < 0.35 else 1.0)
			var depth := 6.0
			var zc := front_z + side * depth * 0.5
			_mesh_box(root, Vector3(cx, h * 0.5, zc), Vector3(w - 0.1, h, depth), wall_mat)
			_box_shape(body, Vector3(cx, h * 0.5, zc), Vector3(w - 0.1, h, depth))
			_mesh_box(root, Vector3(cx, h + 0.08, zc - side * 0.3), Vector3(w + 0.2, 0.16, depth + 0.8), roof)
			# Portão de garagem e janela.
			var gx := cx + _rng.randf_range(-w * 0.25, w * 0.25)
			var gate := _flat_mat(GATE_COLORS[_rng.randi_range(0, GATE_COLORS.size() - 1)], 0.6, 0.4)
			_mesh_box(root, Vector3(gx, 1.1, front_z + side * -0.03), Vector3(2.6, 2.2, 0.08), gate)
			var wx := cx + (w * 0.3 if gx < cx else -w * 0.3)
			_mesh_box(root, Vector3(wx, 1.6, front_z + side * -0.02), Vector3(1.2, 1.0, 0.05), dark)
			if h > 4.0:
				_mesh_box(root, Vector3(cx, 4.6, front_z + side * -0.02), Vector3(1.4, 1.0, 0.05), dark)
		else:
			# Lado da câmera: muro baixo na calçada + casa recuada e baixa.
			var mh := _rng.randf_range(1.5, 2.0)
			_mesh_box(root, Vector3(cx, mh * 0.5, front_z + side * 0.1), Vector3(w - 0.05, mh, 0.2), low_wall)
			_box_shape(body, Vector3(cx, mh * 0.5, front_z + side * 0.1), Vector3(w - 0.05, mh, 0.2))
			var hz := front_z + side * 5.0
			_mesh_box(root, Vector3(cx, 1.4, hz), Vector3(w - 1.0, 2.8, 5.0), wall_mat)
			_mesh_box(root, Vector3(cx, 2.88, hz), Vector3(w - 0.6, 0.16, 5.6), roof)
			var gate2 := _flat_mat(GATE_COLORS[_rng.randi_range(0, GATE_COLORS.size() - 1)], 0.6, 0.4)
			_mesh_box(root, Vector3(cx + _rng.randf_range(-1.5, 1.5), 0.85, front_z + side * 0.1),
				Vector3(1.4, 1.7, 0.24), gate2)
		x += w


func _build_street_ends(root: Node3D) -> void:
	# Casas atravessadas no fim da rua (esquina em T) seguram a bola.
	var body := _static_body(root, _wall_physics)
	for side in [-1.0, 1.0]:
		var x: float = side * (Field.STREET_HALF_LENGTH + 0.6)
		var width := (Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH) * 2.0 + 0.4
		var color := WALL_COLORS[_rng.randi_range(0, WALL_COLORS.size() - 1)]
		var mat := _surface("end_%d" % color.to_rgba32(), color, 0.12, 0.4, 0.1, 0.5)
		_mesh_box(root, Vector3(x, 1.6, 0), Vector3(1.2, 3.2, width), mat)
		_box_shape(body, Vector3(x, 1.6, 0), Vector3(1.2, 3.2, width))


func _build_props(root: Node3D) -> void:
	var concrete := _surface("pole", Color(0.6, 0.6, 0.58), 0.1, 0.3, 0.1)
	var body := _static_body(root, _wall_physics)
	# Postes de luz de concreto nas calçadas.
	for p in [Vector2(-9.0, -1.0), Vector2(12.0, -1.0), Vector2(-24.0, 1.0), Vector2(24.0, 1.0)]:
		var z: float = p.y * (Field.ASPHALT_HALF_WIDTH + 0.35)
		var pos := Vector3(p.x, 3.5, z)
		_mesh_cylinder(root, pos, 0.11, 7.0, concrete)
		var shape := CylinderShape3D.new()
		shape.radius = 0.11
		shape.height = 7.0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		body.add_child(cs)
		_mesh_box(root, Vector3(p.x, 6.8, z - p.y * 0.7), Vector3(0.08, 0.08, 1.4), concrete)
	# Lixeira e tijolos soltos (poucos objetos, sem poluir).
	var bin := _flat_mat(Color(0.2, 0.35, 0.25), 0.7)
	var bin_pos := Vector3(7.5, Field.CURB_HEIGHT + 0.45, -(Field.ASPHALT_HALF_WIDTH + 1.2))
	_mesh_cylinder(root, bin_pos, 0.28, 0.9, bin)
	var brick := _flat_mat(Color(0.6, 0.3, 0.2), 0.9)
	for b in [Vector3(-16.5, 0.05, 3.0), Vector3(-16.2, 0.05, 3.2), Vector3(17.0, 0.05, -3.1)]:
		_mesh_box(root, b, Vector3(0.19, 0.09, 0.09), brick)


## Paredes invisíveis altas nas fachadas: a bola não voa para fora do mundo
## (bola no quintal do vizinho vira evento na Etapa 6).
func _build_boundary(root: Node3D) -> void:
	var body := _static_body(root, _wall_physics)
	body.name = "InvisibleBoundary"
	var face := Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH
	var h := 16.0
	for side in [-1.0, 1.0]:
		_box_shape(body, Vector3(0, h * 0.5, side * (face + 0.25)), Vector3(Field.STREET_HALF_LENGTH * 2.0 + 2.0, h, 0.5))
		_box_shape(body, Vector3(side * (Field.STREET_HALF_LENGTH + 0.25), h * 0.5, 0), Vector3(0.5, h, face * 2.0 + 1.0))


# --- Utilitários --------------------------------------------------------------

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


func _flat_mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%f" % [color.to_html(), roughness]
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


func _mesh_cylinder(root: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
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
