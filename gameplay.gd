extends GameShell

## Dolce's run, inside the reusable navigation and results shell.
##
## The shell's countdown and lives pool are off (`uses_shell_round_rules =
## false`): the model owns hearts, and a run ends through the shell's normal
## `_end_round()` once her last heart is gone and the tumble has played, or
## once she reaches a fixed stage's goal. An endless run is a fresh seed of
## the chunk stream (`--dolce-seed=<n>` after `--` replays one); a stage is
## the same course every time, timed.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const LevelStream = preload("res://games/dolces_adventure/level_stream.gd")
const Stages = preload("res://games/dolces_adventure/stages.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")
const WorldView = preload("res://games/dolces_adventure/world_view.gd")
const RunControls = preload("res://games/dolces_adventure/run_controls.gd")
const RunHud = preload("res://games/dolces_adventure/run_hud.gd")
const Records = preload("res://games/dolces_adventure/run_records.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const DolceAudio = preload("res://games/dolces_adventure/dolce_audio.gd")
const PAUSE_ICON = preload("res://games/dolces_adventure/assets/icons/pause.svg")

## Debug flag: replay a seed shown on the results panel.
const SEED_ARGUMENT := "--dolce-seed="
const HIT_SHAKE := 7.0

var _state: State
var _stream: LevelStream
var _seed := 0
var _view: WorldView
var _controls: RunControls
var _run_hud: RunHud
var _records := Records.new()
var _cues: Dictionary[String, AudioStreamWAV] = {}
## What she wears, by store item id: collar, hat, neck.
var _outfit: Array[String] = [Options.COLLAR_RED, "", ""]
var _start_id := Options.START_BACKYARD
var _start_biome: int = ChunkLibrary.Biome.BACKYARD
## The fixed stage being played, or empty on an endless run.
var _stage: Dictionary = {}
## This start point's best run before the current one, for "new best" copy.
var _best := {}
var _auto_run := false
var _kind_pits := false
var _game_speed := 1.0
var _day_night_enabled := true
var _jump_pending := false
var _ended := false
## Bottom pixels kept clear for the tutorial recorder's caption card.
var _capture_inset := 0.0
var _touch_hint_offered := false
var _header_fonts: Dictionary[Label, int] = {}
var _header_styles: Dictionary[PanelContainer, StyleBoxFlat] = {}
var _header_layout := Vector3(-1, -1, -1)
var _header_touch := false
var _hud_margins: MarginContainer
var _normal_margins := PackedInt32Array()
var _normal_card_minimum := Vector2.ZERO
var _normal_caption_horizontal := Control.SIZE_SHRINK_CENTER


## GameCatalog discovers the folder; no framework branch knows this id.
func game_id() -> String:
	return Options.GAME_ID


func _load_round_settings() -> void:
	super()
	_auto_run = Settings.tunable_bool(Options.AUTO_RUN_KEY)
	_kind_pits = Settings.tunable_bool(Options.KIND_PITS_KEY)
	_game_speed = Settings.tunable(Options.GAME_SPEED_KEY)
	_day_night_enabled = Settings.tunable_bool(Options.DAY_NIGHT_KEY)
	_outfit = _equipped_outfit()


func _build_playfield() -> void:
	_cues = DolceAudio.cues()
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
	_controls.auto_run_requested.connect(_enable_auto_run)
	_controls.layout_changed.connect(_layout_view)
	_controls.visibility_changed.connect(_layout_view)
	_run_hud.resized.connect(_layout_view, CONNECT_DEFERRED)
	_pause_button.icon = PAUSE_ICON
	_pause_button.text = ""
	_pause_button.expand_icon = true
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.accessibility_name = "Pause"
	_pause_button.tooltip_text = "Pause the run"
	_prepare_touch_header()
	for header: Control in [_player_one_card, _time_label.get_parent().get_parent(),
			_pause_button, _pause_button.get_parent()]:
		header.item_rect_changed.connect(_layout_view, CONNECT_DEFERRED)
	_player_one_score.minimum_size_changed.connect(_fit_touch_score, CONNECT_DEFERRED)
	var caption := get_node("%AudioCaption") as Control
	caption.item_rect_changed.connect(_layout_view, CONNECT_DEFERRED)
	caption.visibility_changed.connect(_layout_view, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_layout_view)
	_layout_view()


func _reset_round_state() -> void:
	_jump_pending = false
	_ended = false
	_seed = _requested_seed()
	_start_id = str(GameSession.selected_level().get("id", Options.START_BACKYARD))
	_stage = Stages.find(_start_id)
	_start_biome = int(_stage["biome"]) if not _stage.is_empty() \
		else ChunkLibrary.biome_named(_start_id)
	_stream = LevelStream.new(_seed, _start_biome, _stage)
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
		_dress()
	_sync_hud()


## The store's equipped collar, hat and neck piece. Purely cosmetic.
func _equipped_outfit() -> Array[String]:
	return [
		Store.equipped_id(Options.GAME_ID, Options.COLLAR_SLOT),
		Store.equipped_id(Options.GAME_ID, Options.HAT_SLOT),
		Store.equipped_id(Options.GAME_ID, Options.BANDANA_SLOT),
	]


func _dress() -> void:
	if _view != null and _view.dolce != null:
		_view.dolce.set_outfit(_outfit[0], _outfit[1], _outfit[2])


## The store can be opened from the pause menu, so a new hat shows at once.
func _on_pause_closed() -> void:
	super()
	_outfit = _equipped_outfit()
	_dress()


## The debug seed when one was passed, otherwise a fresh one every run.
func _requested_seed() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(SEED_ARGUMENT):
			return int(argument.trim_prefix(SEED_ARGUMENT))
	return LevelStream.random_seed()


func _live_chunks() -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	for chunk in _stream.placed:
		chunks.append({
			"column": chunk["column"], "width": chunk["width"], "biome": chunk["biome"],
			"gate": chunk["gate"], "goal": chunk["goal"],
		})
	return chunks


## "the Park", for "412 m from the Park".
func _start_title() -> String:
	return str(ChunkLibrary.BIOMES[_start_biome]["title"])


func _activate_round() -> void:
	super()
	get_viewport().gui_release_focus()


func _update_round(delta: float, _time_left: float) -> void:
	if not _round_active or get_tree().paused or Router.is_transitioning():
		return
	var input := _controls.sample(_controller_device())
	if not is_zero_approx(input["move"]) or input["jump"] or input["run"]:
		_controls.dismiss_auto_run_hint()
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
	_view.react(event)
	# Sound and caption come from one table, so every captioned event is tested.
	var cue := DolceAudio.cue_for(event)
	if _cues.has(cue["cue"]):
		AudioManager.play_sfx(_cues[cue["cue"]], cue["volume_db"], cue["pitch"])
	AudioManager.request_caption(cue["caption"])
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
		"biome":
			_show_announcement("WELCOME TO %s!" % str(event["title"]).to_upper(), Art.CREAM, 1.0)
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
	# The headline takes the shell's big card: distance on an endless run
	# (DESIGN §4.5), the clock on a stage (§5.5).
	if _stage.is_empty():
		_time_caption.text = "DISTANCE"
		_time_label.text = "%d m" % floori(_state.distance_m())
	else:
		_time_caption.text = "TIME  ·  %d / %d M" % [
			floori(_state.distance_m()), floori(Stages.length_m(_stage)),
		]
		_time_label.text = Stages.time_text(_state.clear_time if _state.cleared else _state.elapsed)
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
		_controls.dismiss_auto_run_hint()
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
	if not _stage.is_empty():
		return _describe_stage()
	var distance := floori(_state.distance_m())
	var best := int(_best.get("distance", 0))
	var new_best := distance > best and distance > 0
	var lines := PackedStringArray([
		"%d m from %s" % [distance, _start_title()],
		"%d burgers, %d stomps" % [_state.burgers, _state.stomps],
	])
	if not new_best and best > 0:
		lines.append("Best: %d m" % best)
	return {
		"result": "NEW BEST: %d M!" % distance if new_best else "RUN OVER: %d M" % distance,
		"subtitle": "  ·  ".join(lines),
		"color": Art.MUSTARD if new_best else Art.CREAM,
	}


## A stage's results lead with the clock; an attempt that ran out of hearts
## says how far along the course she got.
func _describe_stage() -> Dictionary:
	var title := str(_stage_title())
	var food := "%d of %d burgers, %d stomps" % [
		_state.burgers, Stages.food_total(_stage), _state.stomps,
	]
	var best_ms := int(_best.get("time_ms", 0))
	if not _state.cleared:
		var lines := PackedStringArray([
			"%s: %d of %d m" % [title, floori(_state.distance_m()), floori(Stages.length_m(_stage))],
			food,
		])
		if best_ms > 0:
			lines.append("Best: %s" % Stages.time_text(best_ms / 1000.0))
		return {
			"result": "RUN OVER: %d M TO GO" % ceili(Stages.length_m(_stage) - _state.distance_m()),
			"subtitle": "  ·  ".join(lines),
			"color": Art.CREAM,
		}
	var time_ms := roundi(_state.clear_time * 1000.0)
	var new_best := best_ms <= 0 or time_ms < best_ms
	var lines := PackedStringArray([title, food])
	if not new_best:
		lines.append("Best: %s" % Stages.time_text(best_ms / 1000.0))
	var clock := Stages.time_text(_state.clear_time)
	return {
		"result": "NEW BEST: %s!" % clock if new_best else "STAGE CLEAR: %s" % clock,
		"subtitle": "  ·  ".join(lines),
		"color": Art.MUSTARD if new_best else Art.LETTUCE,
	}


func _stage_title() -> String:
	for level: Dictionary in Options.LEVELS:
		if level["id"] == _start_id:
			return str(level["title"])
	return _start_id


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
	if not _stage.is_empty() and _state.cleared:
		var opened := not AchievementManager.is_unlocked(str(_stage["clear_achievement"]))
		_unlock_round_achievement(str(_stage["clear_achievement"]))
		var next := _next_stage()
		if opened and not next.is_empty():
			_round_progression_notes.append("%s is open" % next["title"])
	var improved := _records.record(_start_id, {
		"distance": floori(distance), "score": _state.score(), "burgers": _state.burgers,
		"time_ms": roundi(_state.clear_time * 1000.0) if _state.cleared else 0,
	})
	if "score" in improved and int(_best.get("score", 0)) > 0:
		_round_progression_notes.append("New best score")


## The stage level after this one in the selector, or empty after the last.
func _next_stage() -> Dictionary:
	for level: Dictionary in Options.LEVELS:
		if level.get("requires_achievement", "") == _stage.get("clear_achievement", ""):
			return level
	return {}


## Treats: the declared rule (score / 100, plus 3 for finishing), and 20 more
## for clearing a stage (owner decision).
func _round_points_earned(player_one_total: int, player_two_total: int) -> int:
	var earned := super(player_one_total, player_two_total)
	if not _stage.is_empty() and _state.cleared:
		earned += Options.TREATS_PER_CLEAR
	return earned


## The share card shows the dog that just ran, dressed as she ran.
func _share_payload() -> Dictionary:
	var data := super()
	data["outfit"] = _outfit.duplicate()
	data["score_caption"] = "SCORE"
	data["level_id"] = _start_id
	data["level_title"] = _stage_title()
	data["distance_m"] = floori(_state.distance_m())
	if not _stage.is_empty():
		data["clear_time"] = Stages.time_text(_state.clear_time) if _state.cleared else ""
	return data


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
			{"label": "Distance", "value": "%d m from %s" % [floori(_state.distance_m()), _start_title()]}
				if _stage.is_empty() else {"label": "Stage", "value": _stage_title()},
			{"label": "Stomps", "value": str(_state.stomps)},
			{"label": "Pits", "value": str(_state.pits)},
			{"label": "Longest clean stretch", "value": "%d m" % floori(_state.best_clean_m)},
		] + _run_details(),
	}


## The last stats rows: an endless run's best distance and seed, or a stage's
## clock and food.
func _run_details() -> Array:
	if _stage.is_empty():
		return [
			{"label": "Best distance", "value": "%d m" % maxi(
				int(_best.get("distance", 0)), floori(_state.distance_m()))},
			{"label": "Course seed", "value": str(_seed)},
		]
	var best_ms := int(_best.get("time_ms", 0))
	return [
		{"label": "Time", "value": Stages.time_text(_state.clear_time) if _state.cleared
			else "Did not finish"},
		{"label": "Best time", "value": Stages.time_text(best_ms / 1000.0) if best_ms > 0 else "-"},
		{"label": "Burgers", "value": "%d of %d" % [_state.burgers, Stages.food_total(_stage)]},
	]


# --------------------------------------------------------------------------
# HUD, settings and layout
# --------------------------------------------------------------------------


func _configure_mode_ui() -> void:
	super()
	_callout.hide()
	# The results card's rules line, once a run is over.
	if _stage.is_empty():
		_round_instructions.text = "Score: metres x %d, plus food and stomps. Every run is a new course." \
			% State.DISTANCE_POINTS
	else:
		_round_instructions.text = "The same course every time. The clock stops at the food truck."
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
		if _controls != null and _auto_run:
			_controls.dismiss_auto_run_hint()
		_layout_view()
	elif key == Options.DAY_NIGHT_KEY:
		_day_night_enabled = Settings.tunable_bool(Options.DAY_NIGHT_KEY)
		if _view != null:
			_view.set_day_night_enabled(_day_night_enabled)
	elif key == "ui/scale":
		_layout_view()


## Park Dolce's decorative motion without changing the run model.
func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_reduced_motion(value)


## Screen shake already respects this through the shell; the view keeps its own
## copy for any game-owned effects.
func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_intense_effects(value)


## The tutorial recorder's caption card covers the bottom of the frame. Like
## the touch buttons, it only lifts the view's ground line clear of it, so
## the clip keeps the full playfield and a readable Dolce.
func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(bottom, 0.0)
	_layout_view()


func _enable_auto_run() -> void:
	Settings.set_value(Options.AUTO_RUN_KEY, true)


## Settings preserves unknown keys on disk, but only loads declared tunables.
## Read this game's onboarding flag without adding a misleading Settings row.
func _has_seen_touch_hint() -> bool:
	var cached: Variant = Settings.get_value(Options.TOUCH_HINT_SEEN_KEY)
	if cached is bool:
		return cached
	var file := ConfigFile.new()
	var status := file.load(Settings.SAVE_PATH)
	if status == ERR_FILE_NOT_FOUND:
		return false
	if status != OK:
		push_warning("Cannot read Dolce's touch tip setting (error %d)." % status)
		return true
	var parts := Options.TOUCH_HINT_SEEN_KEY.split("/", false, 1)
	var seen: Variant = file.get_value(parts[0], parts[1], false)
	if not seen is bool:
		push_warning("Dolce's touch tip setting must be a boolean; leaving it unchanged.")
		return true
	return seen


func _prepare_touch_header() -> void:
	_hud_margins = _hud.get_node("Overlay/Margins") as MarginContainer
	for edge: String in ["left", "top", "right", "bottom"]:
		_normal_margins.append(_hud_margins.get_theme_constant("margin_" + edge))
	_normal_card_minimum = _player_one_card.custom_minimum_size
	var caption := _player_one_card.get_node("Layout/Caption") as Label
	var audio_caption := get_node("%AudioCaption") as PanelContainer
	_normal_caption_horizontal = audio_caption.size_flags_horizontal
	var audio_label := audio_caption.get_node("%CaptionLabel") as Label
	for label: Label in [_player_one_score, _time_label, _mode_title, _time_caption,
			caption, audio_label]:
		_header_fonts[label] = label.get_theme_font_size("font_size")
	for panel: PanelContainer in [_player_one_card, _time_label.get_parent().get_parent(),
			audio_caption]:
		_header_styles[panel] = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat


## On a short phone the two headline cards take two lines, not three, and
## retain readable physical text sizes rather than consuming the whole run.
func _fit_touch_header(readability: float, touch_readability: float) -> void:
	var touch := _controls.visible
	var area := get_viewport_rect().size
	var short := touch and area.x > area.y * 1.15 \
		and area.y * WorldView.physical_scale(self) < 480.0
	var font_scale := touch_readability if short else (readability if touch else 1.0)
	var margin_scale := touch_readability if touch else 1.0
	var layout := Vector3(font_scale, margin_scale, float(short))
	if _header_touch == touch and _header_layout.is_equal_approx(layout):
		return
	_header_touch = touch
	_header_layout = layout
	for label: Label in _header_fonts:
		var font := 18 if label == _mode_title and touch else _header_fonts[label]
		label.add_theme_font_size_override("font_size", roundi(font * font_scale))
	_mode_title.visible = not short
	_player_one_streak.visible = not touch
	_player_one_card.custom_minimum_size = Vector2(150 * font_scale, 0) if touch \
		else _normal_card_minimum
	var audio_caption := get_node("%AudioCaption") as Control
	audio_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL if touch \
		else _normal_caption_horizontal
	for panel: PanelContainer in _header_styles:
		var style := _header_styles[panel].duplicate() as StyleBoxFlat
		if touch:
			style.content_margin_left = 12 * font_scale
			style.content_margin_right = 12 * font_scale
			style.content_margin_top = 8 * font_scale
			style.content_margin_bottom = 8 * font_scale
		panel.add_theme_stylebox_override("panel", style)
	if touch:
		Responsive.set_margins(_hud_margins, roundi(16 * margin_scale),
			roundi(12 * margin_scale), roundi(16 * margin_scale), roundi(12 * margin_scale))
	else:
		Responsive.set_margins(_hud_margins, _normal_margins[0], _normal_margins[1],
			_normal_margins[2], _normal_margins[3])


## A long run's score must fit its card without pushing Pause off a phone.
func _fit_touch_score() -> void:
	if not _controls.visible:
		return
	var font := _player_one_score.get_theme_font("font")
	var font_size := roundi(_header_fonts[_player_one_score] * _header_layout.x)
	var width := font.get_string_size(_player_one_score.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var style := _player_one_card.get_theme_stylebox("panel")
	var available := _player_one_card.custom_minimum_size.x - style.get_minimum_size().x
	font_size = maxi(1, floori(font_size * minf(1.0, available / maxf(width, 1.0))))
	if font_size != _player_one_score.get_theme_font_size("font_size"):
		_player_one_score.add_theme_font_size_override("font_size", font_size)


## Touch has no keyboard footer; use that space while respecting the shared
## header and any active audio caption, including at larger UI scales.
func _playfield_bounds() -> Rect2:
	if _controls == null or not _controls.visible:
		return super()
	var readability := maxf(1.0, 1.0 / maxf(WorldView.physical_scale(self), 0.01) / 1.5)
	var margin := 16.0 * readability
	var area := get_viewport_rect().size
	var time_card := _time_label.get_parent().get_parent() as Control
	var top := maxf(_player_one_card.get_global_rect().end.y,
		maxf(time_card.get_global_rect().end.y, _pause_button.get_global_rect().end.y)) + margin
	var bottom := area.y - margin
	var caption := get_node("%AudioCaption") as Control
	if caption.is_visible_in_tree():
		bottom = minf(bottom, caption.get_global_rect().position.y - margin)
	return Rect2(Vector2(margin, top), Vector2(
		maxf(area.x - margin * 2.0, 0.0), maxf(bottom - top, 0.0)
	))


func _layout_view() -> void:
	if _view == null:
		return
	# Same rule as Cube Trials: grow the controls when the design canvas is
	# shown on far fewer physical pixels, as on a phone.
	var touch_readability := 1.0 / maxf(WorldView.physical_scale(self), 0.01) / 1.5
	var readability := maxf(1.0, touch_readability)
	_pause_button.visible = _controls.visible
	_pause_button.custom_minimum_size = Vector2.ONE * 72.0 * touch_readability
	_pause_button.add_theme_constant_override("icon_max_width", roundi(32 * touch_readability))
	_hint.get_parent().visible = not _controls.visible
	_fit_touch_header(readability, touch_readability)
	if _controls.visible:
		_fit_touch_score()
	if _controls.visible and not _auto_run and not _touch_hint_offered:
		_touch_hint_offered = true
		if not _has_seen_touch_hint():
			_controls.offer_auto_run()
			Settings.set_value(Options.TOUCH_HINT_SEEN_KEY, true)
	var bounds := _playfield_bounds()
	_view.position = bounds.position
	_view.size = bounds.size
	_controls.position = bounds.position
	_controls.fit(bounds.size, touch_readability)
	var under_caption := _capture_inset - (get_viewport_rect().size.y - bounds.end.y)
	_view.bottom_inset = maxf(_controls.covered_height(), under_caption)
	_run_hud.fit(readability)
	_run_hud.position = bounds.position + Vector2.ONE * 12.0 * readability
	_view.top_inset = _run_hud.position.y - bounds.position.y + _run_hud.size.y \
		+ 16.0 * touch_readability
	_view.present(0.0)
