extends RefCounted

## Test-only collision lookahead, not a gameplay assist. Predicts on deep
## copies of the live model, then presses normal actions on the real scene.
## The 54-tile streaming window covers every candidate; no future chunks,
## body placement, extra hearts or removed pests are used to finish a run.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Pests = preload("res://games/dolces_adventure/pests.gd")

const DELTA := 1.0 / 60.0
const LOOKAHEAD_FRAMES := 90
const WALK_FRAMES := 30
const REPLAN_FRAMES := 6
const DELAYS: Array[int] = [0, 3, 6, 9, 12, 18]
const HOLDS: Array[int] = [1, 2, 4, 6, 8, 12, 18, 24]

var _commands: Array[Dictionary] = []
var _state_fields: Array[StringName] = []
var _grid_fields: Array[StringName] = []
var _pest_fields: Array[StringName] = []


func _init() -> void:
	_state_fields = _script_fields(State.new())
	_state_fields.erase(&"grid")
	_state_fields.erase(&"pests")
	_grid_fields = _script_fields(Grid.new())
	_pest_fields = _script_fields(Pests.new())
	release()


func update(state: State) -> bool:
	if state.over:
		release()
		return true
	if _commands.is_empty():
		_commands = _plan(state)
		if _commands.is_empty():
			push_error("No collision-free input plan at %.2f m: position %s, velocity %s." % [
				state.distance_m(), state.position, state.velocity,
			])
			return false
	var input: Dictionary = _commands.pop_front()
	_press(Options.RIGHT, true)
	_press(Options.RUN, input["run"])
	_press(Options.JUMP, input["jump"])
	return true


func release() -> void:
	_commands.clear()
	for action in Options.RUN_ACTIONS:
		Input.action_release(action)


static func _press(action: StringName, held: bool) -> void:
	if held:
		Input.action_press(action)
	else:
		Input.action_release(action)


static func _script_fields(source: Object) -> Array[StringName]:
	var fields: Array[StringName] = []
	for property in source.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property["name"])
	return fields


## Copy private fixed-step/input timers as well as visible state. Sharing an
## items dictionary, pest list or Lunchbox grid would let predictions cheat.
func _copy_model(source: State) -> State:
	var target := State.new()
	_copy_fields(source, target, _state_fields)
	_copy_fields(source.grid, target.grid, _grid_fields)
	_copy_fields(source.pests, target.pests, _pest_fields)
	return target


static func _copy_fields(source: Object, target: Object, fields: Array[StringName]) -> void:
	for name in fields:
		var value: Variant = source.get(name)
		target.set(name, value.duplicate(true) if value is Array or value is Dictionary else value)


func _rollout(source: State, delay: int, hold: int, sprint: bool) -> Dictionary:
	var state := _copy_model(source)
	var commands: Array[Dictionary] = []
	var jumped := false
	for frame in LOOKAHEAD_FRAMES:
		var input := {
			"move": 1.0, "run": sprint,
			"jump": hold > 0 and frame >= delay and frame < delay + hold,
		}
		commands.append(input)
		state.advance(DELTA, input["move"], input["run"], input["jump"])
		for event in state.take_events():
			if event["kind"] == "jump":
				jumped = true
		if state.hits != source.hits or state.over:
			return {"valid": state.cleared, "state": state, "commands": commands}
		if (hold == 0 and frame >= WALK_FRAMES - 1) or (jumped and state.grounded):
			return {"valid": state.grounded, "state": state, "commands": commands}
	return {"valid": false, "state": state, "commands": commands}


func _plan(source: State) -> Array[Dictionary]:
	var walk := _rollout(source, 0, 0, true)
	var walked: State = walk["state"]
	if walk["valid"] and walked.position.x > source.position.x + Grid.TILE:
		var commands: Array[Dictionary] = walk["commands"]
		return commands.slice(0, REPLAN_FRAMES)
	var best: Array[Dictionary] = []
	var best_score := -INF
	for sprint in [true, false]:
		for delay in DELAYS:
			for hold in HOLDS:
				var route := _rollout(source, delay, hold, sprint)
				if not route["valid"]:
					continue
				var target: State = route["state"]
				var score := target.position.x - source.position.x
				if target.cleared:
					score += 100000.0
				if score > best_score:
					best_score = score
					best = route["commands"]
	return best
