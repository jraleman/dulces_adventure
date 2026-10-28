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
	_test_squirrel()
	_test_robo_vac()
	_test_seagull()
	_test_hot_sauce()
	_finish()


func _grid(rows: Array[String]) -> Grid:
	return Grid.new(rows)


## Steps every pest for `seconds`, with Dulce standing at `dulce_x`.
func _step(pests: Pests, grid: Grid, seconds: float, dulce_x := 0.0, dulce_y := FLOOR_Y) -> void:
	for _tick in roundi(seconds / STEP):
		pests.step(grid, Vector2(dulce_x, dulce_y), STEP)


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
		pests.step(grid, Vector2(6.5 * TILE, FLOOR_Y), STEP)
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
	var shapes := {}
	for kind: String in Pests.PROFILES:
		var size: Vector2 = Pests.PROFILES[kind]["size"]
		_expect(not shapes.has(size), "%s has a silhouette of its own." % kind)
		shapes[size] = true


## Waits, then charges once she is within six tiles; hops a two-tile gap,
## stops at a wider one.
func _test_squirrel() -> void:
	var rows: Array[String] = ["", "", "", "", "######..######....######", "######..######....######"]
	var grid := _grid(rows)
	var pests := Pests.new()
	var squirrel := pests.add(Pests.SQUIRREL, Vector2(12.5 * TILE, FLOOR_Y))
	_step(pests, grid, 1.0, 22.5 * TILE)
	_expect(squirrel["state"] == "walk" and squirrel["position"].x == 12.5 * TILE,
		"A squirrel waits while she is more than six tiles off.")
	_step(pests, grid, 1.5, 7.5 * TILE)
	_expect(squirrel["state"] == "charge", "Once she is within six tiles it charges.")
	_step(pests, grid, 2.0, 1.5 * TILE)
	_expect(squirrel["alive"] and squirrel["position"].x < 6.0 * TILE,
		"It hops the two-tile gap to reach her side.")
	var cautious := pests.add(Pests.SQUIRREL, Vector2(21.5 * TILE, FLOOR_Y))
	_step(pests, grid, 3.0, 15.5 * TILE)
	_expect(cautious["alive"] and cautious["position"].x > 18.0 * TILE,
		"It will not try a four-tile gap; it waits at the edge.")


func _test_robo_vac() -> void:
	var rows: Array[String] = ["", "", "", "#.................#", "###################", "###################"]
	var grid := _grid(rows)
	var pests := Pests.new()
	var vac := pests.add(Pests.ROBO_VAC, Vector2(9.5 * TILE, FLOOR_Y))
	var start: float = vac["position"].x
	_step(pests, grid, 1.0, 9.5 * TILE)
	_expect(absf(vac["position"].x - start) <= Pests.PROFILES[Pests.ROBO_VAC]["speed"] * 1.01,
		"A robo-vac trundles slowly.")
	_expect(not pests.stomp(vac) and vac["alive"] and vac["state"] == "flipped",
		"A stomp flips it onto its back instead of defeating it.")
	_expect(pests.is_harmless(vac), "A flipped robo-vac is harmless.")
	var pigeon := pests.add(Pests.PIGEON, Vector2(15.5 * TILE, FLOOR_Y))
	pests.kick(vac, 1)
	_step(pests, grid, 0.05, 9.5 * TILE)
	_expect(vac["state"] == "sliding" and vac["velocity"].x == Pests.VAC_SLIDE_SPEED,
		"A kick sends it sliding fast.")
	_expect(pests.is_harmless(vac), "...and it can't bite the dog who kicked it straight away.")
	_step(pests, grid, 1.2, 9.5 * TILE)
	var bonks := pests.take_events().filter(func(event: Dictionary) -> bool:
		return event["kind"] == "bonk")
	_expect(not pigeon["alive"] and bonks.size() == 1, "A sliding vac bonks the pigeon in its way.")
	_expect(int(vac["facing"]) == -1, "It bounces off the wall at the end.")
	_expect(not pests.is_harmless(vac), "A sliding vac is dangerous again once the kick is past.")
	pests.stomp(vac)
	_step(pests, grid, Pests.VAC_RECOVER_SECONDS + 0.1, 9.5 * TILE)
	_expect(vac["state"] == "walk", "Left alone, a flipped vac rights itself.")
	var pit_rows: Array[String] = ["", "", "", "", "######...", "######..."]
	var pit := _grid(pit_rows)
	var faller := Pests.new()
	var sliding := faller.add(Pests.ROBO_VAC, Vector2(3.5 * TILE, FLOOR_Y))
	faller.stomp(sliding)
	faller.kick(sliding, 1)
	_step(faller, pit, 3.0, 3.5 * TILE)
	_expect(faller.list.is_empty(), "A sliding vac off a ledge falls out of the run.")


## Patrols on a bob without falling, swoops when she passes under, and never
## dives into the ground or far below its perch.
func _test_seagull() -> void:
	var rows: Array[String] = ["", "", "", "", "#".repeat(30), "#".repeat(30)]
	var grid := _grid(rows)
	var pests := Pests.new()
	var home := Vector2(10.5 * TILE, 1.0 * TILE)
	var gull := pests.add(Pests.SEAGULL, home)
	var lowest := -INF
	var furthest := 0.0
	for _tick in roundi(4.0 / STEP):
		pests.step(grid, Vector2(25.5 * TILE, FLOOR_Y), STEP)
		lowest = maxf(lowest, gull["position"].y)
		furthest = maxf(furthest, absf(gull["position"].x - home.x))
	_expect(lowest < home.y + 10.0, "A seagull never falls; it bobs around its perch.")
	_expect(furthest <= Pests.GULL_PATROL + 2.0 and furthest > Grid.TILE,
		"It patrols up to three tiles either side (%.0f)." % furthest)
	var deepest := -INF
	var swooped := false
	for _tick in roundi(3.0 / STEP):
		pests.step(grid, Vector2(gull["position"].x, FLOOR_Y), STEP)
		swooped = swooped or gull["state"] == "swoop"
		deepest = maxf(deepest, gull["position"].y)
	_expect(swooped, "It swoops when she runs underneath.")
	_expect(deepest <= FLOOR_Y - Pests.GULL_CLEARANCE + 0.5
		and deepest <= home.y + Pests.GULL_DIVE_LIMIT + 0.5,
		"A swoop never reaches the ground or more than four tiles below home (%.0f)." % deepest)
	pests.step(grid, Vector2(25.5 * TILE, FLOOR_Y), STEP)
	for _tick in roundi(3.0 / STEP):
		pests.step(grid, Vector2(25.5 * TILE, FLOOR_Y), STEP)
	_expect(absf(gull["position"].y - home.y) < 8.0, "Then it climbs back to its perch.")


func _test_hot_sauce() -> void:
	var rows: Array[String] = ["", "", "", "", "#".repeat(30), "#".repeat(30)]
	var grid := _grid(rows)
	var pests := Pests.new()
	var bottle := pests.add(Pests.HOT_SAUCE, Vector2(12.5 * TILE, FLOOR_Y))
	var highest := FLOOR_Y
	for _tick in roundi(2.0 / STEP):
		pests.step(grid, Vector2(28.5 * TILE, FLOOR_Y), STEP)
		highest = minf(highest, bottle["position"].y)
	_expect(highest < FLOOR_Y - 10.0 and bottle["position"].x == 12.5 * TILE,
		"A hot-sauce bottle hops in place.")
	_expect(pests.take_events().is_empty(), "Out of range, it never spits.")
	var spits := []
	for _tick in roundi(Pests.SAUCE_SPIT_SECONDS / STEP):
		pests.step(grid, Vector2(7.5 * TILE, FLOOR_Y), STEP)
		spits = pests.take_events().filter(func(event: Dictionary) -> bool:
			return event["kind"] == "spit")
		if not spits.is_empty():
			break
	_expect(spits.size() >= 1, "In range, it spits.")
	var drops := pests.list.filter(func(pest: Dictionary) -> bool:
		return pest["kind"] == Pests.SAUCE_DROP and pest["alive"])
	_expect(not drops.is_empty() and drops[0]["velocity"].x < 0.0, "The drop flies toward her.")
	_expect(pests.alive_count() == 1, "Drops are not pests to count or stomp.")
	_step(pests, grid, 1.5, 7.5 * TILE)
	var flying := pests.list.filter(func(pest: Dictionary) -> bool:
		return pest["kind"] == Pests.SAUCE_DROP and pest["alive"])
	_expect(flying.is_empty() and drops[0]["exit"] == Pests.SPLAT, "A drop splats on the ground.")
	_expect(not Pests.stompable(drops[0]), "A drop can't be stomped: touching it is a hit.")


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
