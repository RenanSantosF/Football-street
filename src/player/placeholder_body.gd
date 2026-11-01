class_name PlaceholderBody
extends Node3D
## Manequim PROVISÓRIO (Etapa 1) feito de primitivas, só para testar jogabilidade.
##
## Ele é estático de propósito: NÃO simulamos animação movendo partes por
## código. Na Etapa 2 este nó é substituído pelo modelo humanoide real com
## esqueleto + AnimationTree, mantendo a mesma interface apply_appearance().
## O modelo olha para -Z (padrão Godot).

static var _materials := {}


func apply_appearance(a: CharacterAppearance, _team: int, role: int) -> void:
	for c in get_children():
		c.queue_free()
	var skin := _mat(a.skin_color)
	var torso_col := a.shirt_color if a.has_shirt else a.skin_color
	# Goleiro com camisa usa cor diferente para destacar (comum na pelada).
	if role == Player.Role.GOALKEEPER and a.has_shirt:
		torso_col = Color(0.15, 0.15, 0.15)
	var torso := _mat(torso_col.lerp(Color(0.35, 0.3, 0.25), a.dirt * 0.25))
	var shorts := _mat(a.shorts_color.lerp(Color(0.3, 0.27, 0.22), a.dirt * 0.2))
	var shoes := _mat(a.shoes_color.lerp(Color(0.35, 0.32, 0.28), a.dirt * 0.5))
	var hair := _mat(a.hair_color)

	for side in [-1.0, 1.0]:
		_add_capsule(Vector3(0.1 * side, 0.27, 0.0), 0.065, 0.54, skin)       # canela
		_add_capsule(Vector3(0.1 * side, 0.62, 0.0), 0.085, 0.4, shorts)      # coxa/bermuda
		_add_box(Vector3(0.1 * side, 0.04, -0.04), Vector3(0.1, 0.08, 0.24), shoes)
		var arm_mat := torso if a.has_shirt else skin
		_add_capsule(Vector3(0.24 * side, 1.18, 0.0), 0.055, 0.3, arm_mat)    # braço
		_add_capsule(Vector3(0.25 * side, 0.92, 0.0), 0.045, 0.3, skin)       # antebraço
	_add_capsule(Vector3(0.0, 1.12, 0.0), 0.17, 0.56, torso)                  # tronco
	_add_capsule(Vector3(0.0, 1.41, 0.0), 0.05, 0.12, skin)                   # pescoço
	_add_sphere(Vector3(0.0, 1.55, 0.0), 0.11, skin)                          # cabeça
	_add_box(Vector3(0.0, 1.54, -0.105), Vector3(0.03, 0.04, 0.04), skin)    # nariz (frente)
	var hair_h := [0.05, 0.08, 0.03, 0.1, 0.06][a.hair_style % 5] as float
	var cap := _add_sphere(Vector3(0.0, 1.6, 0.012), 0.115, hair)
	cap.scale = Vector3(1.0, 0.55 + hair_h * 3.0, 1.0)


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_materials[key] = m
	return _materials[key]


func _add_capsule(pos: Vector3, radius: float, height: float, m: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 10
	mesh.rings = 3
	return _add(mesh, pos, m)


func _add_sphere(pos: Vector3, radius: float, m: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add(mesh, pos, m)


func _add_box(pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, pos, m)


func _add(mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi
