class_name LeanModifier
extends SkeletonModifier3D
## Postura na corrida: traz o tronco e a cabeça um pouquinho para trás
## (os clipes de corrida inclinam demais o corpo e a cabeça fica muito à frente).
## [member amount] 0..1 vem da velocidade (PlayerAnimationController).

var amount := 0.0
const SPINE_DEG := 4.0
const HEAD_DEG := 5.0

var _spine := -2
var _head := -2


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or amount <= 0.001:
		return
	if _spine == -2:
		_spine = sk.find_bone("Spine")
		_head = sk.find_bone("Head")
	# (modelo olha para +Z no espaço do esqueleto: girar em X negativo = para trás)
	_tilt(sk, _spine, -deg_to_rad(SPINE_DEG) * amount)
	_tilt(sk, _head, -deg_to_rad(HEAD_DEG) * amount)


func _tilt(sk: Skeleton3D, bone: int, ang: float) -> void:
	if bone < 0:
		return
	var gp := sk.get_bone_global_pose(bone)
	gp.basis = Basis(Vector3.RIGHT, ang) * gp.basis
	sk.set_bone_global_pose(bone, gp)
