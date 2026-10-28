extends RefCounted

## Fixed-step platformer body for Dulce, independent of nodes and autoloads.
##
## Every tuning constant sits at the top so the tests, the tunables and the
## chunk validator quote the same numbers (DESIGN §4.1). Units are y-down
## simulation units; one tile is `Grid.TILE` (40) units, one metre.
##
## Milestone 1 is movement only. Hearts, pests, pickups and scoring join the
## same step in Milestone 2.

const Grid = preload("res://games/dulces_adventure/tile_grid.gd")

const STEP := 1.0 / 120.0
const WALK_SPEED := 220.0
const RUN_SPEED := 360.0
const GROUND_ACCEL := 1400.0
const GROUND_DECEL := 1800.0
const AIR_ACCEL := 900.0
const GRAVITY := 2600.0
## Heavier on the way down, so a jump reads as a snappy arc rather than a float.
const FALL_GRAVITY_MULT := 1.6
const JUMP_SPEED := 900.0
## Releasing Jump while rising keeps this much of the upward speed: short hops.
const JUMP_CUT_MULT := 0.45
## Extra take-off speed per 100 u/s of ground speed above `WALK_SPEED`.
const RUN_JUMP_BONUS := 0.08
const MAX_FALL_SPEED := 1500.0
const COYOTE_SECONDS := 0.09
const JUMP_BUFFER_SECONDS := 0.12
## The hit box, a little smaller than the 0.6 m x 0.45 m model, so a graze
## that looks like a miss is one. Narrower than a tile, so one-tile gaps fit.
const BODY_SIZE := Vector2(20.0, 16.0)
## A fall this far below the deepest tile is a pit, not a long drop.
const FALL_MARGIN_TILES := 4

var grid: Grid
## Bottom centre of the body: the point between her paws.
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var grounded := false
## 1 facing right, -1 facing left; the view turns the model from this.
var facing := 1
## Auto-run assist (DESIGN §4.6): always run right, Left only slows down.
var auto_run := false
## Game-speed assist: scales model time, so every jump keeps its shape.
var time_scale := 1.0
## The camera's left edge. It only moves forward (DESIGN §4.7).
var left_limit := -INF
var start_x := 0.0
var furthest_x := 0.0
var elapsed := 0.0
var fell := false

var _accumulator := 0.0
var _coyote_left := 0.0
var _buffer_left := 0.0
var _jump_was_held := false
## True from take-off until the cut has been applied or she starts falling.
var _rising_from_jump := false
var _events: Array[Dictionary] = []


func _init(tiles: Grid = null, start := Vector2.ZERO) -> void:
	grid = tiles if tiles != null else Grid.new()
	place(start)
	start_x = start.x
	furthest_x = start.x


## Puts the body at rest at `point`, as a respawn does.
func place(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	fell = false
	_rising_from_jump = false
	_coyote_left = 0.0
	_buffer_left = 0.0
	grounded = _supported()


## Advances by `delta` real seconds in fixed steps.
##
## `move` is -1..1. `jump_pressed` carries a press that may have been released
## again within the same frame, so a quick tap is never lost between steps.
func advance(
	delta: float, move: float, run: bool, jump_held: bool, jump_pressed := false
) -> void:
	if jump_pressed or (jump_held and not _jump_was_held):
		_buffer_left = JUMP_BUFFER_SECONDS
	_jump_was_held = jump_held
	_accumulator += delta * time_scale
	while _accumulator + 0.0000001 >= STEP and not fell:
		_accumulator -= STEP
		_step(clampf(move, -1.0, 1.0), run, jump_held)


## Moves the camera's left edge forward; it never moves back.
func push_left_limit(x: float) -> void:
	left_limit = maxf(left_limit, x)


func take_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events


func distance_m() -> float:
	return maxf(0.0, furthest_x - start_x) / Grid.TILE


func body_rect() -> Rect2:
	return Rect2(position - Vector2(BODY_SIZE.x * 0.5, BODY_SIZE.y), BODY_SIZE)


func is_running_fast() -> bool:
	return absf(velocity.x) > WALK_SPEED + 1.0


# --------------------------------------------------------------------------
# Jump arithmetic shared with the chunk validator
# --------------------------------------------------------------------------


## Take-off speed for a jump at `ground_speed`: running jumps go higher.
static func jump_speed_at(ground_speed: float) -> float:
	var over := maxf(0.0, absf(ground_speed) - WALK_SPEED)
	return JUMP_SPEED * (1.0 + RUN_JUMP_BONUS * over / 100.0)


## One step of vertical velocity, exactly as the body integrates it.
static func fall_step(vertical_speed: float) -> float:
	var gravity := GRAVITY * (FALL_GRAVITY_MULT if vertical_speed > 0.0 else 1.0)
	return minf(vertical_speed + gravity * STEP, MAX_FALL_SPEED)


## The highest point a full-hold jump reaches above its take-off, in units.
static func jump_height(ground_speed := RUN_SPEED) -> float:
	var vertical := -jump_speed_at(ground_speed)
	var height := 0.0
	var peak := 0.0
	while vertical < 0.0:
		vertical = fall_step(vertical)
		height -= vertical * STEP
		peak = maxf(peak, height)
	return peak


## How far a full-hold jump at a steady `ground_speed` travels before its feet
## come back down through `rise` units above the take-off (negative for a
## landing below it). Returns -1 when the jump never gets that high.
static func jump_reach(ground_speed := RUN_SPEED, rise := 0.0) -> float:
	var vertical := -jump_speed_at(ground_speed)
	var height := 0.0
	var peak := 0.0
	var travelled := 0.0
	# A drop can take seconds; a bounded loop keeps a bad argument from hanging.
	for _tick in 1200:
		vertical = fall_step(vertical)
		height -= vertical * STEP
		peak = maxf(peak, height)
		travelled += absf(ground_speed) * STEP
		if vertical > 0.0 and height <= rise:
			# Feet that never rose above the ledge cannot land on it.
			return travelled if peak >= rise else -1.0
	return -1.0


# --------------------------------------------------------------------------
# The step
# --------------------------------------------------------------------------


func _step(move: float, run: bool, jump_held: bool) -> void:
	elapsed += STEP
	_buffer_left = maxf(0.0, _buffer_left - STEP)
	_coyote_left = COYOTE_SECONDS if grounded else maxf(0.0, _coyote_left - STEP)
	_steer(move, run)
	if _buffer_left > 0.0 and _coyote_left > 0.0:
		_jump()
	if _rising_from_jump and (not jump_held or velocity.y >= 0.0):
		if velocity.y < 0.0:
			velocity.y *= JUMP_CUT_MULT
		_rising_from_jump = false
	velocity.y = fall_step(velocity.y)
	_move_horizontal()
	_move_vertical()
	furthest_x = maxf(furthest_x, position.x)
	if position.y > (grid.bottom_row + 1 + FALL_MARGIN_TILES) * Grid.TILE:
		fell = true
		_events.append({"kind": "fell"})


func _steer(move: float, run: bool) -> void:
	var target := move * (RUN_SPEED if run else WALK_SPEED)
	if auto_run:
		# Left brakes to a walk rather than turning, so one thumb is enough.
		target = WALK_SPEED if move < 0.0 else RUN_SPEED
	if not is_zero_approx(target):
		facing = 1 if target > 0.0 else -1
	if not grounded:
		# Mario-like air control: steer toward the input, but never shed speed
		# just because Run was let go mid-jump.
		if is_zero_approx(move) and not auto_run:
			return
		if signf(target) == signf(velocity.x) and absf(velocity.x) >= absf(target):
			return
		velocity.x = move_toward(velocity.x, target, AIR_ACCEL * STEP)
		return
	var speeding_up := signf(target) == signf(velocity.x) or is_zero_approx(velocity.x)
	speeding_up = speeding_up and absf(target) > absf(velocity.x)
	var rate := GROUND_ACCEL if speeding_up else GROUND_DECEL
	velocity.x = move_toward(velocity.x, target, rate * STEP)


## One jump per ground contact: take-off spends the coyote window and buffer.
func _jump() -> void:
	velocity.y = -jump_speed_at(velocity.x)
	grounded = false
	_coyote_left = 0.0
	_buffer_left = 0.0
	_rising_from_jump = true
	_events.append({"kind": "jump", "speed": -velocity.y})


func _move_horizontal() -> void:
	position.x += velocity.x * STEP
	var half := BODY_SIZE.x * 0.5
	if position.x - half < left_limit:
		position.x = left_limit + half
		velocity.x = maxf(velocity.x, 0.0)
	if is_zero_approx(velocity.x):
		return
	var rect := body_rect()
	var top := floori(rect.position.y / Grid.TILE)
	var bottom := floori((rect.end.y - 0.001) / Grid.TILE)
	if velocity.x > 0.0:
		var column := floori((rect.end.x - 0.001) / Grid.TILE)
		for row in range(top, bottom + 1):
			if grid.is_solid(Vector2i(column, row)):
				position.x = column * Grid.TILE - half
				velocity.x = 0.0
				return
	else:
		var column := floori(rect.position.x / Grid.TILE)
		for row in range(top, bottom + 1):
			if grid.is_solid(Vector2i(column, row)):
				position.x = (column + 1) * Grid.TILE + half
				velocity.x = 0.0
				return


func _move_vertical() -> void:
	var was_grounded := grounded
	var previous_feet := position.y
	position.y += velocity.y * STEP
	var rect := body_rect()
	var left := floori(rect.position.x / Grid.TILE)
	var right := floori((rect.end.x - 0.001) / Grid.TILE)
	grounded = false
	if velocity.y > 0.0:
		var row := floori((position.y - 0.001) / Grid.TILE)
		var surface := row * Grid.TILE
		for column in range(left, right + 1):
			var kind := grid.tile(Vector2i(column, row))
			# A one-way platform only catches feet that were above its top.
			var catches := kind == Grid.SOLID \
				or (kind == Grid.ONE_WAY and previous_feet <= surface + 0.001)
			if catches:
				if not was_grounded:
					_events.append({"kind": "land", "speed": velocity.y})
				position.y = surface
				velocity.y = 0.0
				grounded = true
				return
	elif velocity.y < 0.0:
		var row := floori(rect.position.y / Grid.TILE)
		for column in range(left, right + 1):
			var cell := Vector2i(column, row)
			if grid.is_solid(cell):
				position.y = (row + 1) * Grid.TILE + BODY_SIZE.y
				velocity.y = 0.0
				_rising_from_jump = false
				# Milestone 2 turns a bump on a Lunchbox block into a pickup.
				_events.append({"kind": "bump", "cell": cell})
				return


## Standing on something: a solid tile or a one-way top just under the paws.
func _supported() -> bool:
	if not is_zero_approx(fposmod(position.y, Grid.TILE)):
		return false
	var row := floori(position.y / Grid.TILE)
	var rect := body_rect()
	for column in range(floori(rect.position.x / Grid.TILE),
			floori((rect.end.x - 0.001) / Grid.TILE) + 1):
		if grid.tile(Vector2i(column, row)) != Grid.EMPTY:
			return true
	return false
