extends RefCounted

## Seeded assembly of authored chunks into an endless run (DESIGN §5.2).
##
## Which chunk comes next depends only on the seed and the chunks already
## placed, never on how Dulce plays, so the same seed always builds the same
## run and a great run can be replayed. The stream keeps about three screens
## of chunks ahead of her and frees chunks two screens behind the camera, so
## the model only ever holds the live tiles.

const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")

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
var biome: int = ChunkLibrary.Biome.BACKYARD
var grid := Grid.new()
## Live chunks, oldest first: `{id, column, width, difficulty, breather}`.
var placed: Array[Dictionary] = []
## Where the next chunk will start, in tiles.
var next_column := 0
var _rng := RandomNumberGenerator.new()
var _since_breather := 0
var _last_id := ""


func _init(seed_value := 0, start_biome: int = ChunkLibrary.Biome.BACKYARD) -> void:
	run_seed = posmod(seed_value, SEED_LIMIT)
	biome = start_biome
	_rng.seed = run_seed


static func random_seed() -> int:
	return randi() % SEED_LIMIT


## Lays the start chunk and everything ahead of it, and returns a run on it.
func start() -> State:
	var course := _place(ChunkLibrary.START)
	var state := State.new(grid, ChunkLibrary.start_position())
	state.add_course(course)
	_fill(state)
	return state


## Keeps the window of live chunks around her. Returns true when chunks were
## added or freed, so the view knows to re-bake terrain.
func update(state: State, left_edge: float) -> bool:
	var added := _fill(state)
	var freed := is_finite(left_edge) and _free_behind(state, left_edge)
	return added or freed


## The next chunk in this seed's sequence: the forced breather when one is
## due, otherwise any chunk no harder than the ramp allows, never the same one
## twice in a row.
func next_chunk() -> Dictionary:
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
static func sequence(seed_value: int, metres: float) -> Array[String]:
	var stream := new(seed_value)
	stream._place(ChunkLibrary.START)
	var ids: Array[String] = [str(ChunkLibrary.START["id"])]
	while stream.next_column - ChunkLibrary.START_COLUMN < metres:
		var chunk := stream.next_chunk()
		stream._place(chunk)
		ids.append(str(chunk["id"]))
	return ids


## The rows of everything this seed lays over the first `metres`, joined into
## one strip, so the validator can walk a whole run end to end.
static func strip(seed_value: int, metres: float) -> Array[String]:
	var rows: Array[String] = []
	rows.resize(ChunkLibrary.ROWS)
	rows.fill("")
	var stream := new(seed_value)
	var chunk: Dictionary = ChunkLibrary.START
	while chunk != null:
		var chunk_rows := ChunkLibrary.rows_of(chunk)
		for row in ChunkLibrary.ROWS:
			rows[row] += chunk_rows[row]
		stream._place(chunk)
		if stream.next_column - ChunkLibrary.START_COLUMN >= metres:
			break
		chunk = stream.next_chunk()
	return rows


func _fill(state: State) -> bool:
	var added := false
	while next_column * Grid.TILE < state.position.x + AHEAD_TILES * Grid.TILE:
		state.add_course(_place(next_chunk()))
		added = true
	return added


func _place(chunk: Dictionary) -> Dictionary:
	var rows := ChunkLibrary.rows_of(chunk)
	var course := ChunkLibrary.build(rows, grid, Vector2i(next_column, 0))
	var breather := bool(chunk.get("breather", false))
	placed.append({
		"id": str(chunk["id"]), "column": next_column, "width": rows[0].length(),
		"difficulty": int(chunk["difficulty"]), "breather": breather,
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
