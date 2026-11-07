class_name Pedestrians
extends Node3D
## Pessoas passando pelas CALÇADAS (Etapa 27): adultos andando e crianças
## correndo (às vezes em dupla, conversando e rindo). Usam o mesmo corpo e as
## mesmas passadas dos jogadores (escala de adulto ou de criança), com a
## cadência casada com a velocidade. Às vezes um adulto para um pouco para
## olhar o jogo. Passos e vozes são posicionais (GameAudio).
## Só visual: não colidem com a bola nem com os jogadores.

@export var max_walkers := 3
@export var ball_path: NodePath

const SIDEWALK_Z := Field.ASPHALT_HALF_WIDTH + Field.SIDEWALK_WIDTH * 0.55
const END_X := Field.STREET_HALF_LENGTH + 3.0

var _walkers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _ball: Node3D
var _spawn_timer := 3.0


func _ready() -> void:
	_rng.randomize()
	if ball_path != NodePath(""):
		_ball = get_node_or_null(ball_path) as Node3D
	if _ball == null:
		_ball = get_tree().get_first_node_in_group("ball") as Node3D


func _audio() -> GameAudio:
	return get_tree().get_first_node_in_group("game_audio") as GameAudio


func _physics_process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _rng.randf_range(7.0, 18.0)
		if _walkers.size() < max_walkers:
			_spawn_group()
	for i in range(_walkers.size() - 1, -1, -1):
		var w: Dictionary = _walkers[i]
		if not _update_walker(w, delta):
			(w["node"] as Node3D).queue_free()
			_walkers.remove_at(i)


func _spawn_group() -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var dir := -1.0 if _rng.randf() < 0.5 else 1.0
	var kids := _rng.randf() < 0.45
	var n := 1
	if kids and _rng.randf() < 0.55 and _walkers.size() + 1 < max_walkers:
		n = 2
	var speed := _rng.randf_range(2.5, 3.3) if kids else _rng.randf_range(1.15, 1.45)
	for k in n:
		var lane := side * (SIDEWALK_Z + (0.35 if k == 1 else -0.1) * side * _rng.randf_range(0.6, 1.0))
		_spawn(kids, Vector3(-dir * (END_X + k * _rng.randf_range(0.6, 1.2)), Field.CURB_HEIGHT, lane), dir,
			speed * _rng.randf_range(0.96, 1.04))


func _spawn(kid: bool, pos: Vector3, dir: float, speed: float) -> void:
	var root := Node3D.new()
	root.name = "Kid" if kid else "Walker"
	add_child(root)
	root.global_position = pos
	var vis := HumanoidCharacter.new()
	vis.name = "Visual"
	root.add_child(vis)
	var a := CharacterAppearance.random_for_team(Team.SHIRTS if _rng.randf() < 0.6 else Team.SKINS, _rng)
	vis.apply_appearance(a, Team.SHIRTS, 0)
	# criança ~1,25–1,40 m; adulto ~1,72–1,85 m (o corpo base tem 1,64 m)
	var s := _rng.randf_range(0.76, 0.85) if kid else _rng.randf_range(1.05, 1.13)
	vis.scale = Vector3.ONE * s
	var face := Vector3(dir, 0.0, 0.0)
	root.rotation.y = atan2(-face.x, -face.z)
	if vis.lean != null:
		vis.set_motion_style(_rng.randf_range(0.8, 1.0), _rng.randf_range(-2.0, 2.0))
	_walkers.append({
		"node": root, "vis": vis, "kid": kid, "dir": dir, "speed": speed, "cur": 0.0,
		"stop_at": _rng.randf_range(-6.0, 6.0) if (not kid and _rng.randf() < 0.3) else INF,
		"stop_t": 0.0, "stopped": false, "voice_t": _rng.randf_range(0.5, 2.5),
		"feet": {}, "blend": 0.0,
	})


## Anda (ou para olhando o jogo). Devolve false quando saiu da rua.
func _update_walker(w: Dictionary, delta: float) -> bool:
	var root: Node3D = w["node"]
	var vis: HumanoidCharacter = w["vis"]
	var dir: float = w["dir"]
	var want: float = w["speed"]
	var x := root.global_position.x
	# parar um pouco para olhar o jogo (só adultos)
	if not w["stopped"] and float(w["stop_at"]) < INF and absf(x - float(w["stop_at"])) < 0.3:
		w["stopped"] = true
		w["stop_t"] = _rng.randf_range(3.0, 6.0)
	if w["stopped"]:
		w["stop_t"] = float(w["stop_t"]) - delta
		want = 0.0
		if float(w["stop_t"]) <= 0.0:
			w["stopped"] = false
			w["stop_at"] = INF
	# aceleração humana (sem arrancar/parar seco)
	var cur: float = move_toward(float(w["cur"]), want, (2.2 if want > float(w["cur"]) else 2.8) * delta)
	w["cur"] = cur
	root.global_position.x += dir * cur * delta
	# olha o jogo quando passa perto / parado
	if _ball != null and vis.lean != null:
		var to_b := _ball.global_position - root.global_position
		var look := 0.75 if w["stopped"] else (0.35 if absf(to_b.x) < 8.0 else 0.0)
		vis.set_ball_gaze(_ball.global_position, look)
	# passada casada com a velocidade (mesmo BlendSpace dos jogadores)
	if vis.anim_tree != null:
		var k := maxf(vis.get_locomotion_scale(), 0.05)
		var x_bl: float = lerpf(float(w["blend"]), cur / k, 1.0 - exp(-10.0 * delta))
		w["blend"] = x_bl
		vis.anim_tree.set("parameters/Locomotion/Speed/blend_position", Vector2(x_bl, 0.0))
		vis.anim_tree.set("parameters/Locomotion/Scale/scale", AnimationCatalog.loco_cycle_mult(x_bl))
	_footsteps(w, delta)
	_voices(w, delta)
	return absf(root.global_position.x) < END_X + 3.0


func _footsteps(w: Dictionary, delta: float) -> void:
	var vis: HumanoidCharacter = w["vis"]
	var root: Node3D = w["node"]
	var cur: float = w["cur"]
	var st: Dictionary = w["feet"]
	var audio := _audio()
	for s in [1.0, -1.0]:
		var y: float = vis.get_ankle_position(s).y - root.global_position.y
		var kmin := "min%d" % int(s)
		var kdn := "dn%d" % int(s)
		var ymin: float = st.get(kmin, y)
		ymin = minf(ymin + delta * 0.02, y)
		var down: bool = st.get(kdn, true)
		if not down and y < ymin + 0.02 and cur > 0.3:
			down = true
			if audio != null:
				var kid: bool = w["kid"]
				var p := vis.get_ankle_position(s)
				var db := (-17.0 if kid else -21.0) + _rng.randf_range(-1.5, 1.5)
				audio.play(&"step_run" if kid else &"step_walk", p, db, _rng.randf_range(1.08, 1.2) if kid else _rng.randf_range(0.9, 1.0))
		elif down and y > ymin + 0.05:
			down = false
		st[kmin] = ymin
		st[kdn] = down
	w["feet"] = st


## Crianças conversando/rindo enquanto passam.
func _voices(w: Dictionary, delta: float) -> void:
	if not w["kid"]:
		return
	w["voice_t"] = float(w["voice_t"]) - delta
	if float(w["voice_t"]) > 0.0:
		return
	w["voice_t"] = _rng.randf_range(2.5, 6.0)
	var audio := _audio()
	if audio == null:
		return
	var root: Node3D = w["node"]
	var pos := root.global_position + Vector3.UP * 1.2
	if _rng.randf() < 0.6:
		audio.play(&"kid", pos, -12.0, _rng.randf_range(0.98, 1.08))
	else:
		audio.play(&"giggle", pos, -13.0, _rng.randf_range(1.0, 1.12))
