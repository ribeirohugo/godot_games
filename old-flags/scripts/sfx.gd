extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["click"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.15 * exp(-t * 120.0))
	sounds["move"] = _make(0.025, func(t: float) -> float:
		return sin(TAU * 1400.0 * t) * 0.06 * exp(-t * 160.0))
	sounds["correct"] = _make(0.3, func(t: float) -> float:
		var note := 660.0 if t < 0.09 else 990.0
		return (sin(TAU * note * t) * 0.25 + sin(TAU * note * 2.0 * t) * 0.06) * exp(-fmod(t, 0.09) * 12.0))
	sounds["wrong"] = _make(0.3, func(t: float) -> float:
		return (_sweep(t, 260.0, 180.0, 0.3) + sin(TAU * 196.0 * t) * 0.6) * 0.16 * exp(-t * 7.0))
	sounds["pass"] = _make(1.0, func(t: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0]
		var i := mini(int(t / 0.13), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.13
		return (sin(TAU * note * t) * 0.25 + sin(TAU * note * 2.0 * t) * 0.07) * exp(-local * (5.0 if i == notes.size() - 1 else 13.0)))
	sounds["fail"] = _make(0.8, func(t: float) -> float:
		var notes := [392.0, 349.0, 311.0]
		var i := mini(int(t / 0.18), notes.size() - 1)
		var local := t - i * 0.18
		return sin(TAU * notes[i] * t) * 0.2 * exp(-local * (4.0 if i == notes.size() - 1 else 9.0)))

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


## Sine wave whose pitch slides from `from_hz` to `to_hz` over `duration`.
func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))
