extends RefCounted

## Fixed-step platformer body and run rules for Dulce, independent of nodes
## and autoloads.
##
## Every tuning constant sits at the top so the tests, the tunables and the
## chunk validator quote the same numbers (DESIGN §4). Units are y-down
## simulation units; one tile is `Grid.TILE` (40) units, one metre.

const Grid = preload("res://games/dulces_adventure/tile_grid.gd")
const Pests = preload("res://games/dulces_adventure/pests.gd")

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
## Bounce off a stomped pest; holding Jump bounces higher.
const STOMP_BOUNCE_SPEED := 620.0
const STOMP_BOUNCE_HELD_SPEED := 980.0
## Feet this far below a pest's top on the previous step still count as from
## above, so a stomp on a pest that is stepping up a little is not a hit.
const STOMP_TOLERANCE := 6.0
const INVULNERABLE_SECONDS := 1.5
## A hit pops her up a little, so it reads even with intense effects off.
const HIT_HOP_SPEED := 420.0
## The flustered tumble between the last heart and the results.
const TUMBLE_SECONDS := 1.2
## The hit box, a little smaller than the 0.6 m x 0.45 m model, so a graze
## that looks like a miss is one. Narrower than a tile, so one-tile gaps fit.
const BODY_SIZE := Vector2(20.0, 16.0)
## A fall this far below the deepest tile is a pit, not a long drop.
const FALL_MARGIN_TILES := 4

const STARTING_HEARTS := 3
const MAX_HEARTS := 3
const BURGERS_PER_HEART := 100

## Scoring (DESIGN §4.5): distance is the headline, food and stomps on top.
const DISTANCE_POINTS := 10
const BURGER_POINTS := 100
const BIG_BURGER_POINTS := 500
const BIG_BURGER_FULL_POINTS := 1000
const GOLDEN_BONE_POINTS := 1000
## Paid by the hundredth burger instead of a heart she has no room for.
const HEART_CAPPED_POINTS := 1000
## Stomps chained without touching the ground; the last value repeats.
const STOMP_CHAIN_POINTS: Array[int] = [200, 400, 800, 1600]

const BURGER := "burger"
const BIG_BURGER := "big_burger"
const GOLDEN_BONE := "golden_bone"
## The pickup's hit box, centred in its tile.
const PICKUP_SIZE := 24.0

var grid: Grid
var pests := Pests.new()
## Bottom centre of the body: the point between her paws.
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var grounded := false
## 1 facing right, -1 facing left; the view turns the model from this.
var facing := 1
## Auto-run assist (DESIGN §4.6): always run right, Left only slows down.
var auto_run := false
## Kind pits assist (DESIGN §4.2): a fall while Full costs Full, not a heart.
var kind_pits := false
## Game-speed assist: scales model time, so every jump keeps its shape.
var time_scale := 1.0
## The camera's left edge. It only moves forward (DESIGN §4.7).
var left_limit := -INF
var start_x := 0.0
var furthest_x := 0.0
var elapsed := 0.0

var hearts := STARTING_HEARTS
## Full after a Big Burger: one hit costs this instead of a heart.
var full := false
var invulnerable_left := 0.0
## The last heart is gone and the tumble has started.
var over := false
var tumble_left := 0.0
var burgers := 0
var stomps := 0
var chain := 0
var best_chain := 0
var item_points := 0
var stomp_points := 0
## Times anything cost her Full or a heart: pest touches and pits alike.
var hits := 0
var pits := 0
## The longest stretch, in metres, run without a hit (Not a Scratch).
var best_clean_m := 0.0

## Food waiting in the world, by tile: `BURGER`, `BIG_BURGER` or `GOLDEN_BONE`.
var items: Dictionary[Vector2i, String] = {}
## What each unopened Lunchbox holds.
var lunchboxes: Dictionary[Vector2i, String] = {}
## Respawn points, sorted by x; a pit sends her to the last one passed.
var safe_points: Array[Vector2] = []
var safe_point := Vector2.ZERO

var _accumulator := 0.0
var _coyote_left := 0.0
var _buffer_left := 0.0
var _jump_was_held := false
## True from take-off until the cut has been applied or she starts falling.
var _rising_from_jump := false
var _next_safe := 0
var _clean_from_x := 0.0
var _events: Array[Dictionary] = []


func _init(tiles: Grid = null, start := Vector2.ZERO) -> void:
	grid = tiles if tiles != null else Grid.new()
	place(start)
	start_x = start.x
	furthest_x = start.x
	safe_point = start
	_clean_from_x = start.x


## Adds a built stretch of course (see `chunk_library.gd`): its food, its
## Lunchboxes, its pests and its safe ground. The tiles are already painted.
func add_course(course: Dictionary) -> void:
	for cell: Vector2i in course.get("items", {}):
		items[cell] = course["items"][cell]
	for cell: Vector2i in course.get("lunchboxes", {}):
		lunchboxes[cell] = course["lunchboxes"][cell]
	for spawn: Dictionary in course.get("pests", []):
		pests.add(spawn["kind"], spawn["feet"])
	for point: Vector2 in course.get("safe_points", []):
		safe_points.append(point)
	safe_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	while _next_safe < safe_points.size() and safe_points[_next_safe].x <= furthest_x:
		_next_safe += 1


## Drops everything left of `column`, as the stream frees chunks behind the
## camera. The safe ground she would respawn on is always kept.
func forget_before(column: int) -> void:
	for cell: Vector2i in items.keys():
		if cell.x < column:
			items.erase(cell)
	for cell: Vector2i in lunchboxes.keys():
		if cell.x < column:
			lunchboxes.erase(cell)
	pests.clear_before(column * Grid.TILE)
	while _next_safe > 1 and safe_points[0].x < column * Grid.TILE:
		safe_points.remove_at(0)
		_next_safe -= 1


## Puts the body at rest at `point`, as a respawn does.
func place(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	chain = 0
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
	while _accumulator + 0.0000001 >= STEP and not run_finished():
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


func score() -> int:
	return floori(distance_m()) * DISTANCE_POINTS + item_points + stomp_points


## Burgers eaten plus burgers she has run past and left behind, in the open or
## in an unopened Lunchbox: the honest denominator for "collected".
func burgers_passed() -> int:
	var passed := burgers
	for cell: Vector2i in items:
		passed += int(items[cell] == BURGER and (cell.x + 1) * Grid.TILE <= furthest_x)
	for cell: Vector2i in lunchboxes:
		passed += int(lunchboxes[cell] == BURGER and (cell.x + 1) * Grid.TILE <= furthest_x)
	return passed


## The tumble has played out; the run is ready for its results.
func run_finished() -> bool:
	return over and tumble_left <= 0.0


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


func body_rect() -> Rect2:
	return Rect2(position - Vector2(BODY_SIZE.x * 0.5, BODY_SIZE.y), BODY_SIZE)


func is_running_fast() -> bool:
	return absf(velocity.x) > WALK_SPEED + 1.0


static func pickup_rect(cell: Vector2i) -> Rect2:
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * Grid.TILE
	return Rect2(centre - Vector2.ONE * PICKUP_SIZE * 0.5, Vector2.ONE * PICKUP_SIZE)


## Points for the `n`th stomp of a chain (1-based).
static func stomp_chain_points(n: int) -> int:
	return STOMP_CHAIN_POINTS[clampi(n, 1, STOMP_CHAIN_POINTS.size()) - 1]


# --------------------------------------------------------------------------
# Jump arithmetic shared with the chunk validator
# --------------------------------------------------------------------------


## Take-off speed for a jump at `ground_speed`: running jumps go higher.
static func jump_speed_at(ground_speed: float) -> float:
	var extra := maxf(0.0, absf(ground_speed) - WALK_SPEED)
	return JUMP_SPEED * (1.0 + RUN_JUMP_BONUS * extra / 100.0)


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
	if over:
		tumble_left = maxf(0.0, tumble_left - STEP)
		return
	invulnerable_left = maxf(0.0, invulnerable_left - STEP)
	var previous_feet := position.y
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
	if grounded:
		chain = 0
	_collect_items()
	pests.step(grid, position.x, STEP)
	_touch_pests(jump_held, previous_feet)
	if over:
		return
	furthest_x = maxf(furthest_x, position.x)
	best_clean_m = maxf(best_clean_m, (furthest_x - _clean_from_x) / Grid.TILE)
	while _next_safe < safe_points.size() and position.x >= safe_points[_next_safe].x:
		safe_point = safe_points[_next_safe]
		_next_safe += 1
	if position.y > (grid.bottom_row + 1 + FALL_MARGIN_TILES) * Grid.TILE:
		_fall_in_pit()


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
			var cell := Vector2i(column, row)
			# A one-way platform only catches feet that were above its top.
			var catches := grid.is_solid(cell) \
				or (grid.tile(cell) == Grid.ONE_WAY and previous_feet <= surface + 0.001)
			if catches:
				if not was_grounded:
					_events.append({"kind": "land", "speed": velocity.y})
				position.y = surface
				velocity.y = 0.0
				grounded = true
				return
	elif velocity.y < 0.0:
		var row := floori(rect.position.y / Grid.TILE)
		# Straddling two blocks, the one under her middle is the one she bumps.
		var columns := range(left, right + 1)
		columns.sort_custom(func(a: int, b: int) -> bool:
			return absf((a + 0.5) * Grid.TILE - position.x) \
				< absf((b + 0.5) * Grid.TILE - position.x))
		for column: int in columns:
			var cell := Vector2i(column, row)
			if grid.is_solid(cell):
				position.y = (row + 1) * Grid.TILE + BODY_SIZE.y
				velocity.y = 0.0
				_rising_from_jump = false
				_events.append({"kind": "bump", "cell": cell})
				if grid.tile(cell) == Grid.LUNCHBOX:
					_open_lunchbox(cell)
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


# --------------------------------------------------------------------------
# Rules
# --------------------------------------------------------------------------


## A burger goes straight into Dulce; a Big Burger pops out on top of the box.
func _open_lunchbox(cell: Vector2i) -> void:
	var content: String = lunchboxes.get(cell, BURGER)
	lunchboxes.erase(cell)
	grid.set_tile(cell, Grid.EMPTY_BOX)
	_events.append({"kind": "lunchbox", "cell": cell, "content": content})
	if content == BURGER:
		_eat(BURGER, cell)
	else:
		items[cell + Vector2i.UP] = content


func _collect_items() -> void:
	var rect := body_rect()
	for column in range(floori(rect.position.x / Grid.TILE),
			floori((rect.end.x - 0.001) / Grid.TILE) + 1):
		for row in range(floori(rect.position.y / Grid.TILE),
				floori((rect.end.y - 0.001) / Grid.TILE) + 1):
			var cell := Vector2i(column, row)
			if items.has(cell) and rect.intersects(pickup_rect(cell)):
				var kind: String = items[cell]
				items.erase(cell)
				_eat(kind, cell)


func _eat(kind: String, cell: Vector2i) -> void:
	match kind:
		BURGER:
			burgers += 1
			item_points += BURGER_POINTS
			_events.append({"kind": "eat", "item": kind, "cell": cell, "points": BURGER_POINTS})
			if burgers % BURGERS_PER_HEART == 0:
				_gain_heart("burgers", HEART_CAPPED_POINTS)
		BIG_BURGER:
			var points := BIG_BURGER_FULL_POINTS if full else BIG_BURGER_POINTS
			item_points += points
			var was_full := full
			full = true
			_events.append({"kind": "eat", "item": kind, "cell": cell, "points": points})
			if not was_full:
				_events.append({"kind": "full"})
		GOLDEN_BONE:
			item_points += GOLDEN_BONE_POINTS
			_events.append({
				"kind": "eat", "item": kind, "cell": cell, "points": GOLDEN_BONE_POINTS,
			})
			_gain_heart("golden_bone", 0)


func _gain_heart(source: String, capped_points: int) -> void:
	if hearts < MAX_HEARTS:
		hearts += 1
		_events.append({"kind": "heart", "source": source})
	elif capped_points > 0:
		item_points += capped_points
		_events.append({"kind": "heart_capped", "source": source, "points": capped_points})


## From above with downward speed is a stomp; anything else is a hit.
func _touch_pests(jump_held: bool, previous_feet: float) -> void:
	var rect := body_rect()
	for pest in pests.list:
		if over:
			return
		if not pest["alive"]:
			continue
		var target := Pests.rect(pest)
		if not rect.intersects(target):
			continue
		var from_above := velocity.y > 0.0 \
			and previous_feet <= target.position.y + STOMP_TOLERANCE
		if from_above and Pests.stompable(pest):
			_stomp(pest, jump_held, target)
			rect = body_rect()
		elif not is_invulnerable():
			_hit(str(pest["kind"]))
			rect = body_rect()


func _stomp(pest: Dictionary, jump_held: bool, target: Rect2) -> void:
	pests.defeat(pest)
	chain += 1
	best_chain = maxi(best_chain, chain)
	stomps += 1
	var points := stomp_chain_points(chain)
	stomp_points += points
	position.y = minf(position.y, target.position.y)
	velocity.y = -(STOMP_BOUNCE_HELD_SPEED if jump_held else STOMP_BOUNCE_SPEED)
	grounded = false
	_coyote_left = 0.0
	# A held bounce behaves like a held jump: let go early to cut it short.
	_rising_from_jump = jump_held
	_events.append({
		"kind": "stomp", "pest": pest["kind"], "chain": chain, "points": points,
	})


## Full soaks one hit; otherwise a heart goes. Either way, i-frames.
func _hit(cause: String) -> void:
	hits += 1
	_clean_from_x = furthest_x
	if full:
		full = false
		_events.append({"kind": "shrink", "cause": cause})
	else:
		hearts -= 1
		_events.append({"kind": "hurt", "cause": cause, "hearts": hearts})
	invulnerable_left = INVULNERABLE_SECONDS
	velocity.y = -HIT_HOP_SPEED
	grounded = false
	_rising_from_jump = false
	if hearts <= 0:
		_end_run()


## A pit costs a heart even when Full, and the Full state with it, unless
## Kind pits lets Full pay instead. She respawns on the last safe ground.
func _fall_in_pit() -> void:
	pits += 1
	hits += 1
	_clean_from_x = furthest_x
	if kind_pits and full:
		full = false
		_events.append({"kind": "shrink", "cause": "pit"})
	else:
		full = false
		hearts -= 1
		_events.append({"kind": "hurt", "cause": "pit", "hearts": hearts})
	if hearts <= 0:
		_end_run()
		return
	place(safe_point)
	invulnerable_left = INVULNERABLE_SECONDS
	_events.append({"kind": "respawn", "point": safe_point})


func _end_run() -> void:
	hearts = 0
	over = true
	tumble_left = TUMBLE_SECONDS
	invulnerable_left = 0.0
	_events.append({"kind": "run_over"})
