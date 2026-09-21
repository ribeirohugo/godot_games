extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 7
	# Two clay chips knocking together.
	sounds["chip"] = _make(0.09, func(t: float) -> float:
		var knock := sin(TAU * 2300.0 * t) * exp(-t * 90.0) + sin(TAU * 3400.0 * t) * 0.6 * exp(-t * 120.0)
		var second := 0.0 if t < 0.03 else sin(TAU * 2600.0 * (t - 0.03)) * 0.6 * exp(-(t - 0.03) * 110.0)
		return (knock + second + _noise() * exp(-t * 200.0) * 0.6) * 0.18)
	sounds["remove"] = _make(0.07, func(t: float) -> float:
		return (_sweep(t, 1900.0, 1100.0, 0.07) * 0.5 + _noise() * 0.3) * 0.16 * exp(-t * 45.0))
	# The croupier launching the ball: a rising whoosh.
	sounds["spin"] = _make(0.7, func(t: float) -> float:
		var env := sin(PI * t / 0.7)
		return (_noise() * 0.5 + _sweep(t, 180.0, 420.0, 0.7) * 0.25) * env * env * 0.22)
	# The ball hitting a pocket fret.
	sounds["tick"] = _make(0.035, func(t: float) -> float:
		return (sin(TAU * 3900.0 * t) * 0.6 + _noise() * 0.4) * 0.2 * exp(-t * 160.0))
	sounds["land"] = _make(0.2, func(t: float) -> float:
		return (sin(TAU * 1800.0 * t) * 0.4 + sin(TAU * 260.0 * t) * 0.6) * 0.25 * exp(-t * 26.0))
	sounds["click"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.15 * exp(-t * 120.0))
	sounds["error"] = _make(0.2, func(t: float) -> float:
		return (sin(TAU * 196.0 * t) + sin(TAU * 207.0 * t)) * 0.13 * exp(-t * 12.0))
	sounds["lose"] = _make(0.5, func(t: float) -> float:
		var note := 392.0 if t < 0.18 else 311.0
		return sin(TAU * note * t) * 0.16 * exp(-fmod(t, 0.18) * 7.0))
	sounds["win"] = _make(1.1, func(t: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0, 1318.0]
		var i := mini(int(t / 0.1), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.1
		return (sin(TAU * note * t) * 0.25 + sin(TAU * note * 2.0 * t) * 0.07) * exp(-local * (5.0 if i == notes.size() - 1 else 14.0)))
	# Coins pouring out for a big win.
	sounds["coins"] = _make(1.2, func(t: float) -> float:
		var hit := fmod(t, 0.06)
		var pitch := 2800.0 + 900.0 * sin(float(int(t / 0.06)) * 2.3)
		return sin(TAU * pitch * hit) * 0.13 * exp(-hit * 70.0) * (1.0 - t / 1.2))

	for i in 10:
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
