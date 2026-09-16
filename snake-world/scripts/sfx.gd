extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["eat"] = _make(0.12, func(t: float) -> float:
		return _sweep(t, 380.0, 1100.0, 0.12) * 0.5 * exp(-t * 22.0))
	sounds["golden"] = _make(0.4, func(t: float) -> float:
		var note: float = [784.0, 988.0, 1175.0, 1568.0][mini(int(t / 0.08), 3)]
		return (sin(TAU * note * t) + 0.3 * sin(TAU * note * 2.0 * t)) * 0.35 * exp(-fmod(t, 0.08) * 20.0))
	sounds["hit"] = _make(0.4, func(t: float) -> float:
		return signf(_sweep(t, 220.0, 50.0, 0.4)) * 0.3 * (1.0 - t / 0.4) + _noise() * 0.5 * exp(-t * 25.0))
	sounds["pop"] = _make(0.05, func(t: float) -> float:
		return (_noise() * 0.4 + sin(TAU * 520.0 * t) * 0.4) * exp(-t * 70.0))
	sounds["over"] = _make(0.7, func(t: float) -> float:
		var note: float = [392.0, 330.0, 262.0][mini(int(t / 0.2), 2)]
		return signf(sin(TAU * note * t)) * 0.18 * exp(-fmod(t, 0.2) * 6.0))
	sounds["start"] = _make(0.25, func(t: float) -> float:
		var note := 660.0 if t < 0.1 else 990.0
		return sin(TAU * note * t) * 0.45 * exp(-fmod(t, 0.1) * 12.0))
	sounds["select"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 880.0 * t) * 0.3 * exp(-t * 60.0))
	# Swallowing rot: a queasy warble sliding downhill.
	sounds["poison"] = _make(0.45, func(t: float) -> float:
		var wobble := 1.0 + 0.25 * sin(TAU * 11.0 * t)
		return _sweep(t, 420.0 * wobble, 90.0, 0.45) * 0.35 * exp(-t * 4.0) + _noise() * 0.1 * exp(-t * 9.0))
	# Level cleared: a rising four-note flourish.
	sounds["clear"] = _make(0.75, func(t: float) -> float:
		var note: float = [523.0, 659.0, 784.0, 1047.0][mini(int(t / 0.15), 3)]
		var ring := 1.0 if t < 0.45 else exp(-(t - 0.45) * 7.0)
		return (sin(TAU * note * t) + 0.35 * sin(TAU * note * 2.0 * t)) * 0.3 * exp(-fmod(t, 0.15) * 7.0) * ring)
	# A locked level: a flat, dead thud.
	sounds["locked"] = _make(0.12, func(t: float) -> float:
		return sin(TAU * 150.0 * t) * 0.3 * exp(-t * 30.0))

	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)


func play(sound: String) -> void:
	for player in players:
		if not player.playing:
			player.stream = sounds[sound]
			player.play()
			return
	# All busy: cut off the first one.
	players[0].stream = sounds[sound]
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
	return randf_range(-1.0, 1.0)


## Sine wave whose pitch slides from `from_hz` to `to_hz` over `duration`.
func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))
