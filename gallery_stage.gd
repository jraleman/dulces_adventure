extends Control

## The gallery's turntable for everything Dolce's run is made of.
##
## The gallery screen asks for this by path (`GameManifest.gallery_stage_scene_path`)
## and drives it with `configure()`, `set_view()` and `set_auto_spin()`, so the
## framework never learns what a robo-vac is. Every exhibit is built by the
## same code the run uses: Dolce's rig in her equipped outfit, the pest and
## food meshes, and the finish line's food truck. A gallery that showed a
## nicer version than the run would be an advert, not a museum.

const Studio = preload("res://games/dolces_adventure/world/studio.gd")
const DolceModel = preload("res://games/dolces_adventure/world/dolce_model.gd")
const PestModels = preload("res://games/dolces_adventure/world/pest_models.gd")
const FoodModels = preload("res://games/dolces_adventure/world/food_models.gd")
const BiomeProps = preload("res://games/dolces_adventure/world/biome_props.gd")
const MeshBuilder = preload("res://games/dolces_adventure/world/mesh_builder.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Pests = preload("res://games/dolces_adventure/pests.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")

const FIELD_OF_VIEW := 32.0
## Breathing room, so an ear tip or a flag never touches the case's edge.
const MARGIN := 1.12
## Clear of the poles: an orbit straight down cannot tell which way is up.
const PITCH_LIMIT := 1.3
## Everything faces +X, the way the side camera sees it, so each opens at a
## front three-quarter with a little height.
const BASE_YAW := 0.75
const BASE_PITCH := 0.25
const PESTS := [Pests.PIGEON, Pests.GNOME, Pests.SQUIRREL, Pests.ROBO_VAC, Pests.SEAGULL,
	Pests.HOT_SAUCE]

var _set: Dictionary = {}
## Built exhibits, kept by id and hidden rather than rebuilt.
var _built: Dictionary[String, Node3D] = {}
var _exhibit: Node3D
var _focus := Vector3.ZERO
var _radius := 0.5
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _inert := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inert = DisplayServer.get_name() == "headless"
	if _inert:
		return
	_set = Studio.build(self, true, Viewport.MSAA_4X)
	(_set["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	resized.connect(_apply_camera)


## Puts [param exhibit], a `GameManifest.gallery_exhibits` entry, on the plinth.
func configure(exhibit: Dictionary) -> void:
	if _inert or _set.is_empty():
		return
	if _exhibit != null:
		_exhibit.visible = false
	var id := str(exhibit.get("id", ""))
	if not _built.has(id):
		var built := build(id)
		if built == null:
			_exhibit = null
			return
		(_set["stage"] as Node3D).add_child(built)
		_built[id] = built
	_exhibit = _built[id]
	_exhibit.visible = true
	if id in [Options.EXHIBIT_DOLCE, Options.EXHIBIT_DOLCE_FULL]:
		_dress(_exhibit as DolceModel)
	var box := Studio.bounds(_set["stage"], _exhibit)
	_focus = box.get_center()
	_radius = maxf(box.size.length() * 0.5, 0.05)
	_apply_camera()


## Orbit offsets from the exhibit's default framing, in radians, plus a
## magnification where 1.0 is that default and 2.0 is twice as close.
func set_view(yaw: float, pitch: float, zoom: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_zoom = maxf(zoom, 0.01)
	_apply_camera()


## The screen owns the turntable and feeds it through `set_view()`, so there
## is nothing to spin here.
func set_auto_spin(_enabled: bool) -> void:
	pass


## A fresh copy of the exhibit behind `id`, at the origin, or null if unknown.
## Static and node-light, so a headless test can build every exhibit.
static func build(id: String) -> Node3D:
	if id in [Options.EXHIBIT_DOLCE, Options.EXHIBIT_DOLCE_FULL]:
		var dolce := DolceModel.new()
		var rows: Array[String] = ["", "", "", "", "#".repeat(8), "#".repeat(8)]
		var state := State.new(Grid.new(rows), Vector2(4.5 * Grid.TILE, 4.0 * Grid.TILE))
		state.full = id == Options.EXHIBIT_DOLCE_FULL
		dolce.present(state, 0.0, true)
		dolce.present(state, 1.0, true)
		dolce.position = Vector3.ZERO
		return dolce
	var holder := Node3D.new()
	holder.name = id.to_pascal_case()
	var finish := Art.material()
	if id in PESTS:
		_add(holder, PestModels.mesh_for(id), finish)
	elif id == "lunchbox":
		var box := MeshBuilder.new()
		FoodModels.lunchbox(box, Vector3(0, 0.46, 0), 0.92, false)
		_add(holder, box.finish(), finish)
	elif id == "big_burger":
		_add(holder, FoodModels.mesh_for(State.BIG_BURGER), finish)
	elif id == "golden_bone":
		_add(holder, FoodModels.mesh_for(State.GOLDEN_BONE), finish)
	elif id == Options.EXHIBIT_FOOD_TRUCK:
		var truck := BiomeProps.goal_mesh(ChunkLibrary.Biome.BACKYARD)
		_add(holder, truck["lit"], finish)
		_add(holder, truck["glow"], Art.glow_material())
	else:
		holder.free()
		return null
	return holder


static func _add(holder: Node3D, mesh: ArrayMesh, finish: Material) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = finish
	holder.add_child(part)


## Dolce in the gallery wears whatever she has equipped in the store.
func _dress(dolce: DolceModel) -> void:
	var store := get_node_or_null("/root/Store")
	if store == null:
		return
	dolce.set_outfit(
		str(store.call("equipped_id", Options.GAME_ID, Options.COLLAR_SLOT)),
		str(store.call("equipped_id", Options.GAME_ID, Options.HAT_SLOT)),
		str(store.call("equipped_id", Options.GAME_ID, Options.BANDANA_SLOT)),
	)


func _apply_camera() -> void:
	if _set.is_empty() or _exhibit == null or size.x < 1.0 or size.y < 1.0:
		return
	var camera: Camera3D = _set["camera"]
	var yaw := BASE_YAW + _yaw
	var pitch := clampf(BASE_PITCH + _pitch, -PITCH_LIMIT, PITCH_LIMIT)
	var half := deg_to_rad(FIELD_OF_VIEW) * 0.5
	var aspect := minf(size.x / size.y, 1.0)
	# Fit a sphere around the exhibit in the narrower of the two directions.
	var distance := _radius * MARGIN / sin(atan(tan(half) * aspect)) / _zoom
	var direction := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	camera.fov = FIELD_OF_VIEW
	camera.transform = Transform3D(Basis.IDENTITY, _focus + direction * distance).looking_at(_focus)
