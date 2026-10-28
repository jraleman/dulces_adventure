extends RefCounted

## Preload-safe options, bindings, levels, store and gallery declarations.
##
## Constants only, so headless tests can import the keys without touching an
## autoload. The game's scenes read the same constants back through `Settings`.

const GAME_ID := "dulces_adventure"

## The headline record lives in this file (DESIGN §4.5). It is progress, not an
## option, so it is declared as a `save_files` entry and never as a tunable.
const SAVE_PATH := "user://dulces_adventure.cfg"

const AUTO_RUN_KEY := "game/dulces_adventure_auto_run"
const KIND_PITS_KEY := "game/dulces_adventure_kind_pits"
const GAME_SPEED_KEY := "game/dulces_adventure_game_speed"
const DAY_NIGHT_KEY := "game/dulces_adventure_day_night"

const LEFT := &"dulces_adventure_left"
const RIGHT := &"dulces_adventure_right"
const JUMP := &"dulces_adventure_jump"
const RUN := &"dulces_adventure_run"
## Every action the run reads each step, so held keys never leak into menus.
const RUN_ACTIONS: Array[StringName] = [LEFT, RIGHT, JUMP, RUN]

const HEADING := "Dulce's Adventure"
const ASSIST_HEADING := "Dulce's Adventure - assists"

## Assists never block achievements (DESIGN §8), so none of these is checked
## when a round awards them.
const TUNABLES: Array[Dictionary] = [
	{
		"key": AUTO_RUN_KEY, "type": GameManifest.OPTION_TOGGLE,
		"default": false, "title": "Auto-run", "heading": ASSIST_HEADING,
		"description": (
			"Dulce always runs right. Left slows her down instead of turning, "
			+ "so the game plays with one thumb."
		),
	},
	{
		"key": KIND_PITS_KEY, "type": GameManifest.OPTION_TOGGLE,
		"default": false, "title": "Kind pits", "heading": ASSIST_HEADING,
		"description": "A fall while Full costs the Full state instead of a heart.",
	},
	{
		"key": GAME_SPEED_KEY, "default": 1.0, "min": 0.7, "max": 1.0,
		"step": 0.05, "format": GameManifest.FORMAT_PERCENT,
		"title": "Game speed", "heading": ASSIST_HEADING,
		"description": "Slows the whole run for more reaction time. Applies to the next run.",
	},
	{
		"key": DAY_NIGHT_KEY, "type": GameManifest.OPTION_TOGGLE,
		"default": true, "title": "Day / night cycle", "heading": HEADING,
		"description": (
			"Let the light change as the run goes on. Turn off for steady daylight. "
			+ "Reduced motion also keeps daylight."
		),
	},
]

## One default key each: the arrow keys and the gamepad are fixed extras the
## gameplay scene reads directly, as Cube Trials does.
const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": "controls/dulces_adventure_left", "action": LEFT,
		"default": KEY_A, "title": "Move left", "player": 0, "movement": true,
		"description": "Walk back, or brake while Auto-run is on.", "heading": HEADING,
	},
	{
		"key": "controls/dulces_adventure_right", "action": RIGHT,
		"default": KEY_D, "title": "Move right", "player": 0, "movement": true,
		"description": "Walk toward the food festival.", "heading": HEADING,
	},
	{
		"key": "controls/dulces_adventure_jump", "action": JUMP,
		"default": KEY_SPACE, "title": "Jump", "player": 0,
		"description": "Hold for a high jump, tap for a hop. Hold it on a stomp to bounce higher.",
		"heading": HEADING,
	},
	{
		"key": "controls/dulces_adventure_run", "action": RUN,
		"default": KEY_SHIFT, "title": "Run", "player": 0,
		"description": "Hold to sprint. Running jumps go higher and farther.",
		"heading": HEADING,
	},
]

## Achievement keys are save keys in `user://achievements.cfg`: stable forever.
const REACHED_PARK := "dulces_adventure_reached_park"
const REACHED_STREET := "dulces_adventure_reached_street"
const REACHED_PIER := "dulces_adventure_reached_pier"
const REACHED_MARKET := "dulces_adventure_reached_market"
const HUNDRED := "dulces_adventure_hundred"
const COMBO := "dulces_adventure_combo"
const CLEAN := "dulces_adventure_clean"
## Metres run in one run, counted from wherever it started (owner decision:
## distance is relative everywhere). The first four also gate start points.
const REACH_METRES := {
	REACHED_PARK: 400, REACHED_STREET: 900, REACHED_PIER: 1500, REACHED_MARKET: 2200,
}
const HUNDRED_BURGERS := 100
const COMBO_CHAIN := 4
const CLEAN_METRES := 500

## Start points and fixed stages for the shared level selector. Filled in by
## Milestones 5 and 6; empty means the setup screen asks no level question.
const LEVELS: Array[Dictionary] = []
## Where a run starts when no level is chosen, and its best-runs section.
const START_BACKYARD := "backyard"

## The cosmetics shop and the museum arrive in Milestone 7.
const STORE_CURRENCY := {}
const STORE_SLOTS: Array[Dictionary] = []
const STORE_ITEMS: Array[Dictionary] = []
const GALLERY_EXHIBITS: Array[Dictionary] = []
