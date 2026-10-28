extends RefCounted

## Node-free pest behaviours (DESIGN §4.3).
##
## Each pest is a plain dictionary so the rules stay testable headless and the
## view can read them without owning them. Milestone 2 has the Backyard pair,
## the Grumpy Pigeon and the Garden Gnome; the rest arrive with their biomes.

const Grid = preload("res://games/dulces_adventure/tile_grid.gd")

const PIGEON := "pigeon"
const GNOME := "gnome"

## Sizes are hit boxes in simulation units. Silhouettes, not colours, tell the
## pests apart, so the gnome's pointy hat makes it the tall one.
const PROFILES := {
	PIGEON: {
		"title": "Grumpy Pigeon", "size": Vector2(26.0, 20.0),
		"speed": 45.0, "stompable": true,
	},
	GNOME: {
		"title": "Garden Gnome", "size": Vector2(22.0, 30.0),
		"speed": 0.0, "stompable": false,
	},
}
## Pests wait until Dulce is this close, so a chunk plays as it was authored
## instead of its pigeons wandering off before they are on screen.
const ACTIVE_RANGE := 16.0 * Grid.TILE
const GRAVITY := 2600.0
const MAX_FALL_SPEED := 1500.0
## How long a bonked pest's puff of feathers lingers for the view.
const POOF_SECONDS := 0.4
const FALL_MARGIN_TILES := 4

var list: Array[Dictionary] = []
var _next_id := 0


static func is_known(kind: String) -> bool:
	return PROFILES.has(kind)


## Spawns a pest standing at `feet`, its bottom centre, facing Dulce.
func add(kind: String, feet: Vector2) -> Dictionary:
	var pest := {
		"id": _next_id, "kind": kind, "position": feet, "velocity": Vector2.ZERO,
		"facing": -1, "alive": true, "active": false, "grounded": false, "poof": 0.0,
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


func alive_count() -> int:
	return list.filter(func(pest: Dictionary) -> bool: return pest["alive"]).size()


## Bonked from above: the pest poofs into feathers and is out of the run.
func defeat(pest: Dictionary) -> void:
	pest["alive"] = false
	pest["velocity"] = Vector2.ZERO
	pest["poof"] = POOF_SECONDS


func step(grid: Grid, dulce_x: float, delta: float) -> void:
	for pest in list:
		if not pest["alive"]:
			pest["poof"] = maxf(0.0, float(pest["poof"]) - delta)
			continue
		if not pest["active"]:
			pest["active"] = absf(float(pest["position"].x) - dulce_x) <= ACTIVE_RANGE
		if pest["active"]:
			_move(pest, grid, delta)
	list.assign(list.filter(func(pest: Dictionary) -> bool:
		return pest["alive"] or float(pest["poof"]) > 0.0))


## Frees pests left of `x`, as the stream drops chunks behind the camera.
func clear_before(x: float) -> void:
	list.assign(list.filter(func(pest: Dictionary) -> bool: return pest["position"].x >= x))


func _move(pest: Dictionary, grid: Grid, delta: float) -> void:
	var profile: Dictionary = PROFILES[pest["kind"]]
	var size: Vector2 = profile["size"]
	var speed: float = profile["speed"]
	var feet: Vector2 = pest["position"]
	var velocity: Vector2 = pest["velocity"]
	if speed > 0.0 and pest["grounded"] and _should_turn(pest, grid):
		pest["facing"] = -int(pest["facing"])
	velocity.x = speed * int(pest["facing"])
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	feet.x += velocity.x * delta
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


## A walker turns at a wall or at the edge of whatever it is standing on.
func _should_turn(pest: Dictionary, grid: Grid) -> bool:
	var size: Vector2 = PROFILES[pest["kind"]]["size"]
	var feet: Vector2 = pest["position"]
	var front := feet.x + int(pest["facing"]) * (size.x * 0.5 + 1.0)
	var wall := grid.is_solid(Grid.cell_at(Vector2(front, feet.y - size.y * 0.5)))
	var floor_ahead := grid.tile(Grid.cell_at(Vector2(front, feet.y + 1.0))) != Grid.EMPTY
	return wall or not floor_ahead
