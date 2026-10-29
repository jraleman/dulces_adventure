extends RefCounted

## The fixed, finishable stages, one per biome (DESIGN §5.5).
##
## Each stage is about 300 m of its own biome's authored chunks, in a fixed
## order that climbs in difficulty. It opens on the biome's gate and ends on
## the goal chunk, so a stage plays the same every time and its clear time
## can be compared between attempts. Clearing a stage opens the next; the
## headline is the clear time. Constants and pure helpers only: no nodes, no
## autoloads.

const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")

## A stage is a short course: long enough to be a journey through its biome,
## short enough to retry for a better time.
const MIN_METRES := 280.0
const MAX_METRES := 340.0

const STAGES: Array[Dictionary] = [
	{
		"id": Options.STAGE_BACKYARD, "number": 1, "biome": ChunkLibrary.Biome.BACKYARD,
		"clear_achievement": Options.CLEARED_BACKYARD,
		"chunks": [
			"backyard_start", "pit_hop", "pigeon_lawn", "two_gaps", "lawn", "steps",
			"gnome_gate", "ledge_gnome", "picnic", "platform_pit", "pigeon_island", "shade",
			"lunch_break", "wide_leap", "pigeon_pair",
		],
	},
	{
		"id": Options.STAGE_PARK, "number": 2, "biome": ChunkLibrary.Biome.PARK,
		"clear_achievement": Options.CLEARED_PARK,
		"chunks": [
			"park_gate", "duck_pond", "park_steps", "park_meadow", "squirrel_run", "bench_hop",
			"park_path", "twin_ponds", "tree_tops", "duck_pond", "squirrel_ambush", "park_path",
			"high_branches", "bench_hop", "park_steps",
		],
	},
	{
		"id": Options.STAGE_STREET, "number": 3, "biome": ChunkLibrary.Biome.STREET,
		"clear_achievement": Options.CLEARED_STREET,
		"chunks": [
			"street_gate", "manhole", "kerb_steps", "corner_shop", "vac_lane", "parked_cars",
			"awnings", "vac_pair", "scaffold", "manhole", "rush_hour", "corner_shop", "rooftop",
			"kerb_steps",
		],
	},
	{
		"id": Options.STAGE_PIER, "number": 4, "biome": ChunkLibrary.Biome.PIER,
		"clear_achievement": Options.CLEARED_PIER,
		"chunks": [
			"pier_gate", "plank_gaps", "gull_watch", "boardwalk", "jetty", "two_gulls",
			"deck_chairs", "broken_pier", "gull_gap", "boardwalk", "storm_pier", "deck_chairs",
			"crane", "plank_gaps",
		],
	},
	{
		"id": Options.STAGE_MARKET, "number": 5, "biome": ChunkLibrary.Biome.MARKET,
		"clear_achievement": Options.CLEARED_MARKET,
		"chunks": [
			"market_gate", "sauce_stall", "truck_hop", "market_stalls", "sauce_pair", "canopies",
			"lantern_row", "truck_convoy", "night_vac", "market_stalls", "sauce_gauntlet",
			"lantern_row", "rooftop_market", "truck_hop",
		],
	},
]


static func find(id: String) -> Dictionary:
	for stage in STAGES:
		if stage["id"] == id:
			return stage
	return {}


static func is_stage(id: String) -> bool:
	return not find(id).is_empty()


## Every chunk the stage lays, in order, the goal included.
static func chunks(stage: Dictionary) -> Array[Dictionary]:
	var laid: Array[Dictionary] = []
	for id: String in stage["chunks"]:
		laid.append(ChunkLibrary.chunk_named(id))
	laid.append(ChunkLibrary.GOAL)
	return laid


## The whole stage as one strip of rows, for the validator and the counts.
static func rows(stage: Dictionary) -> Array[String]:
	var strip: Array[String] = []
	strip.resize(ChunkLibrary.ROWS)
	strip.fill("")
	for chunk in chunks(stage):
		var chunk_rows := ChunkLibrary.rows_of(chunk)
		for row in ChunkLibrary.ROWS:
			strip[row] += chunk_rows[row]
	return strip


## Metres from where she starts to the goal.
static func length_m(stage: Dictionary) -> float:
	var strip := rows(stage)
	for row in strip.size():
		var goal := strip[row].find("F")
		if goal >= 0:
			return goal - ChunkLibrary.START_COLUMN
	return 0.0


## Every burger in the stage, in the open or in a Lunchbox: the "of" in
## "42 of 57 burgers".
static func food_total(stage: Dictionary) -> int:
	var total := 0
	for row in rows(stage):
		total += row.count("B") + row.count("?")
	return total


## "1:04.3", the way a clear time is shown everywhere.
static func time_text(seconds: float) -> String:
	var tenths := roundi(maxf(seconds, 0.0) * 10.0)
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
