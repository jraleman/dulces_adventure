extends RefCounted

## Records the instructions screen's walkthrough on the real Stage 1 course.
##
## `tools/tutorial_capture.tscn` (the host's recorder) loads this by path, sets
## the session up through `configure_session()` and calls `update()` every
## frame. A fixed stage, not an endless run, so every take is the same course.
## The autopilot reads the course the way a player would: it runs right,
## jumps at pits and walls, and jumps onto the pests ahead of it, through the
## same rebindable actions a player presses. Dev-only; excluded from exports.

signal keycap_requested(text: String)

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const Grid = preload("res://games/dolces_adventure/tile_grid.gd")
const Pests = preload("res://games/dolces_adventure/pests.gd")

const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Run as far as you can",
		"body": "D runs right and Shift runs faster. On an endless run, distance is your score."},
	{"time": 5.0, "title": "Jump the pits",
		"body": "Space jumps: hold it to go higher and farther, tap it for a little hop."},
	{"time": 10.0, "title": "Bonk pests from above",
		"body": "Land on a pigeon to stomp it. Gnomes have pointed hats: jump over those."},
	{"time": 16.0, "title": "Eat every burger",
		"body": "Burgers score points. Every hundredth one, and a rare Golden Bone, is a heart."},
	{"time": 21.5, "title": "Three hearts",
		"body": "A pit or a pest from the side costs one. A Big Burger makes her Full, for a free hit."},
]
## Run speed starts here, so the clip shows the walk first.
const RUN_FROM := 2.5
const HOLD_SECONDS := 0.32
## A stomp lands within this many units of the pest's middle.
const STOMP_WINDOW := 10.0
## Take off this close to a pit's edge, jump this far from a wall, and hop a
## gnome from this far, all in units.
const EDGE_UNITS := 6.0
const WALL_UNITS := 30.0
const GNOME_UNITS := 70.0

var _done: Dictionary[String, bool] = {}
var _jump_left := 0.0
var _furthest := 0.0
var _stomps_seen := 0


## The walkthrough is solo; there is no local-multiplayer variant.
func configure(variant: String) -> bool:
	_done.clear()
	_jump_left = 0.0
	_furthest = 0.0
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return STEPS


func duration() -> float:
	return 27.0


## Stock assists and steady daylight, so the course reads the same every take.
func settings_overrides() -> Dictionary:
	return {
		Options.AUTO_RUN_KEY: false,
		Options.KIND_PITS_KEY: false,
		Options.GAME_SPEED_KEY: 1.0,
		Options.DAY_NIGHT_KEY: false,
	}


## Stage 1 is open on a new profile, and it is the same course every time.
func configure_session(session: Node) -> void:
	session.call("configure_single_player")
	session.call("set_level", Options.STAGE_BACKYARD)
	session.call("set_character_for_player", 0, Options.CHARACTER_ID)


## Never inherit a held action when starting a take.
func start(_scene: Node) -> void:
	_release()


func update(scene: Node, time: float, delta: float) -> void:
	if not bool(scene.get("_round_active")) or time < 1.0:
		return
	var state := scene.get("_state") as State
	if state == null or state.over:
		_release()
		return
	_furthest = maxf(_furthest, state.position.x)
	Input.action_press(Options.RIGHT)
	if _once("walk", true):
		keycap_requested.emit("D")
	if time >= RUN_FROM:
		Input.action_press(Options.RUN)
		if _once("run", true):
			keycap_requested.emit("Shift")
	_jump_left = maxf(0.0, _jump_left - delta)
	if _jump_left <= 0.0:
		Input.action_release(Options.JUMP)
	if state.grounded and _jump_left <= 0.0:
		var hold := _jump_for(state)
		if hold > 0.0:
			Input.action_press(Options.JUMP)
			_jump_left = hold
			keycap_requested.emit("Space")
	_stomps_seen = state.stomps


## The take must show real running, jumping, eating and at least one stomp.
func validate_finished(scene: Node) -> bool:
	_release()
	var state := scene.get("_state") as State
	var complete := state != null and state.distance_m() >= 90.0 and state.burgers >= 5 \
		and state.stomps >= 1 and not state.over
	if not complete:
		push_error("Dolce tutorial incomplete: %.0f m, %d burgers, %d stomps, over=%s." % [
			state.distance_m() if state else 0.0, state.burgers if state else 0,
			state.stomps if state else 0, state.over if state else true,
		])
	return complete


## How long to hold Jump now: a full jump timed to come down on a stompable
## pest, or one for a pit edge, a wall or a gnome; 0 to keep running.
func _jump_for(state: State) -> float:
	if _stomp_ready(state) or _trouble_ahead(state):
		return HOLD_SECONDS
	return 0.0


## A pest is where a full jump from here comes down, allowing for it walking
## to meet her; the reach is `run_state`'s own arithmetic.
func _stomp_ready(state: State) -> bool:
	var speed := absf(state.velocity.x)
	if speed < State.WALK_SPEED:
		return false
	for pest: Dictionary in state.pests.list:
		if not pest["alive"] or not Pests.stompable(pest):
			continue
		var top: float = Pests.PROFILES[pest["kind"]]["size"].y
		var reach := State.jump_reach(speed, top)
		if reach <= 0.0:
			continue
		var closing := maxf(0.0, -float(pest["velocity"].x)) * reach / speed
		var gap := float(pest["position"].x) - state.position.x
		if absf(gap - reach - closing) <= STOMP_WINDOW and absf(float(pest["position"].y) - state.position.y) < Grid.TILE \
				and not _pit_before(state, gap):
			return true
	return false


## Ground all the way to `distance` ahead, so a stomp never lands in a pit.
func _pit_before(state: State, distance: float) -> bool:
	var feet_row := floori(state.position.y / Grid.TILE)
	var column := floori(state.position.x / Grid.TILE)
	for step in range(1, ceili(distance / Grid.TILE) + 1):
		if state.grid.tile(Vector2i(column + step, feet_row)) == Grid.EMPTY:
			return true
	return false


## A pit edge right ahead (take off as late as possible, so wide pits are
## cleared), a wall a tile out, or a gnome close enough to hop.
func _trouble_ahead(state: State) -> bool:
	var feet_row := floori(state.position.y / Grid.TILE)
	var front := state.position.x + State.BODY_SIZE.x * 0.5
	if state.grid.tile(Grid.cell_at(Vector2(front + EDGE_UNITS, state.position.y + 1.0))) == Grid.EMPTY:
		return true
	if state.grid.is_solid(Grid.cell_at(Vector2(front + WALL_UNITS, state.position.y - 1.0))):
		return true
	for pest: Dictionary in state.pests.list:
		if not pest["alive"] or Pests.stompable(pest):
			continue
		var gap := float(pest["position"].x) - state.position.x
		if gap > 0.0 and gap < GNOME_UNITS and absf(float(pest["position"].y) - state.position.y) < Grid.TILE:
			return true
	return false


func _once(key: String, ready: bool) -> bool:
	if not ready or _done.has(key):
		return false
	_done[key] = true
	return true


func _release() -> void:
	for action in Options.RUN_ACTIONS:
		Input.action_release(action)
