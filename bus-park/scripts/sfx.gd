extends Node
## Synthesizes the sound effects in code, so the project needs no audio files.

const RATE := 22050
const FANFARE := [523.0, 659.0, 784.0, 1046.0]

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["slide"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 260.0 * t) * 0.22 * exp(-t * 70.0))
	sounds["bump"] = _make(0.09, func(t: float) -> float:
		return _noise() * 0.3 * exp(-t * 30.0))
	sounds["click"] = _make(0.04, func(t: float) -> float:
		return sin(TAU * 1200.0 * t) * 0.25 * exp(-t * 90.0))
	sounds["win"] = _make(0.7, func(t: float) -> float:
		var note: float = FANFARE[mini(int(t / 0.13), 3)]
		return (sin(TAU * note * t) + 0.3 * sin(TAU * note * 2.0 * t)) * 0.35 * exp(-fmod(t, 0.13) * 8.0))
	sounds["honk"] = _make(0.3, func(t: float) -> float:
		return (sin(TAU * 320.0 * t) + 0.6 * sin(TAU * 480.0 * t)) * 0.3 * exp(-t * 5.0))

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
