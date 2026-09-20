extends Node

## Sound effects and music - registered as the `Audio` autoload.
##
## SFX are procedurally synthesized 8-bit waveforms (see SoundGen), so no
## external files are needed for those. Background music is a real track:
## "Underclocked" by Eric Skiff (https://ericskiff.com/music/), licensed
## CC BY 4.0 - free to use with attribution, credited in the README.

const POOL_SIZE := 8
const MUSIC_PATH := "res://assets/audio/underclocked.mp3"

var master_volume_db: float = 0.0
var music_volume_db: float = -10.0

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music_player: AudioStreamPlayer
var _sound_enabled: bool = true
var _music_enabled: bool = true
var _sfx_bus: int
var _music_bus: int


## SFX and music get their own audio buses so muting is a guaranteed
## AudioServer-level mute rather than relying on per-player state (which
## didn't reliably silence a long-running looped stream - stream_paused
## alone wasn't enough).
func _ready() -> void:
	_sfx_bus = _ensure_bus("SFX")
	_music_bus = _ensure_bus("Music")

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_build_sounds()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	var music: AudioStream = Assets.load_mp3(MUSIC_PATH)
	if music != null:
		if music is AudioStreamMP3:
			music.loop = true
		_music_player.stream = music
		_music_player.volume_db = music_volume_db
		_music_player.play()


func _ensure_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
	return idx


func _build_sounds() -> void:
	_sounds["shoot"] = SoundGen.sweep(950.0, 220.0, 0.09, "square", 0.32)
	_sounds["catch"] = SoundGen.sweep(520.0, 1100.0, 0.11, "triangle", 0.38)
	_sounds["catch_gold"] = SoundGen.sequence([
		SoundGen.tone(660.0, 0.07, "triangle", 0.32),
		SoundGen.tone(880.0, 0.07, "triangle", 0.32),
		SoundGen.tone(1175.0, 0.16, "triangle", 0.4),
	])
	_sounds["explosion"] = SoundGen.mix([
		SoundGen.noise_burst(0.4, 0.45, 7),
		SoundGen.sweep(180.0, 40.0, 0.4, "square", 0.3),
	])
	_sounds["click"] = SoundGen.tone(700.0, 0.035, "square", 0.22, 0.002, 0.02)
	_sounds["beep"] = SoundGen.tone(523.0, 0.12, "square", 0.32)
	_sounds["go"] = SoundGen.sweep(523.0, 1046.0, 0.22, "square", 0.38)
	_sounds["powerup"] = SoundGen.sweep(300.0, 1500.0, 0.28, "triangle", 0.32)
	_sounds["warning"] = SoundGen.sweep(500.0, 300.0, 0.15, "square", 0.28)
	_sounds["results"] = SoundGen.sequence([
		SoundGen.tone(392.0, 0.1, "triangle", 0.32),
		SoundGen.tone(523.0, 0.1, "triangle", 0.32),
		SoundGen.tone(659.0, 0.18, "triangle", 0.38),
	])
	_sounds["toggle_on"] = SoundGen.sweep(440.0, 880.0, 0.07, "square", 0.28)
	_sounds["toggle_off"] = SoundGen.sweep(600.0, 350.0, 0.06, "square", 0.22)


func is_sound_enabled() -> bool:
	return _sound_enabled


func is_music_enabled() -> bool:
	return _music_enabled


func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled
	AudioServer.set_bus_mute(_sfx_bus, not enabled)


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	AudioServer.set_bus_mute(_music_bus, not enabled)


## `pitch_variance` (e.g. 0.06) randomizes pitch a little per play so
## repeated hits (catching fish back to back) don't sound identical.
func play(name: String, pitch_variance: float = 0.0) -> void:
	if not _sound_enabled or not _sounds.has(name):
		return
	var p: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sounds[name]
	p.volume_db = master_volume_db
	p.pitch_scale = 1.0 if pitch_variance <= 0.0 else 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.play()
