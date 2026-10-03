extends Node
## Звук: короткие эффекты (пул плееров), фоновые петли (стук колёс, дождь) и музыка
## с плавной сменой состояний (меню / исследование / напряжение). Громкость — из настроек.

const AUDIO_DIR: String = "res://assets/audio/"
const SFX_POOL: int = 10
const MUSIC_FADE: float = 1.2

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name: String = ""
var _train: AudioStreamPlayer
var _rain: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name: String in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_players.append(p)
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_train = _make_player(&"Ambient")
	_rain = _make_player(&"Ambient")
	apply_volumes()


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _stream(name: String, loop: bool = false) -> AudioStream:
	if not _streams.has(name):
		var path: String = AUDIO_DIR + name + ".wav"
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamWAV and loop:
			var wav: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
			s = wav
		_streams[name] = s
	return _streams[name]


func apply_volumes() -> void:
	_set_bus("Music", float(SaveManager.setting("music")))
	_set_bus("SFX", float(SaveManager.setting("sfx")))
	_set_bus("Ambient", float(SaveManager.setting("ambient")))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = _stream(name)
	if s == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	_sfx_players[0].stream = s
	_sfx_players[0].play()


func play_music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	var incoming: AudioStreamPlayer = _music_b if _music_a.playing else _music_a
	var outgoing: AudioStreamPlayer = _music_a if incoming == _music_b else _music_b
	if name != "":
		incoming.stream = _stream(name, true)
		incoming.volume_db = -40.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", 0.0, MUSIC_FADE)
	if outgoing.playing:
		var tw := create_tween()
		tw.tween_property(outgoing, "volume_db", -40.0, MUSIC_FADE)
		tw.tween_callback(outgoing.stop)


func current_music() -> String:
	return _music_name


func set_train_ambience(on: bool, rain: bool = false) -> void:
	_loop(_train, "train_loop", on, -4.0)
	_loop(_rain, "rain_loop", on and rain, -8.0)


func _loop(p: AudioStreamPlayer, name: String, on: bool, db: float) -> void:
	if on and not p.playing:
		p.stream = _stream(name, true)
		p.volume_db = db
		p.play()
	elif not on and p.playing:
		p.stop()


func vibrate(ms: int = 40) -> void:
	if bool(SaveManager.setting("vibration")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
