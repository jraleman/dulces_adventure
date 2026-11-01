extends Control

## Turns keyboard, gamepad and touch into the run model's inputs (DESIGN §8).
##
## The rebindable actions come from the options file. The arrow keys and the
## gamepad are fixed extras, read here directly as Cube Trials reads its pad,
## so they never appear in Settings. Touch is a strip of icon buttons: ◀ and ▶
## under the left thumb, a big Jump under the right, and a double-tap-and-hold
## on ▶ to run. Each finger owns one button, so holding ▶ and tapping Jump work
## together. Touches no autoload: the gameplay scene passes the seat's pad in.

signal jump_requested
signal auto_run_requested
signal layout_changed

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const LEFT_ICON = preload("res://games/dolces_adventure/assets/icons/left.svg")
const RIGHT_ICON = preload("res://games/dolces_adventure/assets/icons/right.svg")
const JUMP_ICON = preload("res://games/dolces_adventure/assets/icons/jump.svg")

const STICK_DEADZONE := 0.25
const TRIGGER_THRESHOLD := 0.35
## A second ▶ press this soon after the last one runs while it is held.
const DOUBLE_TAP_SECONDS := 0.3
## Touch targets, in design pixels before the readability scale: well over the
## 44 physical-pixel minimum on every phone the shell supports.
const BUTTON_SIZE := Vector2(104, 92)
const JUMP_SIZE := Vector2(150, 112)
const EDGE_MARGIN := 16.0

const TITLES := {
	Options.LEFT: "Move left", Options.RIGHT: "Move right (tap twice and hold to run)",
	Options.JUMP: "Jump (hold for a high jump)",
}

var buttons: Dictionary[StringName, Button] = {}
var _touches: Dictionary[int, StringName] = {}
var _tap_touches: Dictionary[int, StringName] = {}
var _mouse_action: StringName = &""
var _mouse_tap := false
var _enabled := true
var _touch_run := false
var _last_right_release := -INF
var _clock := 0.0
var _auto_run_hint: PanelContainer
var _hint_label: Label
var _auto_run_button: Button
var _dismiss_button: Button
var _hint_on_top := false


func _ready() -> void:
	name = "RunControls"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for action: StringName in [Options.LEFT, Options.RIGHT, Options.JUMP]:
		var button := Button.new()
		button.name = str(action).trim_prefix("dolces_adventure_").capitalize()
		button.icon = {Options.LEFT: LEFT_ICON, Options.RIGHT: RIGHT_ICON,
			Options.JUMP: JUMP_ICON}[action]
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = TITLES[action]
		button.accessibility_name = TITLES[action]
		button.modulate = Color(1, 1, 1, 0.82)
		button.button_down.connect(_mouse_down.bind(action))
		button.button_up.connect(_mouse_up)
		add_child(button)
		buttons[action] = button
	_build_auto_run_hint()
	fit(Vector2(1280, 720), 1.0)


func _build_auto_run_hint() -> void:
	_auto_run_hint = PanelContainer.new()
	_auto_run_hint.name = "AutoRunHint"
	_auto_run_hint.accessibility_description = (
		"Auto-run moves Dolce right for you. Left brakes; Jump still works normally."
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Art.INK, 0.9)
	style.set_corner_radius_all(10)
	_auto_run_hint.add_theme_stylebox_override("panel", style)
	add_child(_auto_run_hint)
	var row := HBoxContainer.new()
	_auto_run_hint.add_child(row)
	_hint_label = Label.new()
	_hint_label.text = "One thumb?"
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Art.CREAM)
	row.add_child(_hint_label)
	_auto_run_button = Button.new()
	_auto_run_button.text = "Auto-run"
	_auto_run_button.accessibility_name = "Enable Auto-run"
	_auto_run_button.tooltip_text = _auto_run_hint.accessibility_description
	_auto_run_button.pressed.connect(_request_auto_run)
	row.add_child(_auto_run_button)
	_dismiss_button = Button.new()
	_dismiss_button.text = "Not now"
	_dismiss_button.accessibility_name = "Dismiss Auto-run tip"
	_dismiss_button.pressed.connect(dismiss_auto_run_hint)
	row.add_child(_dismiss_button)
	_auto_run_hint.hide()
	_auto_run_hint.visibility_changed.connect(layout_changed.emit)


## The gameplay scene owns the saved preference; this view only offers it.
func offer_auto_run() -> void:
	_auto_run_hint.show()


## Starting to play or dismissing the tip leaves all held inputs intact.
func dismiss_auto_run_hint() -> void:
	_auto_run_hint.hide()


func _request_auto_run() -> void:
	dismiss_auto_run_hint()
	auto_run_requested.emit()


## Lays the buttons along the bottom edge of `area` (this control's own rect).
func fit(area: Vector2, readability: float) -> void:
	size = area
	var margin := EDGE_MARGIN * readability
	var small := BUTTON_SIZE * readability
	var jump := JUMP_SIZE * readability
	buttons[Options.LEFT].size = small
	buttons[Options.LEFT].position = Vector2(margin, area.y - small.y - margin)
	buttons[Options.RIGHT].size = small
	buttons[Options.RIGHT].position = Vector2(margin * 2.0 + small.x, area.y - small.y - margin)
	buttons[Options.JUMP].size = jump
	buttons[Options.JUMP].position = area - jump - Vector2.ONE * margin
	for button: Button in buttons.values():
		button.add_theme_constant_override("icon_max_width", roundi(button.size.y * 0.5))
	for label: Control in [_hint_label, _auto_run_button, _dismiss_button]:
		label.add_theme_font_size_override("font_size", roundi(20 * readability))
	for button: Button in [_auto_run_button, _dismiss_button]:
		button.custom_minimum_size = Vector2(100, 68) * readability
	var style := _auto_run_hint.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = 8 * readability
	style.content_margin_right = 8 * readability
	style.content_margin_top = 6 * readability
	style.content_margin_bottom = 6 * readability
	_auto_run_hint.reset_size()
	_hint_on_top = area.x > area.y * 1.4 and area.x >= 700 * readability
	if _hint_on_top:
		_auto_run_hint.position = Vector2(area.x - _auto_run_hint.size.x - margin, margin)
	else:
		_auto_run_hint.position = Vector2(
			(area.x - _auto_run_hint.size.x) * 0.5,
			area.y - jump.y - margin - _auto_run_hint.size.y - 8 * readability
		)


## How much of the frame's bottom the buttons cover, so a view can keep the
## ground line clear of them.
func covered_height() -> float:
	if not visible:
		return 0.0
	var top := buttons[Options.JUMP].position.y
	if _auto_run_hint.visible and not _hint_on_top:
		top = minf(top, _auto_run_hint.position.y)
	return size.y - top


## Held state this frame: `move` -1..1, `run` and `jump` held.
func sample(device: int) -> Dictionary:
	var move := Input.get_action_strength(Options.RIGHT) - Input.get_action_strength(Options.LEFT)
	move += float(Input.is_physical_key_pressed(KEY_RIGHT)) \
		- float(Input.is_physical_key_pressed(KEY_LEFT))
	move += _touch_strength(Options.RIGHT) - _touch_strength(Options.LEFT)
	var run := Input.is_action_pressed(Options.RUN) or (_touch_run and _touch_strength(Options.RIGHT) > 0.0)
	var jump := Input.is_action_pressed(Options.JUMP) or Input.is_physical_key_pressed(KEY_UP) \
		or _touch_strength(Options.JUMP) > 0.0
	if device >= 0:
		var stick := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if absf(stick) > STICK_DEADZONE:
			move += stick
		move += float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) \
			- float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
		run = run or Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
			or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_THRESHOLD
		jump = jump or Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	return {"move": clampf(move, -1.0, 1.0), "run": run, "jump": jump}


## A fresh Jump press, so a tap shorter than one frame still reaches the model.
func is_jump_press(event: InputEvent, device: int) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(Options.JUMP):
		return true
	if event is InputEventKey:
		return event.pressed and (event as InputEventKey).physical_keycode == KEY_UP
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == JOY_BUTTON_A and button.device == device
	return false


## Events the run owns, so they are marked handled and never reach a menu.
func owns(event: InputEvent) -> bool:
	for action in Options.RUN_ACTIONS:
		if event.is_action(action):
			return true
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP]
	return false


## A paused or finished run cannot keep running on an absent finger.
func clear_input() -> void:
	_touches.clear()
	_tap_touches.clear()
	_mouse_action = &""
	_mouse_tap = false
	_touch_run = false
	_last_right_release = -INF
	_sync_buttons()


func set_enabled(value: bool) -> void:
	_enabled = value
	clear_input()
	for button: Button in buttons.values():
		button.disabled = not value
	if not value:
		dismiss_auto_run_hint()


func _process(delta: float) -> void:
	_clock += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
		or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		clear_input()


func _input(event: InputEvent) -> void:
	if not _enabled or not is_visible_in_tree():
		return
	# The touch itself is handled below; its emulated mouse twin must not
	# press the button a second time.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) \
		and event.device == InputEvent.DEVICE_ID_EMULATION \
		and (_action_at(event.position) != &"" or not _touches.is_empty()):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_up(not event.canceled and _action_at(event.position) == _mouse_action)
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			var action := _action_at(event.position)
			if action == &"":
				return
			var held := _touch_strength(action) > 0.0
			_touches[event.index] = action
			if not held:
				_tap_touches[event.index] = action
				_pressed(action)
		elif _touches.has(event.index):
			var action := _touches[event.index]
			var tapped: bool = not event.canceled and _tap_touches.get(event.index, &"") == action \
				and _action_at(event.position) == action
			_touches.erase(event.index)
			_tap_touches.erase(event.index)
			if action != &"" and _touch_strength(action) == 0.0:
				_released(action, tapped)
		else:
			return
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var action := _action_at(event.position)
		var previous := _touches[event.index]
		if action != previous:
			var held := _touch_strength(action) > 0.0
			_touches[event.index] = action
			_tap_touches.erase(event.index)
			if previous != &"" and _touch_strength(previous) == 0.0:
				_released(previous, false)
			if action != &"" and not held:
				_pressed(action, false)
	else:
		return
	_sync_buttons()
	get_viewport().set_input_as_handled()


func _pressed(action: StringName, tapped := true) -> void:
	dismiss_auto_run_hint()
	if action == Options.JUMP:
		jump_requested.emit()
	elif action == Options.RIGHT:
		_touch_run = tapped and _clock - _last_right_release <= DOUBLE_TAP_SECONDS


func _released(action: StringName, tapped := true) -> void:
	if action == Options.RIGHT:
		_last_right_release = _clock if tapped else -INF
		_touch_run = false


func _touch_strength(action: StringName) -> float:
	return 1.0 if _enabled and (_mouse_action == action or _touches.values().has(action)) else 0.0


func _action_at(point: Vector2) -> StringName:
	for action: StringName in buttons:
		if buttons[action].get_global_rect().has_point(point):
			return action
	return &""


func _mouse_down(action: StringName) -> void:
	if _enabled:
		var held := _touch_strength(action) > 0.0
		_mouse_action = action
		_mouse_tap = not held
		if not held:
			_pressed(action)


func _mouse_up(tapped := true) -> void:
	var action := _mouse_action
	_mouse_action = &""
	if action != &"" and _touch_strength(action) == 0.0:
		_released(action, tapped and _mouse_tap)
	_mouse_tap = false
	_sync_buttons()


func _sync_buttons() -> void:
	for action: StringName in buttons:
		buttons[action].set_pressed_no_signal(_touch_strength(action) > 0.0)
