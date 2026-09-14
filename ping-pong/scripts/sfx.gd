extends Node
## Synthesizes the game's beeps in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	sounds["paddle"] = _make(0.06, func(t: float) -> float:
		return signf(sin(TAU * 460.0 * t)) * 0.3 * exp(-t * 40.0))
	sounds["wall"] = _make(0.05, func(t: float) -> float:
		return signf(sin(TAU * 230.0 * t)) * 0.25 * exp(-t * 50.0))
	sounds["score"] = _make(0.4, func(t: float) -> float:
		return sin(TAU * (660.0 - 400.0 * t) * t) * 0.5 * (1.0 - t / 0.4))
	sounds["win"] = _make(0.6, func(t: float) -> float:
		var note: float = [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.15), 3)]
		return sin(TAU * note * t) * 0.45 * exp(-fmod(t, 0.15) * 10.0))

	for i in 4:
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
