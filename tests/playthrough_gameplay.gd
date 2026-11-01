extends "res://games/dolces_adventure/gameplay.gd"

## Loaded at runtime after autoloads exist. Seeds the normal round constructor,
## rather than replacing or positioning a live body to create a test course.

var test_unix_time := Time.get_unix_time_from_datetime_string("2026-11-01T23:59:59")


func _requested_seed() -> int:
	if _daily != null:
		return super()
	return 42


func _run_unix_time() -> int:
	return test_unix_time
