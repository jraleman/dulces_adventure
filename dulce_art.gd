extends RefCounted

## Palette, scale and materials shared by the run, its portraits and the HUD.
##
## Same API shape as Cube Trials' `cube_art.gd` (DESIGN §2), copied rather
## than preloaded, so neither game depends on the other.

const INK := Color("2e2a33")
const CREAM := Color("fff1d6")
## The accent: burger cheese.
const MUSTARD := Color("f2b33d")
const KETCHUP := Color("d9533b")
const LETTUCE := Color("6fae4f")
## Dulce's coat, pending reference photos (DESIGN §13.1).
const FAWN := Color("d6a26b")
const SOIL := Color("8a5a3c")
const SOIL_DARK := Color("6b4430")
## The back wall of a pit: dark enough to read as a hole, warm enough to stay
## the same earth as the ground either side.
const PIT := Color("3a2620")
const PLANK := Color("c79a62")
const SHADOW := Color(0.08, 0.06, 0.1, 0.38)

## 40 simulation units are one metre, and one tile.
const WORLD_SCALE := 0.025
## The simulation's y = 0 sits this far above the 3D origin, so the seam row
## (y = 160) is a little above the floor of the world.
const HEIGHT_ORIGIN := 400.0
## How deep the playfield's ground runs into and out of the screen, in metres.
const GROUND_DEPTH := 3.0


## Physics stays in its tested side-view plane; the renderer adds real depth.
static func world_point(point: Vector2, depth := 0.0) -> Vector3:
	return Vector3(point.x * WORLD_SCALE, (HEIGHT_ORIGIN - point.y) * WORLD_SCALE, depth)


## Vertex paint batches details without losing per-part roughness.
static func material(roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.vertex_color_is_srgb = true
	finish.roughness = roughness
	finish.metallic = metallic
	return finish


## Unlit and alpha-blended, for the blob shadow and other flat helpers that
## must read the same in daylight and at night.
static func flat_material(color: Color) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finish.albedo_color = color
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	return finish
