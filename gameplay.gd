extends GameShell

## Dulce's run, inside the reusable navigation and results shell.
##
## Milestone 1, the feel prototype: one grey-box course, the real movement
## model, the 3D side view and keyboard/gamepad input. A pit sends her back to
## the start; hearts, pests and pickups arrive in Milestone 2, so until then a
## run only ends from the pause menu.

const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")
const State = preload("res://games/dulces_adventure/run_state.gd")
const ChunkLibrary = preload("res://games/dulces_adventure/chunk_library.gd")
const WorldView = preload("res://games/dulces_adventure/world_view.gd")
const RunControls = preload("res://games/dulces_adventure/run_controls.gd")

var _state: State
var _view: WorldView
var _controls := RunControls.new()
var _auto_run := false
var _game_speed := 1.0
var _day_night_enabled := true
var _jump_pending := false


## GameCatalog discovers the folder; no framework branch knows this id.
func game_id() -> String:
	return Options.GAME_ID


func _load_round_settings() -> void:
	super()
	_auto_run = Settings.tunable_bool(Options.AUTO_RUN_KEY)
	_game_speed = Settings.tunable(Options.GAME_SPEED_KEY)
	_day_night_enabled = Settings.tunable_bool(Options.DAY_NIGHT_KEY)


func _build_playfield() -> void:
	_state = State.new(ChunkLibrary.feel_grid(), ChunkLibrary.feel_start())
	_view = WorldView.new()
	_view.name = "RunView"
	_view.reduced_motion = _reduced_motion_enabled
	_view.intense_effects = _intense_effects_enabled
	_playfield.add_child(_view)
	_view.configure(_state)
	get_viewport().size_changed.connect(_layout_view)
	_layout_view()


func _reset_round_state() -> void:
	_jump_pending = false
	_state = State.new(ChunkLibrary.feel_grid(), ChunkLibrary.feel_start())
	_state.auto_run = _auto_run
	# Applied per run, so a jump never changes speed half-way through.
	_state.time_scale = _game_speed
	if _view != null:
		_view.set_day_night_enabled(_day_night_enabled)
		_view.configure(_state)


func _update_round(delta: float, _time_left: float) -> void:
	if not _round_active or get_tree().paused or Router.is_transitioning():
		return
	var input := _controls.sample(_controller_device())
	_state.advance(delta, input["move"], input["run"], input["jump"], _jump_pending)
	_jump_pending = false
	for event in _state.take_events():
		if event["kind"] == "fell":
			# Milestone 2 turns this into a lost heart at the last safe ground.
			_respawn(ChunkLibrary.feel_start())
	_view.present(delta)
	_state.push_left_limit(_view.left_edge())
	_scores[PLAYER_ONE] = floori(_state.distance_m())
	_update_scores()


## The camera edge only moves forward, so a respawn behind it re-frames the
## view around her; otherwise the edge would shove her along the ground.
func _respawn(point: Vector2) -> void:
	_state.place(point)
	_state.left_limit = -INF
	_view.configure(_state)


func _handle_gameplay_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if _controls.is_jump_press(event, _controller_device()):
		_jump_pending = true
	if _controls.owns(event):
		get_viewport().set_input_as_handled()


func _configure_mode_ui() -> void:
	super()
	_callout.hide()
	_refresh_hint()


## Rebound keys show up at once, not at the next run.
func _on_controls_changed() -> void:
	_refresh_hint()


func _refresh_hint() -> void:
	_hint.text = "%s / %s move  |  %s jump  |  Hold %s to run  |  Esc pauses" % [
		Settings.control_key_label(Options.LEFT), Settings.control_key_label(Options.RIGHT),
		Settings.control_key_label(Options.JUMP), Settings.control_key_label(Options.RUN),
	]


func _controller_device() -> int:
	return GameSession.controller_device_for_player(PLAYER_ONE)


## A press caught by the pause menu must not jump once the run resumes.
func open_pause_menu() -> void:
	_jump_pending = false
	super()


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Options.AUTO_RUN_KEY:
		_auto_run = Settings.tunable_bool(Options.AUTO_RUN_KEY)
		if _state != null:
			_state.auto_run = _auto_run
	elif key == Options.DAY_NIGHT_KEY:
		_day_night_enabled = Settings.tunable_bool(Options.DAY_NIGHT_KEY)
		if _view != null:
			_view.set_day_night_enabled(_day_night_enabled)


## Ear flop, tail wag and squash will park here too once Dulce has a model.
func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_reduced_motion(value)


## Screen shake and hit flashes will be suppressed here once they exist.
func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_intense_effects(value)


func _layout_view() -> void:
	if _view == null:
		return
	var bounds := _playfield_bounds()
	_view.position = bounds.position
	_view.size = bounds.size
	_view.present(0.0)
