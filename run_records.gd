extends RefCounted

## Best runs, kept in `user://dulces_adventure.cfg` (DESIGN §4.5).
##
## One `ConfigFile` section per start point (`[backyard]`, later `[park]` and
## the fixed stages), each holding `distance`, `score` and `burgers`. Every
## field only ever goes up, and a save merges into the stored file rather than
## rebuilding it, so a build that does not know a section never deletes it.
## The file is declared in the manifest's `save_files`, so the Saves screen
## backs it up, restores it and deletes it with the rest of Dulce's progress.

const Options = preload("res://games/dulces_adventure/dulces_adventure_options.gd")

const FIELDS: Array[String] = ["distance", "score", "burgers"]

var path := Options.SAVE_PATH


func _init(file_path := Options.SAVE_PATH) -> void:
	path = file_path


## The best run from `start_id`, with zeroes where nothing is recorded yet.
func best(start_id: String) -> Dictionary:
	var file := _load()
	var record := {}
	for field in FIELDS:
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
	if not improved.is_empty():
		var saved := file.save(path)
		if saved != OK:
			push_warning("Best runs could not be saved to %s (error %d)." % [path, saved])
	return improved


func _load() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(path)
	return file
