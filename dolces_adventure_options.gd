extends RefCounted

## Preload-safe options, bindings, levels, store and gallery declarations.
##
## Constants only, so headless tests can import the keys without touching an
## autoload. The game's scenes read the same constants back through `Settings`.

const GAME_ID := "dolces_adventure"

## The headline record lives in this file (DESIGN §4.5). It is progress, not an
## option, so it is declared as a `save_files` entry and never as a tunable.
const SAVE_PATH := "user://dolces_adventure.cfg"

const AUTO_RUN_KEY := "game/dolces_adventure_auto_run"
## Onboarding belongs in settings, but is not a player-facing tunable.
const TOUCH_HINT_SEEN_KEY := "game/dolces_adventure_auto_run_hint_seen"
const KIND_PITS_KEY := "game/dolces_adventure_kind_pits"
const GAME_SPEED_KEY := "game/dolces_adventure_game_speed"
const DAY_NIGHT_KEY := "game/dolces_adventure_day_night"

const LEFT := &"dolces_adventure_left"
const RIGHT := &"dolces_adventure_right"
const JUMP := &"dolces_adventure_jump"
const RUN := &"dolces_adventure_run"
## Every action the run reads each step, so held keys never leak into menus.
const RUN_ACTIONS: Array[StringName] = [LEFT, RIGHT, JUMP, RUN]

const HEADING := "Dolce's Adventure"
const ASSIST_HEADING := "Dolce's Adventure - assists"

## Assists never block achievements (DESIGN §8), so none of these is checked
## when a round awards them.
const TUNABLES: Array[Dictionary] = [
	{
		"key": AUTO_RUN_KEY, "type": GameManifest.OPTION_TOGGLE,
		"default": false, "title": "Auto-run", "heading": ASSIST_HEADING,
		"description": (
			"Dolce always runs right. Left slows her down instead of turning, "
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
		"key": "controls/dolces_adventure_left", "action": LEFT,
		"default": KEY_A, "title": "Move left", "player": 0, "movement": true,
		"description": "Walk back, or brake while Auto-run is on.", "heading": HEADING,
	},
	{
		"key": "controls/dolces_adventure_right", "action": RIGHT,
		"default": KEY_D, "title": "Move right", "player": 0, "movement": true,
		"description": "Walk toward the food festival.", "heading": HEADING,
	},
	{
		"key": "controls/dolces_adventure_jump", "action": JUMP,
		"default": KEY_SPACE, "title": "Jump", "player": 0,
		"description": "Hold for a high jump, tap for a hop. Hold it on a stomp to bounce higher.",
		"heading": HEADING,
	},
	{
		"key": "controls/dolces_adventure_run", "action": RUN,
		"default": KEY_SHIFT, "title": "Run", "player": 0,
		"description": "Hold to sprint. Running jumps go higher and farther.",
		"heading": HEADING,
	},
]

## Achievement keys are save keys in `user://achievements.cfg`: stable forever.
const REACHED_PARK := "dolces_adventure_reached_park"
const REACHED_STREET := "dolces_adventure_reached_street"
const REACHED_PIER := "dolces_adventure_reached_pier"
const REACHED_MARKET := "dolces_adventure_reached_market"
const HUNDRED := "dolces_adventure_hundred"
const COMBO := "dolces_adventure_combo"
const CLEAN := "dolces_adventure_clean"
## Metres run in one run, counted from wherever it started (owner decision:
## distance is relative everywhere). The first four also gate start points.
const REACH_METRES := {
	REACHED_PARK: 400, REACHED_STREET: 900, REACHED_PIER: 1500, REACHED_MARKET: 2200,
}
## Clearing a stage opens the next (owner decision). Save keys, permanent.
const CLEARED_BACKYARD := "dolces_adventure_cleared_backyard"
const CLEARED_PARK := "dolces_adventure_cleared_park"
const CLEARED_STREET := "dolces_adventure_cleared_street"
const CLEARED_PIER := "dolces_adventure_cleared_pier"
const CLEARED_MARKET := "dolces_adventure_cleared_market"
const HUNDRED_BURGERS := 100
const COMBO_CHAIN := 4
const CLEAN_METRES := 500

## Where a run starts when no level is chosen, and its best-runs section.
const START_BACKYARD := "backyard"
const START_PARK := "park"
const START_STREET := "street"
const START_PIER := "pier"
const START_MARKET := "market"
## The UTC challenge always starts in the Backyard; bests use dated sections.
const DAILY := "daily"
## Fixed stages: their level ids, and their sections in the best-runs file.
const STAGE_BACKYARD := "stage_backyard"
const STAGE_PARK := "stage_park"
const STAGE_STREET := "stage_street"
const STAGE_PIER := "stage_pier"
const STAGE_MARKET := "stage_market"
## Each start point's still, captured from the real chunks by
## `tools/capture_art.gd`.
const LEVEL_ART := "res://games/dolces_adventure/assets/levels/"

## Start points, Daily UTC and fixed stages for the shared level selector
## (DESIGN §5.4–§5.6). Each later start point opens once a run has covered that far,
## counted from wherever it started; each stage opens when the one before it
## is cleared.
const LEVELS: Array[Dictionary] = [
	{
		"id": START_BACKYARD, "title": "Endless - Backyard", "icon": LEVEL_ART + "backyard.png",
		"description": "From Dolce's front door, past the picket fence. Pigeons and gnomes.",
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
		"id": DAILY, "title": "Daily UTC - Backyard", "icon": LEVEL_ART + "backyard.png",
		"description": (
			"One endless course per UTC date, from the front door. "
			+ "Unlimited retries, separate daily bests. Resets at UTC midnight."
		),
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

## Dolce is the one character; the setup screen stands her on its plinth in
## whatever she is wearing (owner decision).
const CHARACTER_ID := "dolce"
const CHARACTERS: Array[Dictionary] = [
	{
		"id": CHARACTER_ID, "title": "Dolce",
		"description": "A small, cheerful chihuahua mix with a very big appetite.",
	},
]

# --------------------------------------------------------------------------
# The store (DESIGN §9.2)
# --------------------------------------------------------------------------

## Treats: one per 100 points, 3 for any finished run (owner decision), and
## `TREATS_PER_CLEAR` more for clearing a stage, paid by the gameplay scene.
const STORE_CURRENCY := {
	"name": "Treat",
	"plural": "Treats",
	"points_per_score": 0.01,
	"round_bonus": 3,
	"win_bonus": 0,
	"max_per_round": 0,
}
const TREATS_PER_CLEAR := 20

const COLLAR_KIND := "dolce_collar"
const HAT_KIND := "dolce_hat"
const BANDANA_KIND := "dolce_bandana"
const COLLAR_SLOT := "dolce_collar"
const HAT_SLOT := "dolce_hat"
const BANDANA_SLOT := "dolce_bandana"

const COLLAR_RED := "dolce_collar_red"
const COLLAR_BLUE := "dolce_collar_blue"
const COLLAR_SPIKED := "dolce_collar_spiked"
const COLLAR_GOLD := "dolce_collar_gold"
const HAT_PARTY := "dolce_hat_party"
const HAT_FLOWERS := "dolce_hat_flowers"
const HAT_CHEF := "dolce_hat_chef"
const HAT_SOMBRERO := "dolce_hat_sombrero"
const BANDANA_KETCHUP := "dolce_bandana_ketchup"
const BANDANA_MUSTARD := "dolce_bandana_mustard"
const CAPE_HERO := "dolce_cape_hero"

## A collar is always worn; a hat and a bandana are optional.
const STORE_SLOTS: Array[Dictionary] = [
	{
		"id": COLLAR_SLOT, "kind": COLLAR_KIND, "title": "Collar",
		"description": "Always on: the red one she came with, or one you buy her.",
	},
	{
		"id": HAT_SLOT, "kind": HAT_KIND, "title": "Hat", "empty_title": "No hat",
		"description": "Sits between her big ears.",
	},
	{
		"id": BANDANA_SLOT, "kind": BANDANA_KIND, "title": "Neck", "empty_title": "Nothing",
		"description": "A bandana at her neck, or a cape down her back.",
	},
]

## Purely cosmetic: worn in the run, on the setup plinth, on the share card
## and in the gallery, and nothing here changes how she runs or jumps.
const STORE_ITEMS: Array[Dictionary] = [
	{
		"id": COLLAR_RED, "kind": COLLAR_KIND, "price": 0, "default": true,
		"title": "Red Collar", "badge": "RED", "color": Color("c8413a"), "heading": "Collars",
		"description": "The collar she wore out the front door. A tag shaped like a little bun.",
	},
	{
		"id": COLLAR_BLUE, "kind": COLLAR_KIND, "price": 60,
		"title": "Sky Collar", "badge": "SKY", "color": Color("3f86c9"), "heading": "Collars",
		"description": "Blue as the Backyard's afternoon sky.",
	},
	{
		"id": COLLAR_SPIKED, "kind": COLLAR_KIND, "price": 150,
		"title": "Spiked Collar", "badge": "SPIKE", "color": Color("2e2a33"), "heading": "Collars",
		"description": "Studs all round, for a very small, very tough dog.",
	},
	{
		"id": COLLAR_GOLD, "kind": COLLAR_KIND, "price": 300,
		"requires_achievement": CLEARED_MARKET,
		"title": "Gold Collar", "badge": "GOLD", "color": Color("f2c14e"), "heading": "Collars",
		"description": "For a dog who has run every stage to the last food truck.",
	},
	{
		"id": HAT_PARTY, "kind": HAT_KIND, "price": 80,
		"title": "Party Hat", "badge": "PARTY", "color": Color("e86ab0"), "heading": "Hats",
		"description": "Every run is a party if there are burgers at the end.",
	},
	{
		"id": HAT_FLOWERS, "kind": HAT_KIND, "price": 120,
		"title": "Flower Crown", "badge": "BLOOM", "color": Color("f2b33d"), "heading": "Hats",
		"description": "Picked from the Backyard's pots. Nobody saw. Probably.",
	},
	{
		"id": HAT_CHEF, "kind": HAT_KIND, "price": 160,
		"title": "Tiny Chef's Hat", "badge": "CHEF", "color": Color("f4f1ea"), "heading": "Hats",
		"description": "She has strong opinions about burgers now.",
	},
	{
		"id": HAT_SOMBRERO, "kind": HAT_KIND, "price": 220,
		"requires_achievement": REACHED_STREET,
		"title": "Sombrero", "badge": "SOMB", "color": Color("d9a54a"), "heading": "Hats",
		"description": "Wide enough to shade a whole chihuahua on Main Street.",
	},
	{
		"id": BANDANA_KETCHUP, "kind": BANDANA_KIND, "price": 70,
		"title": "Ketchup Bandana", "badge": "RED", "color": Color("d9533b"), "heading": "Neck",
		"description": "Hides any stains from the Night Market, in theory.",
	},
	{
		"id": BANDANA_MUSTARD, "kind": BANDANA_KIND, "price": 70,
		"title": "Mustard Bandana", "badge": "MUST", "color": Color("f2b33d"), "heading": "Neck",
		"description": "Bright enough to spot from the far end of the Pier.",
	},
	{
		"id": CAPE_HERO, "kind": BANDANA_KIND, "price": 250,
		"requires_achievement": REACHED_PIER,
		"title": "Superhero Cape", "badge": "CAPE", "color": Color("3f6aa8"), "heading": "Neck",
		"description": "Does not help her fly. She does not need to know that.",
	},
]

# --------------------------------------------------------------------------
# The gallery (DESIGN §9.3)
# --------------------------------------------------------------------------

const EXHIBIT_DOLCE := "dolce"
const EXHIBIT_DOLCE_FULL := "dolce_full"
const EXHIBIT_FOOD_TRUCK := "food_truck"

## Everything the run is made of, built by the same code the run uses. Later
## biomes' pests open with the distance that reaches their biome.
const GALLERY_EXHIBITS: Array[Dictionary] = [
	{
		"id": EXHIBIT_DOLCE, "title": "Dolce", "heading": "Dolce", "badge": "DOLCE",
		"color": Color("d6a26b"),
		"description": "Big upright ears, a short muzzle and a curled tail, in her equipped outfit.",
		"facts": ["A rig of rigid parts: head, ears, tail, four legs", "0.6 m nose to tail"],
	},
	{
		"id": EXHIBIT_DOLCE_FULL, "title": "Dolce, Full", "heading": "Dolce", "badge": "FULL",
		"color": Color("f2b33d"),
		"description": "After a Big Burger: rounder, and good for one free hit.",
		"facts": ["Full is a shape, never just a colour"],
	},
	{
		"id": "pigeon", "title": "Grumpy Pigeon", "heading": "The pests", "badge": "PIGEON",
		"color": Color("8d93a3"), "description": "Waddles to the edge, turns round, waddles back.",
		"facts": ["First seen: the Backyard", "Stomp: a puff of feathers"],
	},
	{
		"id": "gnome", "title": "Garden Gnome", "heading": "The pests", "badge": "GNOME",
		"color": Color("c8473a"), "description": "Never moves. Never lets you stomp it, either.",
		"facts": ["First seen: the Backyard", "Pointed hat: jump over it"],
	},
	{
		"id": "squirrel", "title": "Squirrel", "heading": "The pests", "badge": "SQRL",
		"color": Color("a0643a"), "requires_achievement": REACHED_PARK,
		"description": "Charges once you are close, and leaps small gaps to do it.",
		"facts": ["First seen: the Park", "Stomp: it scurries off"],
	},
	{
		"id": "robo_vac", "title": "Robo-Vac", "heading": "The pests", "badge": "VAC",
		"color": Color("3d4350"), "requires_achievement": REACHED_STREET,
		"description": "Stomp it onto its back, then kick it into everything else.",
		"facts": ["First seen: Main Street", "Kicked, it bonks other pests"],
	},
	{
		"id": "seagull", "title": "Seagull", "heading": "The pests", "badge": "GULL",
		"color": Color("9aa3ad"), "requires_achievement": REACHED_PIER,
		"description": "Patrols the sky and swoops on anything that smells of fries.",
		"facts": ["First seen: the Pier", "Never swoops into the ground"],
	},
	{
		"id": "hot_sauce", "title": "Hot-Sauce Bottle", "heading": "The pests", "badge": "SAUCE",
		"color": Color("d9533b"), "requires_achievement": REACHED_MARKET,
		"description": "Hops in place and spits slow drops in an arc.",
		"facts": ["First seen: the Night Market", "Stomp: the lid pops"],
	},
	{
		"id": "lunchbox", "title": "Lunchbox", "heading": "The food", "badge": "LUNCH",
		"color": Color("f2b33d"), "description": "Bonk it from below for whatever is inside.",
		"facts": ["Contents are always the same", "Empty once opened"],
	},
	{
		"id": "big_burger", "title": "Big Burger", "heading": "The food", "badge": "BIG",
		"color": Color("d99a4e"), "description": "Makes her Full: the next hit costs Full, not a heart.",
	},
	{
		"id": "golden_bone", "title": "Golden Bone", "heading": "The food", "badge": "BONE",
		"color": Color("f2c14e"), "description": "A heart back, up to three. Very rare.",
	},
	{
		"id": EXHIBIT_FOOD_TRUCK, "title": "The Food Truck", "heading": "The food", "badge": "TRUCK",
		"color": Color("fff1d6"), "requires_achievement": CLEARED_BACKYARD,
		"description": "Waiting at the end of every stage, hatch lit, flag flying.",
	},
]
