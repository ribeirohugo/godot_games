extends Node
## Synthesizes the game's sound effects and its music in code, so the project needs no audio files.
## play() is for the player's own sounds, play_at() for sounds that come from a place in the level.
## The music, a heavy looping riff, is built on a worker thread so the game doesn't stall.

const RATE := 22050
const MUSIC_BPM := 132.0
const MUSIC_BARS := 8

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var players_3d: Array[AudioStreamPlayer3D] = []
var music_player: AudioStreamPlayer
var music_task := -1
var music_data := PackedByteArray()
var want_music := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 1234
	sounds["click"] = _make(0.04, func(t: float) -> float:
		return sin(TAU * 700.0 * t) * 0.2 * exp(-t * 90.0))
	sounds["move"] = _make(0.03, func(t: float) -> float:
		return sin(TAU * 1100.0 * t) * 0.08 * exp(-t * 140.0))

	# Weapons.
	sounds["hammer"] = _make(0.22, func(t: float) -> float:
		return _noise() * 0.25 * sin(PI * minf(t / 0.22, 1.0)) * (0.4 + t * 3.0))
	sounds["hammer_hit"] = _make(0.3, func(t: float) -> float:
		return (sin(TAU * 70.0 * t) * 0.6 + _noise() * 0.5 * exp(-t * 40.0)) * 0.6 * exp(-t * 14.0))
	sounds["hammer_wall"] = _make(0.35, func(t: float) -> float:
		return (sin(TAU * 1250.0 * t) * 0.3 + sin(TAU * 1830.0 * t) * 0.2 + _noise() * 0.4 * exp(-t * 60.0)) * 0.5 * exp(-t * 11.0))
	sounds["rivet"] = _make(0.22, func(t: float) -> float:
		return (_noise() * exp(-t * 35.0) * 0.7 + sin(TAU * 160.0 * t) * exp(-t * 25.0) * 0.6 + sin(TAU * 2400.0 * t) * exp(-t * 90.0) * 0.2) * 0.7)
	sounds["scatter"] = _make(0.7, func(t: float) -> float:
		var blast := _crush(_noise() * exp(-t * 9.0) * 0.9 + sin(TAU * _sweep_hz(t, 110.0, 45.0, 0.3) * t) * exp(-t * 8.0) * 0.8, 1.8) * 0.75
		var pump := _noise() * 0.15 * exp(-(t - 0.45) * (t - 0.45) * 900.0)  # the pump racking back
		return blast + pump)
	sounds["slag"] = _make(0.55, func(t: float) -> float:
		return (_sweep(t, 90.0, 380.0, 0.55) * 0.5 + _noise() * 0.35) * exp(-t * 5.0) * minf(t * 60.0, 1.0))
	sounds["dry"] = _make(0.06, func(t: float) -> float:
		return (sin(TAU * 2200.0 * t) * 0.3 + _noise() * 0.2) * exp(-t * 120.0))
	sounds["switch"] = _make(0.14, func(t: float) -> float:
		var click := exp(-t * 200.0) + exp(-maxf(t - 0.08, 0.0) * 200.0) * float(t > 0.08)
		return (_noise() * 0.3 + sin(TAU * 1500.0 * t) * 0.2) * click)
	sounds["explode"] = _make(1.3, func(t: float) -> float:
		var low := sin(TAU * _sweep_hz(t, 70.0, 30.0, 1.0) * t) * 0.7
		return _crush((_noise() * 0.9 + low) * exp(-t * 3.5), 2.0) * 0.8 * minf(t * 200.0, 1.0))
	sounds["fizzle"] = _make(0.35, func(t: float) -> float:
		return _noise() * 0.35 * exp(-t * 10.0) * (0.6 + 0.4 * sin(TAU * 40.0 * t)))
	sounds["fireball"] = _make(0.5, func(t: float) -> float:
		return (_noise() * 0.5 + _sweep(t, 300.0, 120.0, 0.5) * 0.3) * sin(PI * minf(t / 0.5, 1.0)) * 0.6)

	# Demons.
	sounds["growl_husk"] = _growl(0.9, 85.0, 60.0, 0.5)
	sounds["growl_cinder"] = _make(0.8, func(t: float) -> float:
		return (_noise() * 0.6 + _sweep(t, 520.0, 260.0, 0.8) * 0.3) * sin(PI * minf(t / 0.8, 1.0)) * 0.5 * (0.7 + 0.3 * sin(TAU * 18.0 * t)))
	sounds["growl_brute"] = _growl(1.1, 58.0, 40.0, 0.7)
	sounds["growl_boss"] = _growl(1.8, 42.0, 30.0, 0.9)
	sounds["pain_small"] = _growl(0.3, 150.0, 110.0, 0.5)
	sounds["pain_big"] = _growl(0.4, 80.0, 60.0, 0.6)
	sounds["death_small"] = _growl(0.9, 140.0, 50.0, 0.6)
	sounds["death_big"] = _growl(1.6, 70.0, 25.0, 0.8)
	sounds["claw"] = _make(0.18, func(t: float) -> float:
		return _noise() * 0.35 * sin(PI * minf(t / 0.18, 1.0)))
	sounds["claw_hit"] = _make(0.25, func(t: float) -> float:
		return (_noise() * 0.6 + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 16.0) * 0.7)

	# The player.
	sounds["player_pain"] = _make(0.28, func(t: float) -> float:
		var f := _sweep_hz(t, 190.0, 140.0, 0.28)
		return _voice(t, f) * sin(PI * minf(t / 0.28, 1.0)) * 0.55)
	sounds["player_death"] = _make(1.2, func(t: float) -> float:
		var f := _sweep_hz(t, 210.0, 70.0, 1.2)
		return _voice(t, f) * sin(PI * minf(t / 1.2, 1.0)) * 0.6)
	sounds["sizzle"] = _make(0.35, func(t: float) -> float:
		return _noise() * 0.3 * exp(-t * 6.0) * (0.5 + 0.5 * sin(TAU * 60.0 * t)))
	sounds["pickup"] = _make(0.16, func(t: float) -> float:
		var f := 880.0 if t < 0.06 else 1320.0
		return sin(TAU * f * t) * 0.22 * exp(-fmod(t, 0.06) * 20.0))
	sounds["weapon_pickup"] = _make(0.45, func(t: float) -> float:
		var chk := _noise() * (exp(-t * 60.0) + exp(-maxf(t - 0.15, 0.0) * 60.0) * float(t > 0.15)) * 0.6
		return chk + sin(TAU * 660.0 * t) * 0.15 * exp(-maxf(t - 0.25, 0.0) * 12.0) * float(t > 0.25))
	sounds["key"] = _make(0.7, func(t: float) -> float:
		var notes := [784.0, 988.0, 1175.0]
		var i := mini(int(t / 0.1), 2)
		return sin(TAU * notes[i] * t) * 0.2 * exp(-(t - i * 0.1) * (4.0 if i == 2 else 15.0)))
	sounds["door"] = _make(0.8, func(t: float) -> float:
		var motor := _sweep(t, 70.0, 95.0, 0.8) * 0.4 + _noise() * 0.25
		return _crush(motor, 1.5) * sin(PI * minf(t / 0.8, 1.0)) * 0.5 + _noise() * exp(-maxf(t - 0.7, 0.0) * 40.0) * float(t > 0.7) * 0.3)
	sounds["locked"] = _make(0.3, func(t: float) -> float:
		return signf(sin(TAU * 110.0 * t)) * 0.18 * (1.0 if fmod(t, 0.15) < 0.11 else 0.0))
	sounds["exit"] = _make(1.4, func(t: float) -> float:
		var s := 0.0
		for f: float in [220.0, 277.0, 330.0, 440.0]:
			s += sin(TAU * f * t) * 0.09
		return s * minf(t * 10.0, 1.0) * exp(-t * 1.8))

	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	for i in 16:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 6.0
		player.max_distance = 55.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		players_3d.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -9.0
	add_child(music_player)
	music_task = WorkerThreadPool.add_task(_build_music)


func play(sound: String) -> void:
	for player in players:
		if not player.playing:
			player.stream = sounds[sound]
			player.play()
			return
	players[0].stream = sounds[sound]
	players[0].play()


func play_at(sound: String, pos: Vector3) -> void:
	var pick := players_3d[0]
	for player in players_3d:
		if not player.playing:
			pick = player
			break
	pick.stream = sounds[sound]
	pick.global_position = pos
	pick.play()


## Starts or stops the music. It begins once the worker thread has finished writing it.
func set_music(on: bool) -> void:
	want_music = on
	if not on:
		music_player.stop()
	elif music_player.stream != null and not music_player.playing:
		music_player.play()


func _process(_delta: float) -> void:
	if music_task >= 0 and WorkerThreadPool.is_task_completed(music_task):
		WorkerThreadPool.wait_for_task_completion(music_task)
		music_task = -1
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.data = music_data
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = music_data.size() / 2
		music_player.stream = wav
		if want_music:
			music_player.play()


func _exit_tree() -> void:
	if music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(music_task)


# --- Building sounds -----------------------------------------------------------------------

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
	wav.data = data
	return wav


## A demon's growl: a buzzing tone sliding down, roughened with noise and a wobble.
func _growl(duration: float, from_hz: float, to_hz: float, grit: float) -> AudioStreamWAV:
	return _make(duration, func(t: float) -> float:
		var f := _sweep_hz(t, from_hz, to_hz, duration) * (1.0 + 0.06 * sin(TAU * 7.0 * t))
		var buzz := fmod(f * t, 1.0) * 2.0 - 1.0
		var tone := buzz * (1.0 - grit * 0.5) + _noise() * grit * 0.6 + sin(TAU * f * 2.0 * t) * 0.3
		return _crush(tone, 2.0) * sin(PI * minf(t / duration, 1.0)) * 0.55)


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## A soft clip, for the gritty edge on explosions and growls.
static func _crush(x: float, drive: float) -> float:
	return tanh(x * drive) / tanh(drive)


## Instant frequency of a slide from `from_hz` to `to_hz` over `duration`.
static func _sweep_hz(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return lerpf(from_hz, to_hz, minf(t / duration, 1.0))


## Sine wave whose pitch slides from `from_hz` to `to_hz` over `duration`.
static func _sweep(t: float, from_hz: float, to_hz: float, duration: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))


## A rough "ugh": a buzz filtered through two vowel formants.
static func _voice(t: float, f: float) -> float:
	var saw := fmod(f * t, 1.0) * 2.0 - 1.0
	return saw * 0.3 * (1.0 + sin(TAU * 700.0 * t) * 0.6 + sin(TAU * 1100.0 * t) * 0.3)


# --- Music ---------------------------------------------------------------------------------

## A palm-muted metal riff in E with kick and snare, MUSIC_BARS bars long, looping.
## Runs on a worker thread, so it only touches its own locals and music_data.
func _build_music() -> void:
	var beat := 60.0 / MUSIC_BPM
	var eighth := beat / 2.0
	var count := int(MUSIC_BARS * 4 * beat * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	# Semitones above low E for each eighth note of a two-bar phrase; -1 is a rest.
	var riff := [0, 0, 12, 0, 0, 10, 0, 7, 0, 0, 5, 0, 6, 0, 7, 3,
			0, 0, 12, 0, 0, 10, 0, 7, 8, 8, 7, 7, 5, 5, 3, 2]
	var noise := RandomNumberGenerator.new()
	noise.seed = 99
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var step := int(t / eighth)
		var in_step := t - step * eighth
		var bar := int(t / (beat * 4.0))
		var note: int = riff[step % riff.size()]
		if bar >= MUSIC_BARS - 2:
			note += 5 if bar == MUSIC_BARS - 2 else 3  # climb for the last two bars
		var f := 82.41 * pow(2.0, note / 12.0)
		phase = fmod(phase + f / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		var fifth := fmod(phase * 1.5, 1.0) * 2.0 - 1.0
		var palm := exp(-in_step * 14.0)
		var guitar := tanh((saw + fifth * 0.7) * 5.0) * 0.28 * (0.35 + 0.65 * palm)
		# A one-pole low-pass takes the fizz off the distortion.
		low += (guitar - low) * 0.35
		var in_beat := fmod(t, beat)
		var beat_n := int(t / beat) % 4
		var kick := sin(TAU * (50.0 + 90.0 * exp(-in_beat * 30.0)) * in_beat) * exp(-in_beat * 9.0) * 0.55
		if step % 2 == 1 and (step % 8 == 3 or step % 8 == 7):
			var in_eighth := in_step
			kick += sin(TAU * (50.0 + 90.0 * exp(-in_eighth * 30.0)) * in_eighth) * exp(-in_eighth * 9.0) * 0.4
		var snare := 0.0
		if beat_n == 1 or beat_n == 3:
			snare = (noise.randf_range(-1.0, 1.0) * 0.35 + sin(TAU * 190.0 * in_beat) * 0.15) * exp(-in_beat * 14.0)
		var hat := noise.randf_range(-1.0, 1.0) * 0.06 * exp(-in_step * 60.0)
		var value := clampf(low + kick + snare + hat, -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 26000.0))
	music_data = data
