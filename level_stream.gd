extends RefCounted

## Seeded assembly of authored chunks into an endless run (DESIGN §5.2).
##
## Which chunk comes next depends only on the seed and the chunks already
## placed, never on how Dolce plays, so the same seed always builds the same
## run and a great run can be replayed. Biomes follow the world: a run that
## starts at the Park is 400 m from the front door, so Main Street comes 500 m
## later. Difficulty follows the run itself (distance is relative everywhere),
## so a later start eases in like any other.
##
## Given a fixed stage (`stages.gd`), it lays that stage's chunks in order
## instead, then the goal, and nothing after it: the seed plays no part. The stream keeps about three screens
## of chunks ahead of her and frees chunks two screens behind the camera, so
## the model only ever holds the live tiles.

const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")

## About three landscape screens ahead of her, two behind the camera.
const AHEAD_TILES := 54
const BEHIND_TILES := 36
## The hardest chunk allowed is `1 + metres / RAMP_METRES` *(tune)*.
const RAMP_METRES := 150.0
## At least one breather in every run of this many chunks.
const BREATHER_EVERY := 4
## Seeds are shown on the results panel, so they stay short enough to read.
const SEED_LIMIT := 1000000

var run_seed := 0
## The biome the last placed chunk belongs to.
var biome: int = ChunkLibrary.Biome.BACKYARD
var start_biome: int = ChunkLibrary.Biome.BACKYARD
## How far from the front door the run starts, in metres.
var start_metres := 0.0
var grid := Grid.new()
## Live chunks, oldest first: `{id, column, width, difficulty, breather}`.
var placed: Array[Dictionary] = []
## Where the next chunk will start, in tiles.
var next_column := 0
## The fixed stage being played, or empty on an endless run.
var stage: Dictionary = {}
var _stage_queue: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _since_breather := 0
var _last_id := ""


func _init(
	seed_value := 0, start_biome_value: int = ChunkLibrary.Biome.BACKYARD,
	stage_value: Dictionary = {}
) -> void:
	run_seed = posmod(seed_value, SEED_LIMIT)
	start_biome = start_biome_value
	biome = start_biome_value
	start_metres = float(ChunkLibrary.BIOMES[start_biome_value]["start_m"])
	_rng.seed = run_seed
	stage = stage_value
	if not stage.is_empty():
		start_biome = int(stage["biome"])
		biome = start_biome
		_stage_queue.assign(stage["chunks"])
		_stage_queue.pop_front()
		_stage_queue.append(str(ChunkLibrary.GOAL["id"]))


static func random_seed() -> int:
	return randi() % SEED_LIMIT


## Metres from the front door at `column`: what decides the biome.
func world_metres(column: int) -> float:
	return start_metres + column - ChunkLibrary.START_COLUMN


## Lays the start biome's gate and everything ahead of it, and returns a run
## standing on the gate's safe ground.
func start() -> State:
	var course := _place(ChunkLibrary.gate_of(start_biome), false)
	var state := State.new(grid, ChunkLibrary.start_position())
	state.biome = start_biome
	state.add_course(course)
	_fill(state)
	return state


## Keeps the window of live chunks around her. Returns true when chunks were
## added or freed, so the view knows to re-bake terrain.
func update(state: State, left_edge: float) -> bool:
	var added := _fill(state)
	var freed := is_finite(left_edge) and _free_behind(state, left_edge)
	return added or freed


## The next chunk in this seed's sequence: a new biome's gate where the world
## changes biome, the forced breather when one is due, otherwise any chunk no
## harder than the ramp allows, never the same one twice in a row.
func next_chunk() -> Dictionary:
	if not stage.is_empty():
		# A fixed stage: its own chunks in order, then the goal, then nothing.
		return {} if _stage_queue.is_empty() \
			else ChunkLibrary.chunk_named(_stage_queue.pop_front())
	var here := ChunkLibrary.biome_at(world_metres(next_column))
	if here != biome:
		return ChunkLibrary.gate_of(here)
	var metres := maxf(0.0, next_column - ChunkLibrary.START_COLUMN)
	var hardest := 1 + floori(metres / RAMP_METRES)
	var want_breather := _since_breather >= BREATHER_EVERY - 1
	var candidates: Array[Dictionary] = []
	for chunk in ChunkLibrary.pool(biome):
		if str(chunk["id"]) == _last_id:
			continue
		if bool(chunk.get("breather", false)) != want_breather:
			continue
		if not want_breather and int(chunk["difficulty"]) > hardest:
			continue
		candidates.append(chunk)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## The chunk ids this seed lays over the first `metres`, without a run on them.
static func sequence(
	seed_value: int, metres: float, from_biome: int = ChunkLibrary.Biome.BACKYARD
) -> Array[String]:
	var stream := new(seed_value, from_biome)
	var opening := ChunkLibrary.gate_of(from_biome)
	stream._place(opening, false)
	var ids: Array[String] = [str(opening["id"])]
	while stream.next_column - ChunkLibrary.START_COLUMN < metres:
		var chunk := stream.next_chunk()
		stream._place(chunk)
		ids.append(str(chunk["id"]))
	return ids


## The rows of everything this seed lays over the first `metres`, joined into
## one strip, so the validator can walk a whole run end to end.
static func strip(
	seed_value: int, metres: float, from_biome: int = ChunkLibrary.Biome.BACKYARD
) -> Array[String]:
	var rows: Array[String] = []
	rows.resize(ChunkLibrary.ROWS)
	rows.fill("")
	var stream := new(seed_value, from_biome)
	var chunk: Dictionary = ChunkLibrary.gate_of(from_biome)
	while chunk != null:
		var chunk_rows := ChunkLibrary.rows_of(chunk)
		for row in ChunkLibrary.ROWS:
			rows[row] += chunk_rows[row]
		stream._place(chunk, false)
		if stream.next_column - ChunkLibrary.START_COLUMN >= metres:
			break
		chunk = stream.next_chunk()
	return rows


func _fill(state: State) -> bool:
	var added := false
	while next_column * Grid.TILE < state.position.x + AHEAD_TILES * Grid.TILE:
		var chunk := next_chunk()
		if chunk.is_empty():
			break
		state.add_course(_place(chunk))
		added = true
	return added


## Lays `chunk` at the end of the run. A gate also tells the run where its
## biome begins, unless it is the one the run starts on (`announce` false).
func _place(chunk: Dictionary, announce := true) -> Dictionary:
	var rows := ChunkLibrary.rows_of(chunk)
	var course := ChunkLibrary.build(rows, grid, Vector2i(next_column, 0))
	var breather := bool(chunk.get("breather", false))
	# The goal chunk is shared, so it takes the biome of the stage it ends.
	var chunk_biome := int(chunk["biome"]) if stage.is_empty() else int(stage["biome"])
	if chunk.get("gate", false) and announce:
		course["gates"] = [{
			"x": (next_column + ChunkLibrary.START_COLUMN + 0.5) * Grid.TILE,
			"biome": chunk_biome, "title": ChunkLibrary.BIOMES[chunk_biome]["title"],
		}]
	biome = chunk_biome
	placed.append({
		"id": str(chunk["id"]), "column": next_column, "width": rows[0].length(),
		"difficulty": int(chunk["difficulty"]), "breather": breather, "biome": chunk_biome,
		"gate": chunk.get("gate", false) and chunk != ChunkLibrary.GOAL,
		"goal": chunk.get("goal", false),
	})
	next_column += rows[0].length()
	_since_breather = 0 if breather else _since_breather + 1
	_last_id = str(chunk["id"])
	return course


## Frees whole chunks that ended two screens behind the camera's left edge.
func _free_behind(state: State, left_edge: float) -> bool:
	var cutoff := floori(left_edge / Grid.TILE) - BEHIND_TILES
	var freed := false
	while placed.size() > 1:
		var end := int(placed[0]["column"]) + int(placed[0]["width"])
		if end > cutoff:
			break
		grid.clear_before(end)
		state.forget_before(end)
		placed.pop_front()
		freed = true
	return freed
