extends SceneTree

## The real gameplay scene under the shell (DESIGN §10): it loads, binds its
## HUD and outfit, pauses, ends an endless run and a stage in results, and
## pays the right Treats.
##
## The scene is loaded at runtime and poked with `call`/`get`, never named:
## `GameShell` uses autoload instances, so naming it would break this script's
## headless compile. Every save file a run can touch is snapshotted first and
## put back at the end, so the suite never changes a player's progress.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")

const SAVES: Array[String] = [
	"user://store.cfg", "user://achievements.cfg", "user://settings.cfg", Options.SAVE_PATH,
]

var _failures := PackedStringArray()
var _snapshots := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_snapshot()
	var session := get_root().get_node_or_null("GameSession")
	var store := get_root().get_node_or_null("Store")
	if session == null or store == null:
		_failures.append("GameSession and Store autoloads are required.")
		_finish()
		return
	GameCatalog.select(Options.GAME_ID)
	session.call("configure_single_player")
	session.call("set_level", Options.START_BACKYARD)
	await _test_endless_run(store)
	session.call("set_level", Options.STAGE_BACKYARD)
	await _test_stage_clear(store)
	_restore()
	_finish()


func _open() -> Node:
	var packed := load("res://games/dolces_adventure/gameplay.tscn") as PackedScene
	var game := packed.instantiate()
	get_root().add_child(game)
	# The first round starts once the opening transition and countdown allow.
	for _frame in 240:
		await process_frame
		if bool(game.get("_round_active")):
			break
	_expect(bool(game.get("_round_active")), "The run starts by itself.")
	return game


func _test_endless_run(store: Node) -> void:
	var game := await _open()
	var state := game.get("_state") as State
	_expect(state != null and game.get("_stage").is_empty(), "An endless run starts in the Backyard.")
	_expect((game.get_node("%ModeTitle") as Label).text == "DOLCE'S ADVENTURE",
		"The HUD is titled from the manifest.")
	_expect((game.get_node("%TimeLabel") as Label).text == "0 m",
		"Distance takes the big HUD card on an endless run.")
	var collar := game.get("_view").dolce.get_node("Rig/Torso/Collar") as MeshInstance3D
	_expect(collar.mesh != null, "Dolce is dressed in her equipped collar.")
	game.call("open_pause_menu")
	await process_frame
	_expect(paused, "The shell's pause menu opens over the run.")
	paused = false
	for overlay in get_root().find_children("*", "", true, false):
		if overlay.name.begins_with("PauseMenu"):
			overlay.queue_free()
	await process_frame
	state.place(Vector2(state.position.x + 30.0 * Grid.TILE, state.position.y))
	state.furthest_x = state.position.x
	var before := int(store.call("points", Options.GAME_ID))
	state.call("_end_run")
	await _play(State.TUMBLE_SECONDS + 0.5)
	_expect((game.get_node("%RoundOver") as Control).visible,
		"Losing the last heart ends in the shell's results.")
	_expect(str(game.get("_result_label").text).contains("M"),
		"The results lead with the distance (%s)." % game.get("_result_label").text)
	var score: int = game.get("_scores")[0]
	var expected := roundi(score * 0.01) + int(Options.STORE_CURRENCY["round_bonus"])
	_expect(int(store.call("points", Options.GAME_ID)) - before == expected,
		"A run pays score / 100 plus %d Treats (%d)." % [Options.STORE_CURRENCY["round_bonus"], expected])
	game.queue_free()
	await process_frame


func _test_stage_clear(store: Node) -> void:
	var game := await _open()
	var state := game.get("_state") as State
	_expect(not game.get("_stage").is_empty(), "Stage 1 plays as a stage.")
	_expect(str((game.get_node("%TimeCaption") as Label).text).begins_with("TIME"),
		"A stage puts the clock in the big HUD card.")
	var stream: Object = game.get("_stream")
	while not is_finite(state.goal_x):
		state.place(Vector2(stream.get("next_column") * Grid.TILE, state.position.y))
		stream.call("update", state, -INF)
	state.place(Vector2(state.goal_x - 3.0 * Grid.TILE, 4.0 * Grid.TILE))
	state.left_limit = -INF
	game.get("_view").call("configure", state, game.call("_live_chunks"))
	var before := int(store.call("points", Options.GAME_ID))
	Input.action_press(Options.RIGHT)
	await _play(State.CLEAR_SECONDS + 1.5)
	Input.action_release(Options.RIGHT)
	_expect(state.cleared and (game.get_node("%RoundOver") as Control).visible,
		"Reaching the food truck clears the stage and opens the results.")
	_expect(str(game.get("_result_label").text).contains(":"),
		"A stage's results lead with the clear time (%s)." % game.get("_result_label").text)
	var score: int = game.get("_scores")[0]
	var expected := roundi(score * 0.01) + int(Options.STORE_CURRENCY["round_bonus"]) \
		+ Options.TREATS_PER_CLEAR
	_expect(int(store.call("points", Options.GAME_ID)) - before == expected,
		"A clear pays %d Treats on top (%d)." % [Options.TREATS_PER_CLEAR, expected])
	var achievements := get_root().get_node("AchievementManager")
	_expect(bool(achievements.call("is_unlocked", Options.CLEARED_BACKYARD)),
		"Clearing Stage 1 unlocks its achievement, which opens Stage 2.")
	game.queue_free()
	await process_frame


# --------------------------------------------------------------------------


## Lets `seconds` of real time pass. Headless process frames run in
## microseconds, far below one 120 Hz model step, so this waits on physics
## frames, which tick in real time.
func _play(seconds: float) -> void:
	for _frame in roundi(seconds * 60.0):
		await physics_frame
		await process_frame


func _snapshot() -> void:
	for path in SAVES:
		_snapshots[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null


## Puts every save back as it was, and reloads the autoloads that cache them,
## so nothing this suite earned or unlocked survives it.
func _restore() -> void:
	for path: String in _snapshots:
		var bytes: Variant = _snapshots[path]
		if bytes == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	for autoload: String in ["Store", "AchievementManager", "Settings"]:
		var node := get_root().get_node_or_null(autoload)
		for method in ["_load_state", "load_settings"]:
			if node != null and node.has_method(method):
				node.call(method)
				break


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dolce scene tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
