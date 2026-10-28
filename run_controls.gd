extends RefCounted

## Turns keyboard and gamepad state into the run model's inputs (DESIGN §8).
##
## The rebindable actions come from the options file. The arrow keys and the
## gamepad are fixed extras, read here directly as Cube Trials reads its pad,
## so they never appear in Settings. Touch buttons join in Milestone 2.
## Touches no autoload: the gameplay scene passes the seat's gamepad in.

const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")

const STICK_DEADZONE := 0.25
const TRIGGER_THRESHOLD := 0.35


## Held state this frame: `move` -1..1, `run` and `jump` held.
func sample(device: int) -> Dictionary:
	var move := Input.get_action_strength(Options.RIGHT) - Input.get_action_strength(Options.LEFT)
	move += float(Input.is_physical_key_pressed(KEY_RIGHT)) \
		- float(Input.is_physical_key_pressed(KEY_LEFT))
	var run := Input.is_action_pressed(Options.RUN)
	var jump := Input.is_action_pressed(Options.JUMP) or Input.is_physical_key_pressed(KEY_UP)
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
