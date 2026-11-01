extends RefCounted

## Node-free pest behaviours (DESIGN §4.3).
##
## Each pest is a plain dictionary so the rules stay testable headless and the
## view can read them without owning them. Every pest is readable by its
## silhouette, not its colour: the wide low pigeon, the tall pointed gnome,
## the bushy-tailed squirrel, the flat robo-vac, the winged seagull and the
## upright hot-sauce bottle. Sauce drops are pests too, so they share the
## collision path, but they cannot be stomped.

const Grid = preload("res://games/dolces_adventure/tile_grid.gd")

const PIGEON := "pigeon"
const GNOME := "gnome"
const SQUIRREL := "squirrel"
const ROBO_VAC := "robo_vac"
const SEAGULL := "seagull"
const HOT_SAUCE := "hot_sauce"
const SAUCE_DROP := "sauce_drop"

## How a stomped pest leaves: a puff of feathers, a scurry off-screen or a
## popped lid. Robo-vacs never leave; a stomp flips them.
const POOF := "poof"
const SCURRY := "scurry"
const POP := "pop"
const SPLAT := "splat"

## Hit boxes in simulation units, plus each pest's walking speed.
const PROFILES := {
	PIGEON: {"title": "Grumpy Pigeon", "size": Vector2(26.0, 20.0), "speed": 45.0,
		"stompable": true, "exit": POOF},
	GNOME: {"title": "Garden Gnome", "size": Vector2(22.0, 30.0), "speed": 0.0,
		"stompable": false, "exit": POOF},
	SQUIRREL: {"title": "Squirrel", "size": Vector2(22.0, 18.0), "speed": 160.0,
		"stompable": true, "exit": SCURRY},
	ROBO_VAC: {"title": "Robo-Vac", "size": Vector2(36.0, 14.0), "speed": 30.0,
		"stompable": true, "exit": POOF},
	SEAGULL: {"title": "Seagull", "size": Vector2(30.0, 16.0), "speed": 60.0,
		"stompable": true, "exit": POOF, "flies": true},
	HOT_SAUCE: {"title": "Hot-Sauce Bottle", "size": Vector2(18.0, 28.0), "speed": 0.0,
		"stompable": true, "exit": POP},
	SAUCE_DROP: {"title": "Sauce drop", "size": Vector2(10.0, 10.0), "speed": 0.0,
		"stompable": false, "exit": SPLAT, "projectile": true},
}
## Pests wait until Dolce is this close, so a chunk plays as it was authored
## instead of its pigeons wandering off before they are on screen.
const ACTIVE_RANGE := 16.0 * Grid.TILE
const GRAVITY := 2600.0
const MAX_FALL_SPEED := 1500.0
## How long a bonked pest's puff of feathers lingers for the view.
const POOF_SECONDS := 0.4
const FALL_MARGIN_TILES := 4

## A squirrel charges when she is this close, and hops gaps up to this wide.
const SQUIRREL_SIGHT := 6.0 * Grid.TILE
const SQUIRREL_HOP_TILES := 2
const SQUIRREL_HOP_SPEED := 650.0
## A hop is a leap: faster forward than the run, so it clears two tiles.
const SQUIRREL_LEAP_SPEED := 240.0
## A kicked robo-vac slides at this speed, flipped ones right themselves.
const VAC_SLIDE_SPEED := 420.0
const VAC_RECOVER_SECONDS := 6.0
## After a kick, the vac cannot hurt the dog that kicked it for this long.
const VAC_KICK_GRACE := 0.3
## Seagulls patrol this far either side of home, and swoop on her from above.
const GULL_PATROL := 3.0 * Grid.TILE
const GULL_SWOOP_RANGE := 1.5 * Grid.TILE
const GULL_SWOOP_SPEED := 320.0
const GULL_RISE_SPEED := 200.0
## A swoop never reaches lower than this far above the ground under it, and
## never more than `GULL_DIVE_LIMIT` below the gull's home.
const GULL_CLEARANCE := 8.0
const GULL_DIVE_LIMIT := 4.0 * Grid.TILE
## The bottle hops in place, and spits at her when she is within range.
const SAUCE_HOP_SECONDS := 1.6
const SAUCE_HOP_SPEED := 380.0
const SAUCE_SPIT_SECONDS := 2.5
const SAUCE_RANGE := 8.0 * Grid.TILE
const DROP_GRAVITY := 900.0
const DROP_LAUNCH := 330.0
const DROP_MAX_SPEED := 200.0
const DROP_LIFETIME := 4.0

var list: Array[Dictionary] = []
var _next_id := 0
var _events: Array[Dictionary] = []


static func is_known(kind: String) -> bool:
	return PROFILES.has(kind)


static func flies(kind: String) -> bool:
	return bool(PROFILES.get(kind, {}).get("flies", false))


## Spawns a pest at `feet`, its bottom centre, facing Dolce.
func add(kind: String, feet: Vector2) -> Dictionary:
	var pest := {
		"id": _next_id, "kind": kind, "position": feet, "home": feet,
		"velocity": Vector2.ZERO, "facing": -1, "alive": true, "active": false,
		"grounded": false, "poof": 0.0, "exit": "", "state": "walk", "timer": 0.0,
		"spit_timer": SAUCE_SPIT_SECONDS * 0.5, "grace": 0.0,
	}
	_next_id += 1
	list.append(pest)
	return pest


static func rect(pest: Dictionary) -> Rect2:
	var size: Vector2 = PROFILES[pest["kind"]]["size"]
	var feet: Vector2 = pest["position"]
	return Rect2(feet - Vector2(size.x * 0.5, size.y), size)


static func stompable(pest: Dictionary) -> bool:
	return bool(PROFILES[pest["kind"]]["stompable"])


## Pests Dolce can count: projectiles are not pests to stomp or to tally.
func alive_count() -> int:
	return list.filter(func(pest: Dictionary) -> bool:
		return pest["alive"] and not PROFILES[pest["kind"]].get("projectile", false)).size()


func take_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events


## Out of the run, leaving the way its kind leaves.
func defeat(pest: Dictionary, exit := "") -> void:
	pest["alive"] = false
	pest["velocity"] = Vector2.ZERO
	pest["exit"] = exit if not exit.is_empty() else str(PROFILES[pest["kind"]]["exit"])
	pest["poof"] = POOF_SECONDS


## A stomp: a robo-vac flips onto its back, anything else is defeated.
## Returns true when the pest is out of the run.
func stomp(pest: Dictionary) -> bool:
	if pest["kind"] == ROBO_VAC:
		pest["state"] = "flipped"
		pest["timer"] = VAC_RECOVER_SECONDS
		pest["velocity"] = Vector2.ZERO
		return false
	defeat(pest)
	return true


## Sends a flipped robo-vac sliding away from Dolce, along `direction`.
func kick(pest: Dictionary, direction: int) -> void:
	pest["state"] = "sliding"
	pest["facing"] = 1 if direction >= 0 else -1
	pest["grace"] = VAC_KICK_GRACE


func is_harmless(pest: Dictionary) -> bool:
	return pest["kind"] == ROBO_VAC and (pest["state"] == "flipped" or float(pest["grace"]) > 0.0)


func step(grid: Grid, dolce: Vector2, delta: float) -> void:
	for pest in list.duplicate():
		if not pest["alive"]:
			pest["poof"] = maxf(0.0, float(pest["poof"]) - delta)
			continue
		if not pest["active"]:
			pest["active"] = absf(float(pest["position"].x) - dolce.x) <= ACTIVE_RANGE \
				or PROFILES[pest["kind"]].get("projectile", false)
		if not pest["active"]:
			continue
		match str(pest["kind"]):
			SQUIRREL:
				_squirrel(pest, grid, dolce)
			ROBO_VAC:
				_vac(pest, delta)
			SEAGULL:
				_seagull(pest, grid, dolce, delta)
				continue
			HOT_SAUCE:
				_sauce(pest, dolce, delta)
			SAUCE_DROP:
				_drop(pest, grid, delta)
				continue
			_:
				if float(PROFILES[pest["kind"]]["speed"]) > 0.0 and pest["grounded"] \
						and _should_turn(pest, grid):
					pest["facing"] = -int(pest["facing"])
				_set_velocity(pest, float(PROFILES[pest["kind"]]["speed"]) * int(pest["facing"]), NAN)
		_walk(pest, grid, delta)
		if pest["kind"] == ROBO_VAC and pest["state"] == "sliding":
			_bonk_others(pest)
	list.assign(list.filter(func(pest: Dictionary) -> bool:
		return pest["alive"] or float(pest["poof"]) > 0.0))


## Frees pests left of `x`, as the stream drops chunks behind the camera.
func clear_before(x: float) -> void:
	list.assign(list.filter(func(pest: Dictionary) -> bool: return pest["position"].x >= x))


# --------------------------------------------------------------------------
# Behaviours
# --------------------------------------------------------------------------


## Waits facing her, then charges once she is close, hopping small gaps and
## stopping at the edge of a wide one.
func _squirrel(pest: Dictionary, grid: Grid, dolce: Vector2) -> void:
	var feet: Vector2 = pest["position"]
	var toward := 1 if dolce.x > feet.x else -1
	if pest["state"] == "walk":
		pest["facing"] = toward
		_set_velocity(pest, 0.0, NAN)
		if absf(dolce.x - feet.x) <= SQUIRREL_SIGHT and absf(dolce.y - feet.y) <= 2.0 * Grid.TILE:
			pest["state"] = "charge"
		return
	if not pest["grounded"]:
		return
	pest["facing"] = toward
	var speed: float = PROFILES[SQUIRREL]["speed"]
	_set_velocity(pest, speed * toward, NAN)
	if _wall_ahead(pest, grid):
		_set_velocity(pest, 0.0, NAN)
	elif not _floor_ahead(pest, grid, 0):
		if _landing_within(pest, grid, SQUIRREL_HOP_TILES):
			_set_velocity(pest, SQUIRREL_LEAP_SPEED * toward, -SQUIRREL_HOP_SPEED)
			pest["grounded"] = false
		else:
			_set_velocity(pest, 0.0, NAN)


func _vac(pest: Dictionary, delta: float) -> void:
	pest["grace"] = maxf(0.0, float(pest["grace"]) - delta)
	match str(pest["state"]):
		"flipped":
			_set_velocity(pest, 0.0, NAN)
			pest["timer"] = float(pest["timer"]) - delta
			if float(pest["timer"]) <= 0.0:
				pest["state"] = "walk"
		"sliding":
			_set_velocity(pest, VAC_SLIDE_SPEED * int(pest["facing"]), NAN)
		_:
			_set_velocity(pest, float(PROFILES[ROBO_VAC]["speed"]) * int(pest["facing"]), NAN)


## Patrols around home on a gentle bob, swoops when she passes underneath,
## then climbs back. Never dives into the ground or far below home.
func _seagull(pest: Dictionary, grid: Grid, dolce: Vector2, delta: float) -> void:
	var feet: Vector2 = pest["position"]
	var home: Vector2 = pest["home"]
	pest["timer"] = float(pest["timer"]) + delta
	match str(pest["state"]):
		"swoop":
			var target: Vector2 = pest["target"]
			feet = feet.move_toward(target, GULL_SWOOP_SPEED * delta)
			if feet.distance_to(target) < 1.0 or float(pest["timer"]) > 0.9:
				pest["state"] = "rise"
		"rise":
			feet.y = move_toward(feet.y, home.y, GULL_RISE_SPEED * delta)
			if is_equal_approx(feet.y, home.y):
				pest["state"] = "walk"
				pest["timer"] = 0.0
		_:
			var speed: float = PROFILES[SEAGULL]["speed"]
			feet.x += speed * int(pest["facing"]) * delta
			if absf(feet.x - home.x) > GULL_PATROL:
				pest["facing"] = 1 if feet.x < home.x else -1
			feet.y = home.y + sin(float(pest["timer"]) * 3.0) * 6.0
			if absf(dolce.x - feet.x) < GULL_SWOOP_RANGE and dolce.y > feet.y + Grid.TILE:
				var lowest := minf(_ground_below(grid, Vector2(dolce.x, feet.y)) - GULL_CLEARANCE,
					home.y + GULL_DIVE_LIMIT)
				pest["target"] = Vector2(dolce.x, minf(dolce.y - 6.0, lowest))
				pest["state"] = "swoop"
				pest["timer"] = 0.0
				pest["facing"] = 1 if dolce.x > feet.x else -1
	pest["position"] = feet


## Hops in place on a timer, and spits a slow drop in an arc toward her.
func _sauce(pest: Dictionary, dolce: Vector2, delta: float) -> void:
	_set_velocity(pest, 0.0, NAN)
	var feet: Vector2 = pest["position"]
	pest["facing"] = 1 if dolce.x > feet.x else -1
	pest["timer"] = float(pest["timer"]) + delta
	if pest["grounded"] and float(pest["timer"]) >= SAUCE_HOP_SECONDS:
		pest["timer"] = 0.0
		_set_velocity(pest, NAN, -SAUCE_HOP_SPEED)
		pest["grounded"] = false
	pest["spit_timer"] = float(pest["spit_timer"]) - delta
	if float(pest["spit_timer"]) <= 0.0 and absf(dolce.x - feet.x) <= SAUCE_RANGE:
		pest["spit_timer"] = SAUCE_SPIT_SECONDS
		var mouth := feet - Vector2(0.0, PROFILES[HOT_SAUCE]["size"].y + 2.0)
		var drop := add(SAUCE_DROP, mouth)
		drop["active"] = true
		drop["velocity"] = Vector2(clampf((dolce.x - feet.x) * 0.6, -DROP_MAX_SPEED, DROP_MAX_SPEED),
			-DROP_LAUNCH)
		_events.append({"kind": "spit", "position": mouth})


func _drop(pest: Dictionary, grid: Grid, delta: float) -> void:
	pest["timer"] = float(pest["timer"]) + delta
	var velocity: Vector2 = pest["velocity"]
	velocity.y = minf(velocity.y + DROP_GRAVITY * delta, MAX_FALL_SPEED)
	pest["velocity"] = velocity
	var feet: Vector2 = pest["position"] + velocity * delta
	pest["position"] = feet
	if grid.tile(Grid.cell_at(feet)) != Grid.EMPTY or float(pest["timer"]) > DROP_LIFETIME \
			or feet.y > (grid.bottom_row + 1 + FALL_MARGIN_TILES) * Grid.TILE:
		defeat(pest, SPLAT)


## A sliding robo-vac bonks every other pest it runs into.
func _bonk_others(vac: Dictionary) -> void:
	var sweep := rect(vac)
	for other in list:
		if other == vac or not other["alive"] or other["kind"] == SAUCE_DROP:
			continue
		if sweep.intersects(rect(other)):
			defeat(other)
			_events.append({"kind": "bonk", "pest": other["kind"], "position": other["position"]})


# --------------------------------------------------------------------------
# Walking
# --------------------------------------------------------------------------


func _walk(pest: Dictionary, grid: Grid, delta: float) -> void:
	var size: Vector2 = PROFILES[pest["kind"]]["size"]
	var feet: Vector2 = pest["position"]
	var velocity: Vector2 = pest["velocity"]
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	feet.x += velocity.x * delta
	if velocity.x != 0.0 and _blocked(grid, feet, size):
		feet.x -= velocity.x * delta
		if pest["kind"] == ROBO_VAC and pest["state"] == "sliding":
			pest["facing"] = -int(pest["facing"])
		velocity.x = 0.0
	var previous_feet := feet.y
	feet.y += velocity.y * delta
	pest["grounded"] = false
	if velocity.y > 0.0:
		var row := floori((feet.y - 0.001) / Grid.TILE)
		var surface := row * Grid.TILE
		var left := floori((feet.x - size.x * 0.5) / Grid.TILE)
		var right := floori((feet.x + size.x * 0.5 - 0.001) / Grid.TILE)
		for column in range(left, right + 1):
			var kind := grid.tile(Vector2i(column, row))
			if grid.is_solid(Vector2i(column, row)) \
				or (kind == Grid.ONE_WAY and previous_feet <= surface + 0.001):
				feet.y = surface
				velocity.y = 0.0
				pest["grounded"] = true
				break
	pest["position"] = feet
	pest["velocity"] = velocity
	if feet.y > (grid.bottom_row + 1 + FALL_MARGIN_TILES) * Grid.TILE:
		pest["alive"] = false
		pest["poof"] = 0.0


## Sets one or both velocity axes; NAN leaves that axis as it is.
static func _set_velocity(pest: Dictionary, x: float, y: float) -> void:
	var velocity: Vector2 = pest["velocity"]
	if not is_nan(x):
		velocity.x = x
	if not is_nan(y):
		velocity.y = y
	pest["velocity"] = velocity


static func _blocked(grid: Grid, feet: Vector2, size: Vector2) -> bool:
	var box := Rect2(feet - Vector2(size.x * 0.5, size.y), size)
	for column in range(floori(box.position.x / Grid.TILE), floori((box.end.x - 0.001) / Grid.TILE) + 1):
		for row in range(floori(box.position.y / Grid.TILE), floori((box.end.y - 0.001) / Grid.TILE) + 1):
			if grid.is_solid(Vector2i(column, row)):
				return true
	return false


## A walker turns at a wall or at the edge of whatever it is standing on.
func _should_turn(pest: Dictionary, grid: Grid) -> bool:
	return _wall_ahead(pest, grid) or not _floor_ahead(pest, grid, 0)


func _wall_ahead(pest: Dictionary, grid: Grid) -> bool:
	var size: Vector2 = PROFILES[pest["kind"]]["size"]
	var feet: Vector2 = pest["position"]
	var front := feet.x + int(pest["facing"]) * (size.x * 0.5 + 1.0)
	return grid.is_solid(Grid.cell_at(Vector2(front, feet.y - size.y * 0.5)))


## Floor under the point `tiles_out` tiles beyond the pest's leading edge.
func _floor_ahead(pest: Dictionary, grid: Grid, tiles_out: int) -> bool:
	var size: Vector2 = PROFILES[pest["kind"]]["size"]
	var feet: Vector2 = pest["position"]
	var front := feet.x + int(pest["facing"]) * (size.x * 0.5 + 1.0 + tiles_out * Grid.TILE)
	return grid.tile(Grid.cell_at(Vector2(front, feet.y + 1.0))) != Grid.EMPTY


func _landing_within(pest: Dictionary, grid: Grid, tiles: int) -> bool:
	for out in range(1, tiles + 1):
		if _floor_ahead(pest, grid, out):
			return true
	return false


static func _ground_below(grid: Grid, point: Vector2) -> float:
	var column := floori(point.x / Grid.TILE)
	for row in range(floori(point.y / Grid.TILE) + 1, grid.bottom_row + 1):
		if grid.tile(Vector2i(column, row)) != Grid.EMPTY:
			return row * Grid.TILE
	return INF
