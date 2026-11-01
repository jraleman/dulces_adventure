extends SceneTree

## Real rendered layouts, not a headless projection proxy: Dolce must change
## visible pixels, stay clear of the HUD, and leave every touch target usable.
## Snapshots protect every file the gameplay scene could write.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const View = preload("res://games/dolces_adventure/world_view.gd")
const Controls = preload("res://games/dolces_adventure/run_controls.gd")

const WINDOWS := {
	"desktop": Vector2i(1280, 720),
	"small portrait phone": Vector2i(320, 568),
	"portrait phone": Vector2i(390, 844),
	"small landscape phone": Vector2i(568, 320),
	"landscape phone": Vector2i(844, 390),
	"tablet": Vector2i(768, 1024),
	"ultrawide": Vector2i(3440, 1440),
}
const SAVES: Array[String] = [
	"user://settings.cfg", "user://store.cfg", "user://achievements.cfg", Options.SAVE_PATH,
]
const CAPTURE_ARGUMENT := "--dolce-view-captures="
const MIN_TOUCH_TARGET := 44.0

var _failures := PackedStringArray()
var _snapshots := {}
var _settings: Node
var _original_values: Dictionary
var _game: Node
var _view: View
var _controls: Controls
var _state: State
var _capture_directory := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Dolce view tests need a real window; omit --headless.")
		quit(1)
		return
	_settings = get_root().get_node("Settings")
	_original_values = _settings.get("_values").duplicate(true)
	for path in SAVES:
		_snapshots[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARGUMENT):
			_capture_directory = argument.trim_prefix(CAPTURE_ARGUMENT)
			_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
				"Cannot create the requested capture directory.")
	_settings.call("set_value", "ui/scale", 1.0)
	_settings.call("set_value", "accessibility/reduced_motion", true)
	_settings.call("set_value", "accessibility/visual_effects", false)
	_settings.call("set_value", "accessibility/audio_captions", true)
	_settings.call("set_value", Options.AUTO_RUN_KEY, false)
	_settings.call("set_value", Options.TOUCH_HINT_SEEN_KEY, false)
	get_root().mode = Window.MODE_WINDOWED
	await _resize(WINDOWS["desktop"])
	GameCatalog.select(Options.GAME_ID)
	var session := get_root().get_node("GameSession")
	session.call("configure_single_player")
	session.call("set_level", Options.START_BACKYARD)
	var packed := load("res://games/dolces_adventure/gameplay.tscn") as PackedScene
	_game = packed.instantiate()
	_game.set_script(load("res://games/dolces_adventure/tests/playthrough_gameplay.gd"))
	get_root().add_child(_game)
	for _frame in 240:
		await process_frame
		if bool(_game.get("_round_active")):
			break
	_expect(bool(_game.get("_round_active")), "The real gameplay scene starts.")
	_game.set("_round_active", false)
	_view = _game.get("_view") as View
	_controls = _game.get("_controls") as Controls
	_state = _game.get("_state") as State
	_state.velocity = Vector2.ZERO
	_state.grounded = true
	(_game.get_node("%PlayerOneScore") as Label).text = "9999999"
	(_game.get_node("%TimeLabel") as Label).text = "9999 m"
	var previous_left := _view.left_edge()
	for title: String in WINDOWS:
		await _resize(WINDOWS[title])
		_controls.visible = title != "desktop" and title != "ultrawide"
		if title == "small landscape phone":
			_controls.offer_auto_run()
		await _settle()
		_view.present(0.0)
		await _settle()
		_expect(_view.left_edge() >= previous_left - 0.01,
			"%s: resizing cannot scroll the camera backward." % title)
		previous_left = _view.left_edge()
		_check_layout(title)
		await _check_rendered_dolce(title)
		_capture(title)
		if _controls.get_node("AutoRunHint").visible:
			(_controls.get("_dismiss_button") as Button).pressed.emit()
			await _settle()
	_state.full = true
	_state.burgers = 10000
	_game.call("_sync_hud")
	_settings.call("set_value", "ui/scale", 1.4)
	await _resize(WINDOWS["small landscape phone"])
	_controls.show()
	get_root().get_node("AudioManager").call("request_caption",
		"Full: the next hit costs Full, not a heart.")
	await _settle()
	_view.present(0.0)
	await _settle()
	_check_layout("large UI with Full and audio caption")
	_capture("large UI with Full and audio caption")
	_settings.call("set_value", "accessibility/reduced_motion", false)
	_state.grounded = false
	for velocity: float in [-600.0, 600.0]:
		_state.position.y = 20.0
		_state.velocity.y = velocity
		_view.present(0.0)
		await _settle()
		var body := _body_rect()
		_expect(_view.get_global_rect().grow(1.0).encloses(body),
			"Jump and fall stay on screen with large UI (velocity %.0f)." % velocity)
		_check_layout("large UI airborne %.0f" % velocity)
	await _check_daily_layouts()
	_game.queue_free()
	await process_frame
	_restore()
	if _failures.is_empty():
		print("Dolce view tests passed (portrait, landscape, tablet, ultrawide and large UI).")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _check_daily_layouts() -> void:
	_settings.call("set_value", "ui/scale", 1.0)
	_settings.call("set_value", "accessibility/reduced_motion", true)
	get_root().get_node("GameSession").call("set_level", Options.DAILY)
	_game.call("_start_round")
	_game.set("_round_active", false)
	_state = _game.get("_state") as State
	for title: String in ["desktop", "small portrait phone", "small landscape phone"]:
		await _resize(WINDOWS[title])
		_controls.visible = title != "desktop"
		await _settle()
		_view.present(0.0)
		await _settle()
		_check_layout("Daily UTC " + title)
		var label := _game.get_node("%TimeCaption") as Label
		_expect(label.text == "2026-11-01 UTC" and label.is_visible_in_tree(),
			"%s: the captured daily date remains visible, including on a short phone." % title)
		var width := label.get_theme_font("font").get_string_size(label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		_expect(width <= label.size.x + 1.0,
			"%s: the full daily date fits its HUD label without clipping." % title)
		_expect(label.get_theme_font_size("font_size") * View.physical_scale(_game) >= 13.5,
			"%s: the daily date retains at least 14 physical pixels of readable text." % title)
		_capture("Daily UTC " + title)


func _check_layout(title: String) -> void:
	var screen := Rect2(Vector2.ZERO, get_root().get_visible_rect().size).grow(1.0)
	var frame := _view.get_global_rect()
	var body := _body_rect()
	var physical := View.physical_scale(_game)
	_expect(screen.encloses(frame), "%s: the playfield fits on screen." % title)
	_expect(frame.grow(1.0).encloses(body), "%s: all of Dolce fits in the playfield." % title)
	_expect(body.size.x * physical >= 12.0 and body.size.y * physical >= 8.0,
		"%s: Dolce is too small to read (%.1f x %.1f physical pixels)." % [
			title, body.size.x * physical, body.size.y * physical,
		])
	var hud := _game.get("_run_hud") as Control
	_expect(screen.encloses(hud.get_global_rect()), "%s: all run counters fit." % title)
	_expect(not body.intersects(hud.get_global_rect()), "%s: the counters do not cover Dolce." % title)
	for label_name: String in ["%PlayerOneScore", "%TimeLabel"]:
		var card := _game.get_node(label_name).get_parent().get_parent() as Control
		_expect(screen.encloses(card.get_global_rect()),
			"%s: the shared %s card fits on screen (%s)." % [title, card.name, card.get_global_rect()])
		_expect(not body.intersects(card.get_global_rect()),
			"%s: the shared %s card cannot cover Dolce." % [title, card.name])
		_expect(not hud.get_global_rect().intersects(card.get_global_rect()),
			"%s: the run counters cannot overlap the shared %s card." % [title, card.name])
	var hint_panel := _game.get_node("%Hint").get_parent() as Control
	_expect(hint_panel.visible != _controls.visible,
		"%s: keyboard hints give way to touch icons." % title)
	if not _controls.visible:
		return
	_expect((_game.get_node("%PlayerOneScore") as Label).get_theme_font_size("font_size") \
		* physical >= 18.0, "%s: a long score must remain readable." % title)
	var ground := frame.position + _view.project_point(_state.position)
	var targets: Array[Control] = []
	for button: Button in _controls.buttons.values():
		targets.append(button)
		_expect(button.get_global_rect().position.y > ground.y,
			"%s: %s must be below the ground line." % [title, button.name])
	var tip := _controls.get_node("AutoRunHint") as Control
	if tip.visible:
		_expect(not tip.get_global_rect().intersects(body),
			"%s: the Auto-run tip cannot cover Dolce." % title)
		_expect(not tip.get_global_rect().intersects(hud.get_global_rect()),
			"%s: the Auto-run tip cannot cover the counters." % title)
		if not bool(_controls.get("_hint_on_top")):
			_expect(tip.get_global_rect().position.y > ground.y,
				"%s: a bottom tip must not cover the ground line." % title)
		targets.append(_controls.get("_auto_run_button"))
		targets.append(_controls.get("_dismiss_button"))
	var pause_button := _game.get_node("%PauseButton") as Button
	targets.append(pause_button)
	var caption := _game.get_node("%AudioCaption") as Control
	if caption.is_visible_in_tree():
		var caption_label := caption.get_node("%CaptionLabel") as Label
		_expect(screen.encloses(caption.get_global_rect()),
			"%s: the audio caption fits on screen." % title)
		_expect(caption_label.get_theme_font_size("font_size") * physical >= 14.0,
			"%s: audio captions retain readable physical text." % title)
		_expect(not body.intersects(caption.get_global_rect()),
			"%s: an audio caption cannot cover Dolce." % title)
	for index in targets.size():
		var target := targets[index]
		var rect := target.get_global_rect()
		_expect(screen.encloses(rect), "%s: %s is on screen (%s in %s)." % [
			title, target.name, rect, screen,
		])
		_expect(minf(rect.size.x, rect.size.y) * physical >= MIN_TOUCH_TARGET - 0.5,
			"%s: %s is smaller than 44 physical pixels." % [title, target.name])
		_expect(not target.accessibility_name.is_empty() or not target.tooltip_text.is_empty(),
			"%s: %s has an accessible name." % [title, target.name])
		_expect(not body.intersects(rect), "%s: %s cannot cover Dolce." % [title, target.name])
		if caption.is_visible_in_tree():
			_expect(not rect.intersects(caption.get_global_rect()),
				"%s: an audio caption cannot cover %s." % [title, target.name])
		for other in range(index + 1, targets.size()):
			_expect(not rect.intersects(targets[other].get_global_rect()),
				"%s: touch targets cannot overlap." % title)


## Comparing the same frozen scene with Dolce hidden proves she contributes
## actual rendered pixels instead of merely projecting an occluded bounding box.
func _check_rendered_dolce(title: String) -> void:
	await RenderingServer.frame_post_draw
	var visible_image := _view.world_viewport.get_texture().get_image()
	_view.dolce.hide()
	await RenderingServer.frame_post_draw
	var hidden_image := _view.world_viewport.get_texture().get_image()
	_view.dolce.show()
	await RenderingServer.frame_post_draw
	var changed := 0
	var factor := Vector2(visible_image.get_size()) / _view.size
	var rect := _body_rect()
	var first := Vector2i((rect.position - _view.global_position) * factor)
	var last := Vector2i((rect.end - _view.global_position) * factor)
	for y in range(maxi(first.y, 0), mini(last.y + 1, visible_image.get_height())):
		for x in range(maxi(first.x, 0), mini(last.x + 1, visible_image.get_width())):
			var before := visible_image.get_pixel(x, y)
			var after := hidden_image.get_pixel(x, y)
			if Vector3(before.r, before.g, before.b).distance_to(
				Vector3(after.r, after.g, after.b)) > 0.06:
				changed += 1
	_expect(changed >= 20, "%s: Dolce must draw visible pixels (%d)." % [title, changed])


func _body_rect() -> Rect2:
	var rect := Rect2()
	var first := true
	for node in _view.dolce.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var bounds := mesh.mesh.get_aabb()
		for corner in 8:
			var point := mesh.global_transform * bounds.get_endpoint(corner)
			var pixel := _view.world_camera.unproject_position(point) \
				* _view.size / Vector2(_view.world_viewport.size) + _view.global_position
			rect = Rect2(pixel, Vector2.ZERO) if first else rect.expand(pixel)
			first = false
	return rect


func _resize(window_size: Vector2i) -> void:
	get_root().size = window_size
	await _settle()


func _settle() -> void:
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(title: String) -> void:
	if _capture_directory.is_empty():
		return
	var image := get_root().get_texture().get_image()
	var path := _capture_directory.path_join(title.to_snake_case() + ".png")
	_expect(image.save_png(path) == OK, "Cannot save layout capture: %s." % path)


func _restore() -> void:
	(_settings.get("_save_timer") as Timer).stop()
	_settings.set("_values", _original_values)
	for path: String in _snapshots:
		var bytes: Variant = _snapshots[path]
		if bytes == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
