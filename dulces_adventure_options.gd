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
## Clearing a stage opens the next (owner decision). Save keys, permanent.
const CLEARED_BACKYARD := "dulces_adventure_cleared_backyard"
const CLEARED_PARK := "dulces_adventure_cleared_park"
const CLEARED_STREET := "dulces_adventure_cleared_street"
const CLEARED_PIER := "dulces_adventure_cleared_pier"
const CLEARED_MARKET := "dulces_adventure_cleared_market"
const HUNDRED_BURGERS := 100
const COMBO_CHAIN := 4
const CLEAN_METRES := 500

## Where a run starts when no level is chosen, and its best-runs section.
const START_BACKYARD := "backyard"
const START_PARK := "park"
const START_STREET := "street"
const START_PIER := "pier"
const START_MARKET := "market"
## Fixed stages: their level ids, and their sections in the best-runs file.
const STAGE_BACKYARD := "stage_backyard"
const STAGE_PARK := "stage_park"
const STAGE_STREET := "stage_street"
const STAGE_PIER := "stage_pier"
const STAGE_MARKET := "stage_market"
## Each start point's still, captured from the real chunks by
## `tools/capture_art.gd`.
const LEVEL_ART := "res://games/dulces_adventure/assets/levels/"

## Start points and fixed stages for the shared level selector (DESIGN §5.4,
## §5.5). Each later start point opens once a run has covered that far,
## counted from wherever it started; each stage opens when the one before it
## is cleared.
const LEVELS: Array[Dictionary] = [
	{
		"id": START_BACKYARD, "title": "Endless - Backyard", "icon": LEVEL_ART + "backyard.png",
		"description": "From Dulce's front door, past the picket fence. Pigeons and gnomes.",
	},
	{
		"id": START_PARK, "title": "Endless - the Park", "icon": LEVEL_ART + "park.png",
		"description": "Start 400 m out, among the ponds, trees and squirrels.",
		"requires_achievement": REACHED_PARK,
		"locked_description": "Run 400 m in one run to start from the Park.",
	},
	{
		"id": START_STREET, "title": "Endless - Main Street", "icon": LEVEL_ART + "street.png",
		"description": "Start 900 m out: manholes, parked cars and robo-vacs.",
		"requires_achievement": REACHED_STREET,
		"locked_description": "Run 900 m in one run to start from Main Street.",
	},
	{
		"id": START_PIER, "title": "Endless - the Boardwalk Pier", "icon": LEVEL_ART + "pier.png",
		"description": "Start 1,500 m out, over plank gaps under swooping seagulls.",
		"requires_achievement": REACHED_PIER,
		"locked_description": "Run 1,500 m in one run to start from the Pier.",
	},
	{
		"id": START_MARKET, "title": "Endless - the Night Market", "icon": LEVEL_ART + "market.png",
		"description": "Start 2,200 m out, among food trucks and spitting hot sauce.",
		"requires_achievement": REACHED_MARKET,
		"locked_description": "Run 2,200 m in one run to start from the Night Market.",
	},
	{
		"id": STAGE_BACKYARD, "title": "Stage 1 - Backyard", "icon": LEVEL_ART + "stage_backyard.png",
		"description": "About 300 m from the front door to the food truck. Fastest clear wins.",
	},
	{
		"id": STAGE_PARK, "title": "Stage 2 - the Park", "icon": LEVEL_ART + "stage_park.png",
		"description": "Ponds, branches and squirrels, on the clock.",
		"requires_achievement": CLEARED_BACKYARD,
		"locked_description": "Clear Stage 1 - Backyard.",
	},
	{
		"id": STAGE_STREET, "title": "Stage 3 - Main Street", "icon": LEVEL_ART + "stage_street.png",
		"description": "Manholes, parked cars and robo-vacs, on the clock.",
		"requires_achievement": CLEARED_PARK,
		"locked_description": "Clear Stage 2 - the Park.",
	},
	{
		"id": STAGE_PIER, "title": "Stage 4 - the Boardwalk Pier", "icon": LEVEL_ART + "stage_pier.png",
		"description": "Plank gaps and swooping gulls, on the clock.",
		"requires_achievement": CLEARED_STREET,
		"locked_description": "Clear Stage 3 - Main Street.",
	},
	{
		"id": STAGE_MARKET, "title": "Stage 5 - the Night Market", "icon": LEVEL_ART + "stage_market.png",
		"description": "Food trucks and hot sauce under the lanterns, on the clock.",
		"requires_achievement": CLEARED_PIER,
		"locked_description": "Clear Stage 4 - the Boardwalk Pier.",
	},
]

## The cosmetics shop and the museum arrive in Milestone 7.
const STORE_CURRENCY := {}
const STORE_SLOTS: Array[Dictionary] = []
const STORE_ITEMS: Array[Dictionary] = []
const GALLERY_EXHIBITS: Array[Dictionary] = []
