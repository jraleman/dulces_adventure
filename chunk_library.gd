extends RefCounted

## Hand-authored terrain chunks, the one legend, and the validator that keeps
## every generated run fair (DESIGN §5.1).
##
## Chunks are const string grids so they diff and review like text. `build()`
## paints one into a tile grid and returns its food, Lunchboxes, pests and
## safe ground for `run_state.add_course()`. `validate()` is pillar 2 ("always
## fair") as code: it quotes `run_state.gd`'s own jump arithmetic, so a change
## to the movement constants re-checks every chunk.

const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const Pests = preload("res://games/dulces_adventure/pests.gd")

enum Biome { BACKYARD, PARK, STREET, PIER, MARKET }

## Biomes by where they start in the world, in metres from the front door.
## After the Night Market they loop, and the difficulty ramp keeps rising.
const BIOMES := {
	Biome.BACKYARD: {"id": "backyard", "title": "the Backyard", "start_m": 0},
	Biome.PARK: {"id": "park", "title": "the Park", "start_m": 400},
	Biome.STREET: {"id": "street", "title": "Main Street", "start_m": 900},
	Biome.PIER: {"id": "pier", "title": "the Boardwalk Pier", "start_m": 1500},
	Biome.MARKET: {"id": "market", "title": "the Night Market", "start_m": 2200},
}
const CYCLE_METRES := 3000

## Every chunk has six rows and enters and leaves with its ground surface on
## this one, so any two chunks join.
const SEAM_ROW := 4
const ROWS := 6
const MIN_WIDTH := 16
const MAX_WIDTH := 48
## Room left over on every required jump, across and up (DESIGN §5.2).
const MARGIN_TILES := 1
## Furthest apart two spots can be and still be joined by one jump.
const MAX_JUMP_COLUMNS := 8
const DIFFICULTIES := [1, 2, 3, 4, 5]
## Where a run starts: the `S` in `START`, standing on the seam.
const START_COLUMN := 2

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
	"F": "goal",
}
## Glyphs Dulce can stand on, and the ones she cannot pass through.
const SUPPORTS := ["#", "=", "?", "!"]
const BLOCKS := ["#", "?", "!"]

## `jump_reach()` by rise, so a whole generated run validates in moments.
static var _reach_by_rise: Dictionary[float, float] = {}

## Every biome opens with a gate chunk: the "Welcome to" set piece, and where a
## run that starts in that biome begins. Gates are never drawn at random.
## Dulce's front garden is the Backyard's.
const START := {
	"id": "backyard_start", "biome": Biome.BACKYARD, "difficulty": 1, "breather": true,
	"gate": true,
	"rows": [
		"................",
		"................",
		"................",
		"..S...BBB.......",
		"################",
		"################",
	],
}

## The end of a fixed stage (DESIGN §5.5): a flat stretch with the goal, a
## food truck, on solid ground, and enough ground after it that the camera
## never shows the world ending. It takes the stage's biome when it is placed,
## and is never drawn at random.
const GOAL := {
	"id": "stage_goal", "biome": Biome.BACKYARD, "difficulty": 1, "breather": true,
	"goal": true,
	"rows": [
		"............................",
		"............................",
		"............................",
		".S........F.................",
		"############################",
		"############################",
	],
}

const BACKYARD: Array[Dictionary] = [
	{
		"id": "lawn", "biome": Biome.BACKYARD, "difficulty": 1, "breather": true,
		"rows": [
			"................",
			"................",
			"................",
			".S...BBBB.......",
			"################",
			"################",
		],
	},
	{
		"id": "picnic", "biome": Biome.BACKYARD, "difficulty": 1, "breather": true,
		"rows": [
			"....................",
			"......?.......?.....",
			"....................",
			".S........BBB.......",
			"####################",
			"####################",
		],
	},
	{
		"id": "shade", "biome": Biome.BACKYARD, "difficulty": 1, "breather": true,
		"rows": [
			"..................",
			".....BBBB.........",
			".....====.........",
			".S................",
			"##################",
			"##################",
		],
	},
	{
		"id": "pit_hop", "biome": Biome.BACKYARD, "difficulty": 1,
		"rows": [
			"................",
			"........B.......",
			"......=====.....",
			".S.........p.S..",
			"####...#########",
			"####...#########",
		],
	},
	{
		"id": "two_gaps", "biome": Biome.BACKYARD, "difficulty": 1,
		"rows": [
			"....................",
			"....................",
			"....BB.....BBB......",
			".S.....S.........S..",
			"####..#####...######",
			"####..#####...######",
		],
	},
	{
		"id": "pigeon_lawn", "biome": Biome.BACKYARD, "difficulty": 1,
		"rows": [
			"..................",
			"........?.........",
			"..................",
			".S..BB.......p....",
			"##################",
			"##################",
		],
	},
	{
		"id": "steps", "biome": Biome.BACKYARD, "difficulty": 1,
		"rows": [
			"..................",
			".........BB.......",
			".....BB.####......",
			".S..########....S.",
			"##################",
			"##################",
		],
	},
	{
		"id": "gnome_gate", "biome": Biome.BACKYARD, "difficulty": 2,
		"rows": [
			"....................",
			"....................",
			".........B..........",
			".S.......n.......S..",
			"##############...###",
			"##############...###",
		],
	},
	{
		"id": "ledge_gnome", "biome": Biome.BACKYARD, "difficulty": 2,
		"rows": [
			"....................",
			"..........n.........",
			"......######........",
			".S....######..B..S..",
			"####################",
			"####################",
		],
	},
	{
		"id": "platform_pit", "biome": Biome.BACKYARD, "difficulty": 2,
		"rows": [
			"......................",
			".......BBBB...........",
			"......======..........",
			".S.............S......",
			"#####......###########",
			"#####......###########",
		],
	},
	{
		"id": "pigeon_island", "biome": Biome.BACKYARD, "difficulty": 2,
		"rows": [
			"......................",
			"......................",
			"...BB.........BB......",
			".S......S..p.......S..",
			"###...########...#####",
			"###...########...#####",
		],
	},
	{
		"id": "lunch_break", "biome": Biome.BACKYARD, "difficulty": 2,
		"rows": [
			"....................",
			".....?.!............",
			"....................",
			".S...........S......",
			"##########...#######",
			"##########...#######",
		],
	},
	{
		"id": "wide_leap", "biome": Biome.BACKYARD, "difficulty": 3,
		"rows": [
			"....................",
			"........BBB.........",
			"....................",
			".S.............S....",
			"######.....#########",
			"######.....#########",
		],
	},
	{
		"id": "pigeon_pair", "biome": Biome.BACKYARD, "difficulty": 3,
		"rows": [
			"........................",
			"........................",
			".........BBB............",
			".S....p.....p.......S...",
			"################....####",
			"################....####",
		],
	},
	{
		"id": "staircase", "biome": Biome.BACKYARD, "difficulty": 3,
		"rows": [
			".........BBB........",
			".........===........",
			"......===...........",
			".S.===............S.",
			"###..............###",
			"###..............###",
		],
	},
	{
		"id": "ledge_drop", "biome": Biome.BACKYARD, "difficulty": 3,
		"rows": [
			"......................",
			"......................",
			"...######.............",
			".S.######.....BB...S..",
			"#########.....########",
			"#########.....########",
		],
	},
	{
		"id": "golden_gap", "biome": Biome.BACKYARD, "difficulty": 3,
		"rows": [
			"......................",
			".........+............",
			"......................",
			".S..............S.....",
			"#######....###########",
			"#######....###########",
		],
	},
	{
		"id": "island_hop", "biome": Biome.BACKYARD, "difficulty": 4,
		"rows": [
			"..........................",
			"......B.....B......B......",
			"..........................",
			".S...................S....",
			"####...##...##....########",
			"####...##...##....########",
		],
	},
	{
		"id": "tall_steps", "biome": Biome.BACKYARD, "difficulty": 4,
		"rows": [
			"..........BB..........",
			"..........####........",
			"......########........",
			".S..##########......S.",
			"##############....####",
			"##############....####",
		],
	},
	{
		"id": "pigeon_platforms", "biome": Biome.BACKYARD, "difficulty": 4,
		"rows": [
			"........................",
			".........B.......B......",
			"....p.......p...........",
			".S.=====...=====.....S..",
			"###.................####",
			"###.................####",
		],
	},
	{
		"id": "gnome_ledges", "biome": Biome.BACKYARD, "difficulty": 4,
		"rows": [
			"........................",
			".....n.........n........",
			"...#####.....#####......",
			".S.#####.....#####...S..",
			"########.....###########",
			"########.....###########",
		],
	},
]


const PARK: Array[Dictionary] = [
	{
		"id": "park_gate", "biome": Biome.PARK, "difficulty": 1, "breather": true, "gate": true,
		"rows": [
			"................",
			"................",
			"................",
			"..S....BBBBB....",
			"################",
			"################",
		],
	},
	{
		"id": "park_meadow", "biome": Biome.PARK, "difficulty": 1, "breather": true,
		"rows": [
			"..................",
			".......?..........",
			"..................",
			".S..........BBB...",
			"##################",
			"##################",
		],
	},
	{
		"id": "park_path", "biome": Biome.PARK, "difficulty": 1, "breather": true,
		"rows": [
			"................",
			".....BBBB.......",
			".....====.......",
			".S..............",
			"################",
			"################",
		],
	},
	{
		"id": "duck_pond", "biome": Biome.PARK, "difficulty": 1,
		"rows": [
			"..................",
			"..................",
			"......BBB.........",
			".S..........S..p..",
			"#####...##########",
			"#####...##########",
		],
	},
	{
		"id": "park_steps", "biome": Biome.PARK, "difficulty": 1,
		"rows": [
			"..................",
			"..........BB......",
			"......BB.####.....",
			".S...########...S.",
			"##################",
			"##################",
		],
	},
	{
		"id": "squirrel_run", "biome": Biome.PARK, "difficulty": 2,
		"rows": [
			"....................",
			"....................",
			".........BBB........",
			".S.............s.S..",
			"##########...#######",
			"##########...#######",
		],
	},
	{
		"id": "bench_hop", "biome": Biome.PARK, "difficulty": 2,
		"rows": [
			"....................",
			"......B.....B.......",
			"....................",
			".S...##....##...p.S.",
			"####################",
			"####################",
		],
	},
	{
		"id": "twin_ponds", "biome": Biome.PARK, "difficulty": 3,
		"rows": [
			"......................",
			"......................",
			"....BB.........BB.....",
			".S.......S..s.......S.",
			"###....######....#####",
			"###....######....#####",
		],
	},
	{
		"id": "tree_tops", "biome": Biome.PARK, "difficulty": 3,
		"rows": [
			"......................",
			"........BB....BB......",
			".......====..====.....",
			".S.................S..",
			"#####............#####",
			"#####............#####",
		],
	},
	{
		"id": "squirrel_ambush", "biome": Biome.PARK, "difficulty": 4,
		"rows": [
			"........................",
			"........................",
			"......BB..........BB....",
			".S.........S..s.s.....S.",
			"#####.....#########.####",
			"#####.....#########.####",
		],
	},
	{
		"id": "high_branches", "biome": Biome.PARK, "difficulty": 4,
		"rows": [
			"...........BB.........",
			"..........####........",
			"......########........",
			".S..##########......S.",
			"##############.....###",
			"##############.....###",
		],
	},
]

const STREET: Array[Dictionary] = [
	{
		"id": "street_gate", "biome": Biome.STREET, "difficulty": 1, "breather": true, "gate": true,
		"rows": [
			"................",
			"................",
			"................",
			"..S....BBBBB....",
			"################",
			"################",
		],
	},
	{
		"id": "corner_shop", "biome": Biome.STREET, "difficulty": 1, "breather": true,
		"rows": [
			"....................",
			".....?.....?........",
			"....................",
			".S.........BBB......",
			"####################",
			"####################",
		],
	},
	{
		"id": "awnings", "biome": Biome.STREET, "difficulty": 1, "breather": true,
		"rows": [
			"..................",
			"....BBB...........",
			"....===...===.....",
			".S................",
			"##################",
			"##################",
		],
	},
	{
		"id": "manhole", "biome": Biome.STREET, "difficulty": 1,
		"rows": [
			"..................",
			"..................",
			"......BB..........",
			".S..........S.p...",
			"######..##########",
			"######..##########",
		],
	},
	{
		"id": "kerb_steps", "biome": Biome.STREET, "difficulty": 1,
		"rows": [
			"..................",
			"..........BB......",
			"......BB..........",
			".S...#####.##...S.",
			"##################",
			"##################",
		],
	},
	{
		"id": "vac_lane", "biome": Biome.STREET, "difficulty": 2,
		"rows": [
			"......................",
			"......................",
			"..............BBB.....",
			".S.......v..........S.",
			"#############...######",
			"#############...######",
		],
	},
	{
		"id": "parked_cars", "biome": Biome.STREET, "difficulty": 2,
		"rows": [
			"......................",
			".......BB......BB.....",
			"......###.............",
			".S...#####....####..S.",
			"######################",
			"######################",
		],
	},
	{
		"id": "vac_pair", "biome": Biome.STREET, "difficulty": 3,
		"rows": [
			"........................",
			"........................",
			"........BBB.............",
			".S...v.........v.....S..",
			"#################....###",
			"#################....###",
		],
	},
	{
		"id": "scaffold", "biome": Biome.STREET, "difficulty": 3,
		"rows": [
			"......................",
			"..........BBB.........",
			"......===.===.===.....",
			".S..................S.",
			"#####............#####",
			"#####............#####",
		],
	},
	{
		"id": "rush_hour", "biome": Biome.STREET, "difficulty": 4,
		"rows": [
			"..........................",
			"..........................",
			".......BB.........BB......",
			".S..v.......S..v........S.",
			"#######.....#######.....##",
			"#######.....#######.....##",
		],
	},
	{
		"id": "rooftop", "biome": Biome.STREET, "difficulty": 4,
		"rows": [
			"........................",
			".........p..............",
			"......#######...........",
			".S..#########.......S...",
			"#############.....######",
			"#############.....######",
		],
	},
]

const PIER: Array[Dictionary] = [
	{
		"id": "pier_gate", "biome": Biome.PIER, "difficulty": 1, "breather": true, "gate": true,
		"rows": [
			"................",
			"................",
			"................",
			"..S....BBBBB....",
			"################",
			"################",
		],
	},
	{
		"id": "boardwalk", "biome": Biome.PIER, "difficulty": 1, "breather": true,
		"rows": [
			"..................",
			"......?...........",
			"..................",
			".S.........BBBB...",
			"##################",
			"##################",
		],
	},
	{
		"id": "deck_chairs", "biome": Biome.PIER, "difficulty": 1, "breather": true,
		"rows": [
			"................",
			"....BBB.........",
			"....===.........",
			".S..............",
			"################",
			"################",
		],
	},
	{
		"id": "plank_gaps", "biome": Biome.PIER, "difficulty": 1,
		"rows": [
			"....................",
			"....................",
			".....B....B.....B...",
			".S..................",
			"#####.####.####.####",
			"#####.####.####.####",
		],
	},
	{
		"id": "gull_watch", "biome": Biome.PIER, "difficulty": 1,
		"rows": [
			"....................",
			"..........g.........",
			"....................",
			".S......BB.....S....",
			"############..######",
			"############..######",
		],
	},
	{
		"id": "jetty", "biome": Biome.PIER, "difficulty": 2,
		"rows": [
			"......................",
			"......................",
			"....BB......BB........",
			".S......S........S....",
			"###...#####...########",
			"###...#####...########",
		],
	},
	{
		"id": "two_gulls", "biome": Biome.PIER, "difficulty": 2,
		"rows": [
			"......................",
			"......g.......g.......",
			"......................",
			".S.........BBB......S.",
			"######################",
			"######################",
		],
	},
	{
		"id": "broken_pier", "biome": Biome.PIER, "difficulty": 3,
		"rows": [
			"........................",
			"........................",
			".....B.....B.....B......",
			".S.................S....",
			"###...##...##....#######",
			"###...##...##....#######",
		],
	},
	{
		"id": "gull_gap", "biome": Biome.PIER, "difficulty": 3,
		"rows": [
			"......................",
			"........g.............",
			"........BBB...........",
			".S..............S.....",
			"######.....###########",
			"######.....###########",
		],
	},
	{
		"id": "storm_pier", "biome": Biome.PIER, "difficulty": 4,
		"rows": [
			"..........................",
			".......g..........g.......",
			"..........................",
			".S.........S..p........S..",
			"####.....#######.....#####",
			"####.....#######.....#####",
		],
	},
	{
		"id": "crane", "biome": Biome.PIER, "difficulty": 4,
		"rows": [
			"........................",
			"...........BB...........",
			"...====...====...====...",
			".S.........g..........S.",
			"##....................##",
			"##....................##",
		],
	},
]

const MARKET: Array[Dictionary] = [
	{
		"id": "market_gate", "biome": Biome.MARKET, "difficulty": 1, "breather": true, "gate": true,
		"rows": [
			"................",
			"................",
			"................",
			"..S....BBBBB....",
			"################",
			"################",
		],
	},
	{
		"id": "market_stalls", "biome": Biome.MARKET, "difficulty": 1, "breather": true,
		"rows": [
			"....................",
			"......?......?......",
			"....................",
			".S.......BBBB.......",
			"####################",
			"####################",
		],
	},
	{
		"id": "lantern_row", "biome": Biome.MARKET, "difficulty": 1, "breather": true,
		"rows": [
			"..................",
			"......BBBB........",
			"......====........",
			".S................",
			"##################",
			"##################",
		],
	},
	{
		"id": "sauce_stall", "biome": Biome.MARKET, "difficulty": 1,
		"rows": [
			"....................",
			"....................",
			".......BB...........",
			".S.............h..S.",
			"##########..########",
			"##########..########",
		],
	},
	{
		"id": "truck_hop", "biome": Biome.MARKET, "difficulty": 1,
		"rows": [
			"....................",
			"........BB..........",
			".......####.........",
			".S.....####.....S...",
			"####################",
			"####################",
		],
	},
	{
		"id": "sauce_pair", "biome": Biome.MARKET, "difficulty": 2,
		"rows": [
			"......................",
			"......................",
			"...........BBB........",
			".S...h...........h..S.",
			"########...###########",
			"########...###########",
		],
	},
	{
		"id": "canopies", "biome": Biome.MARKET, "difficulty": 2,
		"rows": [
			"......................",
			".......BB....BB.......",
			"......====..====......",
			".S..................S.",
			"######..........######",
			"######..........######",
		],
	},
	{
		"id": "truck_convoy", "biome": Biome.MARKET, "difficulty": 3,
		"rows": [
			"........................",
			"..............BB........",
			"......###....####.......",
			".S....###....####....S..",
			"##########...###########",
			"##########...###########",
		],
	},
	{
		"id": "night_vac", "biome": Biome.MARKET, "difficulty": 3,
		"rows": [
			"......................",
			"......................",
			"...........BB.........",
			".S....v..........h..S.",
			"#############....#####",
			"#############....#####",
		],
	},
	{
		"id": "sauce_gauntlet", "biome": Biome.MARKET, "difficulty": 4,
		"rows": [
			"..........................",
			"..........................",
			".....BB........BB.........",
			".S..h.......S.h........hS.",
			"######.....######.....####",
			"######.....######.....####",
		],
	},
	{
		"id": "rooftop_market", "biome": Biome.MARKET, "difficulty": 4,
		"rows": [
			"........................",
			"..........g.............",
			"......########..........",
			".S..##########....h..S..",
			"##############....######",
			"##############....######",
		],
	},
]

## Every chunk of one biome, its gate included.
static func chunks_of(biome: int) -> Array[Dictionary]:
	match biome:
		Biome.BACKYARD:
			var backyard: Array[Dictionary] = [START]
			backyard.append_array(BACKYARD)
			return backyard
		Biome.PARK:
			return PARK
		Biome.STREET:
			return STREET
		Biome.PIER:
			return PIER
		Biome.MARKET:
			return MARKET
	return []


## Any chunk by id, the start, goal and gates included; empty if unknown.
static func chunk_named(id: String) -> Dictionary:
	if id == GOAL["id"]:
		return GOAL
	for biome: int in BIOMES:
		for chunk in chunks_of(biome):
			if chunk["id"] == id:
				return chunk
	return {}


## The chunks the stream may draw at random in `biome`: everything but the gate.
static func pool(biome: int) -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	for chunk in chunks_of(biome):
		if not chunk.get("gate", false):
			chunks.append(chunk)
	return chunks


static func gate_of(biome: int) -> Dictionary:
	for chunk in chunks_of(biome):
		if chunk.get("gate", false):
			return chunk
	return START


## The biome at `world_metres` from the front door, looping after the Market.
static func biome_at(world_metres: float) -> int:
	var along := fposmod(world_metres, CYCLE_METRES)
	var found: int = Biome.BACKYARD
	for biome: int in BIOMES:
		if along >= float(BIOMES[biome]["start_m"]):
			found = biome
	return found


static func biome_named(id: String) -> int:
	for biome: int in BIOMES:
		if BIOMES[biome]["id"] == id:
			return biome
	return Biome.BACKYARD


static func rows_of(chunk: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	rows.assign(chunk.get("rows", []))
	return rows


static func start_position() -> Vector2:
	return Vector2((START_COLUMN + 0.5) * Grid.TILE, SEAM_ROW * Grid.TILE)


## Paints `rows` into `grid` with row 0 at `origin.y`, and returns what else
## the rows hold: `{items, lunchboxes, pests, safe_points}`.
static func build(rows: Array[String], grid: Grid, origin := Vector2i.ZERO) -> Dictionary:
	var items: Dictionary[Vector2i, String] = {}
	var lunchboxes: Dictionary[Vector2i, String] = {}
	var pests: Array[Dictionary] = []
	var safe_points: Array[Vector2] = []
	var goal_x := INF
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
				"F":
					goal_x = feet.x
				_:
					var kind := str(LEGEND.get(glyph, ""))
					if Pests.is_known(kind):
						pests.append({"kind": kind, "feet": feet})
					else:
						push_error("Chunk glyph '%s' at %s is not built yet." % [glyph, cell])
	var course := {
		"items": items, "lunchboxes": lunchboxes, "pests": pests, "safe_points": safe_points,
	}
	if is_finite(goal_x):
		course["goal_x"] = goal_x
	return course


# --------------------------------------------------------------------------
# The validator
# --------------------------------------------------------------------------


## Every reason `chunk` would be unfair or would not join its neighbours; an
## empty list means it may ship.
static func validate(chunk: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var id := str(chunk.get("id", "?"))
	var rows := rows_of(chunk)
	if rows.size() != ROWS:
		problems.append("%s: needs %d rows, has %d." % [id, ROWS, rows.size()])
		return problems
	var width := rows[0].length()
	for row in rows:
		if row.length() != width:
			problems.append("%s: rows differ in width." % id)
			return problems
	if width < MIN_WIDTH or width > MAX_WIDTH:
		problems.append("%s: %d tiles wide; chunks are %d-%d." % [id, width, MIN_WIDTH, MAX_WIDTH])
	if not int(chunk.get("difficulty", 0)) in DIFFICULTIES:
		problems.append("%s: difficulty must be one of %s." % [id, DIFFICULTIES])
	for row in ROWS:
		for column in width:
			var glyph := rows[row][column]
			var kind := str(LEGEND.get(glyph, ""))
			if kind.is_empty():
				problems.append("%s: '%s' at (%d, %d) is not in the legend." % [id, glyph, column, row])
			elif glyph in "psvgh" and not Pests.is_known(kind):
				problems.append("%s: the %s at (%d, %d) is not built yet." % [id, kind, column, row])
	if not problems.is_empty():
		return problems
	if bool(chunk.get("gate", false)):
		if not bool(chunk.get("breather", false)):
			problems.append("%s: a gate is a breather, so a run can start on it." % id)
		if rows[SEAM_ROW - 1][START_COLUMN] != "S":
			problems.append("%s: a gate has safe ground at column %d, where runs start." % [id, START_COLUMN])
	for column: int in [0, width - 1]:
		if rows[SEAM_ROW][column] != "#" or _blocked_above(rows, column, SEAM_ROW):
			problems.append("%s: column %d must be open ground on the seam row." % [id, column])
	if bool(chunk.get("breather", false)):
		for column in width:
			if rows[SEAM_ROW][column] != "#":
				problems.append("%s: a breather has no pits (column %d)." % [id, column])
				break
		for row in rows:
			for glyph in "pnsvgh":
				if glyph in row:
					problems.append("%s: a breather has no pests." % id)
					return problems
	problems.append_array(_placement_problems(id, rows))
	problems.append_array(route_problems(rows, id))
	return problems


## Reachability over any strip of six rows: from the entry, the exit can be
## reached, and every safe-ground marker is reachable and is not a dead end.
## Used on single chunks and on whole generated runs alike.
static func route_problems(rows: Array[String], id := "course") -> PackedStringArray:
	var problems := PackedStringArray()
	var width := rows[0].length()
	var spots := _spots(rows)
	var entry := Vector2i(0, SEAM_ROW)
	var exit := Vector2i(width - 1, SEAM_ROW)
	if not spots.has(entry) or not spots.has(exit):
		problems.append("%s: no ground to enter or leave on." % id)
		return problems
	var by_column := _by_column(spots)
	var from_entry := _reachable(rows, by_column, entry, false)
	# Searching backwards from the exit finds every spot that is not a dead end
	# in one pass, however many markers the strip holds.
	var to_exit := _reachable(rows, by_column, exit, true)
	if not from_entry.has(exit):
		problems.append("%s: the exit cannot be reached from the entry." % id)
	var markers := 0
	for row in ROWS:
		for column in width:
			if rows[row][column] == "F":
				var under := Vector2i(column, row + 1)
				if row + 1 >= ROWS or rows[row + 1][column] != "#":
					problems.append("%s: the goal at (%d, %d) must stand on solid ground." % [id, column, row])
				elif not from_entry.has(under):
					problems.append("%s: the goal at (%d, %d) cannot be reached." % [id, column, row])
				continue
			if rows[row][column] != "S":
				continue
			markers += 1
			var spot := Vector2i(column, row + 1)
			if row + 1 >= ROWS or rows[row + 1][column] != "#":
				problems.append("%s: the S at (%d, %d) must stand on solid ground." % [id, column, row])
			elif not from_entry.has(spot):
				problems.append("%s: the S at (%d, %d) cannot be reached." % [id, column, row])
			elif not to_exit.has(spot):
				problems.append("%s: respawning at the S at (%d, %d) is a dead end." % [id, column, row])
	if markers == 0:
		problems.append("%s: needs at least one S (safe ground)." % id)
	return problems


## Pests stand on something, and a gnome, which cannot be stomped, leaves
## room to land on either side of it.
static func _placement_problems(id: String, rows: Array[String]) -> PackedStringArray:
	var problems := PackedStringArray()
	var spots := _spots(rows)
	for row in ROWS:
		for column in rows[0].length():
			var glyph := rows[row][column]
			if not glyph in "pnsvgh":
				continue
			if Pests.flies(str(LEGEND[glyph])):
				continue
			if not spots.has(Vector2i(column, row + 1)):
				problems.append("%s: the pest at (%d, %d) has nothing to stand on." % [id, column, row])
			elif glyph == "n" and not (spots.has(Vector2i(column - 1, row + 1))
					and spots.has(Vector2i(column + 1, row + 1))):
				problems.append("%s: the gnome at (%d, %d) needs room to land beside it." % [id, column, row])
	return problems


## Every place she can stand: `Vector2i(column, row)` of the tile under her.
static func _spots(rows: Array[String]) -> Dictionary:
	var spots := {}
	for row in ROWS:
		for column in rows[row].length():
			if rows[row][column] in SUPPORTS and not _glyph_blocks(rows, column, row - 1):
				spots[Vector2i(column, row)] = true
	return spots


static func _by_column(spots: Dictionary) -> Dictionary:
	var columns := {}
	for spot: Vector2i in spots:
		if not columns.has(spot.x):
			columns[spot.x] = []
		columns[spot.x].append(spot)
	return columns


## Spots reachable from `from`, or with `backwards`, spots that can reach it.
static func _reachable(
	rows: Array[String], by_column: Dictionary, from: Vector2i, backwards: bool
) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_front()
		for column in range(here.x - MAX_JUMP_COLUMNS, here.x + MAX_JUMP_COLUMNS + 1):
			for there: Vector2i in by_column.get(column, []):
				if seen.has(there):
					continue
				var moves := _can_move(rows, there, here) if backwards \
					else _can_move(rows, here, there)
				if moves:
					seen[there] = true
					queue.append(there)
	return seen


## A walk to the next tile at the same height, or a running jump that the
## body clears with `MARGIN_TILES` to spare across and up, over columns with
## nothing solid at or above the lower of the two surfaces.
static func _can_move(rows: Array[String], from: Vector2i, to: Vector2i) -> bool:
	var across := absi(to.x - from.x)
	if across == 0 or across > MAX_JUMP_COLUMNS:
		return false
	if across == 1 and to.y == from.y:
		return true
	var rise := (from.y - to.y) * Grid.TILE
	if rise > 0.0 and rise > State.jump_height(State.RUN_SPEED) - MARGIN_TILES * Grid.TILE:
		return false
	var lowest := maxi(from.y, to.y)
	var step := signi(to.x - from.x)
	for column in range(from.x + step, to.x, step):
		for row in lowest:
			if _glyph_blocks(rows, column, row):
				return false
	if not _reach_by_rise.has(rise):
		_reach_by_rise[rise] = State.jump_reach(State.RUN_SPEED, rise)
	return _reach_by_rise[rise] >= (across - 1 + MARGIN_TILES) * Grid.TILE


static func _glyph_blocks(rows: Array[String], column: int, row: int) -> bool:
	if row < 0 or row >= ROWS or column < 0 or column >= rows[row].length():
		return false
	return rows[row][column] in BLOCKS


static func _blocked_above(rows: Array[String], column: int, row: int) -> bool:
	for above in row:
		if _glyph_blocks(rows, column, above):
			return true
	return false
