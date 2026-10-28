extends SceneTree

## Pest-behaviour regression checks for `pests.gd` (DESIGN §4.3, §10).
##
## Pests are plain dictionaries stepped against a tile grid, so each case
## builds a strip of ground, steps the pests alone and reads them back.

const Pests = preload("res://games/dulces_adventure/pests.gd")
const Grid = preload("res://games/dulces_adventure/tile_grid.gd")

const STEP := 1.0 / 120.0
const TILE := Grid.TILE
const FLOOR_Y := 4.0 * TILE

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pigeon_turns_at_edges()
	_test_pigeon_turns_at_walls()
	_test_pigeon_on_platform()
	_test_gnome_stands_still()
	_test_activation_range()
	_test_defeat_and_poof()
	_test_falls_out_of_the_world()
	_test_clear_before()
	_test_profiles()
	_finish()


func _grid(rows: Array[String]) -> Grid:
	return Grid.new(rows)


## Steps every pest for `seconds`, with Dulce standing at `dulce_x`.
func _step(pests: Pests, grid: Grid, seconds: float, dulce_x := 0.0) -> void:
	for _tick in roundi(seconds / STEP):
		pests.step(grid, dulce_x, STEP)


## A pigeon on a six-tile island patrols it and never walks off.
func _test_pigeon_turns_at_edges() -> void:
	var rows: Array[String] = ["", "", "", "", "...######...", "...######..."]
	var grid := _grid(rows)
	var pests := Pests.new()
	var pigeon := pests.add(Pests.PIGEON, Vector2(6.5 * TILE, FLOOR_Y))
	var lowest := INF
	var highest := -INF
	var turns := 0
	var facing: int = pigeon["facing"]
	for _tick in roundi(12.0 / STEP):
		pests.step(grid, 6.5 * TILE, STEP)
		lowest = minf(lowest, pigeon["position"].x)
		highest = maxf(highest, pigeon["position"].x)
		if pigeon["facing"] != facing:
			turns += 1
			facing = pigeon["facing"]
	var half: float = Pests.PROFILES[Pests.PIGEON]["size"].x * 0.5
	_expect(pigeon["alive"] and pigeon["grounded"], "A patrolling pigeon stays on its island.")
	_expect(lowest - half >= 3.0 * TILE - 2.0 and highest + half <= 9.0 * TILE + 2.0,
		"It turns at both edges instead of walking off (%.0f..%.0f)." % [lowest, highest])
	_expect(turns >= 2, "Twelve seconds of patrol turns it round at least twice.")
	_expect(highest - lowest > 3.0 * TILE, "It actually walks most of the island.")


func _test_pigeon_turns_at_walls() -> void:
	var rows: Array[String] = ["", "", "", "..#.....", "########", "########"]
	var grid := _grid(rows)
	var pests := Pests.new()
	var pigeon := pests.add(Pests.PIGEON, Vector2(5.5 * TILE, FLOOR_Y))
	_step(pests, grid, 3.0, 5.5 * TILE)
	_expect(pigeon["facing"] == 1, "Walking into a wall turns a pigeon round.")
	var half: float = Pests.PROFILES[Pests.PIGEON]["size"].x * 0.5
	_expect(pigeon["position"].x - half >= 3.0 * TILE - 1.0, "It never walks into the wall.")


func _test_pigeon_on_platform() -> void:
	var rows: Array[String] = ["", "", "...====", "", "########", "########"]
	var grid := _grid(rows)
	var pests := Pests.new()
	var pigeon := pests.add(Pests.PIGEON, Vector2(5.0 * TILE, 2.0 * TILE))
	_step(pests, grid, 8.0, 5.0 * TILE)
	_expect(pigeon["grounded"] and is_equal_approx(pigeon["position"].y, 2.0 * TILE),
		"A pigeon on a one-way platform patrols the platform, not the floor below.")


func _test_gnome_stands_still() -> void:
	var rows: Array[String] = ["", "", "", "", "########", "########"]
	var grid := _grid(rows)
	var pests := Pests.new()
	var gnome := pests.add(Pests.GNOME, Vector2(3.5 * TILE, FLOOR_Y))
	_step(pests, grid, 3.0, 3.5 * TILE)
	_expect(gnome["position"] == Vector2(3.5 * TILE, FLOOR_Y) and gnome["grounded"],
		"A garden gnome never moves.")
	_expect(not Pests.stompable(gnome) and Pests.stompable(pests.add(Pests.PIGEON, Vector2.ZERO)),
		"Gnomes can't be stomped; pigeons can.")


func _test_activation_range() -> void:
	var rows: Array[String] = ["", "", "", "", "#".repeat(60), "#".repeat(60)]
	var grid := _grid(rows)
	var pests := Pests.new()
	var start := Vector2(40.5 * TILE, FLOOR_Y)
	var pigeon := pests.add(Pests.PIGEON, start)
	_step(pests, grid, 1.0, 40.5 * TILE - Pests.ACTIVE_RANGE - TILE)
	_expect(not pigeon["active"] and pigeon["position"] == start,
		"A pigeon out of range waits where it was placed.")
	_step(pests, grid, 1.0, 40.5 * TILE - Pests.ACTIVE_RANGE + TILE)
	_expect(pigeon["active"] and pigeon["position"].x < start.x,
		"Once Dulce is in range it starts its patrol, toward her.")
	_step(pests, grid, 1.0, 0.0)
	_expect(pigeon["active"], "An active pest stays active.")


func _test_defeat_and_poof() -> void:
	var rows: Array[String] = ["", "", "", "", "########", "########"]
	var grid := _grid(rows)
	var pests := Pests.new()
	var pigeon := pests.add(Pests.PIGEON, Vector2(3.5 * TILE, FLOOR_Y))
	pests.defeat(pigeon)
	_expect(not pigeon["alive"] and pests.alive_count() == 0 and pests.list.size() == 1,
		"A stomped pigeon is out at once, but lingers as a puff for the view.")
	_step(pests, grid, Pests.POOF_SECONDS + 0.05)
	_expect(pests.list.is_empty(), "The puff clears after POOF_SECONDS.")


func _test_falls_out_of_the_world() -> void:
	var rows: Array[String] = ["", "", "", "", "##......##", "##......##"]
	var grid := _grid(rows)
	var pests := Pests.new()
	pests.add(Pests.PIGEON, Vector2(5.5 * TILE, 2.0 * TILE))
	_step(pests, grid, 3.0, 5.5 * TILE)
	_expect(pests.list.is_empty(), "A pest that falls out of the world is gone, without a puff.")


func _test_clear_before() -> void:
	var pests := Pests.new()
	pests.add(Pests.PIGEON, Vector2(2.0 * TILE, FLOOR_Y))
	pests.add(Pests.GNOME, Vector2(30.0 * TILE, FLOOR_Y))
	pests.clear_before(10.0 * TILE)
	_expect(pests.list.size() == 1 and pests.list[0]["kind"] == Pests.GNOME,
		"clear_before frees pests behind the camera only.")


## Readable by silhouette, not colour (DESIGN §4.3): the two shapes must differ.
func _test_profiles() -> void:
	var pigeon: Vector2 = Pests.PROFILES[Pests.PIGEON]["size"]
	var gnome: Vector2 = Pests.PROFILES[Pests.GNOME]["size"]
	_expect(pigeon.x > pigeon.y and gnome.y > gnome.x,
		"The pigeon is wide and low; the gnome is narrow and tall.")
	for kind: String in Pests.PROFILES:
		var size: Vector2 = Pests.PROFILES[kind]["size"]
		_expect(size.x < TILE and size.y < TILE,
			"%s fits inside one tile, so the chunk validator's tile maths holds." % kind)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dulce pests tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
