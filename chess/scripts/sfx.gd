extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()
var low := 0.0  # state of the low-pass filter in _soft_noise


func _ready() -> void:
	rng.seed = 7
	# A wooden piece set down on the board.
	sounds["move"] = _make(0.14, func(t: float) -> float:
		return _knock(t, 1.0) * 0.55)
	# Taking a piece: the piece knocks the other one aside, then lands.
	sounds["capture"] = _make(0.24, func(t: float) -> float:
		var hit := (_noise() * exp(-t * 110.0) * 0.5 + sin(TAU * 1250.0 * t) * exp(-t * 70.0) * 0.25)
		return (hit + _knock(t - 0.05, 0.9)) * 0.5)
	# King and rook, one after the other.
	sounds["castle"] = _make(0.3, func(t: float) -> float:
		return (_knock(t, 1.0) + _knock(t - 0.12, 1.15) * 0.8) * 0.5)
	# The move plus a warning ping.
	sounds["check"] = _make(0.6, func(t: float) -> float:
		var ping := 0.0
		if t > 0.05:
			var u := t - 0.05
			ping = (sin(TAU * 1175.0 * u) + sin(TAU * 1760.0 * u) * 0.4) * exp(-u * 7.0) * 0.12
		return _knock(t, 1.0) * 0.5 + ping)
	sounds["promote"] = _make(0.7, func(t: float) -> float:
		var notes := [784.0, 988.0, 1175.0, 1568.0]
		var i := mini(int(t / 0.07), notes.size() - 1)
		var local := t - i * 0.07
		var sparkle := sin(TAU * notes[i] * t) * exp(-local * (5.0 if i == notes.size() - 1 else 16.0)) * 0.13
		return _knock(t, 1.0) * 0.4 + sparkle)
	sounds["select"] = _make(0.05, func(t: float) -> float:
		return (sin(TAU * 1600.0 * t) * 0.6 + _soft_noise(0.6) * 0.3) * 0.08 * exp(-t * 90.0))
	sounds["click"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.15 * exp(-t * 120.0))
	sounds["error"] = _make(0.22, func(t: float) -> float:
		return (sin(TAU * 196.0 * t) + sin(TAU * 207.0 * t)) * 0.12 * exp(-t * 12.0))
	sounds["undo"] = _make(0.2, func(t: float) -> float:
		var env := sin(PI * t / 0.2)
		return (_soft_noise(0.3) * 0.5 + _sweep(t, 900.0, 400.0, 0.2) * 0.25) * env * env * 0.35)
	sounds["hint"] = _make(0.6, func(t: float) -> float:
		var note := 880.0 if t < 0.09 else 1320.0
		var local := fmod(t, 0.09) if t < 0.09 else t - 0.09
		return (sin(TAU * note * t) + sin(TAU * note * 2.0 * t) * 0.2) * 0.12 * exp(-local * 7.0))
	sounds["start"] = _make(0.55, func(t: float) -> float:
		var note := 523.0 if t < 0.12 else 784.0
		var local := fmod(t, 0.12) if t < 0.12 else t - 0.12
		return (sin(TAU * note * t) + sin(TAU * note * 0.5 * t) * 0.3) * 0.13 * exp(-local * 7.0))
	sounds["win"] = _make(1.6, func(t: float) -> float:
		var melody := [[523.0, 0.0], [659.0, 0.12], [784.0, 0.24], [1046.0, 0.36], [784.0, 0.6], [1046.0, 0.72]]
		var out := 0.0
		for n in melody:
			var start: float = n[1]
			if t >= start:
				var u := t - start
				out += (sin(TAU * n[0] * u) * 0.2 + sin(TAU * n[0] * 2.0 * u) * 0.05) * exp(-u * (2.5 if start >= 0.72 else 9.0))
		if t > 0.72:
			var u := t - 0.72
			out += (sin(TAU * 659.0 * u) + sin(TAU * 784.0 * u)) * 0.07 * exp(-u * 2.5)
		return out)
	sounds["lose"] = _make(1.0, func(t: float) -> float:
		var notes := [392.0, 370.0, 311.0]
		var i := mini(int(t / 0.24), notes.size() - 1)
		var local := t - i * 0.24
		return (sin(TAU * notes[i] * t) + sin(TAU * notes[i] * 0.5 * t) * 0.4) * 0.12 * exp(-local * (3.5 if i == 2 else 7.0)))
	# Two calm notes, the second one a plain fifth: nobody won.
	sounds["draw"] = _make(0.8, func(t: float) -> float:
		if t < 0.16:
			return sin(TAU * 587.0 * t) * 0.1 * exp(-t * 10.0)
		var u := t - 0.16
		return (sin(TAU * 587.0 * u) + sin(TAU * 440.0 * u) * 0.6) * 0.1 * exp(-u * 4.0))

	for i in 8:
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
	low = 0.0
	for i in count:
		var value := clampf(generator.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## A short hollow wooden knock starting at t = 0 (silent before); `pitch` scales its tone.
func _knock(t: float, pitch: float) -> float:
	if t < 0.0:
		return 0.0
	var body := sin(TAU * 190.0 * pitch * t) * exp(-t * 45.0) * 0.7
	var tone := sin(TAU * 520.0 * pitch * t) * exp(-t * 70.0) * 0.45
	var tap := _noise() * exp(-t * 160.0) * 0.5
	return body + tone + tap


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## Noise through a one-pole low-pass filter: `amount` near 0 is dull, near 1 is bright.
func _soft_noise(amount: float) -> float:
	low += (_noise() - low) * amount
	return low * 1.6


## Sine wave whose pitch slides from `from_hz` to `to_hz` over `duration`.
func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))
