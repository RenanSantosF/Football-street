class_name GameAudio
extends Node
## SONS do jogo (Etapa 27). Tudo posicional (3D) a partir da câmera, com
## atenuação pela distância, perda de agudos com a distância (ar) e um pouco
## de reverberação de rua (casas e muros dos dois lados).
##
## Fontes (assets/audio, ver tools/audio/build_sfx.py e CREDITS.md):
##  - bola: sintetizada por modelo físico (tempo de contato + modos da bola);
##  - passos, quedas, vozes, ambiência: gravações reais CC0/CC-BY;
##  - apito: sintetizado (tom com trinado da bolinha).
##
## Eventos:
##  - toque/chute: GameEvents.ball_kicked e Player.ball_touched — volume e
##    timbre pela variação de velocidade da bola (Ball.last_touch_dv);
##  - quique/batida: Ball.impact (chão, meio-fio, madeira, alambrado, ferro,
##    muro, trave);
##  - bola rolando: loop contínuo, volume e tom pela velocidade;
##  - passos: pé chegando ao chão na pose FINAL do esqueleto (casa com a
##    animação), andar/correr pela velocidade; derrapada em freada brusca;
##  - corpo: trombada, queda, carrinho, pouso do pulo;
##  - apito: falta, saída; torcida dos vizinhos no gol; ambiência da rua.

const DIR := "res://assets/audio/"
const POOL := 24
## nome do banco -> [prefixo, quantidade]
const BANKS := {
	&"kick_soft": ["ball/kick_soft_", 8], &"kick_pass": ["ball/kick_pass_", 8],
	&"kick_strong": ["ball/kick_strong_", 6], &"bounce": ["ball/bounce_", 8],
	&"curb": ["ball/curb_", 4], &"brick": ["ball/brick_", 4], &"wood": ["ball/wood_", 4],
	&"wire": ["ball/wire_", 4], &"iron": ["ball/iron_", 3], &"post": ["ball/post_", 4],
	&"ball_body": ["ball/body_", 5], &"ball_head": ["ball/head_", 4],
	&"step_run": ["steps/run_", 6], &"step_walk": ["steps/walk_", 12], &"scuff": ["steps/scuff_", 6],
	&"fall": ["body/fall_", 5], &"land": ["body/land_", 1], &"slide": ["body/slide_", 3],
	&"kid": ["voices/kid_", 3], &"giggle": ["voices/giggle_", 2], &"cheer": ["voices/cheer_", 2],
}
const SINGLES := {
	&"whistle_short": "whistle/short", &"whistle_long": "whistle/long",
	&"whistle_double": "whistle/double", &"whistle_final": "whistle/final",
	&"roll": "ball/roll_loop", &"ambience": "ambience/street_day",
}

var match_manager: MatchManager
var enabled := true

var _banks := {}
var _single := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _last_pick := {}
var _rng := RandomNumberGenerator.new()
var _roll: AudioStreamPlayer3D
var _ambience: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _feet := {}
var _prev_vel := {}
var _scuff_cd := {}
var _delayed: Array = []
## Contagem de sons tocados por banco (diagnóstico/testes).
var stats := {}


func _ready() -> void:
	add_to_group(&"game_audio")
	_rng.randomize()
	_setup_buses()
	_load_banks()
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 6.0
		p.max_db = 4.0
		p.max_distance = 70.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 6500.0
		p.attenuation_filter_db = -14.0
		p.panning_strength = 0.7
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_pool.append(p)
	_roll = AudioStreamPlayer3D.new()
	_roll.bus = &"SFX"
	_roll.unit_size = 5.0
	_roll.volume_db = -60.0
	_roll.attenuation_filter_cutoff_hz = 5000.0
	_roll.panning_strength = 0.7
	add_child(_roll)
	if _single.has(&"roll"):
		var rs: AudioStream = _single[&"roll"]
		_set_loop(rs)
		_roll.stream = rs
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	_ambience.volume_db = -15.0
	add_child(_ambience)
	if _single.has(&"ambience"):
		var a: AudioStream = _single[&"ambience"]
		_set_loop(a)
		_ambience.stream = a
		_ambience.play()
	_ui = AudioStreamPlayer.new()
	_ui.bus = &"SFX"
	add_child(_ui)
	GameEvents.ball_kicked.connect(_on_ball_kicked)
	GameEvents.goal_scored.connect(_on_goal)
	GameEvents.foul_called.connect(func(_p): _play_2d(&"whistle_short", -8.0))
	GameEvents.body_contact.connect(_on_body_contact)
	GameEvents.match_state_changed.connect(_on_state)
	if match_manager != null:
		if match_manager.ball != null:
			match_manager.ball.impact.connect(_on_ball_impact)
		for p in match_manager.players:
			p.ball_touched.connect(_on_touch.bind(p))
			p.action_started.connect(_on_action.bind(p))


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


## Barramentos: SFX (reverberação curta de rua + compressão leve),
## Ambience, e um limitador no Master (sem estourar no celular).
func _setup_buses() -> void:
	if AudioServer.get_bus_index(&"SFX") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, &"SFX")
		AudioServer.set_bus_send(i, &"Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.28
		rv.damping = 0.55
		rv.spread = 0.6
		rv.hipass = 0.25
		rv.dry = 1.0
		rv.wet = 0.09
		rv.predelay_msec = 22.0
		rv.predelay_feedback = 0.2
		AudioServer.add_bus_effect(i, rv)
		var cp := AudioEffectCompressor.new()
		cp.threshold = -14.0
		cp.ratio = 3.0
		cp.attack_us = 2000.0
		cp.release_ms = 120.0
		AudioServer.add_bus_effect(i, cp)
	if AudioServer.get_bus_index(&"Ambience") < 0:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, &"Ambience")
		AudioServer.set_bus_send(j, &"Master")
	var m := AudioServer.get_bus_index(&"Master")
	if AudioServer.get_bus_effect_count(m) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.5
		lim.threshold_db = -2.0
		AudioServer.add_bus_effect(m, lim)


func _load_banks() -> void:
	for b in BANKS:
		var spec: Array = BANKS[b]
		var arr: Array[AudioStream] = []
		for k in int(spec[1]):
			var path := DIR + "%s%02d.ogg" % [spec[0], k + 1]
			if ResourceLoader.exists(path):
				var s := load(path) as AudioStream
				if s != null:
					arr.append(s)
		if not arr.is_empty():
			_banks[b] = arr
	for n in SINGLES:
		var path: String = DIR + SINGLES[n] + ".ogg"
		if ResourceLoader.exists(path):
			_single[n] = load(path)


func has_bank(b: StringName) -> bool:
	return _banks.has(b)


## Toca um som do banco [param bank] em [param pos].
func play(bank: StringName, pos: Vector3, db: float, pitch := 1.0) -> AudioStreamPlayer3D:
	stats[bank] = int(stats.get(bank, 0)) + 1
	if not enabled or not _banks.has(bank):
		return null
	var arr: Array = _banks[bank]
	# nunca repete o mesmo arquivo duas vezes seguidas
	var i := _rng.randi() % arr.size()
	if arr.size() > 1 and _last_pick.get(bank, -1) == i:
		i = (i + 1 + _rng.randi() % (arr.size() - 1)) % arr.size()
	_last_pick[bank] = i
	return _play_stream(arr[i], pos, db, pitch)


func _play_stream(s: AudioStream, pos: Vector3, db: float, pitch: float) -> AudioStreamPlayer3D:
	var p := _free_player()
	p.stream = s
	p.global_position = pos
	p.volume_db = db
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()
	return p


func _free_player() -> AudioStreamPlayer3D:
	for k in POOL:
		var p := _pool[(_pool_i + k) % POOL]
		if not p.playing:
			_pool_i = (_pool_i + k + 1) % POOL
			return p
	# todos ocupados: rouba o mais antigo (round-robin)
	var q := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	return q


func _play_2d(name: StringName, db: float) -> void:
	stats[name] = int(stats.get(name, 0)) + 1
	if not enabled:
		return
	var s: AudioStream = _single.get(name, null)
	if s == null and _banks.has(name):
		var arr: Array = _banks[name]
		s = arr[_rng.randi() % arr.size()]
	if s == null:
		return
	_ui.stream = s
	_ui.volume_db = db
	_ui.play()


# --- Bola ------------------------------------------------------------------------

func _ball_pos() -> Vector3:
	return match_manager.ball.global_position if match_manager != null and match_manager.ball != null else Vector3.ZERO


func _on_ball_kicked(_kicker: Node, kind: StringName, power: float) -> void:
	var dv := match_manager.ball.last_touch_dv if match_manager != null else 10.0
	var bank := &"kick_pass"
	var db := lerpf(-6.0, 0.0, clampf(power, 0.0, 1.0))
	var pitch := _rng.randf_range(0.95, 1.06)
	if kind in [&"shoot", &"shoot_power", &"chip", &"volley"] or dv > 17.0:
		bank = &"kick_strong"
		db = lerpf(-3.0, 2.0, clampf((dv - 12.0) / 14.0, 0.0, 1.0))
		pitch = _rng.randf_range(0.92, 1.02)
	elif dv < 6.5:
		bank = &"kick_soft"
		db = lerpf(-12.0, -5.0, clampf(dv / 6.5, 0.0, 1.0))
	elif kind == &"tackle":
		bank = &"kick_soft"
		db = -4.0
	play(bank, _ball_pos(), db, pitch)


func _on_touch(kind: StringName, p: Player) -> void:
	if kind in [&"pass", &"shoot"]:
		return # o ball_kicked já tocou
	var dv := match_manager.ball.last_touch_dv
	var pos := _ball_pos()
	match kind:
		&"body":
			play(&"ball_body", pos, lerpf(-14.0, -4.0, clampf(dv / 8.0, 0.0, 1.0)), _rng.randf_range(0.9, 1.08))
		&"header":
			play(&"ball_head", pos, lerpf(-8.0, 0.0, clampf(dv / 10.0, 0.0, 1.0)), _rng.randf_range(0.95, 1.05))
		&"receive_air":
			play(&"ball_body", pos, lerpf(-12.0, -4.0, clampf(dv / 8.0, 0.0, 1.0)), _rng.randf_range(0.95, 1.1))
		&"drag", &"trap":
			# sola na bola: toque abafado e curto
			play(&"kick_soft", pos, lerpf(-20.0, -12.0, clampf(dv / 3.0, 0.0, 1.0)), _rng.randf_range(0.8, 0.9))
		_:
			# condução, domínio, toque de lado, interceptação, desarme
			var db := lerpf(-18.0, -6.0, clampf(dv / 6.0, 0.0, 1.0))
			if kind in [&"tackle", &"intercept", &"slide"]:
				db = maxf(db, -9.0)
			play(&"kick_soft", pos, db, _rng.randf_range(0.93, 1.08))
	if p == null:
		return


func _on_ball_impact(pos: Vector3, strength: float, surface: StringName) -> void:
	var k := clampf((strength - 0.6) / 9.0, 0.0, 1.0)
	match surface:
		&"post":
			play(&"post", pos, lerpf(-8.0, 3.0, k), _rng.randf_range(0.97, 1.03))
		&"iron":
			play(&"iron", pos, lerpf(-10.0, 1.0, k))
		&"wire":
			play(&"wire", pos, lerpf(-12.0, -1.0, k))
		&"wood":
			play(&"wood", pos, lerpf(-10.0, 0.0, k))
		&"brick":
			play(&"brick", pos, lerpf(-10.0, 0.0, k))
		&"curb":
			play(&"curb", pos, lerpf(-14.0, -2.0, k))
		_:
			play(&"bounce", pos, lerpf(-18.0, -2.0, k), _rng.randf_range(0.96, 1.05))


func _on_goal(_team: int, _scorer: Node) -> void:
	_play_2d(&"cheer", -9.0)
	_delay(0.6, func(): play(&"giggle", _ball_pos() + Vector3(0, 0, 6), -14.0))


func _on_state(s: int) -> void:
	if s == MatchManager.MatchState.KICKOFF:
		_delay(0.4, func(): _play_2d(&"whistle_long", -9.0))


# --- Corpo -----------------------------------------------------------------------

func _on_action(kind: StringName, p: Player) -> void:
	match kind:
		&"slide":
			play(&"slide", p.global_position, -5.0, _rng.randf_range(0.92, 1.05))
		&"trip":
			# o corpo chega ao chão um pouco depois do tropeço
			_delay(0.42, func(): play(&"fall", p.global_position, -3.0, _rng.randf_range(0.9, 1.05)))
		&"jump":
			_delay(maxf(p.action_time_left() - 0.05, 0.3), func(): play(&"land", p.global_position, -8.0))
		&"stumble":
			play(&"scuff", p.global_position, -12.0, _rng.randf_range(0.9, 1.05))


func _on_body_contact(p: Node, strength: float) -> void:
	var pl := p as Player
	if pl == null or strength < 1.3:
		return # encostos leves não fazem barulho
	var db := lerpf(-18.0, -6.0, clampf((strength - 1.3) / 3.0, 0.0, 1.0))
	play(&"fall", pl.global_position + Vector3.UP, db, _rng.randf_range(1.15, 1.35))


func _delay(t: float, f: Callable) -> void:
	_delayed.append([t, f])


# --- Por quadro: passos, derrapadas, bola rolando ------------------------------------

func _physics_process(delta: float) -> void:
	for i in range(_delayed.size() - 1, -1, -1):
		_delayed[i][0] -= delta
		if _delayed[i][0] <= 0.0:
			var f: Callable = _delayed[i][1]
			_delayed.remove_at(i)
			if f.is_valid():
				f.call()
	if match_manager == null:
		return
	_update_roll()
	for p in match_manager.players:
		if p.visible and p.is_physics_processing():
			_update_feet(p, delta)


func _update_roll() -> void:
	var b := match_manager.ball
	if b == null or _roll.stream == null:
		return
	var v := b.flat_velocity().length()
	var on_ground := b.grounded or b.global_position.y < Ball.RADIUS + 0.03
	var target := -60.0
	if on_ground and v > 0.35:
		target = lerpf(-30.0, -9.0, clampf((v - 0.35) / 9.0, 0.0, 1.0))
	_roll.global_position = b.global_position
	_roll.volume_db = lerpf(_roll.volume_db, target, 0.25)
	_roll.pitch_scale = clampf(0.75 + v * 0.05, 0.75, 1.4)
	if _roll.volume_db > -55.0 and not _roll.playing and enabled:
		_roll.play(_rng.randf_range(0.0, 3.0))
	elif _roll.volume_db <= -58.0 and _roll.playing:
		_roll.stop()


## Passo = o pé chega ao chão (pose final): altura do tornozelo descendo até
## perto da mínima de apoio dele. Andar/correr pela velocidade.
func _update_feet(p: Player, delta: float) -> void:
	var vis = p.visual
	if vis == null or not vis.has_method("get_ankle_position"):
		return
	var hv := p.get_flat_velocity()
	var speed := hv.length()
	var st: Dictionary = _feet.get(p, {})
	for s in [1.0, -1.0]:
		var y: float = vis.get_ankle_position(s).y - p.global_position.y
		var key_min := "min%d" % int(s)
		var key_dn := "dn%d" % int(s)
		var key_y := "y%d" % int(s)
		var ymin: float = st.get(key_min, y)
		ymin = minf(ymin + delta * 0.02, y) # acompanha devagar a altura de apoio
		var down: bool = st.get(key_dn, true)
		var prev_y: float = st.get(key_y, y)
		if not down and y < ymin + 0.022 and y <= prev_y and speed > 0.25:
			down = true
			if p.state != Player.State.FROZEN:
				_step(p, s, speed)
		elif down and y > ymin + 0.055:
			down = false
		st[key_min] = ymin
		st[key_dn] = down
		st[key_y] = y
	_feet[p] = st
	# derrapada: freada ou virada brusca em velocidade
	var pv: Vector3 = _prev_vel.get(p, hv)
	_prev_vel[p] = hv
	var acc := (hv - pv).length() / maxf(delta, 0.001)
	var cd: float = maxf(float(_scuff_cd.get(p, 0.0)) - delta, 0.0)
	if cd <= 0.0 and acc > 13.0 and pv.length() > 2.8:
		cd = 1.4
		play(&"scuff", p.global_position, lerpf(-16.0, -8.0, clampf((pv.length() - 2.3) / 2.0, 0.0, 1.0)), _rng.randf_range(0.9, 1.1))
	_scuff_cd[p] = cd


func _step(p: Player, side: float, speed: float) -> void:
	var pos: Vector3 = p.visual.get_ankle_position(side)
	pos.y = 0.0
	var run := speed > 2.0
	var k := clampf((speed - 0.4) / 4.0, 0.0, 1.0)
	var db := lerpf(-24.0, -11.0, k) + _rng.randf_range(-1.5, 1.5)
	play(&"step_run" if run else &"step_walk", pos, db, _rng.randf_range(0.92, 1.08))
