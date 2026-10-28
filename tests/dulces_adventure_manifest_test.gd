extends SceneTree

## Smoke checks for Dulce's Adventure's manifest and constants-only options.
##
## The manifest and options are loaded by path, as `GameCatalog` loads them, so
## this suite proves they compile before the autoloads exist. The catalog is
## then asked for the same id, which is what every framework sweep relies on.

const GAME_PATH := "res://games/dulces_adventure/game.gd"
const OPTIONS_PATH := "res://games/dulces_adventure/dulces_adventure_options.gd"
## Prefix every action and key with the game id (DESIGN §8), so two games can
## share a key without sharing a saved binding.
const PREFIX := "dulces_adventure_"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_script := load(GAME_PATH) as GDScript
	var options := load(OPTIONS_PATH) as GDScript
	_expect(game_script != null, "game.gd must load by path.")
	_expect(options != null, "The options file must load by path.")
	if game_script == null or options == null:
		_finish()
		return
	var constants := options.get_script_constant_map()
	var manifest := game_script.call("manifest") as GameManifest
	_expect(manifest != null and manifest.is_valid(), "manifest() must return a valid manifest.")
	if manifest == null:
		_finish()
		return
	_test_identity(manifest, constants)
	_test_rules(manifest)
	_test_options(manifest, constants)
	_test_bindings(manifest, constants)
	_test_catalog(manifest)
	_finish()


func _test_identity(manifest: GameManifest, constants: Dictionary) -> void:
	_expect(manifest.id == "dulces_adventure", "The id is permanent: 'dulces_adventure'.")
	_expect(manifest.id == str(constants.get("GAME_ID", "")),
		"The manifest must take its id from the options file.")
	_expect(manifest.title == "Dulce's Adventure", "The title must be 'Dulce's Adventure'.")
	_expect(manifest.menu_order == 9, "Dulce's Adventure sits after Cube Trials, at 9.")
	_expect(ResourceLoader.exists(manifest.gameplay_scene_path),
		"The gameplay scene must exist: %s" % manifest.gameplay_scene_path)
	_expect(manifest.stats_url.to_utf8_buffer().size() <= 42,
		"The stats URL must stay within 42 UTF-8 bytes or the QR stops scanning.")


## The run ends by its own rules, and v1 is solo (owner decision, TODO.md).
func _test_rules(manifest: GameManifest) -> void:
	_expect(manifest.control_style == GameManifest.CONTROL_STYLE_CUSTOM_KEYS,
		"Dulce's Adventure declares its own keys.")
	_expect(not manifest.uses_shell_round_rules,
		"A run ends on the last heart, not on the shell's countdown or lives pool.")
	_expect(not manifest.supports_multiplayer, "Hot seat is a v2 item; v1 is solo.")
	_expect(not manifest.supports_cpu_opponent, "There is no CPU opponent.")


func _test_options(manifest: GameManifest, constants: Dictionary) -> void:
	var keys := PackedStringArray()
	for definition: Dictionary in manifest.tunables:
		keys.append(str(definition.get("key", "")))
	for name: String in ["AUTO_RUN_KEY", "KIND_PITS_KEY", "GAME_SPEED_KEY", "DAY_NIGHT_KEY"]:
		var key := str(constants.get(name, ""))
		_expect(key.begins_with("game/" + PREFIX), "%s must be a prefixed game key." % name)
		_expect(key in keys, "The manifest must declare %s." % key)
	var speed := _definition(manifest.tunables, str(constants.get("GAME_SPEED_KEY", "")))
	_expect(is_equal_approx(float(speed.get("min", 0.0)), 0.7)
		and is_equal_approx(float(speed.get("max", 0.0)), 1.0)
		and is_equal_approx(float(speed.get("default", 0.0)), 1.0),
		"Game speed runs from 70% to 100% and starts at full speed (DESIGN §8).")
	var defaults := {
		"AUTO_RUN_KEY": false, "KIND_PITS_KEY": false, "DAY_NIGHT_KEY": true,
	}
	for name: String in defaults:
		var definition := _definition(manifest.tunables, str(constants.get(name, "")))
		_expect(definition.get("type", "") == GameManifest.OPTION_TOGGLE
			and definition.get("default", null) == defaults[name],
			"%s must be a toggle defaulting to %s." % [name, defaults[name]])


func _test_bindings(manifest: GameManifest, constants: Dictionary) -> void:
	var actions := PackedStringArray()
	for definition: Dictionary in manifest.control_bindings:
		var key := str(definition.get("key", ""))
		var action := str(definition.get("action", ""))
		_expect(key == "controls/" + action, "Binding '%s' must be keyed by its action." % key)
		_expect(action.begins_with(PREFIX), "Action '%s' must carry the game prefix." % action)
		_expect(int(definition.get("player", -1)) == 0, "'%s' belongs to the one runner." % key)
		actions.append(action)
	for name: String in ["LEFT", "RIGHT", "JUMP", "RUN"]:
		_expect(str(constants.get(name, "")) in actions, "The manifest must bind %s." % name)


func _test_catalog(manifest: GameManifest) -> void:
	var listed := GameCatalog.get_manifest(manifest.id)
	_expect(listed != null, "GameCatalog must discover games/dulces_adventure/game.gd.")
	if listed != null:
		_expect(listed.title == manifest.title, "The catalog must hold this manifest.")


func _definition(definitions: Array[Dictionary], key: String) -> Dictionary:
	for definition in definitions:
		if str(definition.get("key", "")) == key:
			return definition
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dulce's Adventure manifest tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
