extends RefCounted

## Hand-authored terrain, written as const string grids so it is diffable.
##
## `build()` paints a grid's tiles and returns the stretch's food, Lunchboxes,
## pests and safe ground for `run_state.add_course()`; the Milestone 3 stream
## calls it once per chunk. Until then the run is the grey-box course below.

const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const Pests = preload("res://games/dulces_adventure/pests.gd")

## Every chunk enters and leaves with its ground surface on this row.
const SEAM_ROW := 4

## The one legend (DESIGN §5.1). Lunchbox contents are authored, never rolled,
## so every chunk plays the same way every time: `?` holds a burger and `!` a
## Big Burger. Pests not yet built are listed so the validator can name them.
const LEGEND := {
	".": "air",
	"#": "ground",
	"=": "platform",
	"?": "lunchbox",
	"!": "lunchbox_big_burger",
	"B": State.BURGER,
	"G": State.BIG_BURGER,
	"+": State.GOLDEN_BONE,
	"p": Pests.PIGEON,
	"n": Pests.GNOME,
	"s": "squirrel",
	"v": "robo_vac",
	"g": "seagull",
	"h": "hot_sauce",
	"S": "safe",
}

## Gaps of 2-5 tiles, a one-way platform, a two-tile ledge with a gnome on it,
## two Lunchboxes, pigeons on islands and a one-way staircase of burgers.
## Measured limits (tests/dulce_physics_test.gd): a running jump clears about
## 6.2 tiles across and 4.7 up; a standing one about 3.8 up.
const FEEL_COURSE: Array[String] = [
	"..........................................................................................BBB...................................",
	"..........?..........B..........BBBB........n......+...........!.......................BBB===...................................",
	"............BB..................====.....######.....................................BBB===.......B......BB......................",
	"..S...BBB......S........S..p.S.........S.######.......S.....S.............S...p...S.===.............S.......S........S.BB.p.p...",
	"############..######...##########################....###############.....#######################...####....####.....############",
	"############..######...##########################....###############.....#######################...####....####.....############",
]
## Five laps reach about 640 m: far enough for Off the Leash (400 m), and with
## 25 burgers a lap, for Hungry Hungry too.
const FEEL_LAPS := 5
## A wall closes the grey-box course; a pit past it would be a cheap end.
const FEEL_END: Array[String] = ["####", "####", "####", "####", "####", "####"]
## Where a run of the feel course starts: column 2, standing on the seam.
const FEEL_START_COLUMN := 2


## Paints `rows` into `grid` with row 0 at `origin.y`, and returns what else
## the rows hold: `{items, lunchboxes, pests, safe_points}`.
static func build(rows: Array[String], grid: Grid, origin := Vector2i.ZERO) -> Dictionary:
	var items: Dictionary[Vector2i, String] = {}
	var lunchboxes: Dictionary[Vector2i, String] = {}
	var pests: Array[Dictionary] = []
	var safe_points: Array[Vector2] = []
	for row in rows.size():
		var line := rows[row]
		for column in line.length():
			var glyph := line[column]
			var cell := origin + Vector2i(column, row)
			var feet := Vector2((cell.x + 0.5) * Grid.TILE, (cell.y + 1) * Grid.TILE)
			match glyph:
				".":
					pass
				"#":
					grid.set_tile(cell, Grid.SOLID)
				"=":
					grid.set_tile(cell, Grid.ONE_WAY)
				"?", "!":
					grid.set_tile(cell, Grid.LUNCHBOX)
					lunchboxes[cell] = State.BURGER if glyph == "?" else State.BIG_BURGER
				"B", "G", "+":
					items[cell] = LEGEND[glyph]
				"S":
					safe_points.append(feet)
				_:
					var kind := str(LEGEND.get(glyph, ""))
					if Pests.is_known(kind):
						pests.append({"kind": kind, "feet": feet})
					else:
						push_error("Chunk glyph '%s' at %s is not built yet." % [glyph, cell])
	return {
		"items": items, "lunchboxes": lunchboxes, "pests": pests, "safe_points": safe_points,
	}


## The grey-box course, `FEEL_LAPS` times over and closed by a wall.
static func feel_rows() -> Array[String]:
	var rows: Array[String] = []
	for row in FEEL_COURSE.size():
		rows.append(FEEL_COURSE[row].repeat(FEEL_LAPS) + FEEL_END[row])
	return rows


## A ready-to-run state on the grey-box course.
static func feel_run() -> State:
	var grid := Grid.new()
	var course := build(feel_rows(), grid)
	var state := State.new(grid, feel_start())
	state.add_course(course)
	return state


static func feel_start() -> Vector2:
	return Vector2((FEEL_START_COLUMN + 0.5) * Grid.TILE, SEAM_ROW * Grid.TILE)
