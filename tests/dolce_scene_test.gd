extends SceneTree

## The real gameplay scene under the shell (DESIGN §10): it loads, binds its
## HUD and outfit, pauses, drives Backyard to Market and every full stage
## through inputs, and checks results, records and fresh sequential unlocks.
##
## The scene is loaded at runtime and poked with `call`/`get`, never named:
## `GameShell` uses autoload instances, so naming it would break this script's
## headless compile. Every save file a run can touch is snapshotted first and
## put back at the end, so the suite never changes a player's progress.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Stages = preload("res://games/dolces_adventure/stages.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")
const Pests = preload("res://games/dolces_adventure/pests.gd")
const Records = preload("res://games/dolces_adventure/run_records.gd")
const Driver = preload("res://games/dolces_adventure/tests/playthrough_driver.gd")
const DailyRun = preload("res://games/dolces_adventure/daily_run.gd")

const MAX_RUN_FRAMES := 18000
const MARKET_METRES := 2250.0

const SAVES: Array[String] = [
	"user://store.cfg", "user://achievements.cfg", "user://settings.cfg", Options.SAVE_PATH,
]

var _failures := PackedStringArray()
var _snapshots := {}
var _settings_snapshot: Dictionary = {}
var _achievements_snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_snapshot()
	var session := get_root().get_node_or_null("GameSession")
	var store := get_root().get_node_or_null("Store")
	if session == null or store == null:
		_failures.append("GameSession and Store autoloads are required.")
		_restore()
		_finish()
		return
	GameCatalog.select(Options.GAME_ID)
	session.call("configure_single_player")
	session.call("set_level", Options.START_BACKYARD)
	await _test_touch_tip()
	_test_driver_isolation()
	if _fresh_progress():
		await _test_endless_run(store)
	if _fresh_progress(true):
		for index in Stages.STAGES.size():
			var stage: Dictionary = Stages.STAGES[index]
			for level: Dictionary in session.call("level_options"):
				if Stages.is_stage(str(level["id"])):
					var number := int(Stages.find(str(level["id"]))["number"])
					_expect(bool(session.call("setup_option_is_unlocked", level)) == (number <= index + 1),
						"Only Stage 1 and stages earned so far are selectable (%s)." % level["id"])
			session.call("set_level", str(stage["id"]))
			if not await _test_stage_clear(store, stage):
				break
	if _fresh_progress(true):
		await _test_daily_run(session, store)
	_restore()
	_finish()


func _open() -> Node:
	var packed := load("res://games/dolces_adventure/gameplay.tscn") as PackedScene
	var game := packed.instantiate()
	game.set_script(load("res://games/dolces_adventure/tests/playthrough_gameplay.gd"))
	get_root().add_child(game)
	# The first round starts once the opening transition and countdown allow.
	for _frame in 240:
		await process_frame
		if bool(game.get("_round_active")):
			break
	_expect(bool(game.get("_round_active")), "The run starts by itself.")
	return game


func _test_touch_tip() -> void:
	var settings := get_root().get_node("Settings")
	settings.call("set_value", Options.AUTO_RUN_KEY, false)
	settings.call("set_value", Options.TOUCH_HINT_SEEN_KEY, false)
	var game := await _open()
	game.set("_round_active", false)
	var controls: Control = game.get("_controls")
	controls.show()
	await process_frame
	_expect(controls.get_node("AutoRunHint").visible,
		"A first touchscreen run offers Auto-run without enabling it.")
	(controls.get("_dismiss_button") as Button).pressed.emit()
	_expect(not controls.get_node("AutoRunHint").visible and not game.get("_state").auto_run,
		"Not now dismisses the tip without changing the assist.")
	settings.call("save")
	game.queue_free()
	await process_frame
	# The framework does not register onboarding as a tunable. Simulate a new
	# process so the game must read its merge-preserved flag from disk.
	settings.get("_values").erase(Options.TOUCH_HINT_SEEN_KEY)
	game = await _open()
	game.set("_round_active", false)
	controls = game.get("_controls")
	controls.show()
	await process_frame
	_expect(not controls.get_node("AutoRunHint").visible,
		"The tip stays dismissed after the saved flag is reloaded.")
	game.queue_free()
	await process_frame
	settings.call("set_value", Options.TOUCH_HINT_SEEN_KEY, false)
	game = await _open()
	game.set("_round_active", false)
	controls = game.get("_controls")
	controls.show()
	await process_frame
	(controls.get("_auto_run_button") as Button).pressed.emit()
	_expect(game.get("_state").auto_run and settings.call("tunable_bool", Options.AUTO_RUN_KEY),
		"Accepting the tip enables the real, saved Auto-run assist.")
	_expect(not controls.get_node("AutoRunHint").visible,
		"Accepting Auto-run dismisses the tip.")
	game.queue_free()
	await process_frame
	settings.call("set_value", Options.AUTO_RUN_KEY, false)


func _test_endless_run(store: Node) -> void:
	var game := await _open()
	var state := game.get("_state") as State
	_expect(state != null and game.get("_stage").is_empty(), "An endless run starts in the Backyard.")
	_expect(int(game.get("_seed")) == 42 and state.position == ChunkLibrary.start_position(),
		"The seeded run starts at the normal front-door spawn.")
	var session := get_root().get_node("GameSession")
	for level: Dictionary in session.call("level_options"):
		if level.has("requires_achievement") and not Stages.is_stage(str(level["id"])):
			_expect(not bool(session.call("setup_option_is_unlocked", level)),
				"A fresh profile cannot start at %s." % level["id"])
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
	var before := int(store.call("points", Options.GAME_ID))
	var run := await _drive(game, true)
	print("Endless seed 42: %.0f m, %d burgers, %d stomps, biomes=%s." % [
		state.distance_m(), state.burgers, state.stomps, run["biomes"],
	])
	_expect(run["reached_market"] and run["biomes"] == ChunkLibrary.Biome.values(),
		"Normal inputs pass all five biome gates from the Backyard into the Market.")
	_expect(state.hearts == 0 and state.over and not state.cleared,
		"After reaching the Market, untimed jumps lose the last heart normally.")
	_expect((game.get_node("%RoundOver") as Control).visible,
		"Losing the last heart ends in the shell's results.")
	_expect(str(game.get("_result_label").text).contains("M"),
		"The results lead with the distance (%s)." % game.get("_result_label").text)
	var score: int = game.get("_scores")[0]
	var expected := roundi(score * 0.01) + int(Options.STORE_CURRENCY["round_bonus"])
	_expect(int(store.call("points", Options.GAME_ID)) - before == expected,
		"A run pays score / 100 plus %d Treats (%d)." % [Options.STORE_CURRENCY["round_bonus"], expected])
	var achievements := get_root().get_node("AchievementManager")
	for key: String in Options.REACH_METRES:
		_expect(bool(achievements.call("is_unlocked", key)),
			"The full endless run earns %s." % key)
	for key: String in [Options.HUNDRED, Options.CLEAN]:
		_expect(bool(achievements.call("is_unlocked", key)),
			"The collected food and clean stretch earn %s." % key)
	for level: Dictionary in session.call("level_options"):
		if not Stages.is_stage(str(level["id"])):
			_expect(bool(session.call("setup_option_is_unlocked", level)),
				"The real results unlock the endless start at %s." % level["id"])
	var record := Records.new().best(Options.START_BACKYARD)
	_expect(int(record["distance"]) == floori(state.distance_m()) and int(record["score"]) == score,
		"The full endless result saves its actual distance and score.")
	game.queue_free()
	await process_frame


func _fresh_progress(keep_records := false) -> bool:
	var paths: Array[String] = ["user://achievements.cfg"]
	if not keep_records:
		paths.append(Options.SAVE_PATH)
	for path in paths:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			_expect(error == OK, "Fresh progression removes %s (%d)." % [path, error])
			if error != OK:
				return false
	get_root().get_node("AchievementManager").set("_unlocked", {})
	var settings := get_root().get_node("Settings")
	for key: String in [Options.AUTO_RUN_KEY, Options.KIND_PITS_KEY, Options.DAY_NIGHT_KEY]:
		settings.call("set_value", key, false)
	settings.call("set_value", Options.GAME_SPEED_KEY, 1.0)
	return true


func _test_stage_clear(store: Node, stage: Dictionary) -> bool:
	var game := await _open()
	var state := game.get("_state") as State
	var id := str(stage["id"])
	_expect(game.get("_stage").get("id", "") == id, "%s starts as the selected stage." % id)
	_expect(str((game.get_node("%TimeCaption") as Label).text).begins_with("TIME"),
		"A stage puts the clock in the big HUD card.")
	var before := int(store.call("points", Options.GAME_ID))
	await _drive(game)
	print("%s: %.0f m, %d burgers, %d hearts, cleared=%s, %.2f model seconds." % [
		id, state.distance_m(), state.burgers, state.hearts, state.cleared, state.elapsed])
	_expect(state.cleared and (game.get_node("%RoundOver") as Control).visible,
		"%s reaches the food truck and opens the results." % id)
	_expect(state.hearts == State.STARTING_HEARTS and state.hits == 0 and state.pits == 0,
		"%s clears its full course without a hit or pit recovery." % id)
	_expect(state.distance_m() >= Stages.length_m(stage) - 1.0
		and state.burgers > 0 and state.stomps > 0,
		"%s really traverses the authored course, collecting food and stomping pests." % id)
	_expect(str(game.get("_result_label").text).contains(":"),
		"A stage's results lead with the clear time (%s)." % game.get("_result_label").text)
	var score: int = game.get("_scores")[0]
	var expected := roundi(score * 0.01) + int(Options.STORE_CURRENCY["round_bonus"]) \
		+ Options.TREATS_PER_CLEAR
	_expect(int(store.call("points", Options.GAME_ID)) - before == expected,
		"A clear pays %d Treats on top (%d)." % [Options.TREATS_PER_CLEAR, expected])
	var achievements := get_root().get_node("AchievementManager")
	_expect(bool(achievements.call("is_unlocked", str(stage["clear_achievement"]))),
		"Clearing %s unlocks its achievement." % id)
	var record := Records.new().best(id)
	_expect(int(record["time_ms"]) == roundi(state.clear_time * 1000.0)
		and int(record["distance"]) == floori(state.distance_m()),
		"%s saves its actual full-course clear time and distance." % id)
	game.queue_free()
	await process_frame
	return state.cleared


# --------------------------------------------------------------------------

func _test_daily_run(session: Node, store: Node) -> void:
	var records := Records.new()
	var original_bests := {Options.START_BACKYARD: records.best(Options.START_BACKYARD)}
	for stage: Dictionary in Stages.STAGES:
		original_bests[str(stage["id"])] = records.best(str(stage["id"]))
	session.call("set_level", Options.DAILY)
	_expect(str(session.call("selected_level")["id"]) == Options.DAILY,
		"Daily UTC is selectable with no achievements or attempt gate.")
	var settings := get_root().get_node("Settings")
	settings.call("set_value", Options.AUTO_RUN_KEY, true)
	settings.call("set_value", Options.KIND_PITS_KEY, true)
	settings.call("set_value", Options.GAME_SPEED_KEY, 0.7)
	var game := await _open()
	var state := game.get("_state") as State
	_expect(state.auto_run and state.kind_pits and is_equal_approx(state.time_scale, 0.7),
		"Daily UTC retains every existing run assist.")
	game.queue_free()
	await process_frame
	settings.call("set_value", Options.AUTO_RUN_KEY, false)
	settings.call("set_value", Options.GAME_SPEED_KEY, 1.0)
	game = await _open()
	var daily := game.get("_daily") as DailyRun
	var first_chunks: Array = game.get("_stream").placed.duplicate(true)
	_expect(daily.utc_date == "2026-11-01" and int(game.get("_seed")) == daily.seed
		and daily.seed != 42, "Daily uses its UTC date, not the test's ordinary replay seed.")
	for attempt in 2:
		state = game.get("_state") as State
		await _drive(game, true, true)
		_expect(state.over and state.hearts == 0 and bool(game.get("_ended")),
			"Daily attempt %d ends through real, untimed controls." % (attempt + 1))
		(game.get_node("%PlayAgainButton") as Button).pressed.emit()
		state = game.get("_state") as State
		_expect(bool(game.get("_round_active")) and state.position == ChunkLibrary.start_position()
			and game.get("_daily").utc_date == daily.utc_date
			and int(game.get("_seed")) == daily.seed and game.get("_stream").placed == first_chunks,
			"Play Again repeats today's course without consuming an attempt allowance.")
	state = game.get("_state") as State
	var tomorrow_time := Time.get_unix_time_from_datetime_string("2026-11-02T00:00:00")
	game.set("test_unix_time", tomorrow_time)
	game.call("_configure_mode_ui")
	_expect(game.get("_daily").utc_date == daily.utc_date and int(game.get("_seed")) == daily.seed,
		"Crossing UTC midnight cannot change an active run's identity.")
	_expect((game.get_node("%TimeCaption") as Label).text == daily.utc_date + " UTC",
		"The live HUD still shows the run's captured UTC date.")
	var before := int(store.call("points", Options.GAME_ID))
	var run := await _drive(game, true)
	var score: int = game.get("_scores")[0]
	_expect(run["reached_market"] and bool(game.get("_ended")),
		"The daily course plays from Backyard through Market and normal death results.")
	_expect(int(store.call("points", Options.GAME_ID)) - before == roundi(score * 0.01)
		+ int(Options.STORE_CURRENCY["round_bonus"]),
		"A daily result pays the unchanged endless Treats rule.")
	var achievements := get_root().get_node("AchievementManager")
	for key: String in Options.REACH_METRES:
		_expect(bool(achievements.call("is_unlocked", key)),
			"Daily results earn %s even with Kind pits enabled." % key)
	var saved := records.best(daily.record_id)
	_expect(int(saved["distance"]) == floori(state.distance_m()) and int(saved["score"]) == score,
		"A run ending after midnight saves under its starting date.")
	var tomorrow := DailyRun.new(tomorrow_time)
	_expect(int(records.best(tomorrow.record_id)["distance"]) == 0,
		"Finishing yesterday's run cannot populate tomorrow's best.")
	for id: String in original_bests:
		_expect(records.best(id) == original_bests[id],
			"The actual daily payout preserves the v1 best at %s." % id)
	var payload: Dictionary = game.call("_share_payload")
	_expect(payload.get("daily_date", "") == daily.utc_date
		and int(payload.get("course_seed", -1)) == daily.seed
		and str(payload.get("mode", "")).contains(daily.utc_date)
		and str(payload.get("subtitle", "")).contains("%06d" % daily.seed),
		"The share card carries the captured daily date and actual course seed.")
	_expect(str(game.get("_result_label").text).contains("DAILY")
		and str(game.get("_round_subtitle").text).contains(daily.utc_date),
		"Daily results identify their own date and distance best.")
	print("Daily UTC %s, seed %06d: %.0f m, retries and midnight rollover passed." % [
		daily.utc_date, daily.seed, state.distance_m(),
	])
	(game.get_node("%PlayAgainButton") as Button).pressed.emit()
	_expect(game.get("_daily").utc_date == tomorrow.utc_date
		and int(game.get("_seed")) == tomorrow.seed
		and int(game.get("_best").get("distance", -1)) == 0,
		"Play Again after UTC midnight starts the new date with separate bests.")
	session.call("set_level", Options.START_BACKYARD)
	game.call("_start_round")
	_expect(game.get("_daily") == null and int(game.get("_seed")) == 42
		and (game.get_node("%TimeCaption") as Label).text == "DISTANCE",
		"Leaving Daily UTC restores ordinary replay seeds, HUD and record routing.")
	game.queue_free()
	await process_frame


func _test_driver_isolation() -> void:
	var grid := Grid.new(["........", "........", "........", "........", "########", "########"])
	var cell := Vector2i(2, 2)
	grid.set_tile(cell, Grid.LUNCHBOX)
	var state := State.new(grid, Vector2(100.0, 4.0 * Grid.TILE))
	state.lunchboxes[cell] = State.BIG_BURGER
	state.items[Vector2i(3, 3)] = State.BURGER
	state.pests.add(Pests.PIGEON, Vector2(220.0, 4.0 * Grid.TILE))
	var items := state.items.duplicate(true)
	var boxes := state.lunchboxes.duplicate(true)
	var pests := state.pests.list.duplicate(true)
	var driver := Driver.new()
	var route: Dictionary = driver.call("_rollout", state, 0, 24, true)
	var predicted: State = route["state"]
	_expect(predicted.grid.tile(cell) == Grid.EMPTY_BOX and predicted.pests.list != pests,
		"The prediction really opens a Lunchbox and advances a pest.")
	_expect(state.grid.tile(cell) == Grid.LUNCHBOX and state.items == items
		and state.lunchboxes == boxes and state.pests.list == pests,
		"Lookahead cannot consume the live food, mutate its Lunchbox or move its pest.")
	_expect(state.position == Vector2(100.0, 4.0 * Grid.TILE) and state.elapsed == 0.0
		and state.hearts == State.STARTING_HEARTS and state.take_events().is_empty(),
		"Lookahead cannot advance the live body, its clock, hearts or events.")


## Only normal controls advance this callback. After the endless milestone,
## untimed hops clear walls but let real collisions end the run for results.
func _drive(game: Node, endless := false, untimed := false) -> Dictionary:
	var state := game.get("_state") as State
	var driver := Driver.new()
	var biomes: Array[int] = [state.biome]
	var reached_market := false
	game.set_process(false)
	for tick in MAX_RUN_FRAMES:
		if endless and not reached_market and state.biome == ChunkLibrary.Biome.MARKET \
				and state.distance_m() >= MARKET_METRES:
			reached_market = true
			_expect(state.hits == 0 and state.pits == 0 and state.hearts == State.STARTING_HEARTS,
				"The input-only 2.25 km run reaches the Market without damage or respawns.")
			_expect(state.burgers >= Options.HUNDRED_BURGERS,
				"The actual long run collects at least a hundred burgers.")
		if (reached_market or untimed) and not state.over:
			Input.action_press(Options.RIGHT)
			Input.action_press(Options.RUN)
			if tick % 60 < 24:
				Input.action_press(Options.JUMP)
			else:
				Input.action_release(Options.JUMP)
		elif not driver.update(state):
			_failures.append("Input driver could not finish %s at %.2f m." % [
				game.get("_start_id"), state.distance_m(),
			])
			break
		game.call("_update_round", Driver.DELTA, 0.0)
		if state.biome != biomes.back():
			biomes.append(state.biome)
		if bool(game.get("_ended")):
			break
		if tick % 60 == 0:
			await process_frame
	driver.release()
	_expect(bool(game.get("_ended")), "Normal inputs finish the run within the bounded frame budget.")
	# The accelerated model clock cannot finish the real-time 0.55 s cues.
	await _play(0.75)
	return {"biomes": biomes, "reached_market": reached_market}


## Lets `seconds` of real time pass. Headless process frames run in
## microseconds, far below one 120 Hz model step, so this waits on physics
## frames, which tick in real time.
func _play(seconds: float) -> void:
	for _frame in roundi(seconds * 60.0):
		await physics_frame
		await process_frame


func _snapshot() -> void:
	var settings := get_root().get_node_or_null("Settings")
	if settings != null:
		_settings_snapshot = settings.get("_values").duplicate(true)
	var achievements := get_root().get_node_or_null("AchievementManager")
	if achievements != null:
		_achievements_snapshot = achievements.get("_unlocked").duplicate(true)
	for path in SAVES:
		_snapshots[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null


## Puts every save back as it was, and reloads the autoloads that cache them,
## so nothing this suite earned or unlocked survives it.
func _restore() -> void:
	var settings := get_root().get_node_or_null("Settings")
	if settings != null:
		(settings.get("_save_timer") as Timer).stop()
		settings.set("_values", _settings_snapshot)
	var achievements := get_root().get_node_or_null("AchievementManager")
	if achievements != null:
		achievements.set("_unlocked", _achievements_snapshot)
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
