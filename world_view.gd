extends Control

## An isolated Compatibility 3D viewport that draws the run under the 2D shell.
##
## Read-only: it presents `run_state.gd` and its tile grid, and reports where
## the camera's left edge is so the model can stop Dulce walking past it. The
## camera only ever scrolls forward (DESIGN §4.7).

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const Daylight = preload("res://games/dulces_adventure/world/daylight.gd")
const DulceModel = preload("res://games/dulces_adventure/world/dulce_model.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")

## How much of the run fits on screen, in tiles, before the aspect decides.
const VISIBLE_TILES_WIDE := 18.0
## Narrow enough that Dulce reads on a phone, wide enough for a five-tile pit
## and its landing to fit ahead of her.
const VISIBLE_TILES_WIDE_PORTRAIT := 9.0
const VISIBLE_TILES_HIGH := 10.0
## How far the soil runs below the deepest row, past any frame's bottom edge.
const BEDROCK_TILES := 24.0
## Dulce sits left of centre, so more of what is coming is on screen.
const LOOK_AHEAD := 0.14
## The seam row's surface rests this far down the screen while she runs.
const GROUND_LINE := 0.72
## A slight downward tilt, so the tops of ledges and platforms read.
const CAMERA_OFFSET := Vector3(0, 5.0, 30.0)
const MAX_RENDER_WIDTH := 1920
const MAX_RENDER_HEIGHT := 1600

var state: State
var reduced_motion := false
var intense_effects := true
var day_night_enabled := true
## The camera centre, in simulation units.
var camera := Vector2.ZERO
var world_viewport: SubViewport
var world_camera: Camera3D
var world: Node3D
var dulce: DulceModel
var daylight: Daylight
var _terrain: MeshInstance3D
var _shadow: MeshInstance3D
var _image: TextureRect
var _zoom := 1.0
## The forward-only left edge of the frame, in simulation units.
var _left := -INF
var _camera_ready := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	world_viewport = SubViewport.new()
	world_viewport.name = "RunViewport"
	world_viewport.own_world_3d = true
	world_viewport.gui_disable_input = true
	world_viewport.msaa_3d = Viewport.MSAA_4X
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.size = Vector2i(1280, 720)
	add_child(world_viewport)
	world = Node3D.new()
	world.name = "RunWorld"
	world_viewport.add_child(world)
	daylight = Daylight.new(world)
	_terrain = MeshInstance3D.new()
	_terrain.name = "Terrain"
	_terrain.material_override = Art.material()
	world.add_child(_terrain)
	dulce = DulceModel.new()
	world.add_child(dulce)
	_shadow = MeshInstance3D.new()
	_shadow.name = "BlobShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.22
	disc.height = 0.004
	disc.radial_segments = 20
	disc.rings = 1
	_shadow.mesh = disc
	_shadow.material_override = Art.flat_material(Art.SHADOW)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_shadow)
	world_camera = Camera3D.new()
	world_camera.name = "SideCamera"
	world_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	world_camera.near = 0.1
	world_camera.far = 250.0
	world_camera.current = true
	world.add_child(world_camera)
	_image = TextureRect.new()
	_image.name = "WorldImage"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.texture = world_viewport.get_texture()
	add_child(_image)
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resize_world)
	_resize_world()
	if state != null:
		rebuild_terrain()


## Points the view at a run, and snaps the camera to it on the next frame.
func configure(run: State) -> void:
	state = run
	_camera_ready = false
	if is_inside_tree():
		rebuild_terrain()
		present(0.0)


## Rebakes every live tile into one batched surface.
func rebuild_terrain() -> void:
	if _terrain == null or state == null:
		return
	_terrain.mesh = terrain_mesh(state.grid)


## One surface for the whole grid: soil in a checker so distance reads, a grass
## cap on every exposed top, and thin planks for one-way platforms. A dark back
## wall below the seam makes every pit read as a hole in the ground.
static func terrain_mesh(grid: Grid) -> ArrayMesh:
	var mesh := MeshBuilder.new()
	var cell_size := Grid.TILE * Art.WORLD_SCALE
	var columns := Vector2i(1 << 30, -(1 << 30))
	for cell in grid.cells():
		columns = Vector2i(mini(columns.x, cell.x), maxi(columns.y, cell.x))
	if columns.y >= columns.x:
		var depth := (grid.bottom_row + 1 - ChunkLibrary.SEAM_ROW + BEDROCK_TILES) * cell_size
		var width := (columns.y - columns.x + 1) * cell_size
		var corner := Art.world_point(Vector2(columns.x, ChunkLibrary.SEAM_ROW) * Grid.TILE)
		mesh.box(corner + Vector3(width * 0.5, -depth * 0.5, -Art.GROUND_DEPTH * 0.5 - 0.05),
			Vector3(width, depth, 0.1), Art.PIT)
	for cell in grid.cells():
		var centre := Art.world_point((Vector2(cell) + Vector2(0.5, 0.5)) * Grid.TILE)
		if grid.tile(cell) == Grid.ONE_WAY:
			var top := centre + Vector3(0, cell_size * 0.5 - 0.08, 0)
			mesh.box(top, Vector3(cell_size, 0.16, Art.GROUND_DEPTH * 0.6), Art.PLANK)
			continue
		var soil := Art.SOIL if (cell.x + cell.y) % 2 == 0 else Art.SOIL_DARK
		mesh.box(centre, Vector3(cell_size, cell_size, Art.GROUND_DEPTH), soil)
		if cell.y == grid.bottom_row:
			# The ground carries on below the frame, so a pit reads as a hole
			# rather than a gap onto sky.
			var depth := BEDROCK_TILES * cell_size
			mesh.box(centre - Vector3(0, (cell_size + depth) * 0.5, 0),
				Vector3(cell_size, depth, Art.GROUND_DEPTH), Art.SOIL_DARK)
		if not grid.is_solid(cell + Vector2i.UP):
			var cap := centre + Vector3(0, cell_size * 0.5 + 0.04, 0)
			mesh.box(cap, Vector3(cell_size, 0.12, Art.GROUND_DEPTH + 0.04), Art.LETTUCE)
	return mesh.finish()


## The camera's left edge in simulation units; the model clamps Dulce to it.
## Before the first framed picture there is no edge yet.
func left_edge() -> float:
	return _left if _camera_ready else -INF


func present(delta: float) -> void:
	if state == null or world == null:
		return
	var moving_delta := 0.0 if get_tree().paused else delta
	dulce.present(state, moving_delta, reduced_motion)
	_present_shadow()
	_present_camera(moving_delta)
	var light_time := state.elapsed if day_night_enabled and not reduced_motion else 0.0
	daylight.set_elapsed(light_time)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	present(0.0)


func set_intense_effects(value: bool) -> void:
	intense_effects = value


func set_day_night_enabled(value: bool) -> void:
	day_night_enabled = value
	present(0.0)


## Projects a simulation point to this control's pixels, for HUD and tests.
func project_point(point: Vector2) -> Vector2:
	if world_camera == null or world_viewport == null:
		return Vector2.ZERO
	var pixel := world_camera.unproject_position(Art.world_point(point))
	return pixel * size / Vector2(world_viewport.size)


## The blob sits on the first surface below her paws and shrinks with height,
## so how far she is above a pit always reads (DESIGN §7.1).
func _present_shadow() -> void:
	var surface := _surface_below(state.position)
	_shadow.visible = is_finite(surface)
	if not _shadow.visible:
		return
	var height := (surface - state.position.y) / Grid.TILE
	var spread := clampf(1.0 - height * 0.12, 0.45, 1.0)
	_shadow.position = Art.world_point(Vector2(state.position.x, surface)) + Vector3(0, 0.012, 0)
	_shadow.scale = Vector3(spread, 1.0, spread)


func _surface_below(feet: Vector2) -> float:
	var column := floori(feet.x / Grid.TILE)
	for row in range(floori((feet.y - 0.001) / Grid.TILE) + 1, state.grid.bottom_row + 1):
		if state.grid.tile(Vector2i(column, row)) != Grid.EMPTY:
			return row * Grid.TILE
	return INF


func _present_camera(delta: float) -> void:
	# Before layout the control has no size, and a zoom taken from it would
	# throw the forward-only edge far ahead of her for good.
	if size.x < 1.0 or size.y < 1.0:
		return
	var portrait := size.y > size.x * 0.95
	var wide := VISIBLE_TILES_WIDE_PORTRAIT if portrait else VISIBLE_TILES_WIDE
	_zoom = minf(size.x / (wide * Grid.TILE), size.y / (VISIBLE_TILES_HIGH * Grid.TILE))
	var view_size := size / _zoom
	# Forward only: the left edge never scrolls back toward the start. It is the
	# edge, not the centre, that is kept, so a narrower window after a resize or
	# a rotation can never leave the edge ahead of her.
	var trailing := state.position.x - view_size.x * (0.5 - LOOK_AHEAD)
	_left = trailing if not _camera_ready else maxf(_left, trailing)
	camera.x = _left + view_size.x * 0.5
	var seam := ChunkLibrary.SEAM_ROW * Grid.TILE
	var target_y := seam - view_size.y * (GROUND_LINE - 0.5)
	# Rise with her only once she nears the top of the frame.
	var ceiling := target_y - view_size.y * 0.3
	if state.position.y - State.BODY_SIZE.y < ceiling:
		target_y += state.position.y - State.BODY_SIZE.y - ceiling
	if reduced_motion or not _camera_ready:
		camera.y = target_y
	else:
		camera.y = lerpf(camera.y, target_y, 1.0 - exp(-delta * 5.0))
	_camera_ready = true
	var focus := Art.world_point(camera)
	world_camera.size = view_size.y * Art.WORLD_SCALE
	world_camera.position = focus + CAMERA_OFFSET
	world_camera.look_at(focus, Vector3.UP)


func _resize_world() -> void:
	if world_viewport == null:
		return
	var visible_size := get_viewport().get_visible_rect().size
	var physical_scale := float(get_window().size.x) / maxf(visible_size.x, 1.0)
	var render_size := size * physical_scale
	if render_size.x > MAX_RENDER_WIDTH:
		render_size *= MAX_RENDER_WIDTH / render_size.x
	if render_size.y > MAX_RENDER_HEIGHT:
		render_size *= MAX_RENDER_HEIGHT / render_size.y
	world_viewport.size = Vector2i(maxi(1, roundi(render_size.x)), maxi(1, roundi(render_size.y)))
	present(0.0)
