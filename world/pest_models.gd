extends RefCounted

## Pest meshes, built from primitives into one vertex-coloured surface each.
##
## Milestone 2 grey boxes, original shapes sized to the hit boxes in
## `pests.gd`. Silhouette, not colour, tells them apart (DESIGN §4.3): the
## pigeon is wide and low with a beak, the gnome narrow and tall with a
## pointed hat. Each faces +x with its feet at the origin. Milestone 4 swaps
## in the Blender models behind `mesh_for()`.

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const Pests = preload("res://games/dulces_adventure/pests.gd")

const PIGEON_GREY := Color("8d93a3")
const PIGEON_NECK := Color("6f8f86")
const BEAK := Color("e0a148")
const GNOME_HAT := Color("c8473a")
const GNOME_COAT := Color("3f6aa8")
const BEARD := Color("f1ece2")
const SKIN := Color("f0c4a0")

static var _cache: Dictionary[String, ArrayMesh] = {}


static func mesh_for(kind: String) -> ArrayMesh:
	if not _cache.has(kind):
		_cache[kind] = _pigeon() if kind == Pests.PIGEON else _gnome()
	return _cache[kind]


static func _pigeon() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.ellipsoid(Vector3(-0.02, 0.2, 0), Vector3(0.5, 0.3, 0.3), PIGEON_GREY, 16)
	mesh.ellipsoid(Vector3(0.18, 0.36, 0), Vector3(0.18, 0.18, 0.17), PIGEON_NECK, 12)
	mesh.cylinder(Vector3(0.31, 0.36, 0), 0.035, 0.1, BEAK, Vector3(0, 0, -PI / 2), 8, 0.2)
	mesh.box(Vector3(-0.3, 0.26, 0), Vector3(0.16, 0.05, 0.2), PIGEON_GREY.darkened(0.2),
		Vector3(0, 0, 0.35))
	for side: float in [-1.0, 1.0]:
		mesh.ellipsoid(Vector3(0.24, 0.4, 0.07 * side), Vector3(0.04, 0.04, 0.02), Art.INK, 6)
		mesh.cylinder(Vector3(0.0, 0.04, 0.06 * side), 0.015, 0.09, BEAK, Vector3.ZERO, 6)
	return mesh.finish()


static func _gnome() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.cylinder(Vector3(0, 0.16, 0), 0.17, 0.32, GNOME_COAT, Vector3.ZERO, 14, 0.75)
	mesh.ellipsoid(Vector3(0, 0.38, 0), Vector3(0.22, 0.2, 0.2), SKIN, 12)
	mesh.ellipsoid(Vector3(0.04, 0.32, 0), Vector3(0.2, 0.18, 0.18), BEARD, 12)
	# The pointed hat is why a gnome can't be stomped; it has to read at a glance.
	mesh.cylinder(Vector3(0, 0.6, 0), 0.13, 0.36, GNOME_HAT, Vector3.ZERO, 14, 0.0)
	mesh.ellipsoid(Vector3(0.1, 0.38, 0), Vector3(0.05, 0.05, 0.05), Color("d98a73"), 8)
	return mesh.finish()
