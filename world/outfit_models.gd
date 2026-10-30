extends RefCounted

## The store's cosmetics as meshes, built in the same rounded-primitive style
## as Dulce (DESIGN §9.2).
##
## Every colour comes from the item's own entry in the options file, so the
## swatch on a store card and the thing she wears can never disagree. Hats
## are built for the head pivot (origin between her ears), collars and
## bandanas for the collar socket on her neck.

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")

## Where a hat sits on the head pivot, in metres. Neck pieces are built
## around the collar socket itself.
const HAT_AT := Vector3(0.04, 0.14, 0.0)

static var _cache: Dictionary[String, ArrayMesh] = {}


static func item(id: String) -> Dictionary:
	for entry: Dictionary in Options.STORE_ITEMS:
		if entry["id"] == id:
			return entry
	return {}


static func color_of(id: String, fallback := Art.COLLAR) -> Color:
	return item(id).get("color", fallback)


## The collar band for `id`: its colour, a little bun-shaped tag, and studs
## on the spiked one.
static func collar_mesh(id: String) -> ArrayMesh:
	var key := "collar_" + id
	if not _cache.has(key):
		var mesh := MeshBuilder.new()
		mesh.torus(Vector3.ZERO, 0.062, 0.082, color_of(id), Vector3(0, 0, -PI / 2 + 0.55))
		mesh.ellipsoid(Vector3(0.02, -0.075, 0.0), Vector3(0.025, 0.03, 0.012), Art.MUSTARD, 8)
		if id == Options.COLLAR_SPIKED:
			for stud in 8:
				var angle := TAU * stud / 8.0
				var at := Basis.from_euler(Vector3(0, 0, -PI / 2 + 0.55)) \
					* Vector3(cos(angle) * 0.085, 0.0, sin(angle) * 0.085)
				mesh.cylinder(at, 0.012, 0.03, Color("d9dde3"), Vector3(0, 0, 0), 6, 0.1)
		_cache[key] = mesh.finish()
	return _cache[key]


## A hat for the head pivot, or null for no hat.
static func hat_mesh(id: String) -> ArrayMesh:
	if id.is_empty() or item(id).is_empty():
		return null
	var key := "hat_" + id
	if not _cache.has(key):
		var mesh := MeshBuilder.new()
		var colour := color_of(id)
		match id:
			Options.HAT_PARTY:
				mesh.cylinder(HAT_AT + Vector3(0, 0.07, 0), 0.06, 0.15, colour, Vector3(0, 0, -0.15), 14, 0.0)
				mesh.ellipsoid(HAT_AT + Vector3(-0.012, 0.15, 0), Vector3.ONE * 0.03, Art.MUSTARD, 8)
				mesh.torus(HAT_AT + Vector3(0, 0.005, 0), 0.05, 0.066, Color("6fc3e8"), Vector3(0, 0, -0.15))
			Options.HAT_FLOWERS:
				for bloom in 7:
					var angle := TAU * bloom / 7.0
					var at := HAT_AT + Vector3(cos(angle) * 0.07, 0.0, sin(angle) * 0.07)
					mesh.ellipsoid(at, Vector3.ONE * 0.04, [colour, Art.KETCHUP, Color("f4f1ea")][bloom % 3], 8)
				mesh.torus(HAT_AT, 0.06, 0.075, Art.LETTUCE)
			Options.HAT_CHEF:
				mesh.cylinder(HAT_AT + Vector3(0, 0.02, 0), 0.06, 0.05, colour, Vector3.ZERO, 14)
				mesh.ellipsoid(HAT_AT + Vector3(0, 0.08, 0), Vector3(0.15, 0.1, 0.15), colour, 14)
			Options.HAT_SOMBRERO:
				mesh.cylinder(HAT_AT, 0.17, 0.02, colour, Vector3.ZERO, 24)
				mesh.cylinder(HAT_AT + Vector3(0, 0.05, 0), 0.06, 0.09, colour, Vector3.ZERO, 16, 0.75)
				mesh.torus(HAT_AT + Vector3(0, 0.02, 0), 0.06, 0.07, Art.KETCHUP)
			_:
				mesh.cylinder(HAT_AT + Vector3(0, 0.04, 0), 0.07, 0.08, colour, Vector3.ZERO, 14)
		_cache[key] = mesh.finish()
	return _cache[key]


## A bandana or cape for the torso pivot, or null for neither.
static func neck_mesh(id: String) -> ArrayMesh:
	if id.is_empty() or item(id).is_empty():
		return null
	var key := "neck_" + id
	if not _cache.has(key):
		var mesh := MeshBuilder.new()
		var colour := color_of(id)
		if id == Options.CAPE_HERO:
			# Down her back from the collar, like a cape should be.
			mesh.rounded_box(Vector3(-0.12, 0.05, 0), Vector3(0.3, 0.02, 0.24), 0.01, colour,
				Vector3(0, 0, -0.12))
			mesh.torus(Vector3.ZERO, 0.06, 0.075, Art.MUSTARD, Vector3(0, 0, -PI / 2 + 0.55))
		else:
			# A folded triangle under the chin.
			var fold := PackedVector2Array([
				Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.0, -0.1),
			])
			mesh.extrude(fold, 0.17, colour)
			mesh.torus(Vector3(0, 0.0, 0), 0.06, 0.075, colour, Vector3(0, 0, -PI / 2 + 0.55))
		_cache[key] = mesh.finish()
	return _cache[key]
