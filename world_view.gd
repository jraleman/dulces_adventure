extends Control

## An isolated Compatibility 3D viewport that draws the run under the 2D shell.
##
## Read-only: it presents `run_state.gd` (its tiles, food, Lunchboxes, pests
## and Dulce) dressed in each chunk's biome, with a parallax backdrop and the
## biome's sky, and reports where the camera's left edge is, so the model can
## stop her walking past it. The camera only ever scrolls forward (DESIGN §4.7).

const Art = preload("res://games/dulces_adventure/dulce_art.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const MeshBuilder = preload("res://games/dulces_adventure/world/mesh_builder.gd")
const Daylight = preload("res://games/dulces_adventure/world/daylight.gd")
const DulceModel = preload("res://games/dulces_adventure/world/dulce_model.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const Pests = preload("res://games/dulces_adventure/pests.gd")
const FoodModels = preload("res://games/dulces_adventure/world/food_models.gd")
const PestModels = preload("res://games/dulces_adventure/world/pest_models.gd")
const PawParticles = preload("res://games/dulces_adventure/world/paw_particles.gd")
const BiomeProps = preload("res://games/dulces_adventure/world/biome_props.gd")

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
## Food turns slowly on the spot so it reads as a pickup; reduced motion parks it.
const FOOD_SPIN := 1.6
const FOOD_PARKED_ANGLE := 0.5
## Never let the ground line climb above this much of the frame to clear the
## touch buttons; on a very short screen they overlap the ground instead.
const HIGHEST_GROUND_LINE := 0.55
## One puff of dust behind her paws every this many metres at a run.
const FOOTSTEP_METRES := 0.45
const FOOTSTEP_SPEED := 150.0
const DUST := Color(0.82, 0.72, 0.58, 0.7)
const FEATHERS := Color(0.93, 0.93, 0.95, 0.9)
## The pigeon's waddle, a decoration reduced motion parks.
const WADDLE_HZ := 2.2
## A sliding robo-vac spins like a kicked shell; a scurrying squirrel bolts.
const VAC_SPIN := 14.0
const SCURRY_METRES := 2.5
## Backdrop tiles recycled as the camera moves.
const BACKDROP_POOL := 4

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
var particles: PawParticles
var daylight: Daylight
## One baked chunk (terrain, props and glow) per live chunk, by its first
## column, so placing a chunk or opening a Lunchbox re-bakes one chunk.
var _chunk_meshes: Dictionary[int, Node3D] = {}
## Every live chunk: `{column, width, biome, gate}`.
var _chunks: Array[Dictionary] = []
var _glow: StandardMaterial3D
var _backdrop: Node3D
var _backdrop_tiles: Array[Node3D] = []
var _backdrop_meshes: Dictionary[int, Dictionary] = {}
var _far_ground: MeshInstance3D
var _far_ground_finish: StandardMaterial3D
## Pixels at the bottom of this control covered by touch buttons.
var bottom_inset := 0.0
var _finish: StandardMaterial3D
var _items: Dictionary[Vector2i, MeshInstance3D] = {}
var _pests: Dictionary[int, MeshInstance3D] = {}
var _shadow: MeshInstance3D
var _image: TextureRect
var _zoom := 1.0
## The forward-only left edge of the frame, in simulation units.
var _left := -INF
var _camera_ready := false
var _footstep_left := FOOTSTEP_METRES


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
	_finish = Art.material()
	_glow = Art.glow_material()
	_backdrop = Node3D.new()
	_backdrop.name = "Backdrop"
	_backdrop.scale = Vector3.ONE * BiomeProps.BACKDROP_SCALE
	world.add_child(_backdrop)
	_far_ground = MeshInstance3D.new()
	_far_ground.name = "FarGround"
	var strip := BoxMesh.new()
	strip.size = Vector3(400.0, 0.1, -BiomeProps.BACKDROP_DEPTH - 1.6)
	_far_ground.mesh = strip
	_far_ground_finish = StandardMaterial3D.new()
	_far_ground.material_override = _far_ground_finish
	_far_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_far_ground)
	for index in BACKDROP_POOL:
		var tile := Node3D.new()
		tile.name = "Tile%d" % index
		for layer: String in ["Lit", "Glow"]:
			var part := MeshInstance3D.new()
			part.name = layer
			part.material_override = _finish if layer == "Lit" else _glow
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tile.add_child(part)
		_backdrop.add_child(tile)
		_backdrop_tiles.append(tile)
	dulce = DulceModel.new()
	world.add_child(dulce)
	particles = PawParticles.new()
	particles.reduced_motion = reduced_motion
	world.add_child(particles)
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
		if _chunks.is_empty():
			_chunks = _whole_grid()
		rebuild_terrain()


## Points the view at a run, and snaps the camera to it on the next frame.
## `chunks` are the live chunks as `{column, width, biome, gate}`; without
## them the whole grid is baked as one Backyard stretch.
func configure(run: State, chunks: Array[Dictionary] = []) -> void:
	var fresh := run != state
	state = run
	_camera_ready = false
	if fresh:
		if particles != null:
			particles.clear()
		for node: Node3D in _items.values() + _pests.values() + _chunk_meshes.values():
			node.queue_free()
		_items.clear()
		_pests.clear()
		_chunk_meshes.clear()
		_chunks.clear()
	if fresh:
		_chunks = chunks.duplicate() if not chunks.is_empty() else _whole_grid()
	if is_inside_tree():
		# A respawn re-frames the same run; only a new run needs re-baking.
		if fresh:
			rebuild_terrain()
			daylight.set_palette(BiomeProps.palette(state.biome)["sky"], true)
		present(0.0)


## Matches the baked chunks to the live ones: new chunks are baked, freed ones
## dropped, and the rest left alone.
func sync_chunks(chunks: Array[Dictionary]) -> void:
	_chunks = chunks.duplicate()
	if world == null or state == null:
		return
	var live := {}
	for chunk in _chunks:
		live[int(chunk["column"])] = true
		if not _chunk_meshes.has(int(chunk["column"])):
			_bake(chunk)
	for column: int in _chunk_meshes.keys():
		if not live.has(column):
			_chunk_meshes[column].queue_free()
			_chunk_meshes.erase(column)


## Re-bakes the chunk holding `column`, as when a Lunchbox there is opened.
func rebuild_chunk_at(column: int) -> void:
	var chunk := _chunk_at(column)
	if not chunk.is_empty():
		_bake(chunk)


func _chunk_at(column: int) -> Dictionary:
	for chunk in _chunks:
		if column >= int(chunk["column"]) and column < int(chunk["column"]) + int(chunk["width"]):
			return chunk
	return {}


## Re-bakes every live chunk.
func rebuild_terrain() -> void:
	if world == null or state == null:
		return
	for node: Node3D in _chunk_meshes.values():
		node.queue_free()
	_chunk_meshes.clear()
	sync_chunks(_chunks)


## Terrain, props and glow for one chunk, each a single surface.
func _bake(chunk: Dictionary) -> void:
	var column := int(chunk["column"])
	var holder: Node3D = _chunk_meshes.get(column)
	if holder == null:
		holder = Node3D.new()
		holder.name = "Chunk_%d" % column
		for layer: String in ["Terrain", "Props", "Glow"]:
			var part := MeshInstance3D.new()
			part.name = layer
			part.material_override = _glow if layer == "Glow" else _finish
			if layer == "Glow":
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(part)
		world.add_child(holder)
		_chunk_meshes[column] = holder
	var biome := int(chunk.get("biome", ChunkLibrary.Biome.BACKYARD))
	var width := int(chunk["width"])
	(holder.get_node("Terrain") as MeshInstance3D).mesh = terrain_mesh(state.grid, column, width, biome)
	var props := BiomeProps.props(state.grid, biome, column, width, bool(chunk.get("gate", false)),
		state.goal_x)
	(holder.get_node("Props") as MeshInstance3D).mesh = props["lit"]
	(holder.get_node("Glow") as MeshInstance3D).mesh = props["glow"]


func _whole_grid() -> Array[Dictionary]:
	var columns := Vector2i(1 << 30, -(1 << 30))
	for cell in state.grid.cells():
		columns = Vector2i(mini(columns.x, cell.x), maxi(columns.y, cell.x))
	if columns.y < columns.x:
		return []
	return [{
		"column": columns.x, "width": columns.y - columns.x + 1,
		"biome": state.biome, "gate": false,
	}]


## One surface for `width` columns from `first`, in `biome`'s colours: soil in
## a checker so distance reads, a cap on every exposed top, and thin planks for
## one-way platforms. A back wall below the seam, in the biome's pit colour
## (earth, pond, manhole, sea), makes every pit read as a hole.
static func terrain_mesh(
	grid: Grid, first: int, width: int, biome: int = ChunkLibrary.Biome.BACKYARD
) -> ArrayMesh:
	var colours := BiomeProps.palette(biome)
	var mesh := MeshBuilder.new()
	var cell_size := Grid.TILE * Art.WORLD_SCALE
	var depth := (grid.bottom_row + 1 - ChunkLibrary.SEAM_ROW + BEDROCK_TILES) * cell_size
	var corner := Art.world_point(Vector2(first, ChunkLibrary.SEAM_ROW) * Grid.TILE)
	mesh.box(corner + Vector3(width * cell_size * 0.5, -depth * 0.5, -Art.GROUND_DEPTH * 0.5 - 0.05),
		Vector3(width * cell_size, depth, 0.1), colours["pit"])
	var cells: Array[Vector2i] = []
	for column in range(first, first + width):
		for row in grid.bottom_row + 1:
			if grid.tile(Vector2i(column, row)) != Grid.EMPTY:
				cells.append(Vector2i(column, row))
	for cell in cells:
		var centre := Art.world_point((Vector2(cell) + Vector2(0.5, 0.5)) * Grid.TILE)
		var kind := grid.tile(cell)
		if kind == Grid.ONE_WAY:
			var top := centre + Vector3(0, cell_size * 0.5 - 0.08, 0)
			mesh.box(top, Vector3(cell_size, 0.16, Art.GROUND_DEPTH * 0.6), colours["plank"])
			continue
		if kind == Grid.LUNCHBOX or kind == Grid.EMPTY_BOX:
			FoodModels.lunchbox(mesh, centre, cell_size * 0.92, kind == Grid.EMPTY_BOX)
			continue
		var soil: Color = colours["soil"] if (cell.x + cell.y) % 2 == 0 else colours["soil_dark"]
		mesh.box(centre, Vector3(cell_size, cell_size, Art.GROUND_DEPTH), soil)
		if cell.y == grid.bottom_row:
			# The ground carries on below the frame, so a pit reads as a hole
			# rather than a gap onto sky.
			var bedrock := BEDROCK_TILES * cell_size
			mesh.box(centre - Vector3(0, (cell_size + bedrock) * 0.5, 0),
				Vector3(cell_size, bedrock, Art.GROUND_DEPTH), colours["soil_dark"])
		if not grid.is_solid(cell + Vector2i.UP):
			var cap := centre + Vector3(0, cell_size * 0.5 + 0.04, 0)
			mesh.box(cap, Vector3(cell_size, 0.12, Art.GROUND_DEPTH + 0.04), colours["top"])
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
	_present_footsteps(moving_delta)
	particles.advance(moving_delta)
	_present_items()
	_present_pests()
	_present_shadow()
	_present_camera(moving_delta)
	_present_backdrop()
	var light_time := state.elapsed if day_night_enabled and not reduced_motion else 0.0
	daylight.set_palette(BiomeProps.palette(state.biome)["sky"], reduced_motion)
	daylight.advance(moving_delta)
	daylight.set_elapsed(light_time)


## Shows one run event: Dulce's reaction and its puff of dust, crumbs or
## feathers. Read-only, like everything else here.
func react(event: Dictionary) -> void:
	if dulce == null or state == null:
		return
	var feet := Art.world_point(state.position)
	match str(event.get("kind", "")):
		"jump":
			particles.burst(feet, 3, DUST, 0.1, 0.35, 0.2, 0.35)
		"land":
			dulce.react("land")
			var impact := clampf(float(event.get("speed", 0.0)) / 1200.0, 0.3, 1.0)
			particles.burst(feet, roundi(4 + 4 * impact), DUST, 0.12 * impact + 0.05,
				0.7 * impact, 0.35, 0.45)
		"stomp":
			dulce.react("stomp")
			particles.burst(feet + Vector3(0, -0.1, 0), 8, FEATHERS, 0.1, 0.9, 0.8, 0.5)
		"eat":
			dulce.react("eat")
			var cell: Vector2i = event.get("cell", Vector2i.ZERO)
			var at := Art.world_point((Vector2(cell) + Vector2(0.5, 0.5)) * Grid.TILE)
			particles.burst(at, 5, FoodModels.BUN, 0.06, 0.5, 0.5, 0.35)
		"hurt", "shrink":
			dulce.react("hurt")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if particles != null:
		particles.reduced_motion = value
		if value:
			particles.clear()
	present(0.0)


func set_intense_effects(value: bool) -> void:
	intense_effects = value


func set_day_night_enabled(value: bool) -> void:
	day_night_enabled = value
	present(0.0)


## Food appears when it is in the model and goes when it is eaten, including a
## Big Burger popped out of a Lunchbox mid-run.
func _present_items() -> void:
	for cell: Vector2i in _items.keys():
		if not state.items.has(cell):
			_items[cell].queue_free()
			_items.erase(cell)
	var angle := FOOD_PARKED_ANGLE if reduced_motion else state.elapsed * FOOD_SPIN
	for cell: Vector2i in state.items:
		if not _items.has(cell):
			var food := MeshInstance3D.new()
			food.name = "%s_%d_%d" % [state.items[cell], cell.x, cell.y]
			var chunk := _chunk_at(cell.x)
			food.mesh = FoodModels.mesh_for(state.items[cell],
				int(chunk.get("biome", ChunkLibrary.Biome.BACKYARD)))
			food.material_override = _finish
			food.position = Art.world_point((Vector2(cell) + Vector2(0.5, 0.5)) * Grid.TILE)
			world.add_child(food)
			_items[cell] = food
		_items[cell].rotation.y = angle


## Pests turn to face the way they walk; a stomped one shrinks into its puff,
## or simply vanishes under reduced motion.
func _present_pests() -> void:
	var live := {}
	for pest: Dictionary in state.pests.list:
		var id: int = pest["id"]
		live[id] = true
		if not _pests.has(id):
			var body := MeshInstance3D.new()
			body.name = "%s_%d" % [pest["kind"], id]
			body.mesh = PestModels.mesh_for(pest["kind"])
			body.material_override = _finish
			world.add_child(body)
			_pests[id] = body
		var node := _pests[id]
		node.position = Art.world_point(pest["position"])
		node.rotation = Vector3(0.0, 0.0 if int(pest["facing"]) > 0 else PI, 0.0)
		node.scale = Vector3.ONE
		node.visible = true
		if pest["alive"]:
			_pose_pest(node, pest, id)
		else:
			_pose_exit(node, pest)
	for id: int in _pests.keys():
		if not live.has(id):
			_pests[id].queue_free()
			_pests.erase(id)


## Each pest's living pose: the pigeon's waddle, a robo-vac on its back or
## spinning across the ground. Decoration parks under reduced motion; a vac's
## flip does not, because it says the vac is safe to touch.
func _pose_pest(node: MeshInstance3D, pest: Dictionary, id: int) -> void:
	match str(pest["kind"]):
		Pests.PIGEON:
			if pest["active"] and not reduced_motion:
				var step := sin(state.elapsed * TAU * WADDLE_HZ + id)
				node.rotation.z = step * 0.14
				node.position.y += absf(step) * 0.025
		Pests.ROBO_VAC:
			if pest["state"] != "walk":
				node.rotation.x = PI
				node.position.y += 0.2
				if pest["state"] == "sliding" and not reduced_motion:
					node.rotation.y = state.elapsed * VAC_SPIN


## How a stomped pest leaves: a puff that squashes away, a squirrel bolting
## off-screen, a bottle's lid popping. Reduced motion just removes it.
func _pose_exit(node: MeshInstance3D, pest: Dictionary) -> void:
	var left := float(pest["poof"]) / Pests.POOF_SECONDS
	node.visible = not reduced_motion and left > 0.0
	match str(pest["exit"]):
		Pests.SCURRY:
			node.position.x += (1.0 - left) * SCURRY_METRES * int(pest["facing"]) * -1.0
			node.rotation.y += PI
		Pests.POP:
			node.scale = Vector3(1.0 + (1.0 - left) * 0.3, left, 1.0 + (1.0 - left) * 0.3)
		_:
			node.scale = Vector3(1.0 + (1.0 - left) * 0.4, left, 1.0 + (1.0 - left) * 0.4)


## The far backdrop scrolls at `PARALLAX` of the playfield's speed: real
## geometry, recycled tile by tile, in the biome she is in.
func _present_backdrop() -> void:
	if not _camera_ready or _backdrop_tiles.is_empty():
		return
	var focus := camera.x * Art.WORLD_SCALE
	var ground := Art.world_point(Vector2(0.0, ChunkLibrary.SEAM_ROW * Grid.TILE)).y
	_far_ground.position = Vector3(focus, ground - 0.08, BiomeProps.BACKDROP_DEPTH * 0.5 - 0.8)
	_far_ground_finish.albedo_color = BiomeProps.far_ground(state.biome)
	_backdrop.position = Vector3(focus * (1.0 - BiomeProps.PARALLAX), ground, BiomeProps.BACKDROP_DEPTH)
	if not _backdrop_meshes.has(state.biome):
		_backdrop_meshes[state.biome] = BiomeProps.backdrop(state.biome)
	var meshes: Dictionary = _backdrop_meshes[state.biome]
	# In the backdrop's own, unscaled space: what is on screen, tile by tile.
	var half := size.x / maxf(_zoom, 0.0001) * Art.WORLD_SCALE * 0.5 / BiomeProps.BACKDROP_SCALE
	var local_centre := focus * BiomeProps.PARALLAX / BiomeProps.BACKDROP_SCALE
	var first := floori((local_centre - half) / BiomeProps.BACKDROP_TILE)
	for index in _backdrop_tiles.size():
		var tile := _backdrop_tiles[index]
		tile.position = Vector3((first + index) * BiomeProps.BACKDROP_TILE, 0.0, 0.0)
		(tile.get_node("Lit") as MeshInstance3D).mesh = meshes["lit"]
		(tile.get_node("Glow") as MeshInstance3D).mesh = meshes["glow"]


## A puff behind her paws for every stretch of ground she runs, never while
## she walks slowly or flies.
func _present_footsteps(delta: float) -> void:
	if not state.grounded or absf(state.velocity.x) < FOOTSTEP_SPEED or state.over:
		return
	_footstep_left -= absf(state.velocity.x) * Art.WORLD_SCALE * delta
	if _footstep_left > 0.0:
		return
	_footstep_left = FOOTSTEP_METRES
	var behind := Vector2(state.position.x - 8.0 * state.facing, state.position.y)
	particles.burst(Art.world_point(behind, 0.05), 1, DUST, 0.11, 0.15, 0.25, 0.4)


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
	# Lift the ground line clear of any touch buttons along the bottom edge.
	var clear := 1.0 - (bottom_inset + 12.0) / size.y if bottom_inset > 0.0 else 1.0
	var ground_line := clampf(minf(GROUND_LINE, clear), HIGHEST_GROUND_LINE, GROUND_LINE)
	var target_y := seam - view_size.y * (ground_line - 0.5)
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


## Physical pixels per design pixel for whatever viewport `node` is drawn in.
## Measures that viewport rather than the OS window, which is the same thing
## in the game but not when the scene is hosted in a `SubViewport`.
static func physical_scale(node: Node) -> float:
	var viewport := node.get_viewport()
	var physical := Vector2((viewport as Window).size) if viewport is Window \
		else Vector2((viewport as SubViewport).size)
	return physical.x / maxf(viewport.get_visible_rect().size.x, 1.0)


func _resize_world() -> void:
	if world_viewport == null:
		return
	var render_size := size * physical_scale(self)
	if render_size.x > MAX_RENDER_WIDTH:
		render_size *= MAX_RENDER_WIDTH / render_size.x
	if render_size.y > MAX_RENDER_HEIGHT:
		render_size *= MAX_RENDER_HEIGHT / render_size.y
	world_viewport.size = Vector2i(maxi(1, roundi(render_size.x)), maxi(1, roundi(render_size.y)))
	present(0.0)
