extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["select"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.2 * exp(-t * 70.0))
	sounds["op"] = _make(0.06, func(t: float) -> float:
		return sin(TAU * 620.0 * t) * 0.2 * exp(-t * 55.0))
	sounds["combine"] = _make(0.14, func(t: float) -> float:
		var note := 520.0 if t < 0.06 else 780.0
		return (sin(TAU * note * t) * 0.24 + sin(TAU * note * 2.0 * t) * 0.05) * exp(-fmod(t, 0.06) * 18.0))
	sounds["undo"] = _make(0.07, func(t: float) -> float:
		return _sweep(t, 500.0, 800.0, 0.07) * 0.15 * exp(-t * 35.0))
	sounds["error"] = _make(0.2, func(t: float) -> float:
		return (sin(TAU * 200.0 * t) + sin(TAU * 212.0 * t)) * 0.14 * exp(-t * 12.0))
	sounds["deal"] = _make(0.18, func(t: float) -> float:
		var beat := fmod(t, 0.045)
		return sin(TAU * (700.0 + 90.0 * int(t / 0.045)) * t) * 0.16 * exp(-beat * 90.0))
	sounds["win"] = _make(1.0, func(t: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0, 1318.0]
		var i := mini(int(t / 0.11), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.11
		return (sin(TAU * note * t) * 0.25 + sin(TAU * note * 2.0 * t) * 0.07) * exp(-local * (6.0 if i == notes.size() - 1 else 14.0)))

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
