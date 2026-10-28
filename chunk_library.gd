extends RefCounted

## Hand-authored terrain, written as const string grids so it is diffable.
##
## Milestone 1 holds a single grey-box course for tuning the jump. Milestone 3
## turns this file into the chunk library: the full legend, the Backyard
## chunks and `validate()` (DESIGN §5.1).

const Grid = preload("res://games/dulces_adventure/tile_grid.gd")

## Every chunk enters and leaves with its ground surface on this row.
const SEAM_ROW := 4

## Gaps of 2-5 tiles, a one-way platform, a two-tile ledge, a bump block
## overhead and a one-way staircase: everything the jump has to feel right on.
## Measured limits (tests/dulce_physics_test.gd): a running jump clears about
## 6.2 tiles across and 4.7 up; a standing one about 3.8 up.
const FEEL_COURSE: Array[String] = [
	"......................................................................................................................................####",
	"...............................................................#..........................===.........................................####",
	"................................====.....######........................................===............................................####",
	".........................................######.....................................===...............................................####",
	"############..######...##########################....###############.....#######################...####....####.....######################",
	"############..######...##########################....###############.....#######################...####....####.....######################",
]
## Where a run of the feel course starts: column 2, standing on the seam.
const FEEL_START_COLUMN := 2


static func feel_grid() -> Grid:
	return Grid.new(FEEL_COURSE)


static func feel_start() -> Vector2:
	return Vector2((FEEL_START_COLUMN + 0.5) * Grid.TILE, SEAM_ROW * Grid.TILE)
