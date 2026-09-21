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
	sounds["error"] = _make(0.2, func(t: float) -> float:
		return (sin(TAU * 196.0 * t) + sin(TAU * 207.0 * t)) * 0.13 * exp(-t * 12.0))
	# Pulling the lever: a quick rising whirr.
	sounds["spin"] = _make(0.35, func(t: float) -> float:
		var env := minf(t * 30.0, 1.0) * exp(-t * 5.0)
		return (_sweep(t, 220.0, 620.0, 0.35) * 0.35 + _noise() * 0.25) * env * 0.3)
	# A reel slamming to a stop.
	sounds["stop"] = _make(0.14, func(t: float) -> float:
		return (sin(TAU * 110.0 * t) * 0.7 + _noise() * 0.35 * exp(-t * 60.0) + sin(TAU * 1700.0 * t) * 0.15 * exp(-t * 80.0)) * 0.35 * exp(-t * 28.0))
	sounds["scatter"] = _make(0.5, func(t: float) -> float:
		return (sin(TAU * 1046.0 * t) * 0.3 + sin(TAU * 1568.0 * t) * 0.2 + sin(TAU * 2093.0 * t) * 0.1) * exp(-t * 6.0) * 0.5)
	# Suspense while the last reels spin with two bonus symbols showing.
	sounds["tease"] = _make(1.0, func(t: float) -> float:
		var wobble := sin(TAU * 7.0 * t) * 0.5 + 0.5
		return _sweep(t, 300.0, 900.0, 1.0) * 0.18 * (0.6 + 0.4 * wobble) * minf(t * 8.0, 1.0))
	sounds["win"] = _make(0.45, func(t: float) -> float:
		var notes := [784.0, 988.0, 1175.0]
		var i := mini(int(t / 0.09), notes.size() - 1)
		var note: float = notes[i]
		return (sin(TAU * note * t) * 0.25 + sin(TAU * note * 2.0 * t) * 0.06) * exp(-(t - i * 0.09) * (6.0 if i == 2 else 18.0)))
	sounds["line"] = _make(0.08, func(t: float) -> float:
		return sin(TAU * 1320.0 * t) * 0.14 * exp(-t * 40.0))
	sounds["tick"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 2600.0 * t) * 0.1 * exp(-t * 150.0))
	sounds["big"] = _make(1.6, func(t: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0, 784.0, 1046.0, 1318.0]
		var i := mini(int(t / 0.13), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.13
		var last := i == notes.size() - 1
		var tone := sin(TAU * note * t) * 0.24 + sin(TAU * note * 1.5 * t) * 0.08 + sin(TAU * note * 0.5 * t) * 0.1
		return tone * exp(-local * (2.5 if last else 9.0)))
	sounds["coins"] = _make(1.2, func(t: float) -> float:
		var hit := fmod(t, 0.055)
		var pitch := 2800.0 + 900.0 * sin(float(int(t / 0.055)) * 2.3)
		return sin(TAU * pitch * hit) * 0.12 * exp(-hit * 70.0) * (1.0 - t / 1.2))
	sounds["free"] = _make(1.3, func(t: float) -> float:
		var notes := [659.0, 784.0, 988.0, 1318.0, 988.0, 1318.0, 1568.0, 1976.0]
		var i := mini(int(t / 0.1), notes.size() - 1)
		var note: float = notes[i]
		return (sin(TAU * note * t) * 0.2 + sin(TAU * note * 3.0 * t) * 0.04) * exp(-(t - i * 0.1) * (3.0 if i == notes.size() - 1 else 12.0)))
	sounds["jackpot"] = _make(2.4, func(t: float) -> float:
		var bell := fmod(t, 0.2)
		var note: float = [1046.0, 1318.0, 1568.0, 2093.0][int(t / 0.2) % 4]
		return (sin(TAU * note * bell) * 0.22 + sin(TAU * note * 2.76 * bell) * 0.06) * exp(-bell * 12.0) * minf(1.0, (2.4 - t) * 2.0))

	for i in 12:
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
