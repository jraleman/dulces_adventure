extends Node3D

## Dulce in the 3D world: a rig of rigid, vertex-coloured parts that reads
## `run_state.gd` and never feeds back into it.
##
## Built from rounded primitives in GDScript, like Chicken Pit's birds, so it
## needs no Blender and its poses stay testable headless (owner decision; a
## GLB could replace the parts behind the same calls). Head, ears, tail, four
## legs and a collar socket each hang off their own pivot, and a pose is just
## an angle per pivot. The look is DESIGN §7.2's assumed one: all its colours
## live in `dulce_art.gd`.
##
## Reduced motion drops the decorative motion (ear flop, tail wag, squash and
## stretch, the Full bounce) but keeps every pose, so jump, apex, fall and run
## still read differently (DESIGN §9.5).

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")

const IDLE := "idle"
const TROT := "trot"
const SPRINT := "sprint"
const JUMP := "jump"
const APEX := "apex"
const FALL := "fall"
const TUMBLE := "tumble"
const SIT := "sit"
const POSES: Array[String] = [IDLE, TROT, SPRINT, JUMP, APEX, FALL, TUMBLE, SIT]

## Vertical speed, in units per second, that separates rising, apex and falling.
const APEX_BAND := 150.0
## Below this she is standing still.
const STILL_SPEED := 8.0
## Metres of ground per full stride, so paws never skate.
const STRIDE_M := 0.34
## Turning round takes this long; reduced motion turns at once.
const TURN_SECONDS := 0.12
## How fast a pivot settles on its next pose, per second.
const SETTLE_RATE := 18.0
## Full is a shape, not a colour: a round belly and a slightly bigger body.
const FULL_BELLY := Vector3(1.3, 1.5, 1.25)
const FULL_BODY := Vector3(1.05, 1.07, 1.07)
## The i-frame blink: a gentle opacity pulse, never a flash, in either mode.
const BLINK_HZ := 4.0
const BLINK_LOWEST := 0.35
## The flustered tumble: one and a half turns over the tumble's length.
const TUMBLE_TURNS := 1.5
## Short reactions to run events, in seconds.
const REACTIONS := {"land": 0.14, "stomp": 0.18, "eat": 0.24, "hurt": 0.4}

## Pivot positions, in metres, with her paws at the origin and her nose at +x.
const TORSO_PIVOT := Vector3(0.0, 0.19, 0.0)
const HEAD_PIVOT := Vector3(0.15, 0.05, 0.0)
const TAIL_PIVOT := Vector3(-0.18, 0.06, 0.0)
const EAR_PIVOT := Vector3(0.02, 0.1, 0.05)
const COLLAR_AT := Vector3(0.115, 0.045, 0.0)
## Front near, front far, back near, back far; "near" faces the camera.
const LEG_PIVOTS: Array[Vector3] = [
	Vector3(0.11, -0.03, 0.065), Vector3(0.11, -0.03, -0.065),
	Vector3(-0.12, -0.03, 0.065), Vector3(-0.12, -0.03, -0.065),
]
const LEG_NAMES: Array[String] = ["FrontNear", "FrontFar", "BackNear", "BackFar"]

static var _meshes: Dictionary[String, ArrayMesh] = {}

var reduced_motion := false
var _rig: Node3D
var _torso: Node3D
var _belly: MeshInstance3D
var _head: Node3D
var _tail: Node3D
var _collar: MeshInstance3D
var _ears: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _finish: StandardMaterial3D
var _yaw := 0.0
var _gait := 0.0
var _clock := 0.0
var _pose := IDLE
var _victory := false
var _reaction := ""
var _reaction_left := 0.0
var _snap := true


func _init() -> void:
	name = "Dulce"
	_finish = Art.material(0.75)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_torso = _pivot(_rig, "Torso", TORSO_PIVOT)
	_part(_torso, "torso")
	_belly = _part(_torso, "belly")
	for index in LEG_PIVOTS.size():
		_legs.append(_pivot(_torso, LEG_NAMES[index], LEG_PIVOTS[index]))
		_part(_legs[index], "leg")
	_head = _pivot(_torso, "Head", HEAD_PIVOT)
	_part(_head, "head")
	for side: float in [1.0, -1.0]:
		var ear := _pivot(_head, "EarNear" if side > 0.0 else "EarFar",
			Vector3(EAR_PIVOT.x, EAR_PIVOT.y, EAR_PIVOT.z * side))
		_part(ear, "ear_near" if side > 0.0 else "ear_far")
		_ears.append(ear)
	_tail = _pivot(_torso, "Tail", TAIL_PIVOT)
	_part(_tail, "tail")
	_collar = MeshInstance3D.new()
	_collar.name = "Collar"
	_collar.position = COLLAR_AT
	_collar.material_override = _finish
	_torso.add_child(_collar)
	set_collar_color(Art.COLLAR)


## Which pose the run state calls for; reactions play on top of it.
static func pose_for(state: State, victory := false) -> String:
	if victory:
		return SIT
	if state.over:
		return TUMBLE
	if not state.grounded:
		if state.velocity.y < -APEX_BAND:
			return JUMP
		return FALL if state.velocity.y > APEX_BAND else APEX
	var speed := absf(state.velocity.x)
	if speed < STILL_SPEED:
		return IDLE
	return TROT if speed <= State.WALK_SPEED + 1.0 else SPRINT


func pose_name() -> String:
	return _pose


## Plays a short reaction to a run event: "land", "stomp", "eat" or "hurt".
func react(kind: String) -> void:
	if REACTIONS.has(kind):
		_reaction = kind
		_reaction_left = REACTIONS[kind]


## The results' and share card's happy sit.
func set_victory(value: bool) -> void:
	_victory = value
	_snap = true


## Store collars recolour the band (Milestone 7); the default is red.
func set_collar_color(color: Color) -> void:
	_collar.mesh = _collar_mesh(color)


## Feet at the model's bottom centre, facing the way she last moved.
func present(state: State, delta: float, motion_reduced: bool) -> void:
	reduced_motion = motion_reduced
	position = Art.world_point(state.position)
	var target_yaw := 0.0 if state.facing > 0 else PI
	_yaw = target_yaw if reduced_motion or delta <= 0.0 \
		else move_toward(_yaw, target_yaw, PI * delta / TURN_SECONDS)
	rotation.y = _yaw
	_clock += delta
	if state.grounded:
		_gait += absf(state.velocity.x) * Art.WORLD_SCALE * delta / STRIDE_M * TAU
	_reaction_left = maxf(0.0, _reaction_left - delta)
	_pose = pose_for(state, _victory)
	_apply(_targets(state), delta)
	_present_blink(state)
	_present_tumble(state)


# --------------------------------------------------------------------------
# Poses
# --------------------------------------------------------------------------


## Angles, in radians, for every pivot in the current pose.
func _targets(state: State) -> Dictionary:
	var legs: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var pose := {
		"pitch": 0.0, "drop": 0.0, "head": 0.0, "head_turn": 0.0, "ears": 0.0,
		"tail_lift": 0.35, "tail_wag": 0.0, "legs": legs,
		"squash": Vector3.ONE, "full": state.full,
	}
	match _pose:
		TROT:
			# Diagonal pairs swing together, like a real trot.
			for index in 4:
				var offset := 0.0 if index in [0, 3] else PI
				legs[index] = sin(_gait + offset) * 0.55
			pose["ears"] = 0.1
			pose["tail_wag"] = sin(_clock * 9.0) * 0.25
		SPRINT:
			# A gallop: front pair, then back pair, ears pinned back.
			for index in 4:
				var offset := (0.0 if index < 2 else PI) + (0.35 if index % 2 == 1 else 0.0)
				legs[index] = sin(_gait + offset) * 0.85
			pose["pitch"] = sin(_gait) * 0.06
			pose["drop"] = -0.015
			pose["ears"] = 0.75
			pose["tail_lift"] = -0.35
		JUMP:
			legs.assign([0.75, 0.65, -0.85, -0.75])
			pose["pitch"] = 0.3
			pose["ears"] = 0.5
			pose["head"] = -0.12
			pose["tail_lift"] = 0.1
		APEX:
			legs.assign([0.45, 0.35, -0.45, -0.35])
			pose["ears"] = -0.15
			pose["tail_lift"] = 0.45
		FALL:
			# Front paws reach for the ground and the nose dips: never mistaken
			# for the climb.
			legs.assign([0.95, 0.85, 0.25, 0.15])
			pose["pitch"] = -0.28
			pose["head"] = 0.18
			pose["ears"] = -0.4
			pose["tail_lift"] = 0.7
		TUMBLE:
			legs.assign([0.7, -0.5, 0.5, -0.7])
			pose["ears"] = 0.9
		SIT:
			legs.assign([-0.55, -0.55, 1.35, 1.35])
			pose["pitch"] = 0.55
			pose["drop"] = -0.05
			pose["head"] = -0.45
			pose["tail_wag"] = sin(_clock * 7.0) * 0.45
		_:
			pose["tail_wag"] = sin(_clock * 9.0) * 0.5
	_add_reaction(pose)
	if not reduced_motion and _pose in [TROT, SPRINT]:
		# Ears flop with each stride.
		pose["ears"] = float(pose["ears"]) + sin(_gait * 2.0) * 0.12
	if reduced_motion:
		pose["tail_wag"] = 0.0
		pose["head_turn"] = 0.0
		pose["squash"] = Vector3.ONE
	return pose


func _add_reaction(pose: Dictionary) -> void:
	if _reaction_left <= 0.0:
		return
	var played: float = 1.0 - _reaction_left / float(REACTIONS[_reaction])
	var swell := sin(played * PI)
	match _reaction:
		"land":
			pose["squash"] = Vector3(1.0 + 0.14 * swell, 1.0 - 0.16 * swell, 1.0 + 0.1 * swell)
		"stomp":
			pose["squash"] = Vector3(1.0 - 0.1 * swell, 1.0 + 0.16 * swell, 1.0 - 0.06 * swell)
		"eat":
			pose["head"] = float(pose["head"]) - 0.4 * swell
		"hurt":
			pose["ears"] = 1.0
			pose["head_turn"] = sin(played * TAU * 4.0) * 0.3 * (1.0 - played)


func _apply(pose: Dictionary, delta: float) -> void:
	var weight := 1.0 if _snap or delta <= 0.0 else 1.0 - exp(-SETTLE_RATE * delta)
	_snap = false
	var legs: Array[float] = pose["legs"]
	for index in 4:
		_legs[index].rotation.z = lerpf(_legs[index].rotation.z, legs[index], weight)
	_torso.rotation.z = lerpf(_torso.rotation.z, pose["pitch"], weight)
	var bounce := 0.0
	if pose["full"] and not reduced_motion and _pose == TROT:
		bounce = absf(sin(_gait)) * 0.012
	_torso.position.y = lerpf(_torso.position.y,
		TORSO_PIVOT.y + float(pose["drop"]) + bounce, weight)
	_head.rotation.z = lerpf(_head.rotation.z, pose["head"], weight)
	_head.rotation.y = pose["head_turn"]
	for index in _ears.size():
		var splay := 0.28 if index == 0 else -0.28
		_ears[index].rotation = Vector3(splay, 0.0,
			lerpf(_ears[index].rotation.z, pose["ears"], weight))
	_tail.rotation = Vector3(0.0, pose["tail_wag"],
		lerpf(_tail.rotation.z, pose["tail_lift"], weight))
	_rig.scale = pose["squash"]
	_belly.scale = _belly.scale.lerp(FULL_BELLY if pose["full"] else Vector3.ONE, weight)
	_torso.scale = _torso.scale.lerp(FULL_BODY if pose["full"] else Vector3.ONE, weight)


func _present_blink(state: State) -> void:
	var alpha := 1.0
	if state.is_invulnerable() and not state.over:
		var wave := 0.5 + 0.5 * cos(TAU * BLINK_HZ * state.invulnerable_left)
		alpha = lerpf(BLINK_LOWEST, 1.0, wave)
	_finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 \
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	_finish.albedo_color = Color(1, 1, 1, alpha)


## A cute topple, never a death animation. Reduced motion skips the spin and
## simply tips her onto her side.
func _present_tumble(state: State) -> void:
	if _pose != TUMBLE:
		_rig.rotation.z = 0.0
		return
	var played := 1.0 - state.tumble_left / State.TUMBLE_SECONDS
	_rig.rotation.z = PI * 0.5 if reduced_motion else TAU * TUMBLE_TURNS * played


# --------------------------------------------------------------------------
# Parts
# --------------------------------------------------------------------------


func _pivot(parent: Node3D, pivot_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _part(parent: Node3D, part: String) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = part.to_pascal_case() + "Mesh"
	body.mesh = mesh_for(part)
	body.material_override = _finish
	parent.add_child(body)
	return body


## Each part's mesh, built once and shared by every Dulce on screen.
static func mesh_for(part: String) -> ArrayMesh:
	if not _meshes.has(part):
		var mesh := MeshBuilder.new()
		match part:
			"torso":
				mesh.ellipsoid(Vector3(-0.01, 0.0, 0), Vector3(0.38, 0.2, 0.2), Art.FAWN, 18)
				mesh.ellipsoid(Vector3(-0.03, 0.06, 0), Vector3(0.28, 0.08, 0.15), Art.FAWN_DARK, 14)
				mesh.ellipsoid(Vector3(0.12, -0.02, 0), Vector3(0.14, 0.15, 0.16), Art.MARKINGS, 12)
			"belly":
				mesh.ellipsoid(Vector3(0.0, -0.05, 0), Vector3(0.24, 0.1, 0.16), Art.MARKINGS, 14)
			"leg":
				mesh.cylinder(Vector3(0, -0.06, 0), 0.028, 0.13, Art.FAWN, Vector3.ZERO, 10)
				mesh.ellipsoid(Vector3(0.012, -0.135, 0), Vector3(0.06, 0.035, 0.055),
					Art.MARKINGS, 10)
			"head":
				mesh.ellipsoid(Vector3(0.05, 0.05, 0), Vector3(0.19, 0.17, 0.17), Art.FAWN, 18)
				mesh.ellipsoid(Vector3(0.1, 0.075, 0), Vector3(0.06, 0.08, 0.07), Art.MARKINGS, 10)
				mesh.ellipsoid(Vector3(0.13, 0.0, 0), Vector3(0.1, 0.07, 0.08), Art.MARKINGS, 12)
				mesh.ellipsoid(Vector3(0.18, 0.015, 0), Vector3(0.035, 0.03, 0.04), Art.NOSE, 8)
				for side: float in [1.0, -1.0]:
					mesh.ellipsoid(Vector3(0.1, 0.07, 0.06 * side), Vector3(0.035, 0.04, 0.025),
						Art.NOSE, 8)
					mesh.ellipsoid(Vector3(0.112, 0.08, 0.072 * side), Vector3.ONE * 0.01,
						Color.WHITE, 6)
			"ear_near", "ear_far":
				var side := 1.0 if part == "ear_near" else -1.0
				mesh.ellipsoid(Vector3(0, 0.065, 0), Vector3(0.075, 0.13, 0.03), Art.FAWN, 12)
				mesh.ellipsoid(Vector3(0.006, 0.06, 0.012 * side), Vector3(0.045, 0.09, 0.012),
					Art.EAR_INSIDE, 10)
			"tail":
				# A curl over the back, the chihuahua-mix tail (DESIGN §7.2).
				mesh.ellipsoid(Vector3(-0.03, 0.035, 0), Vector3.ONE * 0.06, Art.FAWN, 8)
				mesh.ellipsoid(Vector3(-0.035, 0.085, 0), Vector3.ONE * 0.055, Art.FAWN, 8)
				mesh.ellipsoid(Vector3(-0.005, 0.12, 0), Vector3.ONE * 0.05, Art.FAWN, 8)
				mesh.ellipsoid(Vector3(0.035, 0.115, 0), Vector3.ONE * 0.04, Art.MARKINGS, 8)
		_meshes[part] = mesh.finish()
	return _meshes[part]


static func _collar_mesh(color: Color) -> ArrayMesh:
	var key := "collar_%s" % color.to_html(false)
	if not _meshes.has(key):
		var mesh := MeshBuilder.new()
		mesh.torus(Vector3.ZERO, 0.062, 0.082, color, Vector3(0, 0, -PI / 2 + 0.55))
		mesh.ellipsoid(Vector3(0.02, -0.075, 0.0), Vector3(0.025, 0.03, 0.012), Art.MUSTARD, 8)
		_meshes[key] = mesh.finish()
	return _meshes[key]
