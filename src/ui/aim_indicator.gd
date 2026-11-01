class_name AimIndicator
extends Node3D
## Seta no chão mostrando a mira do chute enquanto o botão está segurado.
## O comprimento cresce com a força. Some ao soltar.

@export var human_input: HumanInput
@export var ball: Ball

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _active := false
var _dir := Vector3.FORWARD
var _power := 0.0


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.75)
	_mat.no_depth_test = false
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _build_arrow()
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false
	if human_input != null:
		human_input.aim_changed.connect(_on_aim_changed)


func _on_aim_changed(active: bool, direction: Vector3, power: float) -> void:
	_active = active
	_dir = Vector3(direction.x, 0.0, direction.z).normalized() if direction.length() > 0.01 else _dir
	_power = power
	visible = active


func _process(_delta: float) -> void:
	if not _active or ball == null:
		return
	global_position = Vector3(ball.global_position.x, 0.03, ball.global_position.z)
	rotation.y = atan2(-_dir.x, -_dir.z)
	var length := 1.2 + _power * 2.8
	_mesh.scale = Vector3(1.0, 1.0, length)
	_mat.albedo_color = Color(1.0, lerpf(0.85, 0.35, _power), 0.2, 0.75)


## Seta apontando para -Z, com 1 m de comprimento (escalada em Z).
func _build_arrow() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.09
	var head := 0.25
	var pts := [
		Vector3(-w, 0, -0.15), Vector3(w, 0, -0.15), Vector3(w, 0, -(1.0 - head)),
		Vector3(-w, 0, -0.15), Vector3(w, 0, -(1.0 - head)), Vector3(-w, 0, -(1.0 - head)),
		Vector3(-w * 2.6, 0, -(1.0 - head)), Vector3(w * 2.6, 0, -(1.0 - head)), Vector3(0, 0, -1.0),
	]
	for p in pts:
		st.set_normal(Vector3.UP)
		st.add_vertex(p)
	return st.commit()
