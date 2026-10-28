extends RefCounted

## Food and Lunchbox meshes, built from primitives into one surface each.
##
## Milestone 2 grey boxes, centred on the origin so a pickup sits in the
## middle of its tile. A Big Burger is a bigger, taller stack than a burger,
## and the Golden Bone is a bone, so none of them depends on colour to read.

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")

const BUN := Color("d99a4e")
const PATTY := Color("6b3b26")
const GOLD := Color("f2c14e")
const LUNCHBOX_LID := Color("e8eef2")

static var _cache: Dictionary[String, ArrayMesh] = {}


static func mesh_for(kind: String) -> ArrayMesh:
	if not _cache.has(kind):
		match kind:
			State.BIG_BURGER:
				_cache[kind] = _burger(1.35, true)
			State.GOLDEN_BONE:
				_cache[kind] = _bone()
			_:
				_cache[kind] = _burger(1.0, false)
	return _cache[kind]


static func _burger(scale: float, big: bool) -> ArrayMesh:
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
