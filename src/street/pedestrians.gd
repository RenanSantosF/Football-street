class_name Pedestrians
extends Node3D
## Pessoas passando pelas calçadas. Andam com a animação de caminhada (passada
## casada com a velocidade), às vezes param para olhar o jogo e seguem.
## Por enquanto usam a mesma skin dos jogadores; outras pessoas virão depois
## (basta registrar novos corpos em HumanoidCharacter.BASES).

@export var count := 4
@export var ball_path: NodePath

var _walkers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _ball: Node3D


func _ready() -> void:
	_rng.randomize()
	_ball = get_node_or_null(ball_path)
	for i in count:
		var c := HumanoidCharacter.new()
		add_child(c)
		c.apply_appearance(CharacterAppearance.new(), 0, 0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := side * (Field.ASPHALT_HALF_WIDTH + _rng.randf_range(0.8, 1.5))
		var x := _rng.randf_range(-Field.STREET_HALF_LENGTH + 3.0, Field.STREET_HALF_LENGTH - 3.0)
		c.position = Vector3(x, Field.CURB_HEIGHT, z)
		_walkers.append({
			"node": c, "dir": 1.0 if _rng.randf() > 0.5 else -1.0,
			"speed": _rng.randf_range(1.0, 1.35), "stop": 0.0,
			"next_stop": _rng.randf_range(6.0, 16.0), "side": side,
		})


func _physics_process(delta: float) -> void:
	for w in _walkers:
		var c: HumanoidCharacter = w["node"]
		var speed := 0.0
		if w["stop"] > 0.0:
			w["stop"] -= delta
			# Parado: olha para o jogo (para a bola).
			if _ball != null:
				var to := _ball.global_position - c.global_position
				c.rotation.y = lerp_angle(c.rotation.y, atan2(to.x, to.z) + PI, delta * 2.0)
		else:
			speed = w["speed"]
			c.position.x += w["dir"] * speed * delta
			c.rotation.y = lerp_angle(c.rotation.y, PI * 0.5 * -w["dir"] + PI, delta * 4.0)
			if absf(c.position.x) > Field.STREET_HALF_LENGTH - 2.0:
				w["dir"] = -signf(c.position.x)
			w["next_stop"] -= delta
			if w["next_stop"] <= 0.0:
				w["stop"] = _rng.randf_range(2.5, 6.0)
				w["next_stop"] = _rng.randf_range(8.0, 20.0)
		if c.anim_tree != null:
			var stride := speed / maxf(c.get_locomotion_scale(), 0.01)
			c.anim_tree.set("parameters/Locomotion/Speed/blend_position", stride)
