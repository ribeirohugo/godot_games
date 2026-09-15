extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["arrow"] = _make(0.09, func(t: float) -> float:
		return (_sweep(t, 900.0, 300.0, 0.09) * 0.25 + _noise() * 0.2) * exp(-t * 40.0))
	sounds["catapult"] = _make(0.18, func(t: float) -> float:
		return (_noise() * 0.35 + sin(TAU * 90.0 * t) * 0.4) * exp(-t * 18.0))
	sounds["boom"] = _make(0.35, func(t: float) -> float:
		return (_noise() * 0.55 + _sweep(t, 140.0, 40.0, 0.35) * 0.5) * exp(-t * 11.0))
	sounds["zap"] = _make(0.22, func(t: float) -> float:
		return signf(sin(TAU * (1400.0 + 600.0 * sin(t * 90.0)) * t)) * 0.16 * exp(-t * 14.0) + _noise() * 0.12 * exp(-t * 20.0))
	sounds["fire"] = _make(0.3, func(t: float) -> float:
		return _noise() * 0.35 * sin(PI * t / 0.3) * (0.6 + 0.4 * sin(t * 60.0)))
	sounds["bell"] = _make(0.5, func(t: float) -> float:
		return (sin(TAU * 1046.0 * t) * 0.3 + sin(TAU * 2093.0 * t) * 0.12 + sin(TAU * 1568.0 * t) * 0.08) * exp(-t * 7.0))
	sounds["spikes"] = _make(0.08, func(t: float) -> float:
		return (_noise() * 0.3 + signf(sin(TAU * 600.0 * t)) * 0.15) * exp(-t * 50.0))
	sounds["coin"] = _make(0.14, func(t: float) -> float:
		var note := 1320.0 if t < 0.05 else 1760.0
		return sin(TAU * note * t) * 0.22 * exp(-fmod(t, 0.05) * 25.0))
	sounds["build"] = _make(0.18, func(t: float) -> float:
		return (_noise() * 0.3 + sin(TAU * 180.0 * t) * 0.4) * exp(-t * 25.0) + sin(TAU * 520.0 * t) * 0.2 * exp(-maxf(t - 0.06, 0.0) * 30.0) * float(t > 0.06))
	sounds["upgrade"] = _make(0.3, func(t: float) -> float:
		var note: float = [523.0, 659.0, 784.0][mini(int(t / 0.1), 2)]
		return sin(TAU * note * t) * 0.3 * exp(-fmod(t, 0.1) * 14.0))
	sounds["sell"] = _make(0.2, func(t: float) -> float:
		return _sweep(t, 700.0, 300.0, 0.2) * 0.3 * exp(-t * 12.0))
	sounds["leak"] = _make(0.45, func(t: float) -> float:
		return signf(_sweep(t, 240.0, 60.0, 0.45)) * 0.25 * (1.0 - t / 0.45) + _noise() * 0.4 * exp(-t * 18.0))
	sounds["wave"] = _make(0.6, func(t: float) -> float:
		var note := 220.0 if t < 0.25 else 330.0
		return (signf(sin(TAU * note * t)) * 0.12 + sin(TAU * note * 2.0 * t) * 0.15) * minf(1.0, t * 30.0) * exp(-fmod(t, 0.25) * 3.0))
	sounds["win"] = _make(0.9, func(t: float) -> float:
		var note: float = [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.18), 3)]
		return (sin(TAU * note * t) + 0.3 * sin(TAU * note * 2.0 * t)) * 0.3 * exp(-fmod(t, 0.18) * 6.0))
	sounds["lose"] = _make(0.9, func(t: float) -> float:
		var note: float = [392.0, 330.0, 262.0, 196.0][mini(int(t / 0.22), 3)]
		return signf(sin(TAU * note * t)) * 0.16 * exp(-fmod(t, 0.22) * 5.0))
	sounds["select"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 880.0 * t) * 0.25 * exp(-t * 60.0))
	sounds["error"] = _make(0.14, func(t: float) -> float:
		return signf(sin(TAU * 140.0 * t)) * 0.18 * exp(-t * 20.0))

	for i in 10:
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
