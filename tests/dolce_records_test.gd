extends SceneTree

## Best-run persistence checks for `run_records.gd` (DESIGN §4.5).
##
## Every case writes to a scratch file of its own under `user://`, never the
## player's `dolces_adventure.cfg`, and deletes it at the end.

const Records = preload("res://games/dolces_adventure/run_records.gd")
const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")

var _failures := PackedStringArray()
var _path := "user://dolces_adventure_records_test_%d.cfg" % Time.get_ticks_usec()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manifest_declares_the_file()
	_test_empty()
	_test_records_never_regress()
	_test_merges_unknown_sections()
	_test_damaged_file_is_left_alone()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	_finish()


func _test_manifest_declares_the_file() -> void:
	var manifest := (load("res://games/dolces_adventure/game.gd") as GDScript).call(
		"manifest") as GameManifest
	var paths := manifest.save_files.map(func(entry: Dictionary) -> String: return entry["path"])
	_expect(Options.SAVE_PATH in paths, "The Saves screen must know about the best-runs file.")
	_expect(Records.new().path == Options.SAVE_PATH, "Records default to the declared file.")


func _test_empty() -> void:
	var best := Records.new(_path).best(Options.START_BACKYARD)
	_expect(best == {"distance": 0, "score": 0, "burgers": 0, "time_ms": 0},
		"With no file yet, every best is zero.")


func _test_records_never_regress() -> void:
	var records := Records.new(_path)
	var first := records.record(Options.START_BACKYARD,
		{"distance": 120, "score": 4000, "burgers": 30})
	_expect(first == PackedStringArray(["distance", "score", "burgers"]),
		"A first run improves every field.")
	var second := records.record(Options.START_BACKYARD,
		{"distance": 90, "score": 5000, "burgers": 10})
	_expect(second == PackedStringArray(["score"]), "Only the beaten field improves.")
	_expect(records.best(Options.START_BACKYARD) == {
		"distance": 120, "score": 5000, "burgers": 30, "time_ms": 0,
	}, "Each field keeps its own best; nothing regresses.")
	_expect(Records.new(_path).best(Options.START_BACKYARD)["distance"] == 120,
		"Bests survive into a fresh reader, so they are really on disk.")


## A later build may add start points or fields; an older one must keep them.
func _test_merges_unknown_sections() -> void:
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value("night_market", "distance", 999)
	file.set_value(Options.START_BACKYARD, "best_time", 42)
	file.save(_path)
	Records.new(_path).record(Options.START_BACKYARD, {"distance": 500})
	var after := ConfigFile.new()
	after.load(_path)
	_expect(int(after.get_value("night_market", "distance", 0)) == 999
		and int(after.get_value(Options.START_BACKYARD, "best_time", 0)) == 42,
		"Saving merges into the file instead of rebuilding it.")


func _test_damaged_file_is_left_alone() -> void:
	var broken := FileAccess.open(_path, FileAccess.WRITE)
	broken.store_string("[backyard\ndistance = = =")
	broken.close()
	var improved := Records.new(_path).record(Options.START_BACKYARD, {"distance": 9999})
	var text := FileAccess.get_file_as_string(_path)
	_expect(improved.is_empty() and text.begins_with("[backyard\n"),
		"A file that will not parse is never overwritten with one run.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Dolce records tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
