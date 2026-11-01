extends SceneTree

## Run-rule regression checks for `run_state.gd` (DESIGN §4.2–§4.5, §10).
##
## Stomps and hits, Full and hearts, i-frames, pits and safe ground, food,
## Lunchboxes, stomp chains, scoring and the end of a run. Every scene is a
## tiny course built through `chunk_library.build()`, the same path the run
## uses, and every expected number is quoted from the model's constants.

const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Pests = preload("res://games/dolces_adventure/pests.gd")
const ChunkLibrary = preload("res://games/dolces_adventure/chunk_library.gd")

const STEP := State.STEP
const TILE := Grid.TILE
const FLOOR_Y := 4.0 * TILE

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stomp_and_side_hit()
	_test_held_stomp_bounce()
	_test_gnome_cannot_be_stomped()
	_test_full_and_hearts()
	_test_invulnerability()
	_test_pit_respawn_at_safe_ground()
	_test_kind_pits()
	_test_burgers_and_hearts()
	_test_golden_bone()
	_test_lunchboxes()
	_test_stomp_chain()
	_test_run_end()
	_test_score_and_clean_distance()
	_test_robo_vac_rules()
	_test_sauce_drop()
	_finish()


# --------------------------------------------------------------------------
# Scenes
# --------------------------------------------------------------------------


## Builds `above` (up to four rows) on a long floor and starts her at column 1.
func _course(above: Array[String], start_column := 1) -> State:
	var rows: Array[String] = []
	var width := 80
	for line in above:
		rows.append(line + ".".repeat(width - line.length()))
	while rows.size() < 4:
		rows.append(".".repeat(width))
	rows.append("#".repeat(width))
	rows.append("#".repeat(width))
	var grid := Grid.new()
	var course := ChunkLibrary.build(rows, grid)
	var state := State.new(grid, Vector2((start_column + 0.5) * TILE, FLOOR_Y))
	state.add_course(course)
	return state


func _hold(state: State, seconds: float, move := 0.0, run := false, jump := false) -> void:
	for _tick in roundi(seconds / STEP):
		state.advance(STEP, move, run, jump)


## Steps until `kind` happens, or `seconds` pass. Returns the matching event.
func _until(
	state: State, kind: String, seconds: float, move := 0.0, run := false, jump := false
) -> Dictionary:
	for _tick in roundi(seconds / STEP):
		state.advance(STEP, move, run, jump)
		for event in state.take_events():
			if event["kind"] == kind:
				return event
	return {}


func _jump(state: State, move := 0.0, run := false, hold := true) -> void:
	state.advance(STEP, move, run, hold, true)


# --------------------------------------------------------------------------
# Cases
# --------------------------------------------------------------------------


func _test_stomp_and_side_hit() -> void:
	var stomper := _course([])
	stomper.place(Vector2(10.5 * TILE, 1.0 * TILE))
	stomper.pests.add(Pests.PIGEON, Vector2(10.5 * TILE, FLOOR_Y))
	var stomp := _until(stomper, "stomp", 2.0)
	_expect(not stomp.is_empty() and stomp["points"] == State.STOMP_CHAIN_POINTS[0],
		"Landing on a pigeon from above stomps it for %d points." % State.STOMP_CHAIN_POINTS[0])
	_expect(stomper.pests.alive_count() == 0 and stomper.hearts == State.STARTING_HEARTS,
		"A stomped pigeon is out of the run, and the stomp costs nothing.")
	_expect(stomper.velocity.y < 0.0 and not stomper.grounded, "A stomp bounces her up.")
	var walker := _course(["", "", "", "....p"])
	var hurt := _until(walker, "hurt", 3.0, 1.0)
	_expect(not hurt.is_empty() and hurt["cause"] == Pests.PIGEON
		and walker.hearts == State.STARTING_HEARTS - 1,
		"Walking into a pigeon from the side costs a heart.")
	_expect(walker.is_invulnerable() and walker.pests.alive_count() == 1,
		"A hit starts her i-frames and leaves the pigeon standing.")


## Holding Jump through a stomp bounces higher than letting go.
func _test_held_stomp_bounce() -> void:
	var peaks: Array[float] = []
	for held in [false, true]:
		var state := _course([])
		state.place(Vector2(10.5 * TILE, 1.0 * TILE))
		state.pests.add(Pests.PIGEON, Vector2(10.5 * TILE, FLOOR_Y))
		var stomped := false
		var peak := INF
		for _tick in 600:
			state.advance(STEP, 0.0, false, held)
			for event in state.take_events():
				stomped = stomped or event["kind"] == "stomp"
			if stomped:
				peak = minf(peak, state.position.y)
			if stomped and state.grounded:
				break
		_expect(stomped, "A body dropped on a pigeon stomps it (held=%s)." % held)
		peaks.append(peak)
	_expect(peaks[1] < peaks[0] - TILE, "Holding Jump on a stomp bounces at least a tile higher.")


func _test_gnome_cannot_be_stomped() -> void:
	var state := _course([])
	state.place(Vector2(10.5 * TILE, 1.0 * TILE))
	state.pests.add(Pests.GNOME, Vector2(10.5 * TILE, FLOOR_Y))
	var hurt := _until(state, "hurt", 2.0)
	_expect(not hurt.is_empty() and hurt["cause"] == Pests.GNOME,
		"Landing on a gnome's pointy hat is a hit, not a stomp.")
	_expect(state.pests.alive_count() == 1 and state.stomps == 0, "The gnome stays put.")


func _test_full_and_hearts() -> void:
	var state := _course(["", "", "", "..GG"])
	_hold(state, 0.4, 1.0)
	_expect(state.full and state.item_points == State.BIG_BURGER_POINTS + State.BIG_BURGER_FULL_POINTS,
		"A Big Burger makes her Full; a second one while Full is worth %d."
		% State.BIG_BURGER_FULL_POINTS)
	var hits := _course(["", "", "", "..G.p"])
	_until(hits, "shrink", 3.0, 1.0)
	_expect(not hits.full and hits.hearts == State.STARTING_HEARTS and hits.is_invulnerable(),
		"A hit while Full costs Full, keeps every heart and starts i-frames.")
	hits.invulnerable_left = 0.0
	hits.place(Vector2(1.5 * TILE, FLOOR_Y))
	_until(hits, "hurt", 3.0, 1.0)
	_expect(hits.hearts == State.STARTING_HEARTS - 1, "The next hit, while Normal, costs a heart.")


func _test_invulnerability() -> void:
	var state := _course(["", "", "", "....p"])
	_until(state, "hurt", 3.0, 1.0)
	var hearts := state.hearts
	# Stand inside the pigeon for most of the i-frames: no second hit.
	_hold(state, State.INVULNERABLE_SECONDS - 0.2)
	_expect(state.hearts == hearts, "No hit lands while she is invulnerable.")
	state.place(state.pests.list[0]["position"])
	_until(state, "hurt", 1.0)
	_expect(state.hearts == hearts - 1, "Once the i-frames run out, a pest hurts again.")


func _test_pit_respawn_at_safe_ground() -> void:
	var rows: Array[String] = [
		"", "", "", "...S..S...S", "##############..####", "##############..####",
	]
	var grid := Grid.new()
	var course := ChunkLibrary.build(rows, grid)
	var state := State.new(grid, Vector2(1.5 * TILE, FLOOR_Y))
	state.add_course(course)
	state.full = true
	var respawn := _until(state, "respawn", 6.0, 1.0)
	_expect(not respawn.is_empty(), "Walking into a pit respawns her.")
	_expect(state.position == Vector2(10.5 * TILE, FLOOR_Y),
		"She respawns on the last safe ground she passed, not the first.")
	_expect(state.hearts == State.STARTING_HEARTS - 1 and not state.full,
		"A pit costs a heart even when Full, and Full with it.")
	_expect(state.is_invulnerable() and state.pits == 1, "A respawn starts i-frames.")


func _test_kind_pits() -> void:
	var rows: Array[String] = ["", "", "", ".S", "####..####", "####..####"]
	var grid := Grid.new()
	var course := ChunkLibrary.build(rows, grid)
	var state := State.new(grid, Vector2(1.5 * TILE, FLOOR_Y))
	state.add_course(course)
	state.kind_pits = true
	state.full = true
	_until(state, "respawn", 6.0, 1.0)
	_expect(state.hearts == State.STARTING_HEARTS and not state.full,
		"With Kind pits, a fall while Full costs Full instead of a heart.")
	_until(state, "respawn", 6.0, 1.0)
	_expect(state.hearts == State.STARTING_HEARTS - 1,
		"With Kind pits, a fall while Normal still costs a heart.")


func _test_burgers_and_hearts() -> void:
	var state := _course(["", "", "", "..BB"])
	state.hearts = State.MAX_HEARTS - 1
	state.burgers = State.BURGERS_PER_HEART - 1
	_hold(state, 0.4, 1.0)
	_expect(state.burgers == State.BURGERS_PER_HEART + 1
		and state.hearts == State.MAX_HEARTS,
		"Every %dth burger in a run is a heart." % State.BURGERS_PER_HEART)
	var capped := _course(["", "", "", "..B"])
	capped.burgers = State.BURGERS_PER_HEART - 1
	_hold(capped, 0.4, 1.0)
	_expect(capped.hearts == State.MAX_HEARTS
		and capped.item_points == State.BURGER_POINTS + State.HEART_CAPPED_POINTS,
		"With every heart full, the %dth burger pays %d points instead."
		% [State.BURGERS_PER_HEART, State.HEART_CAPPED_POINTS])


func _test_golden_bone() -> void:
	var state := _course(["", "", "", "..+.+"])
	state.hearts = State.MAX_HEARTS - 1
	_hold(state, 0.6, 1.0)
	_expect(state.hearts == State.MAX_HEARTS
		and state.item_points == 2 * State.GOLDEN_BONE_POINTS,
		"A Golden Bone is a heart, up to %d, and always %d points."
		% [State.MAX_HEARTS, State.GOLDEN_BONE_POINTS])


func _test_lunchboxes() -> void:
	var state := _course(["", ".?.!"])
	_jump(state)
	_until(state, "land", 2.0, 0.0, false, true)
	_expect(state.burgers == 1 and state.grid.tile(Vector2i(1, 1)) == Grid.EMPTY_BOX,
		"Bonking a ? Lunchbox from below eats its burger and empties the box.")
	_hold(state, 0.3)
	_jump(state)
	_until(state, "land", 2.0, 0.0, false, true)
	_expect(state.burgers == 1 and state.grid.is_solid(Vector2i(1, 1)),
		"An empty box stays solid and gives nothing more.")
	state.place(Vector2(3.5 * TILE, FLOOR_Y))
	_jump(state)
	var opened := _until(state, "lunchbox", 2.0, 0.0, false, true)
	_expect(not opened.is_empty() and opened["content"] == State.BIG_BURGER
		and state.items.get(Vector2i(3, 0), "") == State.BIG_BURGER,
		"A ! Lunchbox pops its Big Burger out on top of the box.")


## A fresh pigeon under her paws on every descent: a chain of five stomps
## without touching the ground, then a landing that ends the chain.
func _test_stomp_chain() -> void:
	var state := _course([])
	state.place(Vector2(10.5 * TILE, -6.0 * TILE))
	var expected := 0
	for link in 5:
		for _tick in 240:
			state.advance(STEP, 0.0, false, false)
			if state.velocity.y > 0.0:
				break
		var feet := state.position + Vector2(0, 2.0 + Pests.PROFILES[Pests.PIGEON]["size"].y)
		state.pests.add(Pests.PIGEON, feet)
		var stomp := _until(state, "stomp", 0.5)
		expected += State.stomp_chain_points(link + 1)
		_expect(not stomp.is_empty() and stomp["chain"] == link + 1,
			"Stomp %d in the air is link %d of the chain." % [link + 1, link + 1])
	_expect(state.stomp_points == expected and expected == 200 + 400 + 800 + 1600 + 1600,
		"A chain pays 200, 400, 800, then 1600 for every stomp after (%d)." % state.stomp_points)
	_until(state, "land", 3.0)
	_expect(state.chain == 0 and state.best_chain == 5,
		"Touching the ground ends the chain; the best chain is kept.")


func _test_run_end() -> void:
	var state := _course(["", "", "", "....p"])
	state.hearts = 1
	var over := _until(state, "run_over", 3.0, 1.0)
	_expect(not over.is_empty() and state.over and state.hearts == 0,
		"Losing the last heart ends the run.")
	_expect(not state.run_finished(), "The tumble plays before the results.")
	var x := state.position.x
	_hold(state, State.TUMBLE_SECONDS + 0.05, 1.0)
	_expect(state.run_finished() and state.position.x == x,
		"After the tumble the run is finished, and she has not moved since.")


func _test_score_and_clean_distance() -> void:
	var state := _course(["", "", "", "..B" + ".".repeat(16) + "p"])
	_until(state, "hurt", 6.0, 1.0)
	var clean := state.best_clean_m
	# The pigeon 18 m ahead wakes up and walks to meet her, so a little less.
	_expect(clean > 12.0 and clean < 18.0,
		"The clean stretch is the distance run before the first hit (%.1f m)." % clean)
	_expect(state.score() == floori(state.distance_m()) * State.DISTANCE_POINTS
		+ State.BURGER_POINTS,
		"Score is whole metres x %d plus food and stomps." % State.DISTANCE_POINTS)
	_hold(state, 1.0, 1.0)
	_expect(state.best_clean_m == clean, "A hit restarts the clean stretch from zero.")


## Stomp flips a robo-vac; walking into a flipped one kicks it; a sliding one
## bonks pests for points and hurts her once the kick's grace is over.
func _test_robo_vac_rules() -> void:
	var state := _course([])
	state.place(Vector2(10.5 * TILE, 1.0 * TILE))
	var vac := state.pests.add(Pests.ROBO_VAC, Vector2(10.5 * TILE, FLOOR_Y))
	var stomp := _until(state, "stomp", 2.0)
	_expect(not stomp.is_empty() and vac["alive"] and vac["state"] == "flipped"
		and state.stomp_points == State.STOMP_CHAIN_POINTS[0],
		"Stomping a robo-vac flips it and scores like any stomp.")
	# Straight back to the ground, before the bounce lands on the vac again.
	state.place(Vector2(7.5 * TILE, FLOOR_Y))
	vac["position"] = Vector2(10.5 * TILE, FLOOR_Y)
	var pigeon := state.pests.add(Pests.PIGEON, Vector2(16.5 * TILE, FLOOR_Y))
	var kick := _until(state, "kick", 2.0, 1.0)
	_expect(not kick.is_empty() and vac["state"] == "sliding" and int(vac["facing"]) == 1
		and state.hearts == State.STARTING_HEARTS,
		"Walking into a flipped vac kicks it away from her, without a scratch.")
	var points := state.stomp_points
	var bonk := _until(state, "bonk", 2.0)
	_expect(not bonk.is_empty() and not pigeon["alive"]
		and state.stomp_points == points + State.BONK_POINTS,
		"A sliding vac bonks the pigeon in its path, for %d points." % State.BONK_POINTS)
	var sliding := _course([])
	var runaway := sliding.pests.add(Pests.ROBO_VAC, Vector2(12.5 * TILE, FLOOR_Y))
	runaway["active"] = true
	sliding.pests.stomp(runaway)
	sliding.pests.kick(runaway, -1)
	runaway["grace"] = 0.0
	var hurt := _until(sliding, "hurt", 3.0)
	_expect(not hurt.is_empty() and hurt["cause"] == Pests.ROBO_VAC,
		"A sliding vac coming at her is a hit.")


func _test_sauce_drop() -> void:
	var state := _course([])
	var drop := state.pests.add(Pests.SAUCE_DROP, Vector2(1.5 * TILE, 2.0 * TILE))
	drop["active"] = true
	var hurt := _until(state, "hurt", 2.0)
	_expect(not hurt.is_empty() and hurt["cause"] == Pests.HOT_SAUCE and not drop["alive"],
		"A sauce drop that lands on her is a hit, and the drop is spent.")
	var second := state.pests.add(Pests.SAUCE_DROP, Vector2(1.5 * TILE, 2.0 * TILE))
	second["active"] = true
	var hearts := state.hearts
	_hold(state, 1.0)
	_expect(state.hearts == hearts and not second["alive"],
		"During i-frames a drop splats harmlessly.")


# --------------------------------------------------------------------------


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dolce rules tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
