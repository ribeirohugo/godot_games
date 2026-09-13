extends Node
## Synthesizes arcade sound effects in code, so the project needs no audio files.

const RATE := 22050
const NOTES := [523.0, 659.0, 784.0, 1046.0]

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["flipper"] = _make(0.07, func(t: float) -> float:
		return _noise() * 0.4 * exp(-t * 60.0) + sin(TAU * 120.0 * t) * 0.7 * exp(-t * 40.0))
	sounds["bumper"] = _make(0.18, func(t: float) -> float:
		return _sweep(t, 900.0, 250.0, 0.18) * 0.8 * exp(-t * 18.0) + _noise() * 0.3 * exp(-t * 50.0))
	sounds["sling"] = _make(0.1, func(t: float) -> float:
		return signf(_sweep(t, 400.0, 150.0, 0.1)) * 0.35 * exp(-t * 30.0))
	sounds["target"] = _make(0.08, func(t: float) -> float:
		return _noise() * 0.6 * exp(-t * 50.0) + sin(TAU * 1800.0 * t) * 0.3 * exp(-t * 60.0))
	sounds["lane"] = _make(0.35, func(t: float) -> float:
		return (sin(TAU * 1320.0 * t) + 0.5 * sin(TAU * 1980.0 * t)) * 0.45 * exp(-t * 9.0))
	sounds["launch"] = _make(0.35, func(t: float) -> float:
		return _noise() * 0.35 * (1.0 - t / 0.35))
	sounds["drain"] = _make(0.7, func(t: float) -> float:
		return _sweep(t, 440.0, 110.0, 0.7) * 0.5 * (1.0 - t / 0.7))
	sounds["bonus"] = _make(0.5, func(t: float) -> float:
		var note: float = NOTES[mini(int(t / 0.12), 3)]
		return sin(TAU * note * t) * 0.45 * exp(-fmod(t, 0.12) * 12.0))
	sounds["nudge"] = _make(0.12, func(t: float) -> float:
		return sin(TAU * 60.0 * t) * 0.9 * exp(-t * 30.0))
	sounds["tilt"] = _make(0.6, func(t: float) -> float:
		return signf(sin(TAU * 80.0 * t)) * 0.3)

	for i in 8:
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
