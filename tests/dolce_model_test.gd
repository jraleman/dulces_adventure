extends SceneTree

## Dolce's rig and particles, headless (DESIGN §7.2, §9.5).
##
## The rig is plain nodes and meshes, so it can be built and posed without a
## window: which pose each run state calls for, her size, reduced motion
## holding the decorative pivots still, the Full shape, the blink, the tumble
## and the collar. The particle pool's bounds are checked here too.

const DolceModel = preload("res://games/dolces_adventure/world/dolce_model.gd")
const PawParticles = preload("res://games/dolces_adventure/world/paw_particles.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")

const FLOOR := Vector2(100.0, 160.0)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_parts()
	_test_pose_for()
	_test_size()
	_test_poses_differ()
	_test_reduced_motion()
	_test_full_shape()
	_test_blink_and_tumble()
	_test_collar()
	_test_particles()
	_finish()


func _state(velocity := Vector2.ZERO, grounded := true) -> State:
	var rows: Array[String] = ["", "", "", "", "#".repeat(20), "#".repeat(20)]
	var state := State.new(Grid.new(rows), FLOOR)
	state.velocity = velocity
	state.grounded = grounded
	return state


func _model() -> DolceModel:
	var model := DolceModel.new()
	get_root().add_child(model)
	return model


func _test_parts() -> void:
	var model := _model()
	for path in ["Rig/Torso", "Rig/Torso/Head", "Rig/Torso/Head/EarNear",
			"Rig/Torso/Head/EarFar", "Rig/Torso/Tail", "Rig/Torso/Collar",
			"Rig/Torso/FrontNear", "Rig/Torso/FrontFar", "Rig/Torso/BackNear",
			"Rig/Torso/BackFar"]:
		_expect(model.get_node_or_null(path) != null, "The rig has a %s pivot." % path)
	var drawn := model.find_children("*", "MeshInstance3D", true, false).filter(
		func(node: MeshInstance3D) -> bool: return node.mesh != null)
	_expect(drawn.size() <= 12, "Dolce draws in a dozen calls or fewer (%d)." % drawn.size())
	model.free()


func _test_pose_for() -> void:
	var cases := [
		[_state(), DolceModel.IDLE],
		[_state(Vector2(State.WALK_SPEED, 0)), DolceModel.TROT],
		[_state(Vector2(State.RUN_SPEED, 0)), DolceModel.SPRINT],
		[_state(Vector2(0, -600), false), DolceModel.JUMP],
		[_state(Vector2(0, 40), false), DolceModel.APEX],
		[_state(Vector2(0, 600), false), DolceModel.FALL],
	]
	for case: Array in cases:
		_expect(DolceModel.pose_for(case[0]) == case[1], "pose_for gives %s." % case[1])
	var over := _state()
	over.over = true
	_expect(DolceModel.pose_for(over) == DolceModel.TUMBLE, "A finished run tumbles.")
	_expect(DolceModel.pose_for(over, true) == DolceModel.SIT, "Victory sits, whatever else.")


## DESIGN §2: about 0.6 m long and 0.45 m tall to the ear tips.
func _test_size() -> void:
	var model := _model()
	model.present(_state(), 0.0, true)
	var bounds := _bounds(model)
	_expect(bounds.size.x > 0.5 and bounds.size.x < 0.7,
		"She is about 0.6 m long (%.2f)." % bounds.size.x)
	_expect(bounds.size.y > 0.4 and bounds.size.y < 0.52,
		"She is about 0.45 m tall to the ear tips (%.2f)." % bounds.size.y)
	_expect(absf(bounds.position.y) < 0.03, "Her paws are at the origin (%.3f)." % bounds.position.y)
	model.free()


## Jump, apex and fall must read differently even with reduced motion on.
func _test_poses_differ() -> void:
	var shapes := {}
	for pose_state: State in [
		_state(Vector2(0, -600), false), _state(Vector2(0, 40), false),
		_state(Vector2(0, 600), false), _state(Vector2(State.RUN_SPEED, 0)), _state(),
	]:
		var model := _model()
		model.present(pose_state, 0.0, true)
		# A few frames in, so a gait is mid-stride rather than at phase zero.
		for _i in 4:
			model.present(pose_state, 1.0 / 30.0, true)
		shapes[model.pose_name()] = _signature(model)
		model.free()
	var seen := {}
	for pose: String in shapes:
		_expect(not seen.has(shapes[pose]), "%s has a shape of its own." % pose)
		seen[shapes[pose]] = true
	_expect(shapes.size() == 5, "Every pose was reached (%s)." % [shapes.keys()])


func _test_reduced_motion() -> void:
	var model := _model()
	var idle := _state()
	model.present(idle, 0.0, true)
	var before := _decoration(model)
	for _i in 30:
		model.present(idle, 1.0 / 30.0, true)
	_expect(_decoration(model) == before,
		"Reduced motion: no tail wag or ear flop while she stands.")
	var lively := _model()
	var tail_angles := {}
	for _i in 30:
		lively.present(idle, 1.0 / 30.0, false)
		tail_angles[snappedf(lively.get_node("Rig/Torso/Tail").rotation.y, 0.01)] = true
	_expect(tail_angles.size() > 5, "With motion on, an idle tail wags.")
	model.react("land")
	model.present(idle, 0.05, true)
	_expect(model.get_node("Rig").scale == Vector3.ONE, "Reduced motion: no squash on landing.")
	model.free()
	lively.free()


func _test_full_shape() -> void:
	var model := _model()
	var state := _state()
	model.present(state, 0.0, true)
	var normal := _bounds(model).size
	state.full = true
	model.set_victory(false)
	model.present(state, 0.0, true)
	model.present(state, 1.0, true)
	var full := _bounds(model).size
	_expect(full.y > normal.y + 0.005 and full.z > normal.z + 0.01,
		"Full changes her shape, not just a colour (%s vs %s)." % [full, normal])
	model.free()


func _test_blink_and_tumble() -> void:
	var model := _model()
	var state := _state()
	state.invulnerable_left = 1.5 - 1.0 / (2.0 * DolceModel.BLINK_HZ)
	model.present(state, 0.0, false)
	var finish := (model.get_node("Rig/Torso/TorsoMesh") as MeshInstance3D).material_override \
		as StandardMaterial3D
	_expect(finish.albedo_color.a < 1.0 and finish.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
		"i-frames fade her, never flash a colour.")
	state.invulnerable_left = 0.0
	model.present(state, 0.0, false)
	_expect(finish.albedo_color.a == 1.0, "She is solid again afterwards.")
	state.over = true
	state.tumble_left = State.TUMBLE_SECONDS * 0.5
	model.present(state, 0.0, true)
	_expect(is_equal_approx(model.get_node("Rig").rotation.z, PI * 0.5),
		"Reduced motion tips her over instead of spinning.")
	model.present(state, 0.0, false)
	_expect(model.get_node("Rig").rotation.z > PI, "Otherwise she tumbles head over heels.")
	model.free()


## Store items dress her by id: a collar always, a hat and a neck piece when
## given, and an unknown collar falls back to the red one she came with.
func _test_collar() -> void:
	var model := _model()
	var collar := model.get_node("Rig/Torso/Collar") as MeshInstance3D
	var hat := model.get_node("Rig/Torso/Head/Hat") as MeshInstance3D
	var neck := model.get_node("Rig/Torso/Neck") as MeshInstance3D
	var red := collar.mesh
	_expect(red != null and hat.mesh == null and neck.mesh == null,
		"She starts in the red collar, with no hat and nothing at her neck.")
	model.set_outfit(Options.COLLAR_SPIKED, Options.HAT_CHEF, Options.CAPE_HERO)
	_expect(collar.mesh != red and hat.mesh != null and neck.mesh != null,
		"A bought collar, hat and cape all show on her.")
	model.set_outfit("not_an_item", "", "")
	_expect(collar.mesh == red and hat.mesh == null and neck.mesh == null,
		"An unknown collar falls back to red; empty slots stay empty.")
	for item: Dictionary in Options.STORE_ITEMS:
		var kind := str(item["kind"])
		model.set_outfit(item["id"] if kind == Options.COLLAR_KIND else Options.COLLAR_RED,
			item["id"] if kind == Options.HAT_KIND else "",
			item["id"] if kind == Options.BANDANA_KIND else "")
		var worn := collar.mesh if kind == Options.COLLAR_KIND \
			else hat.mesh if kind == Options.HAT_KIND else neck.mesh
		_expect(worn != null, "%s has a model she can wear." % item["id"])
	model.free()


func _test_particles() -> void:
	var puffs := PawParticles.new()
	puffs.burst(Vector3.ZERO, 200, Color.WHITE, 0.1, 1.0)
	_expect(puffs.live_count() == PawParticles.POOL, "A burst never grows the pool.")
	for _i in 120:
		puffs.advance(1.0 / 60.0)
	_expect(puffs.live_count() == 0, "Every puff fades out.")
	puffs.reduced_motion = true
	puffs.burst(Vector3.ZERO, 5, Color.WHITE, 0.1, 1.0)
	_expect(puffs.live_count() == 0, "Reduced motion emits nothing.")
	_expect(puffs.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"Particles never cast shadows.")
	puffs.free()


# --------------------------------------------------------------------------


## The model-space box around every mesh, posed.
func _bounds(model: Node3D) -> AABB:
	var total := AABB()
	var first := true
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		var transform := Transform3D.IDENTITY
		var walker: Node = node
		while walker != model:
			transform = (walker as Node3D).transform * transform
			walker = walker.get_parent()
		var box := transform * node.mesh.get_aabb()
		total = box if first else total.merge(box)
		first = false
	return total


func _signature(model: Node3D) -> String:
	var parts := PackedStringArray()
	for path in ["Rig/Torso", "Rig/Torso/FrontNear", "Rig/Torso/BackNear", "Rig/Torso/Head",
			"Rig/Torso/Head/EarNear"]:
		parts.append("%.2f" % model.get_node(path).rotation.z)
	return ",".join(parts)


func _decoration(model: Node3D) -> String:
	var tail := model.get_node("Rig/Torso/Tail") as Node3D
	var ear := model.get_node("Rig/Torso/Head/EarNear") as Node3D
	return "%.4f,%.4f,%.4f" % [tail.rotation.y, tail.rotation.z, ear.rotation.z]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dolce model tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
