extends "res://games/dolces_adventure/store_preview.gd"

## Dolce on the setup screen's plinth, in everything she has equipped.
##
## The screen hands over the character entry (there is one: her). Her outfit
## comes from the store, resolved from the tree rather than named, so this
## script still compiles in headless tests that load it before autoloads.

## The plinth is the hero of the setup screen, so the lens closes in a little
## and drops nearer the plinth's eye height.
const PLINTH_LENS := Vector3(1.0, 0.22, 1.1)

var _shown := ""


func configure(_character: Dictionary) -> void:
	if _inert or _dolce == null:
		return
	var store := get_node_or_null("/root/Store")
	var outfit: Array[String] = [Options.COLLAR_RED, "", ""]
	if store != null:
		var slots := [Options.COLLAR_SLOT, Options.HAT_SLOT, Options.BANDANA_SLOT]
		for index in slots.size():
			outfit[index] = str(store.call("equipped_id", Options.GAME_ID, slots[index]))
	var signature := "/".join(outfit)
	if signature == _shown:
		return
	_shown = signature
	_dress(outfit[0], outfit[1], outfit[2])


func _show() -> void:
	configure({})


func _lens() -> Vector3:
	return PLINTH_LENS


func _margin() -> float:
	return 1.02
