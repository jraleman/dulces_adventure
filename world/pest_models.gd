extends RefCounted

## Pest meshes, built from primitives into one vertex-coloured surface each.
##
## Original shapes sized to the hit boxes in `pests.gd`. Silhouette, not
## colour, tells them apart (DESIGN §4.3): the wide low pigeon with a beak,
## the narrow pointed gnome, the squirrel's big upright tail, the flat round
## robo-vac, the seagull's raised wings and the tall capped bottle. Each faces
## +x with its feet at the origin.

const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const MeshBuilder = preload("res://games/dolces_adventure/world/mesh_builder.gd")
const Pests = preload("res://games/dolces_adventure/pests.gd")

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
		match kind:
			Pests.PIGEON:
				_cache[kind] = _pigeon()
			Pests.SQUIRREL:
				_cache[kind] = _squirrel()
			Pests.ROBO_VAC:
				_cache[kind] = _robo_vac()
			Pests.SEAGULL:
				_cache[kind] = _seagull()
			Pests.HOT_SAUCE:
				_cache[kind] = _hot_sauce()
			Pests.SAUCE_DROP:
				_cache[kind] = _drop()
			_:
				_cache[kind] = _gnome()
	return _cache[kind]


static func _squirrel() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	var fur := Color("a0643a")
	mesh.ellipsoid(Vector3(0.02, 0.18, 0), Vector3(0.32, 0.24, 0.2), fur, 14)
	mesh.ellipsoid(Vector3(0.18, 0.3, 0), Vector3(0.16, 0.15, 0.15), fur, 12)
	mesh.ellipsoid(Vector3(0.24, 0.28, 0), Vector3(0.07, 0.06, 0.08), Color("f1d6b8"), 8)
	mesh.ellipsoid(Vector3(0.2, 0.33, 0.06), Vector3(0.03, 0.035, 0.02), Art.INK, 6)
	mesh.ellipsoid(Vector3(0.16, 0.4, 0.04), Vector3(0.04, 0.07, 0.03), fur.darkened(0.2), 6)
	# The big bushy tail, curled up over its back, is the squirrel's silhouette.
	mesh.ellipsoid(Vector3(-0.17, 0.3, 0), Vector3(0.16, 0.36, 0.16), fur.lightened(0.15), 12)
	mesh.ellipsoid(Vector3(-0.11, 0.5, 0), Vector3(0.2, 0.16, 0.16), fur.lightened(0.15), 10)
	return mesh.finish()


static func _robo_vac() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.cylinder(Vector3(0, 0.09, 0), 0.44, 0.16, Color("3d4350"), Vector3.ZERO, 24)
	mesh.cylinder(Vector3(0, 0.18, 0), 0.36, 0.04, Color("8b93a3"), Vector3.ZERO, 24)
	mesh.box(Vector3(0.38, 0.09, 0), Vector3(0.12, 0.1, 0.5), Art.INK)
	mesh.ellipsoid(Vector3(0.1, 0.21, 0), Vector3(0.08, 0.04, 0.08), Color("7fd6ff"), 8)
	for side: float in [-1.0, 1.0]:
		mesh.cylinder(Vector3(-0.1, 0.01, 0.28 * side), 0.05, 0.04, Art.INK, Vector3(PI / 2, 0, 0), 10)
	return mesh.finish()


static func _seagull() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.ellipsoid(Vector3(0, 0.2, 0), Vector3(0.48, 0.2, 0.2), Color("f4f4f2"), 14)
	mesh.ellipsoid(Vector3(0.24, 0.27, 0), Vector3(0.16, 0.15, 0.14), Color("f4f4f2"), 10)
	mesh.cylinder(Vector3(0.36, 0.26, 0), 0.03, 0.12, BEAK, Vector3(0, 0, -PI / 2), 8, 0.2)
	mesh.ellipsoid(Vector3(0.27, 0.31, 0.06), Vector3(0.03, 0.03, 0.02), Art.INK, 6)
	# Wings raised and swept back, so it reads as flying even when still.
	mesh.rounded_box(Vector3(-0.06, 0.36, 0), Vector3(0.46, 0.05, 0.66), 0.024,
		Color("9aa3ad"), Vector3(0, 0, 0.5))
	mesh.box(Vector3(-0.27, 0.22, 0), Vector3(0.14, 0.04, 0.14), Color("3c3f45"), Vector3(0, 0, 0.3))
	return mesh.finish()


static func _hot_sauce() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.cylinder(Vector3(0, 0.22, 0), 0.16, 0.44, Art.KETCHUP, Vector3.ZERO, 16)
	mesh.cylinder(Vector3(0, 0.5, 0), 0.07, 0.14, Art.KETCHUP, Vector3.ZERO, 12, 0.6)
	mesh.cylinder(Vector3(0, 0.62, 0), 0.06, 0.1, Color("f4f1ea"), Vector3.ZERO, 12)
	mesh.cylinder(Vector3(0, 0.24, 0), 0.165, 0.18, Color("f4e2b8"), Vector3.ZERO, 16)
	mesh.ellipsoid(Vector3(0.12, 0.32, 0.08), Vector3(0.05, 0.05, 0.02), Art.INK, 6)
	return mesh.finish()


static func _drop() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.ellipsoid(Vector3(0, 0.12, 0), Vector3(0.22, 0.26, 0.22), Art.KETCHUP, 10)
	return mesh.finish()


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
