extends Node
## Áudio numa partida IA x IA (rodar no PC):
##   godot --headless --path . res://tests/audio_test.tscn --fixed-fps 60
## Confere que os bancos de som carregaram e conta quantos sons de cada tipo
## tocaram por minuto (toques, chutes, quiques, passos, corpo, apito...).
const MAIN := preload("res://src/main/main.tscn")
const SECONDS := 60.0
var _mm: MatchManager
var _t := 0.0


func _ready() -> void:
	var main := MAIN.instantiate()
	_mm = main.get_node("MatchManager")
	_mm.autoplay = true
	_mm.match_seed = 4242
	add_child(main)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < SECONDS:
		return
	var ga := _mm.get_node("GameAudio") as GameAudio
	var missing := []
	for b in GameAudio.BANKS:
		if not ga.has_bank(b):
			missing.append(b)
	var per_min := {}
	for k in ga.stats:
		per_min[k] = snappedf(ga.stats[k] * 60.0 / SECONDS, 0.1)
	print("BANCOS_FALTANDO: ", missing)
	print("SONS_POR_MINUTO: ", per_min)
	print("RESULTADOS: ", {"bancos_ok": missing.is_empty(), "tem_passos": ga.stats.get(&"step_run", 0) + ga.stats.get(&"step_walk", 0) > 50,
		"tem_toques": ga.stats.get(&"kick_soft", 0) > 20, "tem_chutes": ga.stats.get(&"kick_pass", 0) + ga.stats.get(&"kick_strong", 0) > 3,
		"tem_quiques": ga.stats.get(&"bounce", 0) + ga.stats.get(&"curb", 0) + ga.stats.get(&"wood", 0) + ga.stats.get(&"wire", 0) + ga.stats.get(&"brick", 0) > 0})
	get_tree().quit()
