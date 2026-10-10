extends RefCounted
## What the player has achieved in solo play, and which themes that unlocks.
## Pure logic; reading and writing the file is done by storage.gd.

const VERSION := 1
## Themes open from the first launch. Each later one opens by completing a
## solo round in the theme before it.
const OPEN_AT_START := 2
const MAX_STARS := 3

## theme id -> { "completed": int, "best_stars": int, "best_time": float }
var themes: Dictionary = {}


func completed(theme_id: String) -> int:
	return _entry(theme_id)["completed"]


func best_stars(theme_id: String) -> int:
	return _entry(theme_id)["best_stars"]


## Best time in seconds, or -1.0 if the theme was never completed.
func best_time(theme_id: String) -> float:
	return _entry(theme_id)["best_time"]


## Stores a finished round. Tells which records it beat.
func record(theme_id: String, stars: int, seconds: float) -> Dictionary:
	var entry := _entry(theme_id)
	var new_best_time: bool = entry["best_time"] < 0.0 or seconds < entry["best_time"]
	var new_best_stars: bool = stars > entry["best_stars"]
	themes[theme_id] = {
		"completed": entry["completed"] + 1,
		"best_stars": clampi(maxi(stars, entry["best_stars"]), 0, MAX_STARS),
		"best_time": seconds if new_best_time else entry["best_time"],
	}
	return {"new_best_time": new_best_time, "new_best_stars": new_best_stars}


## `ordered_theme_ids` is the catalog order.
func is_unlocked(ordered_theme_ids: Array[String], theme_id: String) -> bool:
	var index := ordered_theme_ids.find(theme_id)
	if index < 0:
		return false
	if index < OPEN_AT_START:
		return true
	return completed(ordered_theme_ids[index - 1]) > 0


func to_dict() -> Dictionary:
	return {"version": VERSION, "themes": themes.duplicate(true)}


## Never fails: a missing, damaged or foreign file just means less progress.
static func from_dict(data: Variant) -> RefCounted:
	var progress: RefCounted = new()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("themes")) != TYPE_DICTIONARY:
		return progress
	var raw: Dictionary = data["themes"]
	for theme_id: Variant in raw:
		var entry: Variant = raw[theme_id]
		if typeof(theme_id) != TYPE_STRING or typeof(entry) != TYPE_DICTIONARY:
			continue
		var count := _number(entry.get("completed"), 0.0)
		var stars := _number(entry.get("best_stars"), 0.0)
		var time := _number(entry.get("best_time"), -1.0)
		if count < 1.0:
			continue
		progress.themes[theme_id] = {
			"completed": int(count),
			"best_stars": clampi(int(stars), 0, MAX_STARS),
			"best_time": time if time >= 0.0 else -1.0,
		}
	return progress


func _entry(theme_id: String) -> Dictionary:
	return themes.get(theme_id, {"completed": 0, "best_stars": 0, "best_time": -1.0})


static func _number(value: Variant, fallback: float) -> float:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value):
		return float(value)
	return fallback
