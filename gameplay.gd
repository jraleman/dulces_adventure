extends GameShell

## Dulce's run, inside the reusable navigation and results shell.
##
## The shell's countdown and lives pool are off (`uses_shell_round_rules =
## false`): the model owns hearts, and a run ends through the shell's normal
## `_end_round()` once her last heart is gone and the tumble has played. Each
## run is a fresh seed of the chunk stream; `--dulce-seed=<n>` after `--` on
## the command line replays one.

const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const LevelStream = preload("res://games/dulces_adventure/level_stream.gd")
const WorldView = preload("res://games/dulces_adventure/world_view.gd")
const RunControls = preload("res://games/dulces_adventure/run_controls.gd")
const RunHud = preload("res://games/dulces_adventure/run_hud.gd")
const Records = preload("res://games/dulces_adventure/run_records.gd")
const Art = preload("res://games/dulces_adventure/dulce_art.gd")

## Where every run starts until Milestone 5's start points, for results copy.
const START_TITLE := "the Backyard"
## Debug flag: replay a seed shown on the results panel.
const SEED_ARGUMENT := "--dulce-seed="
const HIT_SHAKE := 7.0

var _state: State
var _stream: LevelStream
var _seed := 0
var _view: WorldView
var _controls: RunControls
var _run_hud: RunHud
var _records := Records.new()
var _start_id := Options.START_BACKYARD
## This start point's best run before the current one, for "new best" copy.
var _best := {}
var _auto_run := false
var _kind_pits := false
var _game_speed := 1.0
var _day_night_enabled := true
var _jump_pending := false
var _ended := false


## GameCatalog discovers the folder; no framework branch knows this id.
func game_id() -> String:
	return Options.GAME_ID


func _load_round_settings() -> void:
	super()
	_auto_run = Settings.tunable_bool(Options.AUTO_RUN_KEY)
	_kind_pits = Settings.tunable_bool(Options.KIND_PITS_KEY)
	_game_speed = Settings.tunable(Options.GAME_SPEED_KEY)
	_day_night_enabled = Settings.tunable_bool(Options.DAY_NIGHT_KEY)


func _build_playfield() -> void:
	_stream = LevelStream.new(_seed)
	_state = _stream.start()
	_view = WorldView.new()
	_view.name = "RunView"
	_view.reduced_motion = _reduced_motion_enabled
	_view.intense_effects = _intense_effects_enabled
	_playfield.add_child(_view)
	_view.configure(_state, _live_chunks())
	var overlay := _hud.get_node("Overlay") as Control
	_run_hud = RunHud.new()
	overlay.add_child(_run_hud)
	_controls = RunControls.new()
	overlay.add_child(_controls)
	_controls.visible = DisplayServer.is_touchscreen_available()
	_controls.jump_requested.connect(_queue_jump)
	get_viewport().size_changed.connect(_layout_view)
	_layout_view()


func _reset_round_state() -> void:
	_jump_pending = false
	_ended = false
	_seed = _requested_seed()
	_stream = LevelStream.new(_seed)
	_state = _stream.start()
	_state.auto_run = _auto_run
	_state.kind_pits = _kind_pits
	# Applied per run, so a jump never changes speed half-way through.
	_state.time_scale = _game_speed
	_best = _records.best(_start_id)
	if _controls != null:
		_controls.set_enabled(true)
	if _view != null:
		_view.set_day_night_enabled(_day_night_enabled)
		_view.configure(_state, _live_chunks())
	_sync_hud()


## The debug seed when one was passed, otherwise a fresh one every run.
func _requested_seed() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_ARGUMENT):
			return int(argument.trim_prefix(SEED_ARGUMENT))
	return LevelStream.random_seed()


func _live_chunks() -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	for chunk in _stream.placed:
		chunks.append(Vector2i(int(chunk["column"]), int(chunk["width"])))
	return chunks


func _activate_round() -> void:
	super()
	get_viewport().gui_release_focus()


func _update_round(delta: float, _time_left: float) -> void:
	if not _round_active or get_tree().paused or Router.is_transitioning():
		return
	var input := _controls.sample(_controller_device())
	_state.advance(delta, input["move"], input["run"], input["jump"], _jump_pending)
	_jump_pending = false
	for event in _state.take_events():
		_on_run_event(event)
	_view.present(delta)
	_state.push_left_limit(_view.left_edge())
	if _stream.update(_state, _view.left_edge()):
		_view.sync_chunks(_live_chunks())
	_sync_hud()
	if _state.run_finished() and not _ended:
		_ended = true
		_end_round()


func _on_run_event(event: Dictionary) -> void:
	match str(event["kind"]):
		"respawn":
			# The camera edge only moves forward, so a respawn behind it
			# re-frames the view; otherwise the edge would shove her along.
			_state.left_limit = -INF
			_view.configure(_state)
		"lunchbox":
			_view.rebuild_chunk_at(event["cell"].x)
		"full":
			_show_announcement("FULL!", Art.MUSTARD)
		"heart":
			_show_announcement("+1 HEART", Art.KETCHUP)
		"stomp":
			if int(event["chain"]) >= 2:
				_show_announcement("x%d" % int(event["chain"]), Art.CREAM)
		"hurt", "shrink":
			_add_screen_shake(HIT_SHAKE)
		"run_over":
			_controls.set_enabled(false)
			_jump_pending = false


func _sync_hud() -> void:
	if _state == null:
		return
	_scores[PLAYER_ONE] = _state.score()
	_update_scores()
	# Distance is the headline (DESIGN §4.5), so it takes the shell's big card.
	_time_caption.text = "DISTANCE"
	_time_label.text = "%d m" % floori(_state.distance_m())
	if _run_hud != null:
		_run_hud.present(_state)


func _handle_gameplay_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if _controls.is_jump_press(event, _controller_device()):
		_queue_jump()
	if _controls.owns(event):
		get_viewport().set_input_as_handled()


func _queue_jump() -> void:
	if _round_active and not get_tree().paused and not _state.over:
		_jump_pending = true


func _controller_device() -> int:
	return GameSession.controller_device_for_player(PLAYER_ONE)


## A press caught by the pause menu must not jump once the run resumes.
func open_pause_menu() -> void:
	_jump_pending = false
	if _controls != null:
		_controls.clear_input()
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _round_active:
		open_pause_menu()


func _finish_round() -> void:
	_jump_pending = false
	if _controls != null:
		_controls.set_enabled(false)


# --------------------------------------------------------------------------
# Results
# --------------------------------------------------------------------------


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	var distance := floori(_state.distance_m())
	var best := int(_best.get("distance", 0))
	var new_best := distance > best and distance > 0
	var lines := PackedStringArray([
		"%d m from %s" % [distance, START_TITLE],
		"%d burgers, %d stomps" % [_state.burgers, _state.stomps],
	])
	if not new_best and best > 0:
		lines.append("Best: %d m" % best)
	return {
		"result": "NEW BEST: %d M!" % distance if new_best else "RUN OVER: %d M" % distance,
		"subtitle": "  ·  ".join(lines),
		"color": Art.MUSTARD if new_best else Art.CREAM,
	}


## Assists never block achievements (DESIGN §8), so none of them is checked.
func _award_round_achievements(_one: int, _two: int) -> void:
	var distance := _state.distance_m()
	for key: String in Options.REACH_METRES:
		if distance >= float(Options.REACH_METRES[key]):
			_unlock_round_achievement(key)
	if _state.burgers >= Options.HUNDRED_BURGERS:
		_unlock_round_achievement(Options.HUNDRED)
	if _state.best_chain >= Options.COMBO_CHAIN:
		_unlock_round_achievement(Options.COMBO)
	if _state.best_clean_m >= Options.CLEAN_METRES:
		_unlock_round_achievement(Options.CLEAN)
	var improved := _records.record(_start_id, {
		"distance": floori(distance), "score": _state.score(), "burgers": _state.burgers,
	})
	if "score" in improved and int(_best.get("score", 0)) > 0:
		_round_progression_notes.append("New best score")


func _best_combo_summary() -> String:
	return "Longest stomp chain x%d  |  Longest clean stretch %d m" % [
		_state.best_chain, floori(_state.best_clean_m),
	]


## Burgers eaten out of burgers passed: an endless run has no total to miss.
func _round_totals() -> Dictionary:
	return {"hits": _state.burgers, "attempts": _state.burgers_passed()}


func _player_stats(player: int) -> Dictionary:
	if player != PLAYER_ONE:
		return super(player)
	var passed := _state.burgers_passed()
	return {
		"score": _scores[PLAYER_ONE],
		"hits": _state.burgers,
		"misses": _state.hits,
		"accuracy": roundi(100.0 * _state.burgers / passed) if passed > 0 else 0,
		"streak": _state.best_chain,
		"details": [
			{"label": "Distance", "value": "%d m from %s" % [floori(_state.distance_m()), START_TITLE]},
			{"label": "Stomps", "value": str(_state.stomps)},
			{"label": "Pits", "value": str(_state.pits)},
			{"label": "Longest clean stretch", "value": "%d m" % floori(_state.best_clean_m)},
			{"label": "Best distance", "value": "%d m" % maxi(
				int(_best.get("distance", 0)), floori(_state.distance_m()))},
			{"label": "Course seed", "value": str(_seed)},
		],
	}


# --------------------------------------------------------------------------
# HUD, settings and layout
# --------------------------------------------------------------------------


func _configure_mode_ui() -> void:
	super()
	_callout.hide()
	_hint.text = "%s / %s move  |  %s jump  |  Hold %s to run  |  Esc pauses" % [
		Settings.control_key_label(Options.LEFT), Settings.control_key_label(Options.RIGHT),
		Settings.control_key_label(Options.JUMP), Settings.control_key_label(Options.RUN),
	]
	_sync_hud()


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Options.AUTO_RUN_KEY:
		_auto_run = Settings.tunable_bool(Options.AUTO_RUN_KEY)
		if _state != null:
			_state.auto_run = _auto_run
	elif key == Options.DAY_NIGHT_KEY:
		_day_night_enabled = Settings.tunable_bool(Options.DAY_NIGHT_KEY)
		if _view != null:
			_view.set_day_night_enabled(_day_night_enabled)
	elif key == "ui/scale":
		_layout_view()


## Ear flop, tail wag and squash will park here too once Dulce has a model.
func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_reduced_motion(value)


## Screen shake already respects this through the shell; the view keeps its own
## copy for the flashes Milestone 4 adds.
func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_intense_effects(value)


func _layout_view() -> void:
	if _view == null:
		return
	var bounds := _playfield_bounds()
	# Same rule as Cube Trials: grow the controls when the design canvas is
	# shown on far fewer physical pixels, as on a phone.
	var readability := maxf(1.0, 1.0 / maxf(WorldView.physical_scale(self), 0.01) / 1.5)
	_view.position = bounds.position
	_view.size = bounds.size
	_controls.position = bounds.position
	_controls.fit(bounds.size, readability)
	_view.bottom_inset = _controls.covered_height()
	_run_hud.fit(readability)
	_run_hud.position = bounds.position + Vector2.ONE * 12.0 * readability
	_view.present(0.0)
