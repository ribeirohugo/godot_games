extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 11
	sounds["click"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.15 * exp(-t * 120.0))
	# A hand swinging down through the air.
	sounds["whoosh"] = _make(0.22, func(t: float) -> float:
		var env := sin(PI * t / 0.22)
		return (_noise() * 0.6 + _sweep(t, 520.0, 180.0, 0.22) * 0.3) * env * env * 0.22)
	# The hands opening.
	sounds["pop"] = _make(0.14, func(t: float) -> float:
		return (_sweep(t, 300.0, 900.0, 0.14) * 0.7 + _noise() * 0.2 * exp(-t * 60.0)) * 0.25 * exp(-t * 22.0))
	# One finger counted; played with a rising pitch.
	sounds["tick"] = _make(0.08, func(t: float) -> float:
		return (sin(TAU * 1320.0 * t) + sin(TAU * 1980.0 * t) * 0.3) * 0.14 * exp(-t * 45.0))
	sounds["win"] = _make(0.55, func(t: float) -> float:
		var notes := [659.0, 784.0, 1046.0]
		var i := mini(int(t / 0.09), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.09
		return (sin(TAU * note * t) * 0.25 + sin(TAU * note * 2.0 * t) * 0.06) * exp(-local * (6.0 if i == notes.size() - 1 else 16.0)))
	sounds["lose"] = _make(0.45, func(t: float) -> float:
		var note := 330.0 if t < 0.15 else 262.0
		return (sin(TAU * note * t) * 0.8 + sin(TAU * note * 0.5 * t) * 0.3) * 0.15 * exp(-fmod(t, 0.15) * 6.0))
	sounds["match_win"] = _make(1.3, func(t: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0, 784.0, 1046.0, 1318.0]
		var i := mini(int(t / 0.12), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.12
		var tail := 4.0 if i == notes.size() - 1 else 12.0
		return (sin(TAU * note * t) * 0.22 + sin(TAU * note * 1.5 * t) * 0.06 + sin(TAU * note * 2.0 * t) * 0.05) * exp(-local * tail))
	sounds["match_lose"] = _make(1.1, func(t: float) -> float:
		var notes := [392.0, 370.0, 349.0, 262.0]
		var i := mini(int(t / 0.2), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.2
		var vibrato := sin(TAU * 6.0 * t) * (4.0 if i == notes.size() - 1 else 0.0)
		return sin(TAU * (note + vibrato) * t) * 0.18 * exp(-local * (2.5 if i == notes.size() - 1 else 7.0)))
	sounds["switch"] = _make(0.06, func(t: float) -> float:
		return _sweep(t, 700.0, 1100.0, 0.06) * 0.14 * exp(-t * 50.0))

	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)


func play(sound: String, pitch := 1.0) -> void:
	for player in players:
		if not player.playing:
			player.stream = sounds[sound]
			player.pitch_scale = pitch
			player.play()
			return
	# All busy: cut off the first one.
	players[0].stream = sounds[sound]
	players[0].pitch_scale = pitch
	players[0].play()


func _make(duration: float, generator: Callable) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value := clampf(generator.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## Sine wave whose pitch slides from `from_hz` to `to_hz` over `duration`.
func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))
