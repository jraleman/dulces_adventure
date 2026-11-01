extends RefCounted

## A small lit set for portraits: the store card, the setup plinth, the gallery
## turntable and the share card all stand Dolce, or an exhibit, in one.
##
## Adapted from Cube Trials' store preview: a `SubViewport` under the card, the
## run's own daylight (so a colour is judged in the light it is worn in), and
## a camera that stands back far enough to fit the subject's measured bounds
## at whatever size the card is. Measured rather than dialled in, because a
## hat or a cape changes the bounds.

const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const Daylight = preload("res://games/dolces_adventure/world/daylight.gd")


## Builds the set inside `host`: `{viewport, stage, camera, daylight}`. A clear
## background cuts the subject out against the menu behind it; otherwise the
## Backyard's sky shows.
static func build(host: Control, clear_background := true, msaa := Viewport.MSAA_2X) -> Dictionary:
	var container := SubViewportContainer.new()
	container.name = "Case"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.name = "Portrait"
	viewport.transparent_bg = clear_background
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = msaa
	# The viewport goes in first: a stretching container sizes its viewport as
	# it is laid out, and one added afterwards would keep the 512px default
	# and be cropped by a smaller card.
	container.add_child(viewport)
	host.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := Node3D.new()
	stage.name = "Studio"
	viewport.add_child(stage)
	var daylight := Daylight.new(stage)
	if clear_background:
		daylight.environment.background_mode = Environment.BG_CLEAR_COLOR
	# Nothing here stands on lit ground, so shadows would only cost.
	daylight.sun.shadow_enabled = false
	var camera := Camera3D.new()
	camera.name = "Lens"
	camera.near = 0.02
	camera.far = 60.0
	camera.current = true
	stage.add_child(camera)
	return {"viewport": viewport, "stage": stage, "camera": camera, "daylight": daylight}


## The subject's real extent in the stage's space, measured off its meshes.
static func bounds(stage: Node3D, subject: Node3D) -> AABB:
	var to_stage := stage.global_transform.affine_inverse()
	var merged := AABB()
	var measured := false
	var parts: Array = subject.find_children("*", "GeometryInstance3D", true, false)
	if subject is GeometryInstance3D:
		parts.append(subject)
	for node in parts:
		var instance := node as GeometryInstance3D
		if instance is MeshInstance3D and (instance as MeshInstance3D).mesh == null:
			continue
		var box := (to_stage * instance.global_transform) * instance.get_aabb()
		merged = box if not measured else merged.merge(box)
		measured = true
	return merged


## Stands `camera` back along `lens` until every corner of `box` fits the frame
## with `margin` to spare, for a frame of `aspect` (width / height).
static func frame(
	camera: Camera3D, box: AABB, lens: Vector3, field_of_view: float, aspect: float,
	margin := 1.08
) -> void:
	if box.size.is_zero_approx() or aspect <= 0.0:
		return
	var direction := lens.normalized()
	var forward := -direction
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	var half_height := tan(deg_to_rad(field_of_view) * 0.5)
	var half_width := half_height * aspect
	var focus := box.get_center()
	var distance := 0.0
	for corner in 8:
		var offset := box.get_endpoint(corner) - focus
		var depth := offset.dot(forward)
		distance = maxf(distance, absf(offset.dot(right)) / half_width - depth)
		distance = maxf(distance, absf(offset.dot(up)) / half_height - depth)
	camera.fov = field_of_view
	# `look_at` needs a node already in the tree; a transform does not.
	camera.transform = Transform3D(Basis.IDENTITY, focus + direction * distance * margin) \
		.looking_at(focus)
