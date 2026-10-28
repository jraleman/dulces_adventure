extends Node3D

## Dulce in the 3D world: a read-only picture of `run_state.gd`.
##
## Milestone 1 grey box: a few rounded primitives in her colours, so jump
## height and facing read while the movement is tuned. Milestone 4 swaps the
## geometry for the Blender GLB and its poses behind the same calls.
## Nothing here ever feeds back into the model.

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")

## Turning round takes this long; reduced motion turns at once.
const TURN_SECONDS := 0.12
## Full is a shape, not a colour: rounder and a little taller (DESIGN §9.5).
const FULL_SCALE := Vector3(1.14, 1.1, 1.14)
## The i-frame blink: a gentle opacity pulse, never a flash, in either mode.
const BLINK_HZ := 4.0
const BLINK_LOWEST := 0.35
## The flustered tumble: one and a half turns over the tumble's length.
const TUMBLE_TURNS := 1.5

var _body: MeshInstance3D
var _finish: StandardMaterial3D
var _yaw := 0.0


func _init() -> void:
	name = "Dulce"
	_body = MeshInstance3D.new()
	_body.name = "GreyBox"
	_body.mesh = _build_mesh()
	_finish = Art.material(0.8)
	_body.material_override = _finish
	add_child(_body)


## Feet at the model's bottom centre, facing the way she last moved.
func present(state: State, delta: float, reduced_motion: bool) -> void:
	position = Art.world_point(state.position)
	var target := 0.0 if state.facing > 0 else PI
	if reduced_motion or delta <= 0.0:
		_yaw = target
	else:
		_yaw = move_toward(_yaw, target, PI * delta / TURN_SECONDS)
	rotation.y = _yaw
	_body.scale = FULL_SCALE if state.full else Vector3.ONE
	_present_blink(state)
	_present_tumble(state, reduced_motion)


func _present_blink(state: State) -> void:
	var alpha := 1.0
	if state.is_invulnerable():
		var wave := 0.5 + 0.5 * cos(TAU * BLINK_HZ * state.invulnerable_left)
		alpha = lerpf(BLINK_LOWEST, 1.0, wave)
	_finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 \
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	_finish.albedo_color = Color(1, 1, 1, alpha)


## A cute topple, never a death animation. Reduced motion skips the spin and
## simply tips her onto her side.
func _present_tumble(state: State, reduced_motion: bool) -> void:
	if not state.over:
		_body.rotation.z = 0.0
		return
	var played := 1.0 - state.tumble_left / State.TUMBLE_SECONDS
	_body.rotation.z = PI * 0.5 if reduced_motion else TAU * TUMBLE_TURNS * played


## 0.6 m long and 0.45 m tall to the ear tips (DESIGN §2), facing +x.
static func _build_mesh() -> ArrayMesh:
	var mesh := MeshBuilder.new()
	var fawn := Art.FAWN
	var cream := Art.CREAM
	var ink := Art.INK
	mesh.ellipsoid(Vector3(-0.02, 0.2, 0), Vector3(0.42, 0.22, 0.22), fawn, 16)
	mesh.ellipsoid(Vector3(0.08, 0.17, 0), Vector3(0.2, 0.16, 0.18), cream, 12)
	mesh.ellipsoid(Vector3(0.2, 0.3, 0), Vector3(0.2, 0.18, 0.18), fawn, 16)
	mesh.ellipsoid(Vector3(0.29, 0.27, 0), Vector3(0.1, 0.08, 0.1), cream, 10)
	mesh.ellipsoid(Vector3(0.34, 0.285, 0), Vector3(0.035, 0.03, 0.04), ink, 8)
	for side: float in [-1.0, 1.0]:
		# Big upright ears are her silhouette, so they stay in the grey box.
		mesh.ellipsoid(Vector3(0.17, 0.42, 0.06 * side),
			Vector3(0.06, 0.14, 0.03), fawn, 10)
		mesh.ellipsoid(Vector3(0.26, 0.33, 0.075 * side),
			Vector3(0.035, 0.04, 0.02), ink, 8)
		for along: float in [-0.14, 0.1]:
			mesh.cylinder(Vector3(along, 0.06, 0.07 * side), 0.03, 0.13, fawn, Vector3.ZERO, 8)
	mesh.ellipsoid(Vector3(-0.24, 0.3, 0), Vector3(0.08, 0.12, 0.06), fawn, 10)
	return mesh.finish()
