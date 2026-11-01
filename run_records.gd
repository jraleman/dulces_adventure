extends RefCounted

## Best runs, kept in `user://dolces_adventure.cfg` (DESIGN §4.5).
##
## One `ConfigFile` section per start point (`[backyard]`, `[park]`, …) and
## per fixed stage (`[stage_backyard]`, …), each holding `distance`, `score`
## and `burgers`, which only ever go up. A stage's section also keeps
## `time_ms`, its best clear time, which only ever goes down: an unfinished
## attempt never sets one. A save merges into the stored file rather than
## rebuilding it, so a build that does not know a section never deletes it.
## The file is declared in the manifest's `save_files`, so the Saves screen
## backs it up, restores it and deletes it with the rest of Dolce's progress.

const Options = preload("res://games/dolces_adventure/dolces_adventure_options.gd")

const FIELDS: Array[String] = ["distance", "score", "burgers"]
## Fields where smaller is better; 0 means "none yet".
const LOWER_FIELDS: Array[String] = ["time_ms"]

var path := Options.SAVE_PATH


func _init(file_path := Options.SAVE_PATH) -> void:
	path = file_path


## The best run from `start_id`, with zeroes where nothing is recorded yet.
func best(start_id: String) -> Dictionary:
	var file := _load()
	var record := {}
	for field in FIELDS + LOWER_FIELDS:
		record[field] = int(file.get_value(start_id, field, 0))
	return record


## Merges one finished run into the file and returns the fields it improved.
## A damaged file is left alone rather than overwritten with a single run.
func record(start_id: String, run: Dictionary) -> PackedStringArray:
	var improved := PackedStringArray()
	var file := ConfigFile.new()
	var status := file.load(path)
	if status != OK and status != ERR_FILE_NOT_FOUND:
		push_warning("Best runs at %s could not be read (error %d); not saving." % [path, status])
		return improved
	for field in FIELDS:
		var value := int(run.get(field, 0))
		if value > int(file.get_value(start_id, field, 0)):
			file.set_value(start_id, field, value)
			improved.append(field)
	for field in LOWER_FIELDS:
		var value := int(run.get(field, 0))
		var stored := int(file.get_value(start_id, field, 0))
		if value > 0 and (stored <= 0 or value < stored):
			file.set_value(start_id, field, value)
			improved.append(field)
	if not improved.is_empty():
		var saved := file.save(path)
		if saved != OK:
			push_warning("Best runs could not be saved to %s (error %d)." % [path, saved])
	return improved


func _load() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(path)
	return file
