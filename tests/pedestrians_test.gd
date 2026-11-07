extends Node
## Pedestres nas calçadas (rodar no PC):
##   godot --headless --path . res://tests/pedestrians_test.tscn --fixed-fps 60
## Nascem, andam na calçada (z e altura certos), o pé apoia na calçada (nem
## afunda nem flutua), a passada acompanha a velocidade, fazem barulho de
## passo e somem no fim da rua.
const MAIN := preload("res://src/main/main.tscn")
var _mm: MatchManager
var _peds: Pedestrians
var _t := 0.0
var _foot_min := INF
var _foot_samples := 0
var _max_n := 0
var _on_walk := true
var _seen_kid := false
var _seen_adult := false
var _steps0 := 0


func _ready() -> void:
	var main := MAIN.instantiate()
	_mm = main.get_node("MatchManager")
	_mm.autoplay = true
	add_child(main)
	_peds = main.get_node("Pedestrians")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > 0.5 and _t < 0.52:
		_peds._spawn_group()
		_peds._spawn_group()
		_peds._spawn_group()
		var ga := _mm.get_node("GameAudio") as GameAudio
		_steps0 = int(ga.stats.get(&"step_walk", 0)) + int(ga.stats.get(&"step_run", 0))
	for w in _peds._walkers:
		var root: Node3D = w["node"]
		var vis: HumanoidCharacter = w["vis"]
		if w["kid"]:
			_seen_kid = true
		else:
			_seen_adult = true
		if absf(absf(root.global_position.z) - Pedestrians.SIDEWALK_Z) > 0.6:
			_on_walk = false
		if float(w["cur"]) > 0.5:
			for s in [1.0, -1.0]:
				var y: float = vis.get_ankle_position(s).y - Field.CURB_HEIGHT
				_foot_min = minf(_foot_min, y)
				_foot_samples += 1
	_max_n = maxi(_max_n, _peds._walkers.size())
	if _t > 40.0:
		var ga := _mm.get_node("GameAudio") as GameAudio
		print("RESULTADOS: ", {"nasceram": _max_n, "na_calcada": _on_walk, "crianca": _seen_kid, "adulto": _seen_adult,
			"tornozelo_min_acima_calcada_m": snappedf(_foot_min, 0.001),
			"pe_apoia_na_calcada": _foot_min > 0.02 and _foot_min < 0.14,
			"passos_tocados": int(ga.stats.get(&"step_walk", 0)) + int(ga.stats.get(&"step_run", 0)) - _steps0,
			"sairam_da_rua": _peds._walkers.size() <= 3})
		get_tree().quit()
