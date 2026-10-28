extends SceneTree

## Seeded-stream checks for `level_stream.gd` (DESIGN §5.2, §10).
##
## Same seed, same run; the difficulty ramp; breather spacing; no repeats; a
## whole generated kilometre walked end to end by the validator; and a live
## window that frees what is behind without changing what is ahead.

const LevelStream = preload("res://games/dulces_adventure/level_stream.gd")
const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")

const RUN_METRES := 1000.0
const SEEDS: Array[int] = [0, 1, 7, 42, 2024, 99999, 123456, 987654]

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_same_seed_same_run()
	_test_sequence_rules()
	_test_every_run_is_fair()
	_test_food_supply()
	_test_biome_schedule()
	_test_gate_events()
	_test_live_window()
	_test_seed_range()
	_finish()


func _test_same_seed_same_run() -> void:
	var first := LevelStream.sequence(42, RUN_METRES)
	var again := LevelStream.sequence(42, RUN_METRES)
	_expect(first == again and first.size() > 30,
		"The same seed lays the same %d chunks over %d m." % [first.size(), RUN_METRES])
	_expect(LevelStream.sequence(43, RUN_METRES) != first, "A different seed lays a different run.")
	_expect(first[0] == ChunkLibrary.START["id"], "Every run starts in the front garden.")
	_expect(LevelStream.strip(42, RUN_METRES) == LevelStream.strip(42, RUN_METRES),
		"The same seed builds the same tiles.")


func _test_sequence_rules() -> void:
	var by_id := _chunks_by_id()
	for seed_value in SEEDS:
		var ids := LevelStream.sequence(seed_value, RUN_METRES)
		var column := 0
		var since_breather := 0
		var hardest_seen := 0
		for index in ids.size():
			var chunk: Dictionary = by_id[ids[index]]
			var metres := maxf(0.0, column - ChunkLibrary.START_COLUMN)
			var allowed := 1 + floori(metres / LevelStream.RAMP_METRES)
			if not chunk.get("breather", false):
				_expect(int(chunk["difficulty"]) <= allowed,
					"Seed %d: %s (difficulty %d) at %d m is past the ramp (%d)."
					% [seed_value, ids[index], chunk["difficulty"], metres, allowed])
				hardest_seen = maxi(hardest_seen, int(chunk["difficulty"]))
			since_breather = 0 if chunk.get("breather", false) else since_breather + 1
			_expect(since_breather < LevelStream.BREATHER_EVERY,
				"Seed %d: a breather is due by chunk %d." % [seed_value, index])
			if index > 0:
				_expect(ids[index] != ids[index - 1],
					"Seed %d: %s twice in a row." % [seed_value, ids[index]])
			column += ChunkLibrary.rows_of(chunk)[0].length()
		_expect(hardest_seen >= 4, "Seed %d reaches difficulty 4 within %d m." % [seed_value, RUN_METRES])


## Pillar 2 over a whole run: the validator walks every seam and every pit.
func _test_every_run_is_fair() -> void:
	for seed_value in SEEDS:
		for problem in ChunkLibrary.route_problems(LevelStream.strip(seed_value, RUN_METRES),
				"seed %d" % seed_value):
			_failures.append(problem)
	# A whole cycle, from every start point, for a couple of seeds.
	for start_biome: int in ChunkLibrary.Biome.values():
		for seed_value in [3, 2024]:
			for problem in ChunkLibrary.route_problems(
					LevelStream.strip(seed_value, ChunkLibrary.CYCLE_METRES, start_biome),
					"seed %d from %s" % [seed_value, ChunkLibrary.BIOMES[start_biome]["id"]]):
				_failures.append(problem)


func _test_food_supply() -> void:
	for seed_value in SEEDS:
		_count_food(LevelStream.strip(seed_value, RUN_METRES), "Seed %d" % seed_value)
	for start_biome: int in ChunkLibrary.Biome.values():
		_count_food(LevelStream.strip(9, RUN_METRES, start_biome),
			"From %s" % ChunkLibrary.BIOMES[start_biome]["title"])


func _count_food(rows: Array[String], label: String) -> void:
	var burgers := 0
	for row in rows:
		burgers += row.count("B") + row.count("?")
	_expect(burgers >= Options.HUNDRED_BURGERS,
		"%s: Hungry Hungry needs %d burgers in a kilometre; there are %d."
		% [label, Options.HUNDRED_BURGERS, burgers])


## Moves her along a started run and checks the window around her.
func _chunks_by_id() -> Dictionary:
	var by_id := {}
	for biome: int in ChunkLibrary.Biome.values():
		for chunk in ChunkLibrary.chunks_of(biome):
			by_id[chunk["id"]] = chunk
	return by_id


## Every chunk sits in the biome its place in the world calls for, each new
## biome opens on its gate, and the cycle loops back to the front garden.
func _test_biome_schedule() -> void:
	var by_id := _chunks_by_id()
	for start_biome: int in ChunkLibrary.Biome.values():
		var stream := LevelStream.new(11, start_biome)
		var ids := LevelStream.sequence(11, ChunkLibrary.CYCLE_METRES + 400.0, start_biome)
		_expect(ids[0] == ChunkLibrary.gate_of(start_biome)["id"],
			"A run from %s starts on its gate." % ChunkLibrary.BIOMES[start_biome]["title"])
		var column := 0
		var previous := start_biome
		var seen := {}
		for index in ids.size():
			var id := ids[index]
			var chunk: Dictionary = by_id[id]
			# The opening gate starts 2 m before the start point, at column 0.
			var expected := ChunkLibrary.biome_at(stream.world_metres(maxi(column, ChunkLibrary.START_COLUMN)))
			var chunk_biome := int(chunk["biome"])
			seen[chunk_biome] = true
			_expect(chunk_biome == expected,
				"%s at %d m belongs in %s." % [id, stream.world_metres(column),
				ChunkLibrary.BIOMES[expected]["title"]])
			if chunk_biome != previous:
				_expect(chunk.get("gate", false), "%s opens its biome on a gate, not %s." % [
					ChunkLibrary.BIOMES[chunk_biome]["title"], id])
			previous = chunk_biome
			column += ChunkLibrary.rows_of(chunk)[0].length()
		_expect(seen.size() == ChunkLibrary.Biome.size(),
			"A full cycle from %s visits every biome." % ChunkLibrary.BIOMES[start_biome]["title"])


## The biome gate event reaches the run once, as she passes the gate.
func _test_gate_events() -> void:
	var stream := LevelStream.new(5)
	var state := stream.start()
	_expect(state.biome == ChunkLibrary.Biome.BACKYARD, "A Backyard run starts in the Backyard.")
	var park_at := (ChunkLibrary.START_COLUMN + 400.0 + 20.0) * Grid.TILE
	var announced := []
	var x := state.position.x
	while x < park_at:
		x += 4.0 * Grid.TILE
		state.place(Vector2(x, state.position.y))
		state.furthest_x = x
		stream.update(state, x - 10.0 * Grid.TILE)
		state.advance(State.STEP, 0.0, false, false)
		for event in state.take_events():
			if event["kind"] == "biome":
				announced.append(event["title"])
	_expect(announced == ["the Park"], "Passing the Park's gate announces it once (%s)." % [announced])
	_expect(state.biome == ChunkLibrary.Biome.PARK, "The run knows it is in the Park now.")
	var market := LevelStream.new(5, ChunkLibrary.Biome.MARKET)
	_expect(market.start().biome == ChunkLibrary.Biome.MARKET and market.start_metres == 2200.0,
		"A Market start is 2200 m from the front door.")


func _test_live_window() -> void:
	var stream := LevelStream.new(7)
	var state := stream.start()
	_expect(state.position == ChunkLibrary.start_position(), "A run starts at the start position.")
	_expect(stream.next_column * Grid.TILE >= state.position.x + LevelStream.AHEAD_TILES * Grid.TILE,
		"Three screens of course are laid before she takes a step.")
	var reference := LevelStream.new(7)
	reference.start()
	var x := state.position.x
	var changed := 0
	while x < 600.0 * Grid.TILE:
		x += 6.0 * Grid.TILE
		state.place(Vector2(x, state.position.y))
		state.furthest_x = x
		if stream.update(state, x - 10.0 * Grid.TILE):
			changed += 1
		reference.update(state, -INF)
	_expect(changed > 10, "Moving along lays and frees chunks as she goes.")
	var cutoff := floori((x - 10.0 * Grid.TILE) / Grid.TILE) - LevelStream.BEHIND_TILES
	var behind := stream.grid.cells().filter(func(cell: Vector2i) -> bool: return cell.x < cutoff - 48)
	_expect(behind.is_empty(), "Tiles two screens behind the camera are freed.")
	_expect(stream.placed.size() < 12 and stream.grid.size() < reference.grid.size() / 3,
		"The live window stays small (%d chunks, %d tiles vs %d)."
		% [stream.placed.size(), stream.grid.size(), reference.grid.size()])
	var stale := state.items.keys().filter(func(cell: Vector2i) -> bool: return cell.x < cutoff - 48)
	_expect(stale.is_empty(), "Food behind the window is forgotten with its tiles.")
	_expect(stream.next_column * Grid.TILE >= x + LevelStream.AHEAD_TILES * Grid.TILE,
		"The course always runs three screens ahead of her.")
	var same := true
	for cell in stream.grid.cells():
		same = same and reference.grid.tile(cell) == stream.grid.tile(cell)
	_expect(same, "Freeing what is behind never changes what is ahead.")
	_expect(stream.placed.size() >= 1 and int(stream.placed[0]["column"]) <= cutoff + 48,
		"The window keeps the chunk under the camera.")


func _test_seed_range() -> void:
	_expect(LevelStream.new(-5).run_seed >= 0
		and LevelStream.new(LevelStream.SEED_LIMIT + 3).run_seed == 3,
		"Seeds fold into the range the results panel shows.")
	for _i in 20:
		var seed_value := LevelStream.random_seed()
		_expect(seed_value >= 0 and seed_value < LevelStream.SEED_LIMIT, "Random seeds stay in range.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dulce stream tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
