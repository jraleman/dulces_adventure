extends SceneTree

## Movement-feel regression checks for `run_state.gd` (DESIGN §4.1, §10).
##
## The model is node-free, so every case builds a tiny tile grid, steps the
## body one fixed step per "frame" and reads the result back. Expected numbers
## are quoted from the model's own constants, never retyped.

const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")

const STEP := State.STEP
const TILE := Grid.TILE
## Every scene stands on row 4, the chunk seam (DESIGN §5.1).
const FLOOR_Y := 4.0 * TILE
const START := Vector2(2.5 * TILE, FLOOR_Y)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rest()
	_test_speeds()
	_test_deceleration()
	_test_full_and_short_jumps()
	_test_running_jump()
	_test_jump_helpers()
	_test_coyote_time()
	_test_jump_buffer()
	_test_no_double_jump()
	_test_fall_cap()
	_test_game_speed()
	_test_one_way_platform()
	_test_wall_and_ceiling()
	_test_left_limit()
	_test_auto_run()
	_test_pit()
	_test_grid()
	_finish()


# --------------------------------------------------------------------------
# Scenes
# --------------------------------------------------------------------------


## A flat floor `width` tiles long, with optional rows painted above it.
func _floor(width := 200, above: Array[String] = []) -> Grid:
	var rows: Array[String] = []
	for line in above:
		rows.append(line)
	while rows.size() < 4:
		rows.append("")
	rows.append("#".repeat(width))
	rows.append("#".repeat(width))
	return Grid.new(rows)


func _body(grid: Grid = null, start := START) -> State:
	return State.new(grid if grid != null else _floor(), start)


## Steps `seconds` of model time, one fixed step per call.
func _hold(state: State, seconds: float, move := 0.0, run := false, jump := false) -> void:
	for _tick in roundi(seconds / STEP):
		state.advance(STEP, move, run, jump)


## Counts the jump events the next `seconds` produce.
func _jumps_during(
	state: State, seconds: float, move := 0.0, run := false, jump := false
) -> int:
	_hold(state, seconds, move, run, jump)
	return _count(state.take_events(), "jump")


func _count(events: Array[Dictionary], kind: String) -> int:
	var total := 0
	for event in events:
		total += int(event["kind"] == kind)
	return total


## Highest the feet get above the floor while `jump` is held for the whole arc,
## or tapped for one frame when `tap` is set.
func _apex(state: State, tap := false, move := 0.0, run := false) -> float:
	var lowest := state.position.y
	state.advance(STEP, move, run, not tap, true)
	for _tick in 600:
		state.advance(STEP, move, run, not tap)
		lowest = minf(lowest, state.position.y)
		if state.grounded:
			break
	return FLOOR_Y - lowest


# --------------------------------------------------------------------------
# Cases
# --------------------------------------------------------------------------


func _test_rest() -> void:
	var state := _body()
	_expect(state.grounded, "A body placed on the floor starts grounded.")
	_hold(state, 1.0)
	_expect(state.grounded and is_equal_approx(state.position.y, FLOOR_Y)
		and state.velocity == Vector2.ZERO,
		"Standing still keeps her on the floor without sinking or drifting.")
	_expect(_count(state.take_events(), "land") == 0, "Standing still is not a landing.")


func _test_speeds() -> void:
	var walker := _body()
	_hold(walker, State.WALK_SPEED / State.GROUND_ACCEL + 0.05, 1.0)
	_expect(is_equal_approx(walker.velocity.x, State.WALK_SPEED),
		"Holding right reaches WALK_SPEED in WALK_SPEED / GROUND_ACCEL seconds.")
	_hold(walker, 1.0, 1.0)
	_expect(is_equal_approx(walker.velocity.x, State.WALK_SPEED), "A walk never exceeds WALK_SPEED.")
	var runner := _body()
	_hold(runner, 1.0, 1.0, true)
	_expect(is_equal_approx(runner.velocity.x, State.RUN_SPEED), "Holding Run reaches RUN_SPEED.")
	_expect(runner.is_running_fast() and not walker.is_running_fast(),
		"The view can tell a sprint from a trot.")
	var left := _body(null, START + Vector2(40 * TILE, 0))
	_hold(left, 1.0, -1.0)
	_expect(is_equal_approx(left.velocity.x, -State.WALK_SPEED) and left.facing == -1,
		"Holding left walks left and turns her round.")


func _test_deceleration() -> void:
	var state := _body()
	_hold(state, 1.0, 1.0, true)
	_hold(state, State.RUN_SPEED / State.GROUND_DECEL + 0.02)
	_expect(is_zero_approx(state.velocity.x),
		"Letting go stops a sprint within RUN_SPEED / GROUND_DECEL seconds.")
	_expect(state.facing == 1, "Stopping keeps her facing the way she ran.")


func _test_full_and_short_jumps() -> void:
	var held := _apex(_body())
	var expected := State.jump_height(0.0)
	_expect(absf(held - expected) < 1.0,
		"A held standing jump peaks at jump_height(0) (%.1f vs %.1f)." % [held, expected])
	# DESIGN §4.1: "~3.9 tiles apex with full hold" is the continuous figure;
	# the 120 Hz integration lands a little under it.
	_expect(held / TILE > 3.7 and held / TILE < 4.0,
		"A held standing jump clears about 3.9 tiles (%.2f)." % (held / TILE))
	var tapped := _apex(_body(), true)
	_expect(tapped > 4.0 and tapped < held * 0.4,
		"A tapped jump is a short hop (%.1f of %.1f units)." % [tapped, held])
	var state := _body()
	_apex(state)
	_expect(_count(state.take_events(), "land") == 1 and state.grounded,
		"Every jump ends in exactly one landing.")


func _test_running_jump() -> void:
	var walker := _body()
	_hold(walker, 1.0, 1.0)
	var runner := _body()
	_hold(runner, 1.0, 1.0, true)
	var walk_take_off := walker.position.x
	var run_take_off := runner.position.x
	var walk_apex := _apex(walker, false, 1.0)
	var run_apex := _apex(runner, false, 1.0, true)
	_expect(run_apex > walk_apex + 10.0, "Running jumps go higher than walking ones.")
	_expect(runner.position.x - run_take_off > walker.position.x - walk_take_off + TILE,
		"Running jumps go more than a tile farther than walking ones.")


## The validator's arithmetic must describe the body it guards.
func _test_jump_helpers() -> void:
	var runner := _body()
	_hold(runner, 1.0, 1.0, true)
	var take_off := runner.position.x
	var apex := _apex(runner, false, 1.0, true)
	var reach := State.jump_reach(State.RUN_SPEED, 0.0)
	var travelled := runner.position.x - take_off
	_expect(absf(apex - State.jump_height(State.RUN_SPEED)) < 1.0,
		"jump_height(RUN_SPEED) matches a real running jump (%.1f vs %.1f)."
		% [State.jump_height(State.RUN_SPEED), apex])
	_expect(absf(travelled - reach) <= State.RUN_SPEED * STEP * 2.0,
		"jump_reach(RUN_SPEED, 0) matches a real running jump (%.1f vs %.1f)."
		% [reach, travelled])
	_expect(State.jump_reach(State.RUN_SPEED, TILE) < reach,
		"Landing a tile higher is a shorter jump.")
	_expect(State.jump_reach(State.RUN_SPEED, -2.0 * TILE) > reach,
		"Landing two tiles lower is a longer jump.")
	_expect(State.jump_reach(State.RUN_SPEED, State.jump_height() + TILE) < 0.0,
		"A ledge above the apex is reported as unreachable.")
	_expect(State.jump_speed_at(State.WALK_SPEED) == State.JUMP_SPEED
		and State.jump_speed_at(-State.RUN_SPEED) == State.jump_speed_at(State.RUN_SPEED),
		"The run bonus starts above WALK_SPEED and ignores direction.")
	print("Measured: running jump %.2f tiles high, %.2f tiles long; standing %.2f high." % [
		State.jump_height() / TILE, reach / TILE, State.jump_height(0.0) / TILE,
	])


## A ledge that ends at column 6, so she walks off it heading right.
func _ledge() -> Grid:
	var rows: Array[String] = ["", "", "", "", "######", "######"]
	return Grid.new(rows)


## Steps right until the feet leave the ledge, so the coyote clock starts at 0.
func _walk_off(state: State) -> void:
	for _tick in 600:
		state.advance(STEP, 1.0, false, false)
		if not state.grounded:
			break
	state.take_events()


func _test_coyote_time() -> void:
	var late := _body(_ledge())
	_walk_off(late)
	_hold(late, State.COYOTE_SECONDS * 0.5, 1.0)
	_expect(_jumps_during(late, STEP, 1.0, false, true) == 1,
		"A jump just after leaving a ledge still takes off (coyote time).")
	var too_late := _body(_ledge())
	_walk_off(too_late)
	_hold(too_late, State.COYOTE_SECONDS + 0.03, 1.0)
	_expect(_jumps_during(too_late, STEP, 1.0, false, true) == 0,
		"A jump well after leaving a ledge does nothing.")


## Drops her from three tiles and returns the steps until she lands.
func _drop() -> State:
	return _body(null, START - Vector2(0, 3.0 * TILE))


func _steps_to_land() -> int:
	var state := _drop()
	for tick in 600:
		state.advance(STEP, 0.0, false, false)
		if state.grounded:
			return tick + 1
	return -1


func _test_jump_buffer() -> void:
	var landing := _steps_to_land()
	_expect(landing > 0, "A body dropped above the floor lands.")
	var early := roundi(State.JUMP_BUFFER_SECONDS * 0.5 / STEP)
	var buffered := _drop()
	_hold(buffered, (landing - early) * STEP)
	_expect(_jumps_during(buffered, 0.2, 0.0, false, true) == 1,
		"Jump pressed just before landing fires on touchdown (jump buffer).")
	var stale := _drop()
	var too_early := roundi((State.JUMP_BUFFER_SECONDS + 0.05) / STEP)
	_hold(stale, (landing - too_early) * STEP)
	stale.advance(STEP, 0.0, false, true, true)
	_expect(_jumps_during(stale, 0.3) == 0,
		"A press long before landing has expired by touchdown.")


func _test_no_double_jump() -> void:
	var state := _body()
	state.advance(STEP, 0.0, false, true, true)
	_hold(state, 0.2, 0.0, false, true)
	state.advance(STEP, 0.0, false, false)
	state.advance(STEP, 0.0, false, true, true)
	_hold(state, 0.05, 0.0, false, true)
	_expect(_count(state.take_events(), "jump") == 1 and not state.grounded,
		"A second press in mid-air never jumps again.")
	var holder := _body()
	_expect(_jumps_during(holder, 2.0, 0.0, false, true) == 1,
		"Holding Jump through a landing does not bounce her straight back up.")


func _test_fall_cap() -> void:
	var state := _body(null, START - Vector2(0, 100.0 * TILE))
	var fastest := 0.0
	for _tick in 600:
		state.advance(STEP, 0.0, false, false)
		fastest = maxf(fastest, state.velocity.y)
		if state.grounded:
			break
	_expect(state.grounded, "A long drop still lands on the floor, without tunnelling.")
	_expect(is_equal_approx(fastest, State.MAX_FALL_SPEED), "Falls are capped at MAX_FALL_SPEED.")


func _test_game_speed() -> void:
	var full := _body()
	var slow := _body()
	slow.time_scale = 0.7
	for _tick in 120:
		full.advance(STEP, 1.0, true, false)
		slow.advance(STEP, 1.0, true, false)
	var full_run := full.position.x - START.x
	var slow_run := slow.position.x - START.x
	_expect(slow_run < full_run * 0.75 and slow_run > full_run * 0.65,
		"Game speed 70%% covers about 70%% of the ground (%.0f of %.0f)." % [slow_run, full_run])
	var slow_jump := _body()
	slow_jump.time_scale = 0.7
	_expect(absf(_apex(slow_jump) - State.jump_height(0.0)) < 1.0,
		"Game speed slows the jump but keeps its height, so every chunk stays fair.")


func _test_one_way_platform() -> void:
	var above: Array[String] = ["", "", "====", ""]
	var state := _body(_floor(200, above), Vector2(1.5 * TILE, FLOOR_Y))
	_expect(state.grounded and is_equal_approx(state.position.y, FLOOR_Y),
		"Standing under a one-way platform is fine.")
	_apex(state)
	_expect(state.grounded and is_equal_approx(state.position.y, 2.0 * TILE),
		"Jumping up through a one-way platform lands on its top.")
	var walker := _body(_floor(200, above), Vector2(0.5 * TILE, FLOOR_Y))
	_hold(walker, 1.0, 1.0)
	_expect(walker.position.x > 5.0 * TILE, "One-way platforms never block a walk underneath.")


func _test_wall_and_ceiling() -> void:
	var wall: Array[String] = ["", "", "", "......##"]
	var state := _body(_floor(200, wall))
	_hold(state, 2.0, 1.0, true)
	var face := 6.0 * TILE - State.BODY_SIZE.x * 0.5
	_expect(is_equal_approx(state.position.x, face) and is_zero_approx(state.velocity.x),
		"Running into a wall stops her flush against it.")
	var roof: Array[String] = ["", "..#", "", ""]
	var bumper := _body(_floor(200, roof))
	bumper.advance(STEP, 0.0, false, true, true)
	_hold(bumper, 0.3, 0.0, false, true)
	var bumps := bumper.take_events().filter(
		func(event: Dictionary) -> bool: return event["kind"] == "bump")
	_expect(bumps.size() == 1 and bumps[0]["cell"] == Vector2i(2, 1),
		"A jump into a solid tile overhead reports which tile she bumped.")
	_expect(bumper.position.y - State.BODY_SIZE.y >= 2.0 * TILE - 0.01,
		"Her head never enters the tile above.")


func _test_left_limit() -> void:
	var state := _body(null, START + Vector2(10 * TILE, 0))
	state.push_left_limit(9.0 * TILE)
	state.push_left_limit(4.0 * TILE)
	_expect(is_equal_approx(state.left_limit, 9.0 * TILE), "The camera edge never moves back.")
	_hold(state, 2.0, -1.0, true)
	_expect(state.body_rect().position.x >= 9.0 * TILE - 0.01,
		"She can walk back to the camera's left edge but no further.")


func _test_auto_run() -> void:
	var state := _body()
	state.auto_run = true
	_hold(state, 1.0)
	_expect(is_equal_approx(state.velocity.x, State.RUN_SPEED),
		"Auto-run sprints right with no input at all.")
	_hold(state, 1.0, -1.0)
	_expect(is_equal_approx(state.velocity.x, State.WALK_SPEED) and state.facing == 1,
		"With Auto-run, Left slows her to a walk instead of turning.")


func _test_pit() -> void:
	var rows: Array[String] = ["", "", "", "", "####...####", "####...####"]
	var state := _body(Grid.new(rows), Vector2(1.5 * TILE, FLOOR_Y))
	for _tick in 600:
		state.advance(STEP, 1.0, false, false)
		if state.pits > 0:
			break
	_expect(state.pits == 1 and _count(state.take_events(), "respawn") == 1,
		"Walking into a pit reports one fall and one respawn.")
	_expect(state.grounded and state.position == Vector2(1.5 * TILE, FLOOR_Y),
		"With no safe ground passed, a pit sends her back to the start, at rest.")
	# She ran from 1.5 tiles to past the pit's edge at 4 before dropping.
	_expect(is_equal_approx(state.distance_m(), (state.furthest_x - 1.5 * TILE) / TILE)
		and state.distance_m() > 4.0 - 1.5,
		"Distance is the furthest point from the start, in metres, kept through a respawn.")
	state.place(Vector2(9.5 * TILE, FLOOR_Y))
	_expect(state.grounded and state.velocity == Vector2.ZERO,
		"place() puts her at rest on the floor.")


func _test_grid() -> void:
	var grid := _floor(10)
	_expect(grid.bottom_row == 5, "The grid tracks its deepest row.")
	_expect(grid.tile(Vector2i(3, 4)) == Grid.SOLID and grid.tile(Vector2i(3, 3)) == Grid.EMPTY,
		"Painted rows become solid tiles; everything else is air.")
	grid.clear_before(5)
	_expect(grid.tile(Vector2i(4, 4)) == Grid.EMPTY and grid.is_solid(Vector2i(5, 4))
		and grid.size() == 10, "clear_before frees columns behind the camera only.")
	_expect(Grid.cell_at(Vector2(-1, 41)) == Vector2i(-1, 1), "cell_at floors negative points.")


# --------------------------------------------------------------------------


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dolce physics tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
