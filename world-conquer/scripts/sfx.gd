extends Node
## Synthesizes the sound effects in code, so the project needs no audio files.

const RATE := 22050
const FANFARE := [523.0, 659.0, 784.0, 1046.0]

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["click"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 1100.0 * t) * 0.25 * exp(-t * 80.0))
	sounds["place"] = _make(0.1, func(t: float) -> float:
		return sin(TAU * _glide(t, 220.0, 440.0, 0.1)) * 0.4 * exp(-t * 30.0))
	sounds["dice"] = _make(0.3, func(t: float) -> float:
		var tick := fmod(t, 0.06) / 0.06
		return _noise() * 0.5 * exp(-tick * 12.0) * (1.0 - t / 0.3))
	sounds["hit"] = _make(0.25, func(t: float) -> float:
		return (_noise() * 0.5 + sin(TAU * 90.0 * t) * 0.6) * exp(-t * 14.0))
	sounds["conquer"] = _make(0.45, func(t: float) -> float:
		var note: float = FANFARE[mini(int(t / 0.11), 3)]
		return sin(TAU * note * t) * 0.3 * exp(-fmod(t, 0.11) * 10.0))
	sounds["card"] = _make(0.2, func(t: float) -> float:
		return _noise() * 0.3 * exp(-t * 20.0) + sin(TAU * 1500.0 * t) * 0.2 * exp(-t * 25.0))
	sounds["turn"] = _make(0.3, func(t: float) -> float:
		return (sin(TAU * 660.0 * t) + 0.5 * sin(TAU * 990.0 * t)) * 0.3 * exp(-t * 9.0))
	sounds["victory"] = _make(1.0, func(t: float) -> float:
		var note: float = FANFARE[mini(int(t / 0.2), 3)]
		return (sin(TAU * note * t) + 0.3 * sin(TAU * note * 2.0 * t)) * 0.35 * exp(-fmod(t, 0.2) * 4.0))
	sounds["defeat"] = _make(1.0, func(t: float) -> float:
		return sin(TAU * _glide(t, 330.0, 110.0, 1.0)) * 0.4 * (1.0 - t))

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
