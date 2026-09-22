extends Node
## Synthesizes the game's sound effects in code, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()
var low := 0.0  # state of the low-pass filter in _soft_noise


func _ready() -> void:
	rng.seed = 11
	# Riffle shuffle: the two halves of the deck flicking into each other, twice.
	sounds["shuffle"] = _make(1.0, func(t: float) -> float:
		var local := fmod(t, 0.5)
		if local > 0.4:
			return 0.0
		var env := sin(PI * local / 0.4)
		var flick := exp(-fmod(local, 0.011) * 700.0)
		return (_noise() * flick * 0.8 + _soft_noise(0.35) * 0.3) * env * 0.3)
	# A card sliding off the deck: soft, since 40 of them play in a row.
	sounds["deal"] = _make(0.08, func(t: float) -> float:
		var env := sin(PI * t / 0.08)
		return _soft_noise(0.18) * env * env * 0.06)
	# A card put down on the felt.
	sounds["play"] = _make(0.16, func(t: float) -> float:
		var thump := sin(TAU * 150.0 * t) * exp(-t * 38.0)
		var snap := _noise() * exp(-t * 85.0)
		return (thump * 0.6 + snap * 0.45 + _soft_noise(0.4) * exp(-t * 30.0) * 0.3) * 0.42)
	# Cutting with a trump: a harder slap and a bright sparkle.
	sounds["trump"] = _make(0.75, func(t: float) -> float:
		var slap := (sin(TAU * 105.0 * t) * exp(-t * 26.0) * 0.8 + _noise() * exp(-t * 70.0) * 0.6) * 0.45
		var sparkle := 0.0
		if t > 0.06:
			var notes := [1318.0, 1568.0, 2093.0, 2637.0]
			var i := mini(int((t - 0.06) / 0.06), notes.size() - 1)
			var local := t - 0.06 - i * 0.06
			sparkle = sin(TAU * notes[i] * t) * exp(-local * (6.0 if i == notes.size() - 1 else 18.0)) * 0.13
		return slap + sparkle)
	# The trick swept off the table.
	sounds["collect"] = _make(0.32, func(t: float) -> float:
		var env := sin(PI * t / 0.32)
		return (_soft_noise(0.25) * 0.9 + _sweep(t, 300.0, 700.0, 0.32) * 0.06) * env * env * 0.35)
	sounds["trick_us"] = _make(0.5, func(t: float) -> float:
		var note := 784.0 if t < 0.1 else 1046.0
		var local := fmod(t, 0.1) if t < 0.1 else t - 0.1
		return (sin(TAU * note * t) + sin(TAU * note * 2.0 * t) * 0.25) * 0.14 * exp(-local * 9.0))
	sounds["trick_them"] = _make(0.45, func(t: float) -> float:
		var note := 440.0 if t < 0.12 else 349.0
		var local := fmod(t, 0.12) if t < 0.12 else t - 0.12
		return sin(TAU * note * t) * 0.12 * exp(-local * 9.0))
	# The trump card turned face up.
	sounds["reveal"] = _make(0.8, func(t: float) -> float:
		var flip := _soft_noise(0.5) * exp(-t * 40.0) * 0.4
		var chime := 0.0
		if t > 0.08:
			var u := t - 0.08
			chime = (sin(TAU * 880.0 * u) + sin(TAU * 1320.0 * u) * 0.6 + sin(TAU * 1760.0 * u) * 0.3) * exp(-u * 5.0) * 0.1
		return flip + chime)
	sounds["turn"] = _make(0.22, func(t: float) -> float:
		var note := 660.0 if t < 0.08 else 990.0
		var local := fmod(t, 0.08) if t < 0.08 else t - 0.08
		return sin(TAU * note * t) * 0.09 * exp(-local * 16.0))
	sounds["hover"] = _make(0.03, func(t: float) -> float:
		return (sin(TAU * 2300.0 * t) * 0.5 + _noise() * 0.3) * 0.05 * exp(-t * 150.0))
	sounds["click"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.15 * exp(-t * 120.0))
	sounds["error"] = _make(0.22, func(t: float) -> float:
		return (sin(TAU * 196.0 * t) + sin(TAU * 207.0 * t)) * 0.13 * exp(-t * 12.0))
	sounds["win"] = _make(1.3, func(t: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1046.0, 1318.0]
		var i := mini(int(t / 0.11), notes.size() - 1)
		var note: float = notes[i]
		var local := t - i * 0.11
		return (sin(TAU * note * t) * 0.24 + sin(TAU * note * 2.0 * t) * 0.07) * exp(-local * (4.0 if i == notes.size() - 1 else 13.0)))
	sounds["lose"] = _make(0.9, func(t: float) -> float:
		var notes := [392.0, 370.0, 311.0]
		var i := mini(int(t / 0.22), notes.size() - 1)
		var local := t - i * 0.22
		return (sin(TAU * notes[i] * t) + sin(TAU * notes[i] * 0.5 * t) * 0.4) * 0.12 * exp(-local * (3.5 if i == 2 else 7.0)))
	# A little fanfare for winning the match, ending on a full chord.
	sounds["match_win"] = _make(2.4, func(t: float) -> float:
		var melody := [[523.0, 0.0], [523.0, 0.14], [523.0, 0.28], [698.0, 0.42], [880.0, 0.78], [784.0, 1.0], [1046.0, 1.16]]
		var out := 0.0
		for n in melody:
			var start: float = n[1]
			if t >= start:
				var u := t - start
				var decay := 2.2 if start >= 1.16 else 9.0
				out += (sin(TAU * n[0] * u) * 0.2 + sin(TAU * n[0] * 2.0 * u) * 0.05) * exp(-u * decay)
		if t > 1.16:
			var u := t - 1.16
			out += (sin(TAU * 659.0 * u) + sin(TAU * 784.0 * u)) * 0.08 * exp(-u * 2.2)
		return out)
	sounds["pop"] = _make(0.14, func(t: float) -> float:
		return (_noise() * exp(-t * 60.0) * 0.6 + _sweep(t, 700.0, 1600.0, 0.14) * exp(-t * 25.0) * 0.3) * 0.3)

	for i in 12:
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


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## Noise through a one-pole low-pass filter: `amount` near 0 is dull, near 1 is bright.
func _soft_noise(amount: float) -> float:
	low += (_noise() - low) * amount
	return low * 1.6


## Sine wave whose pitch slides from `from_hz` to `to_hz` over `duration`.
func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))
