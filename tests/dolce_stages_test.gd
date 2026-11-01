extends SceneTree

## Fixed-stage checks (DESIGN §5.5, owner decisions in TODO.md).
##
## Every stage is its own biome's chunks in order, about 300 m long, opening
## on the gate and ending on a goal the validator can reach. Clearing one
## opens the next; the stream lays a stage the same way whatever the seed; a
## scripted clear stops the clock and ends the run; and stage records only
## ever improve.

const Stages = preload("res://games/dolces_adventure/stages.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")
const LevelStream = preload("res://games/dolces_adventure/level_stream.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const Records = preload("res://games/dolces_adventure/run_records.gd")
const DolceModel = preload("res://games/dolces_adventure/world/dolce_model.gd")

var _failures := PackedStringArray()
var _path := "user://dolces_adventure_stages_test_%d.cfg" % Time.get_ticks_usec()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_every_stage()
	_test_unlock_chain()
	_test_stream_lays_the_stage()
	_test_scripted_clear()
	_test_records()
	_test_time_text()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	_finish()


func _test_every_stage() -> void:
	_expect(Stages.STAGES.size() == ChunkLibrary.Biome.size(), "One stage per biome.")
	for index in Stages.STAGES.size():
		var stage: Dictionary = Stages.STAGES[index]
		var id := str(stage["id"])
		_expect(int(stage["number"]) == index + 1, "%s is stage %d." % [id, index + 1])
		_expect(int(stage["biome"]) == ChunkLibrary.Biome.values()[index],
			"Stages run through the biomes in order (%s)." % id)
		var chunk_ids: Array = stage["chunks"]
		_expect(chunk_ids[0] == ChunkLibrary.gate_of(int(stage["biome"]))["id"],
			"%s opens on its biome's gate." % id)
		for chunk_id: String in chunk_ids:
			var chunk := ChunkLibrary.chunk_named(chunk_id)
			_expect(not chunk.is_empty(), "%s: chunk '%s' exists." % [id, chunk_id])
			if not chunk.is_empty():
				_expect(int(chunk["biome"]) == int(stage["biome"]),
					"%s only uses its own biome's chunks ('%s')." % [id, chunk_id])
		for at in range(1, chunk_ids.size()):
			_expect(chunk_ids[at] != chunk_ids[at - 1],
				"%s never repeats a chunk twice in a row ('%s')." % [id, chunk_ids[at]])
		var metres := Stages.length_m(stage)
		_expect(metres >= Stages.MIN_METRES and metres <= Stages.MAX_METRES,
			"%s is about 300 m (%.0f)." % [id, metres])
		_expect(Stages.food_total(stage) >= 30, "%s has food worth chasing (%d)." % [
			id, Stages.food_total(stage)])
		for problem in ChunkLibrary.route_problems(Stages.rows(stage), id):
			_failures.append(problem)
	for problem in ChunkLibrary.validate(ChunkLibrary.GOAL):
		_failures.append(problem)
	_expect(not ChunkLibrary.pool(ChunkLibrary.Biome.BACKYARD).has(ChunkLibrary.GOAL),
		"The goal is never drawn on an endless run.")


## Stage 1 is open; each later stage opens when the one before it is cleared.
func _test_unlock_chain() -> void:
	var previous_clear := ""
	for stage in Stages.STAGES:
		var level := {}
		for candidate: Dictionary in Options.LEVELS:
			if candidate["id"] == stage["id"]:
				level = candidate
		_expect(not level.is_empty(), "%s is in the level selector." % stage["id"])
		_expect(str(level.get("requires_achievement", "")) == previous_clear,
			"%s opens with %s." % [stage["id"], previous_clear if previous_clear else "nothing"])
		previous_clear = str(stage["clear_achievement"])
		_expect(previous_clear.begins_with("dolces_adventure_cleared_"),
			"Clear keys are permanent and prefixed (%s)." % previous_clear)
	var manifest := (load("res://games/dolces_adventure/game.gd") as GDScript).call(
		"manifest") as GameManifest
	for stage in Stages.STAGES:
		_expect(manifest.achievements.has(stage["clear_achievement"]),
			"Clearing %s is a registered achievement." % stage["id"])


func _test_stream_lays_the_stage() -> void:
	for stage in Stages.STAGES:
		var ids := []
		for seed_value in [1, 99]:
			var stream := LevelStream.new(seed_value, ChunkLibrary.Biome.BACKYARD, stage)
			var state := stream.start()
			var x := state.position.x
			for _hop in 200:
				x += 8.0 * Grid.TILE
				state.place(Vector2(x, state.position.y))
				stream.update(state, -INF)
			var laid := stream.placed.map(func(chunk: Dictionary) -> String: return chunk["id"])
			ids.append(laid)
			_expect(state.biome == int(stage["biome"]), "%s is played in its own biome." % stage["id"])
			_expect(is_finite(state.goal_x), "%s's run knows where the goal is." % stage["id"])
			_expect(stream.placed.back()["goal"] and stream.placed.back()["biome"] == stage["biome"],
				"%s ends on the goal, in its biome." % stage["id"])
		var expected: Array = stage["chunks"].duplicate()
		expected.append(ChunkLibrary.GOAL["id"])
		_expect(ids[0] == expected, "%s is laid exactly as authored, then nothing." % stage["id"])
		_expect(ids[0] == ids[1], "%s is the same whatever the seed." % stage["id"])


## Walks her across a stage's goal: the clock stops, the run ends after the
## celebration, she sits, and nothing else counts against her.
func _test_scripted_clear() -> void:
	var stage := Stages.find(Options.STAGE_BACKYARD)
	var stream := LevelStream.new(0, ChunkLibrary.Biome.BACKYARD, stage)
	var state := stream.start()
	while not is_finite(state.goal_x):
		state.place(Vector2(stream.next_column * Grid.TILE, state.position.y))
		stream.update(state, -INF)
	state.place(Vector2(state.goal_x - 4.0 * Grid.TILE, ChunkLibrary.SEAM_ROW * Grid.TILE))
	var goal := {}
	for _tick in 600:
		state.advance(State.STEP, 1.0, false, false)
		for event in state.take_events():
			if event["kind"] == "goal":
				goal = event
		if state.cleared:
			break
	_expect(not goal.is_empty() and state.cleared and state.over,
		"Running past the food truck clears the stage.")
	_expect(is_equal_approx(state.clear_time, float(goal.get("time", -1.0))),
		"The goal event carries the clear time.")
	var stopped := state.clear_time
	var x := state.position.x
	state.advance(State.CLEAR_SECONDS * 0.5, 1.0, false, false)
	_expect(state.clear_time == stopped and state.position.x == x,
		"After the goal the clock and Dolce both stop.")
	_expect(not state.run_finished(), "She celebrates before the results.")
	state.advance(State.CLEAR_SECONDS, 0.0, false, false)
	_expect(state.run_finished() and state.hearts == State.STARTING_HEARTS,
		"Then the run is finished, every heart intact.")
	_expect(DolceModel.pose_for(state) == DolceModel.SIT, "She sits for her treat.")


func _test_records() -> void:
	var records := Records.new(_path)
	records.record(Options.STAGE_PARK, {"distance": 120, "score": 900, "burgers": 10, "time_ms": 0})
	_expect(records.best(Options.STAGE_PARK)["time_ms"] == 0,
		"An attempt that ran out of hearts sets no time.")
	records.record(Options.STAGE_PARK, {"distance": 300, "score": 4000, "time_ms": 75400})
	records.record(Options.STAGE_PARK, {"distance": 300, "score": 3000, "time_ms": 81200})
	var best := records.best(Options.STAGE_PARK)
	_expect(best["time_ms"] == 75400 and best["score"] == 4000,
		"A slower clear never replaces a faster one; scores keep their best too.")
	var faster := records.record(Options.STAGE_PARK, {"distance": 300, "time_ms": 69900})
	_expect("time_ms" in faster and records.best(Options.STAGE_PARK)["time_ms"] == 69900,
		"A faster clear is a new best time.")


func _test_time_text() -> void:
	_expect(Stages.time_text(64.32) == "1:04.3", "Clear times read as m:ss.t (%s)." % Stages.time_text(64.32))
	_expect(Stages.time_text(9.96) == "0:10.0", "Rounding carries into the seconds.")
	_expect(Stages.time_text(-1.0) == "0:00.0", "Never a negative time.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dolce stage tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
