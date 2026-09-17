extends Node
## Synthesizes the sound effects in code, so the project needs no audio files.

const RATE := 22050
const FANFARE := [523.0, 659.0, 784.0, 1046.0]

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["place"] = _make(0.14, func(t: float) -> float:
		return sin(TAU * _glide(t, 180.0, 90.0, 0.14)) * 0.8 * exp(-t * 25.0) + _noise() * 0.25 * exp(-t * 60.0))
	sounds["step"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 320.0 * t) * 0.35 * exp(-t * 80.0))
	sounds["points"] = _make(0.18, func(t: float) -> float:
		return (sin(TAU * 988.0 * t) + 0.5 * sin(TAU * 1480.0 * t)) * 0.3 * exp(-t * 16.0))
	sounds["jump"] = _make(0.25, func(t: float) -> float:
		return sin(TAU * _glide(t, 300.0, 700.0, 0.25)) * 0.4 * (1.0 - t / 0.25))
	sounds["splash"] = _make(0.6, func(t: float) -> float:
		return _noise() * 0.55 * exp(-t * 6.0) * (0.6 + 0.4 * sin(TAU * 7.0 * t)))
	sounds["win"] = _make(0.7, func(t: float) -> float:
		var note: float = FANFARE[mini(int(t / 0.13), 3)]
		return (sin(TAU * note * t) + 0.3 * sin(TAU * note * 2.0 * t)) * 0.35 * exp(-fmod(t, 0.13) * 8.0))
	sounds["lose"] = _make(0.8, func(t: float) -> float:
		return sin(TAU * _glide(t, 400.0, 150.0, 0.8)) * 0.4 * (1.0 - t / 0.8))
	sounds["click"] = _make(0.04, func(t: float) -> float:
		return sin(TAU * 1200.0 * t) * 0.25 * exp(-t * 90.0))

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


## Phase (in cycles) of a tone whose pitch slides from `from_hz` to `to_hz` over `duration`.
func _glide(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)
