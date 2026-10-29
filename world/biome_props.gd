extends RefCounted

## What each biome looks like: its palette, the props behind the playfield,
## its gate set piece and its far backdrop (DESIGN §5.3, §7.1).
##
## Everything is built from primitives into batched, vertex-coloured meshes,
## like the rest of the world. Props stand behind the playfield, never in
## front of Dulce, and are placed by column so the same seed always dresses
## the same run. Lanterns and lit windows go into a separate "glow" mesh that
## stays bright at night.

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")

## Props stand this far behind the playfield, on the back of the ground.
const PROP_DEPTH := -1.15
## The backdrop strip: how deep it sits, how wide one tile of it is (metres,
## before scaling), how fast it scrolls relative to the playfield, and how much
## it is shrunk. The camera is orthographic, so nothing shrinks with distance
## on its own: scale and parallax are what make the backdrop read as far away.
const BACKDROP_DEPTH := -16.0
const BACKDROP_TILE := 40.0
const PARALLAX := 0.35
const BACKDROP_SCALE := 0.42

const WHITE := Color("f4f1ea")
const LEAF := Color("4f8f3e")
const LEAF_DARK := Color("3b7134")
const BARK := Color("6b4a33")
const STONE := Color("9a958c")
const STEEL := Color("7d8590")
const SEA := Color("3f7fa8")
const LANTERN := Color("ffcf6b")
const LANTERN_RED := Color("ff7a5c")

## Ground, soil, pits, platforms and sky per biome. A pit's back wall is the
## biome's water or darkness, so pond pits and manholes read as what they are.
const PALETTES := {
	ChunkLibrary.Biome.BACKYARD: {
		"top": Art.LETTUCE, "soil": Art.SOIL, "soil_dark": Art.SOIL_DARK, "pit": Art.PIT,
		"plank": Art.PLANK,
		"sky": {"top": Color("6fa6c9"), "horizon": Color("f3e2bf"), "ground": Color("a9c38f"),
			"ambient": Color("c4d2c4"), "sun": Color("ffe9c4"), "fill": Color("bcd9e6")},
	},
	ChunkLibrary.Biome.PARK: {
		"top": Color("5ea047"), "soil": Color("7a5236"), "soil_dark": Color("5f3f2b"),
		"pit": Color("3d6f8a"), "plank": Color("a77a4f"),
		"sky": {"top": Color("7fb3d6"), "horizon": Color("eef0d2"), "ground": Color("8fb87a"),
			"ambient": Color("c8d8c4"), "sun": Color("fff0cf"), "fill": Color("c4dfe8")},
	},
	ChunkLibrary.Biome.STREET: {
		"top": Color("b9b4ad"), "soil": Color("9c4f3c"), "soil_dark": Color("7d3e30"),
		"pit": Color("232327"), "plank": Color("8a8f96"),
		"sky": {"top": Color("8aa3b8"), "horizon": Color("ece1cc"), "ground": Color("a9a49b"),
			"ambient": Color("ccd0d4"), "sun": Color("fff1dc"), "fill": Color("c6d3de")},
	},
	ChunkLibrary.Biome.PIER: {
		"top": Color("c99a63"), "soil": Color("9b6f45"), "soil_dark": Color("7f5a37"),
		"pit": Color("2f6f9a"), "plank": Color("d9b07a"),
		"sky": {"top": Color("6f86b8"), "horizon": Color("ffc89a"), "ground": Color("7fb0c8"),
			"ambient": Color("e0c8c0"), "sun": Color("ffcf9a"), "fill": Color("b0c4e8")},
	},
	ChunkLibrary.Biome.MARKET: {
		"top": Color("d08a4a"), "soil": Color("4a3a4f"), "soil_dark": Color("3c2f42"),
		"pit": Color("191621"), "plank": Color("b5653c"),
		"sky": {"top": Color("1c2342"), "horizon": Color("6a4a6f"), "ground": Color("2a2a3a"),
			"ambient": Color("8a88b8"), "sun": Color("a0a8d8"), "fill": Color("6a70a8"),
			"sun_energy": 0.35, "ambient_energy": 0.8},
	},
}


static func palette(biome: int) -> Dictionary:
	return PALETTES.get(biome, PALETTES[ChunkLibrary.Biome.BACKYARD])


## A stable pseudo-random number in [0, 1) for a column, so props never move
## between runs of the same seed.
static func _roll(column: int, salt: int) -> float:
	return float(hash(column * 7919 + salt * 104729) % 1000) / 1000.0


## The props behind `width` columns from `first`: `{lit, glow}` meshes. A gate
## chunk adds its "Welcome to" sign; `goal_x`, when it falls in this chunk,
## adds a stage's finish.
static func props(
	grid: Grid, biome: int, first: int, width: int, gate: bool, goal_x := INF
) -> Dictionary:
	var lit := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var has_goal := is_finite(goal_x) and goal_x >= first * Grid.TILE \
		and goal_x < (first + width) * Grid.TILE
	for column in range(first, first + width):
		var top := _top_row(grid, column)
		if top < 0:
			continue
		var base := Art.world_point(Vector2((column + 0.5) * Grid.TILE, top * Grid.TILE), PROP_DEPTH)
		var on_seam := top == ChunkLibrary.SEAM_ROW
		match biome:
			ChunkLibrary.Biome.BACKYARD:
				_backyard(lit, base, column, on_seam)
			ChunkLibrary.Biome.PARK:
				_park(lit, base, column)
			ChunkLibrary.Biome.STREET:
				_street(lit, glow, base, column)
			ChunkLibrary.Biome.PIER:
				_pier(lit, base, column, on_seam)
			ChunkLibrary.Biome.MARKET:
				# The goal is the only food truck at a finish, so it reads as one.
				_market(lit, glow, base, column, first, has_goal)
	if gate:
		var at := Art.world_point(Vector2((first + 8.0) * Grid.TILE,
			ChunkLibrary.SEAM_ROW * Grid.TILE), PROP_DEPTH - 0.1)
		_gate(lit, glow, at, biome)
	if has_goal:
		var finish := Art.world_point(Vector2(goal_x, ChunkLibrary.SEAM_ROW * Grid.TILE), -0.9)
		_goal(lit, glow, finish, biome)
	return {"lit": lit.finish(), "glow": glow.finish()}


## The first row with something to stand on, or -1 over a pit.
static func _top_row(grid: Grid, column: int) -> int:
	for row in grid.bottom_row + 1:
		var kind := grid.tile(Vector2i(column, row))
		if kind == Grid.SOLID:
			return row
	return -1


static func _backyard(mesh: MeshBuilder, base: Vector3, column: int, on_seam: bool) -> void:
	if on_seam:
		# A picket fence runs along the whole garden.
		for picket in 3:
			var x := base.x - 0.33 + picket * 0.33
			mesh.box(Vector3(x, base.y + 0.38, base.z - 0.2), Vector3(0.09, 0.76, 0.04), WHITE)
			mesh.box(Vector3(x, base.y + 0.78, base.z - 0.2), Vector3(0.065, 0.065, 0.04), WHITE,
				Vector3(0, 0, PI / 4))
		for rail: float in [0.22, 0.56]:
			mesh.box(Vector3(base.x, base.y + rail, base.z - 0.23), Vector3(1.0, 0.07, 0.03), WHITE)
	var roll := _roll(column, 1)
	if roll < 0.14:
		mesh.cylinder(base + Vector3(0, 0.12, 0.25), 0.11, 0.24, Art.KETCHUP.darkened(0.2),
			Vector3.ZERO, 12, 0.75)
		for bloom in 3:
			mesh.ellipsoid(base + Vector3(-0.07 + bloom * 0.07, 0.3, 0.25), Vector3.ONE * 0.08,
				[Art.MUSTARD, Art.KETCHUP, WHITE][bloom], 8)
	elif roll < 0.28:
		mesh.ellipsoid(base + Vector3(0, 0.22, 0.2), Vector3(0.6, 0.45, 0.45), LEAF, 12)


static func _park(mesh: MeshBuilder, base: Vector3, column: int) -> void:
	var roll := _roll(column, 2)
	if roll < 0.2:
		var height := 1.4 + roll * 3.0
		mesh.cylinder(base + Vector3(0, height * 0.5, -0.3), 0.09, height, BARK, Vector3.ZERO, 10)
		mesh.ellipsoid(base + Vector3(0, height + 0.15, -0.3), Vector3(1.1, 0.9, 0.9), LEAF, 14)
		mesh.ellipsoid(base + Vector3(0.25, height + 0.45, -0.25), Vector3(0.7, 0.6, 0.6), LEAF_DARK, 12)
	elif roll < 0.3:
		mesh.box(base + Vector3(0, 0.28, 0.1), Vector3(0.9, 0.06, 0.3), Art.PLANK)
		mesh.box(base + Vector3(0, 0.48, -0.02), Vector3(0.9, 0.22, 0.05), Art.PLANK)
		for leg: float in [-0.38, 0.38]:
			mesh.box(base + Vector3(leg, 0.14, 0.1), Vector3(0.05, 0.28, 0.25), STEEL)
	elif roll < 0.45:
		mesh.ellipsoid(base + Vector3(0, 0.08, 0.3), Vector3(0.3, 0.16, 0.3), STONE, 8)


static func _street(mesh: MeshBuilder, glow: MeshBuilder, base: Vector3, column: int) -> void:
	var roll := _roll(column, 3)
	if roll < 0.16:
		mesh.cylinder(base + Vector3(0, 1.1, -0.2), 0.05, 2.2, STEEL, Vector3.ZERO, 8)
		mesh.box(base + Vector3(0.2, 2.18, -0.2), Vector3(0.45, 0.06, 0.06), STEEL)
		glow.ellipsoid(base + Vector3(0.4, 2.08, -0.2), Vector3(0.16, 0.12, 0.16), LANTERN, 10)
	elif roll < 0.24:
		mesh.cylinder(base + Vector3(0, 0.22, 0.2), 0.1, 0.44, Art.KETCHUP, Vector3.ZERO, 10)
		mesh.ellipsoid(base + Vector3(0, 0.46, 0.2), Vector3(0.2, 0.12, 0.2), Art.KETCHUP, 10)
	elif roll < 0.34:
		# A toy-like parked car, low and round.
		mesh.rounded_box(base + Vector3(0, 0.3, -0.5), Vector3(1.4, 0.38, 0.7), 0.12, Color("4d8fd0"))
		mesh.rounded_box(base + Vector3(-0.1, 0.6, -0.5), Vector3(0.8, 0.3, 0.6), 0.1, Color("d7e6f2"))
		for wheel: float in [-0.45, 0.45]:
			mesh.cylinder(base + Vector3(wheel, 0.13, -0.15), 0.13, 0.1, Art.INK,
				Vector3(PI / 2, 0, 0), 12)


static func _pier(mesh: MeshBuilder, base: Vector3, column: int, on_seam: bool) -> void:
	if on_seam:
		mesh.box(base + Vector3(-0.45, 0.45, -0.25), Vector3(0.09, 0.9, 0.09), Art.PLANK.darkened(0.25))
		mesh.box(base + Vector3(0, 0.82, -0.25), Vector3(1.0, 0.07, 0.07), Art.PLANK.darkened(0.15))
	var roll := _roll(column, 4)
	if roll < 0.12:
		mesh.cylinder(base + Vector3(0, 0.75, 0.1), 0.03, 1.5, WHITE, Vector3.ZERO, 6)
		mesh.cylinder(base + Vector3(0, 1.45, 0.1), 0.7, 0.3, [Art.KETCHUP, Color("4fa3c7"),
			Art.MUSTARD][int(roll * 100) % 3], Vector3.ZERO, 16, 0.02)
	elif roll < 0.2:
		mesh.torus(base + Vector3(0.2, 0.55, -0.2), 0.11, 0.2, Art.KETCHUP, Vector3(PI / 2, 0, 0))


static func _market(
	mesh: MeshBuilder, glow: MeshBuilder, base: Vector3, column: int, first: int,
	no_trucks := false
) -> void:
	if (column - first) % 6 == 0:
		mesh.cylinder(base + Vector3(0, 1.2, -0.3), 0.05, 2.4, BARK, Vector3.ZERO, 8)
		# String lights to the next post, sagging a little.
		for bulb in 8:
			var along := bulb / 8.0
			var sag := sin(along * PI) * 0.35
			glow.ellipsoid(base + Vector3(along * 6.0, 2.3 - sag, -0.3), Vector3.ONE * 0.08,
				LANTERN if bulb % 2 == 0 else LANTERN_RED, 6)
	var roll := _roll(column, 5)
	if roll < 0.1 and not no_trucks:
		# A food truck, the Night Market's set dressing.
		mesh.rounded_box(base + Vector3(0, 0.9, -0.6), Vector3(2.4, 1.4, 1.0), 0.12, Color("e8e2d4"))
		mesh.box(base + Vector3(0.1, 1.15, -0.08), Vector3(1.1, 0.5, 0.04), Art.INK)
		glow.box(base + Vector3(0.1, 1.15, -0.06), Vector3(1.0, 0.4, 0.02), LANTERN)
		mesh.box(base + Vector3(0.1, 1.5, 0.0), Vector3(1.3, 0.05, 0.3), Art.KETCHUP, Vector3(-0.3, 0, 0))
		for wheel: float in [-0.8, 0.8]:
			mesh.cylinder(base + Vector3(wheel, 0.18, -0.05), 0.18, 0.12, Art.INK,
				Vector3(PI / 2, 0, 0), 12)
	elif roll < 0.25:
		glow.ellipsoid(base + Vector3(0, 0.25, 0.25), Vector3(0.22, 0.3, 0.22), LANTERN_RED, 10)


## The "Welcome to" set piece: two posts and a sign in the biome's colours.
static func _gate(mesh: MeshBuilder, glow: MeshBuilder, at: Vector3, biome: int) -> void:
	var colours := palette(biome)
	var post: Color = colours["plank"]
	var sign: Color = colours["top"]
	for side: float in [-1.4, 1.4]:
		mesh.box(at + Vector3(side, 1.2, 0), Vector3(0.18, 2.4, 0.18), post)
		mesh.ellipsoid(at + Vector3(side, 2.5, 0), Vector3.ONE * 0.26, sign, 10)
	mesh.box(at + Vector3(0, 2.15, 0), Vector3(3.0, 0.5, 0.1), sign)
	mesh.box(at + Vector3(0, 2.15, 0.06), Vector3(2.6, 0.3, 0.02), Art.CREAM)
	if biome == ChunkLibrary.Biome.MARKET:
		for bulb in 7:
			glow.ellipsoid(at + Vector3(-1.2 + bulb * 0.4, 2.45, 0.08), Vector3.ONE * 0.09, LANTERN, 6)


## The land (or sea) between the playfield and the backdrop, so the backdrop
## stands on something instead of floating above the playfield's back edge.
static func far_ground(biome: int) -> Color:
	if biome == ChunkLibrary.Biome.PIER:
		return SEA
	return (palette(biome)["top"] as Color).darkened(0.08)


## A stage's finish: a food truck with its hatch lit and a checkered banner
## over the line, so the end of the course reads from a screen away.
static func _goal(mesh: MeshBuilder, glow: MeshBuilder, at: Vector3, biome: int) -> void:
	var paint: Color = palette(biome)["plank"]
	mesh.rounded_box(at + Vector3(1.6, 1.05, -0.4), Vector3(2.8, 1.7, 1.2), 0.14, Art.CREAM)
	mesh.box(at + Vector3(1.6, 0.55, 0.22), Vector3(2.82, 0.22, 0.02), paint)
	mesh.box(at + Vector3(1.5, 1.3, 0.21), Vector3(1.3, 0.6, 0.04), Art.INK)
	glow.box(at + Vector3(1.5, 1.3, 0.24), Vector3(1.2, 0.5, 0.02), LANTERN)
	mesh.box(at + Vector3(1.5, 1.72, 0.45), Vector3(1.5, 0.05, 0.5), Art.KETCHUP, Vector3(-0.35, 0, 0))
	for wheel: float in [0.6, 2.6]:
		mesh.cylinder(at + Vector3(wheel, 0.2, 0.22), 0.2, 0.14, Art.INK, Vector3(PI / 2, 0, 0), 14)
	# A chequered flag on a pole at the line, facing the side camera.
	mesh.cylinder(at + Vector3(0.0, 1.5, 0.3), 0.05, 3.0, WHITE, Vector3.ZERO, 8)
	for column in 5:
		for row in 3:
			var colour := Art.INK if (column + row) % 2 == 0 else WHITE
			mesh.box(at + Vector3(0.12 + column * 0.2, 2.82 - row * 0.2, 0.3),
				Vector3(0.2, 0.2, 0.03), colour)


## One backdrop tile, `BACKDROP_TILE` metres wide, its ground line at y = 0.
static func backdrop(biome: int) -> Dictionary:
	var lit := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var w := BACKDROP_TILE
	match biome:
		ChunkLibrary.Biome.BACKYARD:
			for house in 4:
				var x := house * w / 4.0 + 3.0
				var height := 2.6 + float(house % 2) * 0.8
				lit.box(Vector3(x, height * 0.5, 0), Vector3(4.2, height, 2.0),
					[Color("e8d7c0"), Color("cfe0e6"), Color("f0e2c8"), Color("d8e4cc")][house])
				lit.box(Vector3(x, height + 0.55, 0), Vector3(3.2, 3.2, 2.1), Art.KETCHUP.darkened(0.25),
					Vector3(0, 0, PI / 4))
				lit.ellipsoid(Vector3(x + 4.5, 0.6, 0.8), Vector3(3.0, 1.6, 1.5), LEAF_DARK, 10)
		ChunkLibrary.Biome.PARK:
			for hill in 3:
				lit.ellipsoid(Vector3(hill * w / 3.0 + 6.0, 0.0, 0), Vector3(18.0, 7.0 + hill * 2.0, 6.0),
					LEAF.lightened(0.15), 16)
			for tree in 6:
				var x := tree * w / 6.0 + 2.0
				lit.ellipsoid(Vector3(x, 4.0 + float(tree % 3), 2.5), Vector3(2.4, 2.6, 2.0), LEAF_DARK, 10)
		ChunkLibrary.Biome.STREET:
			for block in 8:
				var x := block * w / 8.0 + 2.5
				var height := 5.0 + float((block * 37) % 5) * 1.6
				lit.box(Vector3(x, height * 0.5, 0), Vector3(4.6, height, 3.0),
					[Color("c9b49a"), Color("a7b4c0"), Color("d6c6b6"), Color("b49a8a")][block % 4])
				for floor_index in int(height / 1.6):
					for window in 3:
						lit.box(Vector3(x - 1.3 + window * 1.3, 1.2 + floor_index * 1.6, 1.52),
							Vector3(0.6, 0.7, 0.05), Color("6f8aa3"))
		ChunkLibrary.Biome.PIER:
			for island in 2:
				lit.ellipsoid(Vector3(island * w / 2.0 + 10.0, 0.0, -6.0), Vector3(14.0, 4.0, 5.0),
					Color("8fa88a"), 14)
		ChunkLibrary.Biome.MARKET:
			for block in 9:
				var x := block * w / 9.0 + 2.0
				var height := 6.0 + float((block * 53) % 7) * 1.4
				lit.box(Vector3(x, height * 0.5, 0), Vector3(4.0, height, 3.0), Color("2a2740"))
				for floor_index in int(height / 1.4):
					for window in 2:
						if (block + floor_index + window) % 3 != 0:
							glow.box(Vector3(x - 0.8 + window * 1.6, 1.0 + floor_index * 1.4, 1.52),
								Vector3(0.7, 0.6, 0.05), LANTERN.darkened(0.15))
	return {"lit": lit.finish(), "glow": glow.finish()}
