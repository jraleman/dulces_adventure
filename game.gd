extends RefCounted

## Dolce's Adventure registers itself through game-owned data, not framework
## conditionals.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")
const Art = preload("res://games/dolces_adventure/dolce_art.gd")
const State = preload("res://games/dolces_adventure/run_state.gd")
const ROOT := "res://games/dolces_adventure/"


## The shell supplies pause, settings, achievements, results and score sharing.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Dolce's Adventure"
	game.tagline = "Small dog. Big appetite. Long way to lunch."
	game.menu_order = 9
	game.gameplay_scene_path = ROOT + "gameplay.tscn"
	game.intro_scene_path = ROOT + "intro.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	# A run ends when Dolce loses her last heart, not on the shell's clock.
	game.uses_shell_round_rules = false
	# Solo in v1; hot-seat turns are a v2 item (DESIGN §12).
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.levels = Options.LEVELS
	# One character, so the setup screen can stand her on its plinth in her
	# outfit (owner decision).
	game.characters = Options.CHARACTERS
	game.character_preview_scene_path = ROOT + "character_preview.tscn"
	# Best distance is progress, so the Saves screen keeps it with the rest.
	game.save_files = [{
		"path": Options.SAVE_PATH, "title": "Best runs",
		"description": "Best distance, score and burgers from each start point, and stage times.",
	}]
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.tutorial_video_path = ROOT + "assets/video/tutorial.ogv"
	game.tutorial_poster_path = ROOT + "assets/video/tutorial_poster.webp"
	game.share_art_scene_path = ROOT + "share_art.tscn"
	game.store_currency = Options.STORE_CURRENCY
	game.store_slots = Options.STORE_SLOTS
	game.store_items = Options.STORE_ITEMS
	game.store_preview_scene_path = ROOT + "store_preview.tscn"
	game.gallery_exhibits = Options.GALLERY_EXHIBITS
	game.gallery_stage_scene_path = ROOT + "gallery_stage.tscn"
	game.stats_url = "https://deskcansaw.com"
	game.copy = {
		"mode_select_intro": "The food festival is at the far end of town. Choose where Dolce sets off.",
		"single_player_description": (
			"Run as far as you can. Jump the pits, bonk the pests and eat every burger."
		),
		"solo_confirm_title": "Choose a run",
		"character_label": "Dog",
		"solo_confirm_description": (
			"Endless runs are a new course every time, scored by how far she gets: run 400, "
			+ "900, 1,500 and 2,200 m to start further along. Stages are the same 300 m "
			+ "every time, against the clock: clear one to open the next."
		),
		"instructions_solo_summary": "Run right, jump the pits, bonk the pests and eat every burger.",
		"instructions_headline": "SMALL DOG. BIG APPETITE.",
		"instructions_rules": (
			"Dolce smells something wonderful drifting over the fence: the neighbourhood "
			+ "food festival has opened at the far end of town. Between her and it are holes, "
			+ "puddles, pigeons and one very rude vacuum robot.\n"
			+ "Run right as far as you can. Hold Jump for a high jump or tap it for a hop, "
			+ "and hold Run for longer, higher jumps. Land on a pest from above to bonk it; "
			+ "gnomes have pointed hats, so jump over those.\n"
			+ "Dolce has three hearts. Touching a pest from the side or falling into a pit "
			+ "costs one, and a fall sends her back to the last safe ground. A Big Burger "
			+ "makes her Full: the next hit costs Full instead of a heart. Every hundredth "
			+ "burger, and a rare Golden Bone, gives a heart back.\n"
			+ "Bump Lunchboxes from below for food. Stomp pests in a row without landing "
			+ "for 200, 400, 800, then 1,600 points each. A robo-vac flips when stomped: "
			+ "walk into it to kick it into the other pests.\n"
			+ "Endless runs score %d points a metre, plus food and stomps, and get harder "
			+ "as she goes, through the Park, Main Street, the Pier and the Night Market. "
			+ "Stages are fixed and timed: the clock stops at the food truck."
		) % State.DISTANCE_POINTS,
		"instructions_demo_prompt": "GO, DOLCE!",
		"instructions_player_one_controls": (
			"A and D, or the arrow keys, move; Space or the up arrow jumps (hold it for a "
			+ "higher jump); hold Shift to run. On a gamepad: the stick or D-pad moves, "
			+ "A jumps, X or the right trigger runs. On a touchscreen: the arrows move, the "
			+ "big button jumps, and tapping the right arrow twice and holding runs. "
			+ "Auto-run in Settings runs for her."
		),
		"store_intro": (
			"Every run pays Treats: one per 100 points, 3 for finishing, and 20 more for "
			+ "clearing a stage. Collars, hats and bandanas are just for looks: nothing "
			+ "here changes how she runs."
		),
		"gallery_intro": (
			"Dolce, her pests and her food, up close. Run further to meet the pests of "
			+ "later neighbourhoods."
		),
	}
	game.achievements = {
		Options.REACHED_PARK: {
			"title": "Off the Leash", "badge": "PARK",
			"description": "Run %d m in one run." % Options.REACH_METRES[Options.REACHED_PARK],
		},
		Options.REACHED_STREET: {
			"title": "Street Smart", "badge": "STREET",
			"description": "Run %d m in one run." % Options.REACH_METRES[Options.REACHED_STREET],
		},
		Options.REACHED_PIER: {
			"title": "Sea Legs", "badge": "PIER",
			"description": "Run %d m in one run." % Options.REACH_METRES[Options.REACHED_PIER],
		},
		Options.REACHED_MARKET: {
			"title": "Follow Your Nose", "badge": "MARKET",
			"description": "Run %d m in one run." % Options.REACH_METRES[Options.REACHED_MARKET],
		},
		Options.HUNDRED: {
			"title": "Hungry Hungry", "badge": "100",
			"description": "Eat %d burgers in one run." % Options.HUNDRED_BURGERS,
		},
		Options.COMBO: {
			"title": "Boing Boing Boing", "badge": "COMBO",
			"description": "Stomp %d pests in a row without touching the ground."
				% Options.COMBO_CHAIN,
		},
		Options.CLEAN: {
			"title": "Not a Scratch", "badge": "CLEAN",
			"description": "Run %d m without a hit or a fall." % Options.CLEAN_METRES,
		},
		Options.CLEARED_BACKYARD: {
			"title": "Out the Gate", "badge": "STAGE 1",
			"description": "Clear Stage 1 - Backyard. Opens Stage 2.",
		},
		Options.CLEARED_PARK: {
			"title": "Walk in the Park", "badge": "STAGE 2",
			"description": "Clear Stage 2 - the Park. Opens Stage 3.",
		},
		Options.CLEARED_STREET: {
			"title": "Street Food", "badge": "STAGE 3",
			"description": "Clear Stage 3 - Main Street. Opens Stage 4.",
		},
		Options.CLEARED_PIER: {
			"title": "Pier Pressure", "badge": "STAGE 4",
			"description": "Clear Stage 4 - the Boardwalk Pier. Opens Stage 5.",
		},
		Options.CLEARED_MARKET: {
			"title": "Last Stop, Lunch", "badge": "STAGE 5",
			"description": "Clear Stage 5 - the Night Market.",
		},
	}
	var theme := GameTheme.new()
	theme.logo_texture_path = ROOT + "assets/game-icon.png"
	theme.accent = Art.MUSTARD
	theme.light = Art.CREAM
	theme.plaque_color = Color("5a3d2e")
	theme.background_top = Color("4a3230")
	theme.background_bottom = Color("1f1424")
	theme.style_share_card = true
	game.theme = theme
	game.credits = [
		{"heading": "Dolce's Adventure", "lines": [
			"Game design and development: DeskCanSaw Games",
			"An endless run and five timed stages through one hungry dog's neighbourhood.",
		]},
		{"heading": "Art and sound", "lines": [
			"Original procedural models: Dolce, her pests, her food and every biome.",
			"Original synthesized yips, boings, munches and fanfares.",
			"Shared DeskCanSaw framework, menus and accessibility.",
		]},
		{"heading": "Acknowledgements", "lines": [
			"Inspired by classic side-scrolling platformers.",
			"No levels, characters, art, sound or music from any other game are used.",
		]},
	]
	return game
