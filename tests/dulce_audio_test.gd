extends SceneTree

## Dulce's synthesized cues and her event-to-caption table (DESIGN §9.5, §9.6).
##
## Every cue builds, is short and is neither silent nor clipped; and every
## event DESIGN §9.5 lists gets an audio caption, so a player who cannot hear
## still learns it happened.

const DulceAudio = preload("res://games/dulces_adventure/dulce_audio.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_cues()
	_test_captions()
	_test_pitch()
	_test_quiet_events()
	_finish()


func _test_cues() -> void:
	var bank := DulceAudio.cues()
	_expect(bank.size() == DulceAudio.CUES.size(), "Every cue is built.")
	for cue in DulceAudio.CUES:
		var stream: AudioStreamWAV = bank.get(cue)
		if stream == null:
			_failures.append("Cue '%s' is missing." % cue)
			continue
		var seconds := stream.data.size() / 2.0 / stream.mix_rate
		_expect(seconds >= 0.04 and seconds <= 0.8, "'%s' is short (%.2f s)." % [cue, seconds])
		var peak := 0
		for index in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(index)))
		_expect(peak > 6000 and peak < 32767, "'%s' is audible and never clips (%d)." % [cue, peak])
		_expect(DulceAudio.cue_stream(cue).data == stream.data, "'%s' builds the same every time." % cue)


## DESIGN §9.5's list: hit, heart lost, heart gained, Full gained and lost,
## stomp chain, biome reached and run over.
func _test_captions() -> void:
	var captioned := [
		{"kind": "hurt", "cause": "pigeon", "hearts": 2},
		{"kind": "hurt", "cause": "pit", "hearts": 0},
		{"kind": "shrink", "cause": "gnome"},
		{"kind": "heart", "hearts": 3},
		{"kind": "heart_capped", "points": 1000},
		{"kind": "full"},
		{"kind": "stomp", "chain": 2},
		{"kind": "biome", "title": "the Park"},
		{"kind": "run_over", "distance": 412},
	]
	for event: Dictionary in captioned:
		var cue := DulceAudio.cue_for(event)
		_expect(not str(cue["caption"]).is_empty(), "'%s' is captioned." % event["kind"])
		_expect(cue["cue"] == "" or cue["cue"] in DulceAudio.CUES,
			"'%s' plays a cue that exists." % event["kind"])
	_expect(DulceAudio.cue_for({"kind": "hurt", "cause": "pigeon", "hearts": 2})["caption"]
		.contains("2 left"), "A lost heart says how many are left.")
	_expect(DulceAudio.cue_for({"kind": "hurt", "cause": "pit", "hearts": 1})["caption"]
		.begins_with("Fell in!"), "A pit is captioned as a fall, not a bite.")
	_expect(DulceAudio.cue_for({"kind": "run_over", "distance": 412})["caption"].contains("412 m"),
		"Run over says how far she got.")


func _test_pitch() -> void:
	var standing := DulceAudio.cue_for({"kind": "jump", "speed": State.JUMP_SPEED})
	var running := DulceAudio.cue_for({
		"kind": "jump", "speed": State.jump_speed_at(State.RUN_SPEED),
	})
	_expect(running["pitch"] > standing["pitch"], "A running jump yips higher.")
	var last := 0.0
	for chain in range(1, 12):
		var pitch: float = DulceAudio.cue_for({"kind": "stomp", "chain": chain})["pitch"]
		_expect(pitch >= last, "A stomp chain's boing climbs (%d)." % chain)
		last = pitch
	_expect(last == DulceAudio.STOMP_PITCH_CAP, "...up to a cap, so it never squeaks.")


## Visible, frequent events stay quiet in captions so the important ones read.
func _test_quiet_events() -> void:
	for event: Dictionary in [
		{"kind": "jump", "speed": State.JUMP_SPEED}, {"kind": "eat", "item": State.BURGER},
		{"kind": "stomp", "chain": 1}, {"kind": "land", "speed": 1200.0},
	]:
		_expect(str(DulceAudio.cue_for(event)["caption"]).is_empty(),
			"'%s' is visible and frequent, so it is not captioned." % event["kind"])
	_expect(DulceAudio.cue_for({"kind": "land", "speed": 200.0})["cue"] == "",
		"Ordinary footfall landings are silent.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dulce audio tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
