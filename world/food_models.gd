extends RefCounted

## Food and Lunchbox meshes, built from primitives into one surface each.
##
## Centred on the origin so a pickup sits in the middle of its tile. Every
## biome serves its own flavour of the humble burger (DESIGN §5.3): hot dogs
## in the Park, tacos on Main Street, fries on the Pier and gold-wrapped
## burgers at the Night Market. They all count as burgers. A Big Burger is a
## bigger stack and the Golden Bone is a bone, so none relies on colour.

const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const MeshBuilder = preload("res://games/dolces_adventure/world/mesh_builder.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")

const BUN := Color("d99a4e")
const PATTY := Color("6b3b26")
const GOLD := Color("f2c14e")
const LUNCHBOX_LID := Color("e8eef2")
const SAUSAGE := Color("b8503a")
const SHELL := Color("e8b54a")
const FRY := Color("f4cf5a")

static var _cache: Dictionary[String, ArrayMesh] = {}


static func mesh_for(kind: String, biome: int = ChunkLibrary.Biome.BACKYARD) -> ArrayMesh:
	var key := kind if kind != State.BURGER else "%s_%d" % [kind, biome]
	if not _cache.has(key):
		match kind:
			State.BIG_BURGER:
				_cache[key] = _burger(1.35, true)
			State.GOLDEN_BONE:
				_cache[key] = _bone()
			_:
				_cache[key] = _flavour(biome)
	return _cache[key]


static func _flavour(biome: int) -> ArrayMesh:
	match biome:
		ChunkLibrary.Biome.PARK:
			return _hot_dog()
		ChunkLibrary.Biome.STREET:
			return _taco()
		ChunkLibrary.Biome.PIER:
			return _fries()
		ChunkLibrary.Biome.MARKET:
			return _burger(1.0, false, true)
	return _burger(1.0, false)


static func _hot_dog() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.ellipsoid(Vector3(0, -0.04, 0), Vector3(0.42, 0.13, 0.16), BUN, 14)
	mesh.cylinder(Vector3(0, 0.02, 0), 0.045, 0.46, SAUSAGE, Vector3(0, 0, PI / 2), 12)
	mesh.box(Vector3(0, 0.07, 0), Vector3(0.3, 0.02, 0.03), Art.MUSTARD, Vector3(0, 0, 0.15))
	return mesh.finish()


## A half-moon shell, open side up, with the filling showing along the top.
static func _taco() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	var shell := PackedVector2Array()
	for step in 13:
		var angle := PI + PI * step / 12.0
		shell.append(Vector2(cos(angle) * 0.2, sin(angle) * 0.17 + 0.06))
	mesh.extrude(shell, 0.12, SHELL)
	mesh.ellipsoid(Vector3(0, 0.07, 0), Vector3(0.34, 0.08, 0.1), Art.LETTUCE, 10)
	mesh.ellipsoid(Vector3(0.06, 0.09, 0), Vector3(0.1, 0.06, 0.08), Art.KETCHUP, 8)
	return mesh.finish()


static func _fries() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.box(Vector3(0, -0.06, 0), Vector3(0.22, 0.22, 0.16), Art.KETCHUP)
	for fry in 5:
		mesh.box(Vector3(-0.08 + fry * 0.04, 0.1 + float(fry % 2) * 0.03, 0),
			Vector3(0.03, 0.22, 0.03), FRY, Vector3(0, 0, (fry - 2) * 0.12))
	return mesh.finish()


static func _burger(scale: float, big: bool, wrapped := false) -> ArrayMesh:
	var mesh := MeshBuilder.new()
	var r := 0.2 * scale
	var y := -0.12 * scale
	mesh.cylinder(Vector3(0, y, 0), r, 0.07 * scale, BUN, Vector3.ZERO, 16)
	y += 0.07 * scale
	mesh.cylinder(Vector3(0, y, 0), r * 1.04, 0.06 * scale, PATTY, Vector3.ZERO, 16)
	if big:
		y += 0.05 * scale
		mesh.cylinder(Vector3(0, y, 0), r * 1.08, 0.025 * scale, Art.MUSTARD, Vector3.ZERO, 16)
		y += 0.04 * scale
		mesh.cylinder(Vector3(0, y, 0), r * 1.04, 0.06 * scale, PATTY, Vector3.ZERO, 16)
	y += 0.045 * scale
	mesh.cylinder(Vector3(0, y, 0), r * 1.1, 0.025 * scale, Art.LETTUCE, Vector3.ZERO, 16)
	mesh.ellipsoid(Vector3(0, y + 0.06 * scale, 0), Vector3(r * 2.0, 0.18 * scale, r * 2.0), BUN, 16)
	if wrapped:
		# The Night Market's burgers come in a gold wrapper.
		mesh.cylinder(Vector3(0, -0.08 * scale, 0), r * 1.15, 0.12 * scale, GOLD, Vector3.ZERO, 16)
	return mesh.finish()


static func _bone() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.cylinder(Vector3.ZERO, 0.045, 0.34, GOLD, Vector3(0, 0, PI / 2), 12)
	for end: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			mesh.ellipsoid(Vector3(0.17 * end, 0.045 * side, 0), Vector3.ONE * 0.1, GOLD, 10)
	return mesh.finish()


## A full Lunchbox reads as a lunchbox: mustard body, white lid, a handle.
## An opened one is a plain, darker box.
static func lunchbox(mesh: MeshBuilder, centre: Vector3, size: float, opened: bool) -> void:
	if opened:
		mesh.box(centre, Vector3(size, size, size), Art.SOIL_DARK.lightened(0.15))
		return
	mesh.box(centre - Vector3(0, size * 0.08, 0), Vector3(size, size * 0.84, size), Art.MUSTARD)
	mesh.box(centre + Vector3(0, size * 0.38, 0), Vector3(size * 1.02, size * 0.16, size * 1.02),
		LUNCHBOX_LID)
	mesh.box(centre + Vector3(0, size * 0.05, size * 0.51), Vector3(size * 0.5, size * 0.12, 0.02),
		Art.INK)
