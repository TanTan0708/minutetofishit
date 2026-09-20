class_name SoundGen
extends RefCounted

## Procedural 8-bit style sound synthesis. Everything here builds a raw
## PCM waveform in memory and wraps it as an AudioStreamWAV, so the game
## needs zero external audio files or an import pipeline - the same idea
## as the procedural pixel art, applied to sound.

const SAMPLE_RATE := 22050


static func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	stream.data = bytes
	return stream


static func _decode(stream: AudioStreamWAV) -> PackedFloat32Array:
	var bytes: PackedByteArray = stream.data
	var n := bytes.size() / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = float(bytes.decode_s16(i * 2)) / 32768.0
	return out


## Linear attack-hold-release envelope, 0..1.
static func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	if t < attack:
		return t / maxf(0.0001, attack)
	var release_start := duration - release
	if t > release_start:
		return maxf(0.0, (duration - t) / maxf(0.0001, release))
	return 1.0


static func _wave(kind: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		"sine":
			return sin(p * TAU)
		"square":
			return 1.0 if p < 0.5 else -1.0
		"triangle":
			return 1.0 - 4.0 * absf(p - 0.5)
		"saw":
			return p * 2.0 - 1.0
	return 0.0


## A single held tone.
static func tone(freq: float, duration: float, wave: String = "square",
		volume: float = 0.4, attack: float = 0.008, release: float = 0.05) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		samples[i] = _wave(wave, t * freq) * _envelope(t, duration, attack, release) * volume
	return _make_stream(samples)


## A tone that glides from one frequency to another - the classic
## 8-bit "pew" (descending) or "power-up" (ascending) sound.
static func sweep(freq_start: float, freq_end: float, duration: float,
		wave: String = "square", volume: float = 0.4) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq: float = lerpf(freq_start, freq_end, t / duration)
		phase += freq / SAMPLE_RATE
		samples[i] = _wave(wave, phase) * _envelope(t, duration, 0.004, duration * 0.4) * volume
	return _make_stream(samples)


## White noise burst - the crunch underneath an explosion.
static func noise_burst(duration: float, volume: float = 0.4, seed: int = 1) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var t := float(i) / SAMPLE_RATE
		samples[i] = rng.randf_range(-1.0, 1.0) * _envelope(t, duration, 0.001, duration * 0.9) * volume
	return _make_stream(samples)


## Plays several sounds one after another (an arpeggio/jingle).
static func sequence(streams: Array) -> AudioStreamWAV:
	var combined := PackedFloat32Array()
	for s in streams:
		combined.append_array(_decode(s))
	return _make_stream(combined)


## Layers several sounds on top of each other (e.g. noise + a low sweep
## for an explosion). Shorter streams just stop contributing early.
static func mix(streams: Array) -> AudioStreamWAV:
	var max_len := 0
	var decoded: Array = []
	for s in streams:
		var samples: PackedFloat32Array = _decode(s)
		decoded.append(samples)
		max_len = maxi(max_len, samples.size())
	var combined := PackedFloat32Array()
	combined.resize(max_len)
	for samples in decoded:
		for i in samples.size():
			combined[i] += samples[i]
	return _make_stream(combined)
