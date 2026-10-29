extends RefCounted

## Dulce's sounds, synthesized at load time, and what each run event says.
##
## Original short PCM cues keep the game self-contained, like Cube Trials'
## `cube_audio.gd`: yips, pats, boings, munches, a gulp, a whine, a chime, a
## fanfare and a tumble. `cue_for()` is the one place that decides which
## sound a model event makes and which events also get an audio caption, so
## the accessibility rule (every meaningful sound-only event is captioned) is
## testable headless (DESIGN §9.5, §9.6). Touches no autoload.

const State = preload("res://games/dulces_adventure/run_state.gd")
const Stages = preload("res://games/dulces_adventure/stages.gd")

const RATE := 22050
## Peak level, as a fraction of 16-bit full scale.
const LEVEL := 0.42
const CUES: Array[String] = [
	"yip", "land", "boing", "munch", "gulp", "whine", "chime", "shrink",
	"fanfare", "tumble", "bump", "pop",
]
## A stomp chain climbs this much in pitch per link, up to `STOMP_PITCH_CAP`.
const STOMP_PITCH_STEP := 0.12
const STOMP_PITCH_CAP := 1.6
## Landings softer than this are part of running and make no sound.
const QUIET_LANDING := 700.0


static func cues() -> Dictionary[String, AudioStreamWAV]:
	var bank: Dictionary[String, AudioStreamWAV] = {}
	for cue in CUES:
		bank[cue] = cue_stream(cue)
	return bank


## The sound, pitch and caption for one `run_state.gd` event; an empty `cue`
## means silent and an empty `caption` means the event is visible enough.
static func cue_for(event: Dictionary) -> Dictionary:
	var result := {"cue": "", "pitch": 1.0, "volume_db": -6.0, "caption": ""}
	match str(event.get("kind", "")):
		"jump":
			# Running jumps yip a little higher than standing ones.
			var strength := inverse_lerp(State.JUMP_SPEED, State.jump_speed_at(State.RUN_SPEED),
				float(event.get("speed", State.JUMP_SPEED)))
			result["cue"] = "yip"
			result["pitch"] = 1.0 + 0.15 * clampf(strength, 0.0, 1.0)
		"land":
			if float(event.get("speed", 0.0)) > QUIET_LANDING:
				result["cue"] = "land"
				result["volume_db"] = -10.0
		"stomp":
			var chain := int(event.get("chain", 1))
			result["cue"] = "boing"
			result["pitch"] = minf(1.0 + STOMP_PITCH_STEP * (chain - 1), STOMP_PITCH_CAP)
			if chain >= 2:
				result["caption"] = "Boing! Stomp chain x%d" % chain
		"eat":
			result["cue"] = "gulp" if event.get("item", "") == State.BIG_BURGER else "munch"
			result["volume_db"] = -9.0
		"full":
			result["caption"] = "Full! The next hit costs Full, not a heart."
		"shrink":
			result["cue"] = "shrink"
			result["caption"] = "%s Full is gone; every heart kept." % _ouch(event)
		"hurt":
			var hearts := int(event.get("hearts", 0))
			result["cue"] = "whine"
			result["caption"] = "%s Last heart lost." % _ouch(event) if hearts <= 0 \
				else "%s Heart lost, %d left." % [_ouch(event), hearts]
		"heart":
			result["cue"] = "chime"
			result["caption"] = "+1 heart: %d of %d." % [int(event.get("hearts", 0)), State.MAX_HEARTS]
		"heart_capped":
			result["cue"] = "chime"
			result["caption"] = "Hearts full: +%d points." % int(event.get("points", 0))
		"bump":
			result["cue"] = "bump"
			result["volume_db"] = -10.0
		"lunchbox":
			result["cue"] = "pop"
		"respawn":
			result["cue"] = "pop"
			result["pitch"] = 0.8
		"run_over":
			result["cue"] = "tumble"
			result["caption"] = "Run over at %d m." % int(event.get("distance", 0))
		"goal":
			result["cue"] = "fanfare"
			result["caption"] = "Stage clear in %s!" % Stages.time_text(float(event.get("time", 0.0)))
		"biome":
			result["cue"] = "fanfare"
			result["caption"] = "Welcome to %s!" % str(event.get("title", "somewhere new"))
	return result


static func _ouch(event: Dictionary) -> String:
	return "Fell in!" if event.get("cause", "") == "pit" else "Ouch!"


## One cue's samples, built the same way every time.
static func cue_stream(cue: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cue)
	match cue:
		"yip":
			samples = _sweep(0.085, 880.0, 1480.0, [1.0, 0.45, 0.2], 0.0, 0.0, 1.2)
			samples.append_array(_sweep(0.045, 1480.0, 1250.0, [1.0, 0.3], 0.0, 0.0, 2.0, 0.5))
		"land":
			samples = _mix(_noise(rng, 0.07, 0.15, 3.0), _sweep(0.07, 130.0, 90.0, [1.0], 0.0, 0.0, 2.0))
		"boing":
			samples = _sweep(0.24, 180.0, 420.0, [1.0, 0.5, 0.25], 18.0, 0.08, 1.4)
		"munch":
			for _bite in 3:
				samples.append_array(_noise(rng, 0.035, 0.5, 2.0))
				samples.append_array(_silence(0.025))
		"gulp":
			samples = _sweep(0.16, 520.0, 170.0, [1.0, 0.2], 9.0, 0.04, 1.2)
		"whine":
			samples = _sweep(0.34, 1150.0, 640.0, [1.0, 0.3, 0.1], 7.0, 0.03, 1.0)
		"chime":
			for note: float in [784.0, 1046.5, 1318.5]:
				samples.append_array(_sweep(0.11, note, note, [1.0, 0.0, 0.25], 0.0, 0.0, 2.5))
		"shrink":
			for note: float in [660.0, 523.25, 415.3]:
				samples.append_array(_sweep(0.07, note, note * 0.97, [1.0, 0.3], 0.0, 0.0, 1.5))
		"fanfare":
			for note: float in [523.25, 659.25, 783.99]:
				samples.append_array(_sweep(0.1, note, note, [1.0, 0.4, 0.2], 0.0, 0.0, 1.0))
			samples.append_array(_sweep(0.24, 1046.5, 1046.5, [1.0, 0.4, 0.2], 5.0, 0.01, 1.5))
		"tumble":
			samples = _sweep(0.55, 620.0, 190.0, [1.0, 0.35], 9.0, 0.12, 1.1)
		"bump":
			samples = _mix(_sweep(0.06, 160.0, 120.0, [1.0, 0.3], 0.0, 0.0, 2.0),
				_noise(rng, 0.05, 0.25, 4.0, 0.4))
		"pop":
			samples = _sweep(0.07, 300.0, 900.0, [1.0, 0.25], 0.0, 0.0, 1.5)
	return _wav(samples)


## A tone gliding from `from_hz` to `to_hz`, with optional vibrato, a 4 ms
## attack and a decay shaped by `decay_power`.
static func _sweep(
	duration: float, from_hz: float, to_hz: float, harmonics: Array, vibrato_hz: float,
	vibrato_depth: float, decay_power: float, gain := 1.0
) -> PackedFloat32Array:
	var count := roundi(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for index in count:
		var along := float(index) / count
		var hz := from_hz * pow(to_hz / from_hz, along)
		hz *= 1.0 + vibrato_depth * sin(TAU * vibrato_hz * index / RATE)
		phase += TAU * hz / RATE
		var wave := 0.0
		for harmonic in harmonics.size():
			wave += float(harmonics[harmonic]) * sin(phase * (harmonic + 1))
		samples[index] = wave * _envelope(index, count, decay_power) * gain
	return samples


## Filtered white noise: `smoothing` near 0 is dull, near 1 is bright.
static func _noise(
	rng: RandomNumberGenerator, duration: float, smoothing: float, decay_power: float,
	gain := 1.0
) -> PackedFloat32Array:
	var count := roundi(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var held := 0.0
	for index in count:
		held = lerpf(held, rng.randf_range(-1.0, 1.0), smoothing)
		samples[index] = held * 2.0 * _envelope(index, count, decay_power) * gain
	return samples


static func _silence(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(RATE * duration))
	return samples


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var longer := a if a.size() >= b.size() else b
	var shorter := b if a.size() >= b.size() else a
	var samples := longer.duplicate()
	for index in shorter.size():
		samples[index] += shorter[index]
	return samples


static func _envelope(index: int, count: int, decay_power: float) -> float:
	var attack := minf(float(index) / (RATE * 0.004), 1.0)
	return attack * pow(1.0 - float(index) / count, decay_power)


## Normalises to `LEVEL` and packs 16-bit mono PCM.
static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for sample in samples:
		peak = maxf(peak, absf(sample))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in samples.size():
		data.encode_s16(index * 2, roundi(samples[index] / peak * LEVEL * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
