extends SceneTree

## Chunk-library checks (DESIGN §5.1, §10): every authored chunk passes
## `validate()`, the library is big and varied enough, and the validator
## itself rejects the unfair shapes it exists to catch.

const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")

const OPEN := "................"
const GROUND := "################"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_every_chunk_validates()
	_test_library_shape()
	_test_start_chunk()
	_test_validator_matches_the_jump()
	_test_validator_rejects()
	_finish()


func _every_chunk() -> Array[Dictionary]:
	var chunks: Array[Dictionary] = [ChunkLibrary.START]
	for biome: int in ChunkLibrary.Biome.values():
		chunks.append_array(ChunkLibrary.pool(biome))
	return chunks


func _test_every_chunk_validates() -> void:
	for chunk in _every_chunk():
		for problem in ChunkLibrary.validate(chunk):
			_failures.append(problem)


func _test_library_shape() -> void:
	var ids := {}
	for chunk in _every_chunk():
		var id := str(chunk["id"])
		_expect(not ids.has(id), "Chunk ids are unique: '%s' appears twice." % id)
		ids[id] = true
	var backyard := ChunkLibrary.pool(ChunkLibrary.Biome.BACKYARD)
	_expect(backyard.size() >= 15, "The Backyard has at least 15 chunks (%d)." % backyard.size())
	var breathers := backyard.filter(func(chunk: Dictionary) -> bool:
		return chunk.get("breather", false))
	_expect(breathers.size() >= 2,
		"Two or more breathers, so the forced one is never the same twice running.")
	for difficulty in [1, 2, 3, 4]:
		var count := backyard.filter(func(chunk: Dictionary) -> bool:
			return not chunk.get("breather", false) and chunk["difficulty"] == difficulty).size()
		_expect(count >= 3,
			"Difficulty %d has at least three Backyard chunks to vary between (%d)."
			% [difficulty, count])
	for chunk in backyard:
		_expect(int(chunk["biome"]) == ChunkLibrary.Biome.BACKYARD,
			"%s sits in the Backyard pool but names another biome." % chunk["id"])
		_expect(not "".join(ChunkLibrary.rows_of(chunk)).contains("s"),
			"Backyard chunks only use Backyard pests (%s)." % chunk["id"])


func _test_start_chunk() -> void:
	var rows := ChunkLibrary.rows_of(ChunkLibrary.START)
	_expect(rows[ChunkLibrary.SEAM_ROW - 1][ChunkLibrary.START_COLUMN] == "S",
		"Dulce starts on the start chunk's safe ground.")
	_expect(ChunkLibrary.start_position()
		== Vector2((ChunkLibrary.START_COLUMN + 0.5) * Grid.TILE, ChunkLibrary.SEAM_ROW * Grid.TILE),
		"The start position stands on the seam.")
	_expect(not ChunkLibrary.pool(ChunkLibrary.Biome.BACKYARD).has(ChunkLibrary.START),
		"The start chunk is never drawn from the random pool.")


## The validator's limits are the body's limits less the margin.
func _test_validator_matches_the_jump() -> void:
	var widest := floori(State.jump_reach(State.RUN_SPEED, 0.0) / Grid.TILE) - ChunkLibrary.MARGIN_TILES
	_expect(widest == 5, "A running jump clears 6.2 tiles, so pits up to 5 are fair (%d)." % widest)
	_expect(_problems(_pit(widest)).is_empty(), "A %d-tile pit is fair." % widest)
	_expect(_mentions(_problems(_pit(widest + 1)), "exit cannot be reached"),
		"A %d-tile pit is not." % (widest + 1))
	_expect(_problems(_wall(3)).is_empty(), "A three-tile ledge is fair.")
	_expect(_mentions(_problems(_wall(4)), "exit cannot be reached"),
		"A four-tile ledge is not: a running jump rises 4.7 and the margin is one.")


func _test_validator_rejects() -> void:
	var over_pit := _pit(3)
	over_pit[3] = ".....S.........."
	_expect(_mentions(_problems(over_pit), "must stand on solid ground"),
		"Safe ground over a pit is rejected.")
	var on_platform := _flat()
	on_platform[2] = ".....====......."
	on_platform[1] = "......S........."
	_expect(_mentions(_problems(on_platform), "must stand on solid ground"),
		"Safe ground on a one-way platform is rejected.")
	var floating := _flat()
	floating[1] = ".....p.........."
	_expect(_mentions(_problems(floating), "nothing to stand on"),
		"A pest in mid-air is rejected.")
	var boxed_gnome := _flat()
	boxed_gnome[2] = "......#........."
	boxed_gnome[3] = ".S....#........."
	boxed_gnome[1] = "......n........."
	_expect(_mentions(_problems(boxed_gnome), "room to land beside it"),
		"A gnome on a one-tile pillar leaves nowhere to land, and is rejected.")
	var unknown := _flat()
	unknown[2] = ".....x.........."
	_expect(_mentions(_problems(unknown), "not in the legend"), "Unknown glyphs are rejected.")
	var unbuilt := _flat()
	unbuilt[3] = ".S...s.........."
	_expect(_mentions(_problems(unbuilt), "not built yet"),
		"A pest from a later milestone is rejected until it exists.")
	var closed := _flat()
	closed[4] = "." + GROUND.substr(1)
	closed[5] = "." + GROUND.substr(1)
	_expect(_mentions(_problems(closed), "open ground on the seam"),
		"A chunk that does not start on the seam is rejected.")
	var no_safe := _flat()
	no_safe[3] = OPEN
	_expect(_mentions(_problems(no_safe), "at least one S"), "A chunk without safe ground is rejected.")
	var restless := {"id": "restless", "biome": 0, "difficulty": 1, "breather": true, "rows": _pit(2)}
	_expect(_mentions(ChunkLibrary.validate(restless), "breather has no pits"),
		"A breather with a pit is rejected.")
	var narrow := {"id": "narrow", "biome": 0, "difficulty": 1, "rows": [
		"..........", "..........", "..........", ".S........", "##########", "##########",
	]}
	_expect(_mentions(ChunkLibrary.validate(narrow), "tiles wide"), "Chunks under 16 tiles are rejected.")
	var short := {"id": "short", "biome": 0, "difficulty": 1, "rows": [OPEN, GROUND]}
	_expect(_mentions(ChunkLibrary.validate(short), "needs 6 rows"), "Chunks need six rows.")
	var unrated := {"id": "unrated", "biome": 0, "difficulty": 9, "rows": _flat()}
	_expect(_mentions(ChunkLibrary.validate(unrated), "difficulty"), "Difficulty is 1-5.")


# --------------------------------------------------------------------------


func _flat() -> Array[String]:
	return [OPEN, OPEN, OPEN, ".S..............", GROUND, GROUND]


## Flat ground with a `width`-tile pit in the middle and safe ground before it.
func _pit(width: int) -> Array[String]:
	var ground := "####" + ".".repeat(width) + "#".repeat(12 - width)
	return [OPEN, OPEN, OPEN, ".S..............", ground, ground]


## A ledge `height` tiles high to climb, with open ground again at the exit.
func _wall(height: int) -> Array[String]:
	var rows := _flat()
	for row in range(ChunkLibrary.SEAM_ROW - height, ChunkLibrary.SEAM_ROW):
		rows[row] = "........#######."
	rows[3] = ".S" + rows[3].substr(2)
	return rows


func _problems(rows: Array[String]) -> PackedStringArray:
	return ChunkLibrary.validate({"id": "probe", "biome": 0, "difficulty": 1, "rows": rows})


func _mentions(problems: PackedStringArray, phrase: String) -> bool:
	for problem in problems:
		if problem.contains(phrase):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dulce chunk tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
