extends RefCounted

## Dulce's Adventure registers itself through game-owned data, not framework
## conditionals.

const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")


## The shell supplies pause, settings, achievements, results and score sharing.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Dulce's Adventure"
	game.tagline = "Small dog. Big appetite. Long way to lunch."
	game.menu_order = 9
	game.gameplay_scene_path = "res://games/dulces_adventure/gameplay.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	# A run ends when Dulce loses her last heart, not on the shell's clock.
	game.uses_shell_round_rules = false
	# Solo in v1; hot-seat turns are a v2 item (DESIGN §12).
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.levels = Options.LEVELS
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.stats_url = "https://deskcansaw.com"
	game.copy = {
		"single_player_description": (
			"Run as far as you can. Jump the pits, bonk the pests and eat every burger."
		),
		"instructions_solo_summary": "Run right, jump pits and pests, and go as far as you can.",
		"instructions_headline": "SMALL DOG. BIG APPETITE.",
		"instructions_rules": (
			"Dulce smells something wonderful drifting over the fence: the neighbourhood "
			+ "food festival has opened at the far end of town. Between her and it are holes, "
			+ "puddles, pigeons and one very rude vacuum robot.\n"
			+ "Run right as far as you can. Hold Jump for a high jump or tap it for a hop, "
			+ "and hold Run for longer, higher jumps. Land on a pest from above to bonk it.\n"
			+ "Dulce has three hearts. Touching a pest from the side or falling into a pit "
			+ "costs one. Your score is the distance you run, plus burgers and stomps."
		),
		"instructions_demo_prompt": "GO, DULCE!",
	}
	return game
