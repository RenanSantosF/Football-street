@tool
class_name GoalController
extends Node3D
## Trave pequena de ferro, velha e sem rede (como na rua: a bola passa direto
## e alguém tem que ir buscar). Gera a geometria e as colisões das barras e
## detecta o gol pela travessia matemática da linha (confiável mesmo com
## chutes rápidos, sem depender de Area3D).
##
## O nó fica sobre a linha de fundo; a estrutura se estende para fora do campo.

## Time que defende esta trave.
@export var defending_team := Team.SHIRTS:
	set(value):
		defending_team = value
		if is_inside_tree():
			_build()

const IRON_SHADER := preload("res://src/shaders/old_iron.gdshader")

static var _iron_material: ShaderMaterial
static var _iron_physics: PhysicsMaterial


func _ready() -> void:
	_build()


## +1 se "fora do campo" é +X a partir desta trave, -1 se é -X.
func outward_sign() -> float:
	return -Field.attack_sign(defending_team)


## Verdadeiro se a bola cruzou totalmente a linha entre as traves e sob o travessão.
func check_goal(prev: Vector3, cur: Vector3) -> bool:
	var s := outward_sign()
	var line_x := global_position.x
	var prev_d := (prev.x - line_x) * s
	var cur_d := (cur.x - line_x) * s
	if prev_d >= Ball.RADIUS or cur_d < Ball.RADIUS:
		return false
	var t := (Ball.RADIUS - prev_d) / maxf(cur_d - prev_d, 0.0001)
	var p := prev.lerp(cur, t)
	return absf(p.z - global_position.z) < Field.GOAL_HALF_WIDTH - Field.POST_RADIUS \
		and p.y < Field.GOAL_HEIGHT - Field.POST_RADIUS


func _build() -> void:
	for c in get_children():
		c.free()
	if _iron_material == null:
		_iron_material = ShaderMaterial.new()
		_iron_material.shader = IRON_SHADER
		_iron_physics = PhysicsMaterial.new()
		_iron_physics.bounce = 0.25
		_iron_physics.friction = 0.4
	var s := outward_sign()
	var w := Field.GOAL_HALF_WIDTH
	var h := Field.GOAL_HEIGHT
	var dp := Field.GOAL_DEPTH
	var r := Field.POST_RADIUS
	var body := StaticBody3D.new()
	body.name = "Frame"
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = _iron_physics
	add_child(body)
	# Postes e travessão.
	_bar(body, Vector3(0, h * 0.5, -w), h, Vector3.ZERO, r)
	_bar(body, Vector3(0, h * 0.5, w), h, Vector3.ZERO, r)
	_bar(body, Vector3(0, h, 0), w * 2.0 + r * 2.0, Vector3(90, 0, 0), r)
	# Base no chão (atrás da linha) e laterais inclinadas, como trave de rua soldada.
	_bar(body, Vector3(s * dp, r, 0), w * 2.0, Vector3(90, 0, 0), r * 0.8)
	for side in [-1.0, 1.0]:
		_bar(body, Vector3(s * dp * 0.5, r, side * w), dp, Vector3(0, 0, 90), r * 0.8)
		var bar_len := sqrt(dp * dp + h * h)
		var ang := rad_to_deg(atan2(dp, h)) * s
		_bar(body, Vector3(s * dp * 0.5, h * 0.5, side * w), bar_len, Vector3(0, 0, ang), r * 0.8)


func _bar(body: StaticBody3D, pos: Vector3, length: float, rot_deg: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _iron_material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	body.add_child(mi)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(radius, 0.085)
	shape.height = length
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	cs.rotation_degrees = rot_deg
	cs.set_meta("surface", "post")
	body.add_child(cs)
