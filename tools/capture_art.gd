extends SceneTree

## Regenerates the game's level stills from its real chunks, sky and Dulce.
## Run with a graphics window; this development tool is excluded from exports.
## `-- --only=levels` refreshes just the start-point stills (for now, all of
## them; Milestone 7 adds the game icon and share art here).
##
## The run is hosted in a fixed-size `SubViewport`, so the stills come out the
## same size whatever the OS window is doing.

const WorldView = preload("res://games/dulces_adventure/world_view.gd")
const LevelStream = preload("res://games/dulces_adventure/level_stream.gd")
const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")
const Stages = preload("res://games/dulces_adventure/stages.gd")

## The shared setup screen's level row, at Cube Trials' size, rendered large
## and scaled down for clean edges.
const LEVEL_ART_SIZE := Vector2i(384, 240)
const LEVEL_ART_SUPERSAMPLE := 3
## A fixed seed, so a still only changes when the chunks or the art do.
const ART_SEED := 2024
## Dulce stands a few tiles into the gate, in front of its sign; on a stage's
## still, a few tiles short of the finish.
const STAND_COLUMN := 6
const GOAL_LEAD_TILES := 7.0

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("capture_art.gd renders real frames: run it without --headless.")
		quit(1)
		return
	for level: Dictionary in Options.LEVELS:
		await _capture_level(level)
	quit(1 if _failed else 0)


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
