extends SceneTree

## Regenerates the game's art from its real chunks, sky and Dolce: the level
## selector's stills and the game icon. Run with a graphics window; this
## development tool is excluded from exports. `-- --only=levels` or
## `-- --only=icon` refreshes just one of them.
##
## The run is hosted in a fixed-size `SubViewport`, so the stills come out the
## same size whatever the OS window is doing.

const WorldView = preload("res://games/dolces_adventure/world_view.gd")
const LevelStream = preload("res://games/dolces_adventure/level_stream.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const Stages = preload("res://games/dolces_adventure/stages.gd")
const Studio = preload("res://games/dolces_adventure/world/studio.gd")
const DolceModel = preload("res://games/dolces_adventure/world/dolce_model.gd")
const FoodModels = preload("res://games/dolces_adventure/world/food_models.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")

## The shared setup screen's level row, at Cube Trials' size, rendered large
## and scaled down for clean edges.
const LEVEL_ART_SIZE := Vector2i(384, 240)
const LEVEL_ART_SUPERSAMPLE := 3
## A fixed seed, so a still only changes when the chunks or the art do.
const ART_SEED := 2024
## Dolce stands a few tiles into the gate, in front of its sign; on a stage's
## still, a few tiles short of the finish.
const STAND_COLUMN := 6
const GOAL_LEAD_TILES := 7.0
## The game icon: her head, burger in mouth, cut out on a clear background.
const ICON_PATH := "res://games/dolces_adventure/assets/game-icon.png"
const ICON_SIZE := 512
## Mostly from the front, so her face and both ears fill the icon.
const ICON_LENS := Vector3(1.0, 0.18, 0.5)

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("capture_art.gd renders real frames: run it without --headless.")
		quit(1)
		return
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	if only in ["", "levels"]:
		for level: Dictionary in Options.LEVELS:
			await _capture_level(level)
	if only in ["", "icon"]:
		await _capture_icon()
	quit(1 if _failed else 0)


func _capture_icon() -> void:
	var frame := SubViewport.new()
	frame.size = Vector2i.ONE * ICON_SIZE * 2
	frame.transparent_bg = true
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(frame)
	var host := Control.new()
	host.size = Vector2(frame.size)
	frame.add_child(host)
	var studio := Studio.build(host, true, Viewport.MSAA_4X)
	var stage: Node3D = studio["stage"]
	var dolce := DolceModel.new()
	stage.add_child(dolce)
	var rows: Array[String] = ["", "", "", "", "#".repeat(8), "#".repeat(8)]
	dolce.present(State.new(Grid.new(rows), Vector2(4.5 * Grid.TILE, 4.0 * Grid.TILE)), 0.0, true)
	dolce.position = Vector3.ZERO
	var burger := MeshInstance3D.new()
	burger.mesh = FoodModels.mesh_for(State.BURGER)
	burger.material_override = Art.material()
	burger.position = Vector3(0.355, 0.215, 0.0)
	burger.rotation.z = -0.3
	burger.scale = Vector3.ONE * 0.36
	stage.add_child(burger)
	await process_frame
	var box := Studio.bounds(stage, dolce.get_node("Rig/Torso/Head")).merge(Studio.bounds(stage, burger))
	Studio.frame(studio["camera"], box, ICON_LENS, 26.0, 1.0, 1.0)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := (studio["viewport"] as SubViewport).get_texture().get_image()
	image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var saved := image.save_png(ProjectSettings.globalize_path(ICON_PATH))
	if saved != OK:
		printerr("Could not save %s (error %d)." % [ICON_PATH, saved])
		_failed = true
	else:
		print("Saved ", ICON_PATH)
	frame.queue_free()
	await process_frame


func _capture_level(level: Dictionary) -> void:
	var frame := SubViewport.new()
	frame.size = LEVEL_ART_SIZE * LEVEL_ART_SUPERSAMPLE
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(frame)
	var view := WorldView.new()
	frame.add_child(view)
	view.size = Vector2(frame.size)
	view.reduced_motion = true
	var stage := Stages.find(str(level["id"]))
	var biome := int(stage["biome"]) if not stage.is_empty() \
		else ChunkLibrary.biome_named(str(level["id"]))
	var stream := LevelStream.new(ART_SEED, biome, stage)
	var state := stream.start()
	var stand := (STAND_COLUMN + 0.5) * 40.0
	if not stage.is_empty():
		# Walk the stream forward until the goal is laid, keeping every chunk.
		while not is_finite(state.goal_x):
			state.place(Vector2(stream.next_column * 40.0, ChunkLibrary.SEAM_ROW * 40.0))
			if not stream.update(state, -INF):
				break
		stand = state.goal_x - GOAL_LEAD_TILES * 40.0
	state.place(Vector2(stand, ChunkLibrary.SEAM_ROW * 40.0))
	var chunks: Array[Dictionary] = []
	for chunk in stream.placed:
		chunks.append({"column": chunk["column"], "width": chunk["width"],
			"biome": chunk["biome"], "gate": chunk["gate"], "goal": chunk["goal"]})
	view.configure(state, chunks)
	for _frame in 6:
		view.present(0.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var image := view.world_viewport.get_texture().get_image()
	image.resize(LEVEL_ART_SIZE.x, LEVEL_ART_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path := str(level["icon"])
	var saved := image.save_png(ProjectSettings.globalize_path(path))
	if saved != OK:
		printerr("Could not save %s (error %d)." % [path, saved])
		_failed = true
	else:
		print("Saved ", path)
	frame.queue_free()
	await process_frame
