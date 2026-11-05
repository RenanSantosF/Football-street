class_name Pedestrians
extends Node3D
## Pessoas passando pelas calçadas. Andam com a animação de caminhada (passada
## casada com a velocidade), às vezes param para olhar o jogo e seguem.
## Por enquanto usam a mesma skin dos jogadores; outras pessoas virão depois
## (basta registrar novos corpos em HumanoidCharacter.BASES).

@export var count := 2
@export var ball_path: NodePath

var _walkers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _ball: Node3D


func _ready() -> void:
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	pass
