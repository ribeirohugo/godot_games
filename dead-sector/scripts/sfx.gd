extends Node
## Synthesizes every sound in code, so the project needs no audio files.
## play() is for the player's own sounds, play_at() for sounds that come from a place on the map.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var players_3d: Array[AudioStreamPlayer3D] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 4242
	sounds["click"] = _make(0.04, func(t: float) -> float:
		return sin(TAU * 900.0 * t) * 0.2 * exp(-t * 90.0))
	sounds["move"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 1300.0 * t) * 0.07 * exp(-t * 140.0))

	# Guns: a sharp crack, a falling body tone and a noisy tail.
	sounds["pistol"] = _gun(0.35, 190.0, 15.0, 80.0, 0.55, 0.6)
	sounds["suppressed"] = _make(0.22, func(t: float) -> float:
		return (_noise() * 0.6 * exp(-t * 30.0) + sin(TAU * 140.0 * t) * 0.3 * exp(-t * 25.0)) * 0.7, 0.2)
	sounds["magnum"] = _gun(0.7, 115.0, 8.0, 55.0, 0.9, 0.5)
	sounds["smg"] = _gun(0.26, 210.0, 20.0, 90.0, 0.5, 0.55)
	sounds["ak"] = _gun(0.5, 120.0, 11.0, 55.0, 0.85, 0.5)
	sounds["rifle"] = _gun(0.45, 150.0, 12.0, 65.0, 0.75, 0.58)
	sounds["m4"] = _gun(0.42, 165.0, 13.0, 70.0, 0.7, 0.62)
	sounds["shotgun"] = _gun(0.75, 85.0, 6.5, 35.0, 1.0, 0.4)
	sounds["scout"] = _gun(0.9, 130.0, 6.0, 55.0, 0.9, 0.5)
	sounds["sniper"] = _gun(1.3, 75.0, 4.0, 40.0, 1.0, 0.45)
	sounds["knife"] = _make(0.25, func(t: float) -> float:
		return _noise() * 0.4 * sin(PI * minf(t / 0.25, 1.0)), 0.35)
	sounds["knife_hit"] = _make(0.2, func(t: float) -> float:
		return (_noise() * 0.5 + sin(TAU * 110.0 * t)) * 0.5 * exp(-t * 22.0), 0.4)
	sounds["dry"] = _make(0.05, func(t: float) -> float:
		return (sin(TAU * 2600.0 * t) * 0.3 + _noise() * 0.2) * exp(-t * 130.0))
	sounds["mag_out"] = _clicks([0.0, 0.05], 0.2, 1800.0)
	sounds["mag_in"] = _clicks([0.0, 0.07], 0.25, 1300.0)
	sounds["bolt"] = _clicks([0.0, 0.12], 0.3, 2200.0)
	sounds["deploy"] = _clicks([0.0, 0.09], 0.2, 1600.0)
	sounds["zoom"] = _clicks([0.0], 0.06, 3000.0)
	sounds["pickup"] = _clicks([0.0, 0.06, 0.1], 0.2, 1500.0)
	sounds["buy"] = _make(0.3, func(t: float) -> float:
		var f := 1320.0 if t < 0.1 else 1760.0
		return sin(TAU * f * t) * 0.18 * exp(-fmod(t, 0.1) * 18.0))
	sounds["denied"] = _make(0.2, func(t: float) -> float:
		return signf(sin(TAU * 140.0 * t)) * 0.12 * exp(-t * 8.0))

	# Hits.
	sounds["hit_flesh"] = _make(0.18, func(t: float) -> float:
		return (_noise() * 0.6 + sin(TAU * 95.0 * t) * 0.7) * exp(-t * 28.0) * 0.6, 0.35)
	sounds["hit_helmet"] = _make(0.4, func(t: float) -> float:
		return (sin(TAU * 2400.0 * t) * 0.4 + sin(TAU * 3700.0 * t) * 0.25 + _noise() * 0.3 * exp(-t * 80.0)) * exp(-t * 11.0))
	sounds["hit_head"] = _make(0.25, func(t: float) -> float:
		return (_noise() * 0.8 + sin(TAU * 70.0 * t)) * exp(-t * 20.0) * 0.6, 0.3)
	sounds["impact"] = _make(0.1, func(t: float) -> float:
		return _noise() * 0.35 * exp(-t * 45.0), 0.6)
	sounds["ricochet"] = _make(0.35, func(t: float) -> float:
		return (_noise() * 0.3 * exp(-t * 60.0) + _sweep(t, 3400.0, 1800.0, 0.35) * 0.12 * exp(-t * 7.0)))

	# Moving.
	sounds["step1"] = _step(0.9)
	sounds["step2"] = _step(1.15)
	sounds["shell"] = _make(0.25, func(t: float) -> float:
		var s := 0.0
		for start: float in [0.0, 0.07, 0.13]:
			if t >= start:
				s += sin(TAU * 5200.0 * (t - start)) * exp(-(t - start) * 60.0) * (1.0 - start * 4.0)
		return s * 0.25)
	sounds["land"] = _make(0.2, func(t: float) -> float:
		return (_noise() * 0.6 + sin(TAU * 60.0 * t)) * exp(-t * 25.0) * 0.6, 0.25)

	# Grenades and the bomb.
	sounds["throw"] = _make(0.3, func(t: float) -> float:
		return _noise() * 0.3 * sin(PI * minf(t / 0.3, 1.0)), 0.3)
	sounds["bounce"] = _make(0.12, func(t: float) -> float:
		return (sin(TAU * 900.0 * t) * 0.3 + _noise() * 0.2) * exp(-t * 40.0))
	sounds["explode"] = _boom(1.6, 1.0)
	sounds["bomb_explode"] = _boom(3.0, 1.3)
	sounds["flashbang"] = _make(0.6, func(t: float) -> float:
		return _crush(_noise() * exp(-t * 25.0) + sin(TAU * 3100.0 * t) * 0.2 * exp(-t * 5.0), 2.5) * 0.8)
	sounds["smoke"] = _make(2.5, func(t: float) -> float:
		return _noise() * 0.25 * minf(t * 8.0, 1.0) * exp(-t * 0.9), 0.5)
	sounds["ring"] = _make(3.0, func(t: float) -> float:
		return sin(TAU * 3520.0 * t) * 0.14 * exp(-t * 1.1))
	sounds["beep"] = _make(0.09, func(t: float) -> float:
		return sin(TAU * 1900.0 * t) * 0.3 * minf(t * 400.0, 1.0) * exp(-t * 12.0))
	sounds["key"] = _make(0.06, func(t: float) -> float:
		return sin(TAU * 1250.0 * t) * 0.2 * exp(-t * 40.0))
	sounds["planted"] = _make(1.2, func(t: float) -> float:
		var f := 880.0 if fmod(t, 0.3) < 0.15 else 660.0
		return signf(sin(TAU * f * t)) * 0.1 * exp(-t * 1.2))
	sounds["defuse"] = _clicks([0.0, 0.1, 0.25], 0.35, 2000.0)
	sounds["defused"] = _notes([988.0, 1319.0, 1760.0], 0.1, 0.18)

	# Rounds and people.
	sounds["radio"] = _make(0.45, func(t: float) -> float:
		var beep := sin(TAU * (1100.0 if t < 0.2 else 1400.0) * t) * 0.15 * float(fmod(t, 0.2) < 0.12)
		return beep + _noise() * 0.05 * exp(-t * 6.0))
	sounds["win"] = _notes([523.0, 659.0, 784.0, 1047.0], 0.13, 0.2)
	sounds["lose"] = _notes([659.0, 523.0, 440.0, 330.0], 0.16, 0.18)
	sounds["pain"] = _make(0.25, func(t: float) -> float:
		return _voice(t, _sweep_hz(t, 170.0, 130.0, 0.25)) * sin(PI * minf(t / 0.25, 1.0)) * 0.5)
	sounds["death"] = _make(0.7, func(t: float) -> float:
		return _voice(t, _sweep_hz(t, 180.0, 80.0, 0.7)) * sin(PI * minf(t / 0.7, 1.0)) * 0.55)

	for i in 10:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	for i in 28:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 9.0
		player.max_distance = 90.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.attenuation_filter_cutoff_hz = 9000.0
		add_child(player)
		players_3d.append(player)


func play(sound: String, volume_db := 0.0) -> void:
	var pick := players[0]
	for player in players:
		if not player.playing:
			pick = player
			break
	pick.stream = sounds[sound]
	pick.volume_db = volume_db
	pick.pitch_scale = rng.randf_range(0.97, 1.03)
	pick.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0) -> void:
	var pick := players_3d[0]
	for player in players_3d:
		if not player.playing:
			pick = player
			break
	pick.stream = sounds[sound]
	pick.volume_db = volume_db
	pick.pitch_scale = rng.randf_range(0.96, 1.04)
	pick.global_position = pos
	pick.play()


## The campaign's sounds: creatures, machines, doors, alarms, the world around. Made the first time a
## mission starts, so the match doesn't wait for them.
func load_campaign() -> void:
	if sounds.has("screech"):
		return
	sounds["screech"] = _make(0.9, func(t: float) -> float:
		var f := _sweep_hz(t, 900.0, 520.0, 0.9) * (1.0 + sin(TAU * 31.0 * t) * 0.08)
		return _crush(_voice(t, f) * 1.6 + _noise() * 0.25, 2.5) * sin(PI * minf(t / 0.9, 1.0)) * 0.6)
	sounds["moan"] = _make(1.6, func(t: float) -> float:
		return _voice(t, 95.0 + sin(TAU * 1.3 * t) * 12.0) * sin(PI * t / 1.6) * 0.45, 0.4)
	sounds["growl"] = _make(1.4, func(t: float) -> float:
		return _crush(_voice(t, 55.0 + sin(TAU * 7.0 * t) * 8.0) + _noise() * 0.3, 2.0) * sin(PI * t / 1.4) * 0.5, 0.3)
	sounds["roar"] = _make(1.8, func(t: float) -> float:
		return _crush(_voice(t, _sweep_hz(t, 140.0, 70.0, 1.8)) * 1.5 + _noise() * 0.5, 3.0) * sin(PI * minf(t / 1.8, 1.0)) * 0.7, 0.35)
	sounds["behemoth"] = _make(3.0, func(t: float) -> float:
		return _crush(_voice(t, _sweep_hz(t, 70.0, 38.0, 3.0)) * 2.0 + _noise() * 0.6 + sin(TAU * 32.0 * t), 3.0) * sin(PI * minf(t / 3.0, 1.0)) * 0.8, 0.25)
	sounds["stomp"] = _boom(0.7, 1.6)
	sounds["claw_hit"] = _make(0.25, func(t: float) -> float:
		return (_noise() * 0.8 * exp(-t * 18.0) + sin(TAU * 80.0 * t) * 0.6 * exp(-t * 20.0)) * 0.7, 0.5)
	sounds["glass"] = _make(0.9, func(t: float) -> float:
		var s := 0.0
		for f: float in [2900.0, 4100.0, 5300.0, 6700.0]:
			s += sin(TAU * f * t + f) * 0.12 * exp(-t * (6.0 + f / 900.0))
		return s + _noise() * 0.5 * exp(-t * 12.0))
	sounds["door"] = _make(1.2, func(t: float) -> float:
		return (_noise() * 0.25 + sin(TAU * 55.0 * t) * 0.4) * sin(PI * t / 1.2) * 0.6 + sin(TAU * 1400.0 * t) * 0.15 * exp(-maxf(t - 1.05, 0.0) * 40.0) * float(t > 1.05), 0.4)
	sounds["power_on"] = _make(1.5, func(t: float) -> float:
		return (sin(TAU * _sweep_hz(t, 40.0, 120.0, 1.5) * t) * 0.5 + _noise() * 0.1) * minf(t * 2.0, 1.0) * exp(-maxf(t - 1.0, 0.0) * 5.0), 0.5)
	sounds["objective"] = _notes([392.0, 523.0, 659.0], 0.12, 0.16)
	sounds["intel"] = _notes([784.0, 988.0, 1175.0, 1568.0], 0.08, 0.14)
	sounds["use_done"] = _notes([660.0, 990.0], 0.08, 0.15)
	sounds["alarm"] = _make(1.2, func(t: float) -> float:
		return signf(sin(TAU * (620.0 if fmod(t, 0.6) < 0.3 else 480.0) * t)) * 0.12 * float(t < 1.1), 0.6)
	sounds["steam"] = _make(1.4, func(t: float) -> float:
		return _noise() * 0.5 * minf(t * 20.0, 1.0) * exp(-maxf(t - 1.0, 0.0) * 8.0))
	sounds["zap"] = _make(0.5, func(t: float) -> float:
		return _crush(_noise() * float(randf() < 0.5) + signf(sin(TAU * 60.0 * t)) * 0.3, 3.0) * exp(-t * 6.0) * 0.6)
	sounds["rumble"] = _make(2.5, func(t: float) -> float:
		return (sin(TAU * 30.0 * t) * 0.6 + _noise() * 0.4) * sin(PI * t / 2.5) * 0.7, 0.15)
	sounds["drone"] = _make(1.9, func(t: float) -> float:
		return (sin(TAU * 180.0 * t) * 0.3 + sin(TAU * 361.0 * t) * 0.2) * (0.8 + 0.2 * sin(TAU * 13.0 * t)) * 0.35)
	sounds["lock_on"] = _notes([1500.0, 1500.0, 2000.0], 0.07, 0.12)
	sounds["dash"] = _make(0.4, func(t: float) -> float:
		return _noise() * 0.6 * sin(PI * t / 0.4) + _sweep(t, 300.0, 1400.0, 0.4) * 0.15 * exp(-t * 4.0), 0.4)
	sounds["first"] = _make(1.2, func(t: float) -> float:
		return _crush(_voice(t, 110.0) * (1.0 + sin(TAU * 90.0 * t)) * 0.8, 2.5) * sin(PI * t / 1.2) * 0.5, 0.5)
	sounds["splash"] = _make(0.3, func(t: float) -> float:
		return _noise() * 0.5 * exp(-t * 14.0), 0.35)
	# Loops: the air of each place.
	sounds["wind"] = _loop(6.0, func(t: float) -> float:
		return _noise() * 0.35 * (0.55 + 0.45 * sin(TAU * t / 6.0)), 0.03)
	sounds["hum"] = _loop(4.0, func(t: float) -> float:
		return (sin(TAU * 60.0 * t) * 0.25 + sin(TAU * 120.0 * t) * 0.12 + _noise() * 0.05) * 0.8, 0.3)
	sounds["drips"] = _loop(5.0, func(t: float) -> float:
		var drop := 0.0
		for at: float in [0.7, 1.9, 2.6, 3.8, 4.4]:
			if t > at:
				drop += sin(TAU * 1800.0 * (t - at)) * exp(-(t - at) * 40.0) * 0.3
		return drop + _noise() * 0.03, 0.8)


func _loop(duration: float, generator: Callable, smooth := 1.0) -> AudioStreamWAV:
	var wav := _make(duration, generator, smooth)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(duration * RATE)
	return wav


# --- Building sounds -----------------------------------------------------------------------

## Samples `generator` over `duration` seconds; `smooth` below 1 runs it through a low-pass filter.
func _make(duration: float, generator: Callable, smooth := 1.0) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var low := 0.0
	for i in count:
		low += (generator.call(float(i) / RATE) - low) * smooth
		data.encode_s16(i * 2, int(clampf(low, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav


## A gunshot: a crack of noise, a body tone that falls in pitch, and a tail.
func _gun(duration: float, body_hz: float, decay: float, crack: float, bass: float, smooth: float) -> AudioStreamWAV:
	return _make(duration, func(t: float) -> float:
		var n := _noise()
		var snap := n * exp(-t * crack)
		var body := sin(TAU * _sweep_hz(t, body_hz, body_hz * 0.45, duration) * t) * exp(-t * decay * 1.4) * bass
		var tail := n * 0.3 * exp(-t * decay)
		return _crush(snap + body + tail, 2.4) * 0.85 * minf(t * 3000.0, 1.0), smooth)


## Short metallic clicks at the given times.
func _clicks(times: Array, duration: float, hz: float) -> AudioStreamWAV:
	return _make(duration, func(t: float) -> float:
		var s := 0.0
		for start: float in times:
			if t >= start:
				var k := t - start
				s += (_noise() * 0.4 + sin(TAU * hz * k) * 0.25) * exp(-k * 90.0)
		return s * 0.8)


func _step(pitch: float) -> AudioStreamWAV:
	return _make(0.14, func(t: float) -> float:
		return (_noise() * 0.5 * exp(-t * 35.0) + sin(TAU * 75.0 * pitch * t) * 0.6 * exp(-t * 30.0)) * 0.5, 0.3)


func _boom(duration: float, size: float) -> AudioStreamWAV:
	return _make(duration, func(t: float) -> float:
		var low := sin(TAU * _sweep_hz(t, 70.0 / size, 28.0, duration) * t) * 0.8
		return _crush((_noise() * 0.9 + low) * exp(-t * 3.2 / size), 2.2) * 0.85 * minf(t * 300.0, 1.0), 0.35)


func _notes(freqs: Array, step: float, level: float) -> AudioStreamWAV:
	var duration := step * freqs.size() + 0.35
	return _make(duration, func(t: float) -> float:
		var i := mini(int(t / step), freqs.size() - 1)
		var k := t - i * step
		var f: float = freqs[i]
		var fade := 3.0 if i == freqs.size() - 1 else 10.0
		return (sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.3) * level * exp(-k * fade))


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## A soft clip, for the gritty edge on shots and explosions.
static func _crush(x: float, drive: float) -> float:
	return tanh(x * drive) / tanh(drive)


static func _sweep_hz(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return lerpf(from_hz, to_hz, minf(t / duration, 1.0))


static func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))


## A rough grunt: a buzz filtered through two vowel formants.
static func _voice(t: float, f: float) -> float:
	var saw := fmod(f * t, 1.0) * 2.0 - 1.0
	return saw * 0.3 * (1.0 + sin(TAU * 650.0 * t) * 0.6 + sin(TAU * 1050.0 * t) * 0.3)
