extends RefCounted

## Captured once per round: midnight must not change its course or save section.

const LevelStream = preload("res://games/dolces_adventure/level_stream.gd")
const SECONDS_PER_DAY := 86400

var utc_date: String
var seed: int
var record_id: String


func _init(unix_seconds: int) -> void:
	utc_date = Time.get_date_string_from_unix_time(unix_seconds)
	var epoch_day := floori(float(unix_seconds) / SECONDS_PER_DAY)
	seed = posmod(epoch_day, LevelStream.SEED_LIMIT)
	record_id = "daily_" + utc_date
