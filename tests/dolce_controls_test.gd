extends SceneTree

## Touch gestures must survive finger handoffs, cancellation and pause without
## inventing a second tap or losing another finger's held input.

const Controls = preload("res://games/dolces_adventure/run_controls.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")

var _failures := PackedStringArray()
var _controls: Controls
var _jumps := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_controls = Controls.new()
	get_root().add_child(_controls)
	_controls.fit(Vector2(1280, 720), 1.0)
	_controls.set_process(false)
	_controls.jump_requested.connect(func() -> void: _jumps += 1)
	_test_independent_fingers()
	_test_sprint_handoff()
	_test_cancel_and_drag()
	_test_pause_and_visibility()
	_test_mouse_handoff()
	_controls.free()
	if _failures.is_empty():
		print("Dolce controls tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_independent_fingers() -> void:
	_controls.clear_input()
	var before := _jumps
	_touch(1, Options.RIGHT, true)
	_touch(2, Options.JUMP, true)
	_expect(_sample()["move"] == 1.0 and _sample()["jump"],
		"Right and Jump can be held by independent fingers.")
	_expect(_jumps == before + 1, "A touch Jump reaches the model exactly once.")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.position = _point(Options.JUMP)
	emulated.global_position = emulated.position
	for pressed: bool in [true, false]:
		emulated.pressed = pressed
		get_root().push_input(emulated, true)
	_expect(_jumps == before + 1, "An emulated mouse twin cannot duplicate a touch Jump.")
	_touch(3, Options.JUMP, true)
	_touch(2, Options.JUMP, false)
	_expect(_sample()["jump"] and _jumps == before + 1,
		"A Jump handoff keeps the hold without inventing another press.")
	_touch(3, Options.JUMP, false)
	_expect(not _sample()["jump"] and _sample()["move"] == 1.0,
		"Releasing Jump leaves Right held.")
	_touch(1, Options.RIGHT, false)


func _test_sprint_handoff() -> void:
	_controls.clear_input()
	_touch(1, Options.RIGHT, true)
	_touch(1, Options.RIGHT, false)
	_controls.call("_process", 0.1)
	_touch(2, Options.RIGHT, true)
	_expect(_sample()["run"], "A real double-tap-and-hold sprints.")
	_controls.call("_process", Controls.DOUBLE_TAP_SECONDS + 0.1)
	_touch(3, Options.RIGHT, true)
	_expect(_sample()["run"], "A second finger cannot cancel a held sprint.")
	_touch(2, Options.RIGHT, false)
	_expect(_sample()["run"] and _sample()["move"] == 1.0,
		"Releasing one Right finger leaves the other sprinting.")
	_touch(3, Options.RIGHT, false)
	_expect(not _sample()["run"] and _sample()["move"] == 0.0,
		"Releasing the last Right finger ends the sprint.")


func _test_cancel_and_drag() -> void:
	_controls.clear_input()
	_touch(1, Options.RIGHT, true)
	_touch(1, Options.RIGHT, false, true)
	_touch(1, Options.RIGHT, true)
	_expect(not _sample()["run"], "A canceled touch is not the first tap of a sprint.")
	_drag(1, Vector2(640, 360))
	_expect(_sample()["move"] == 0.0, "Dragging out releases the movement button.")
	_drag(1, _point(Options.RIGHT))
	_expect(_sample()["move"] == 1.0 and not _sample()["run"],
		"Dragging back in moves but does not count as a double tap.")
	_drag(1, _point(Options.JUMP))
	_expect(_sample()["move"] == 0.0 and _sample()["jump"],
		"Dragging between buttons transfers only that finger's action.")
	_touch(1, Options.JUMP, false)


func _test_pause_and_visibility() -> void:
	_controls.clear_input()
	_touch(1, Options.RIGHT, true)
	_touch(1, Options.RIGHT, false)
	_controls.clear_input()
	_touch(1, Options.RIGHT, true)
	_expect(not _sample()["run"], "Pause clears the old double-tap window too.")
	_controls.hide()
	_expect(_sample()["move"] == 0.0, "Hiding touch controls clears their held fingers.")
	_controls.show()
	_touch(2, Options.JUMP, true)
	_controls.set_enabled(false)
	_expect(not _sample()["jump"], "Disabling the run releases Jump.")
	_controls.set_enabled(true)
	_expect(_sample()["move"] == 0.0 and not _sample()["jump"],
		"Resuming cannot restore an absent finger.")


func _test_mouse_handoff() -> void:
	_controls.clear_input()
	_touch(1, Options.RIGHT, true)
	_touch(1, Options.RIGHT, false)
	_touch(2, Options.RIGHT, true)
	_controls.call("_mouse_down", Options.RIGHT)
	_controls.call("_mouse_up")
	_expect(_sample()["move"] == 1.0 and _sample()["run"],
		"Releasing the mouse cannot release a finger's Right hold or sprint.")
	_touch(2, Options.RIGHT, false)
	_controls.call("_mouse_down", Options.RIGHT)
	var other_button := InputEventMouseButton.new()
	other_button.button_index = MOUSE_BUTTON_RIGHT
	other_button.position = _point(Options.RIGHT)
	get_root().push_input(other_button, true)
	_expect(_sample()["move"] == 1.0, "Another mouse button cannot release the primary hold.")
	_controls.call("_mouse_up")


func _sample() -> Dictionary:
	return _controls.sample(-1)


func _point(action: StringName) -> Vector2:
	return _controls.buttons[action].get_global_rect().get_center()


func _touch(index: int, action: StringName, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _point(action)
	event.pressed = pressed
	event.canceled = canceled
	get_root().push_input(event, true)


func _drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	get_root().push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
