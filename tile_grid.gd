extends RefCounted

## The live tiles the run model collides against, independent of nodes.
##
## Cells are `TILE` units square in a y-down plane, so cell (x, y) covers
## `[x * TILE, (x + 1) * TILE)` on each axis. A missing cell is air, which is
## what lets the stream (DESIGN §5.2) free chunks behind the camera by erasing
## their columns without the model noticing.

## One tile is one metre: 40 simulation units at `WORLD_SCALE = 0.025`.
const TILE := 40.0

const EMPTY := 0
const SOLID := 1
## Lands from above only; walked and jumped through from below and the sides.
const ONE_WAY := 2
## A solid block with food inside; a bump from below opens it (DESIGN §4.4).
const LUNCHBOX := 3
## What a Lunchbox becomes once it has been opened: still solid, now empty.
const EMPTY_BOX := 4
const SOLIDS: Array[int] = [SOLID, LUNCHBOX, EMPTY_BOX]

## The legend characters this grid understands. The full chunk legend, with
## pickups and pests, belongs to `chunk_library.gd`; anything else is air here.
const GLYPHS := {"#": SOLID, "=": ONE_WAY}

var _tiles: Dictionary[Vector2i, int] = {}
## The lowest row that has ever held a tile, so a fall can be detected below
## the deepest ground without scanning the grid.
var bottom_row := 0


## Optionally paints string rows straight away, with row 0 at `origin.y`.
func _init(rows: Array[String] = [], origin := Vector2i.ZERO) -> void:
	paint_rows(rows, origin)


func paint_rows(rows: Array[String], origin := Vector2i.ZERO) -> void:
	for row in rows.size():
		var line := rows[row]
		for column in line.length():
			var kind: int = GLYPHS.get(line[column], EMPTY)
			if kind != EMPTY:
				set_tile(origin + Vector2i(column, row), kind)


func set_tile(cell: Vector2i, kind: int) -> void:
	if kind == EMPTY:
		_tiles.erase(cell)
		return
	_tiles[cell] = kind
	bottom_row = maxi(bottom_row, cell.y)


func tile(cell: Vector2i) -> int:
	return _tiles.get(cell, EMPTY)


func is_solid(cell: Vector2i) -> bool:
	return tile(cell) in SOLIDS


## Frees every tile left of `column`, as the stream drops chunks behind the view.
func clear_before(column: int) -> void:
	for cell: Vector2i in _tiles.keys():
		if cell.x < column:
			_tiles.erase(cell)


func size() -> int:
	return _tiles.size()


func cells() -> Array[Vector2i]:
	return _tiles.keys()


static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))
