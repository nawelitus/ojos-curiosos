extends "res://tools/testing/harness.gd"

const Catalog := preload("res://scripts/core/catalog.gd")
const Progress := preload("res://scripts/core/progress.gd")
const Storage := preload("res://scripts/storage.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")

const SCRATCH := "user://test_progress.json"


func run() -> void:
	_test_catalog()
	_test_records()
	_test_unlocking()
	_test_round_trip()
	_test_storage()


func _test_catalog() -> void:
	var errors: Array[String] = []
	var catalog: Catalog = Catalog.from_dict(_catalog_data(), errors)
	check(catalog != null and errors.is_empty(), "a valid catalog parses")
	if catalog != null:
		check(catalog.theme_ids() == ["beach", "city", "farm"], "themes keep their order")
		check(catalog.find_theme("city")["title"] == "Ciudad", "find_theme returns the theme")
		check(catalog.find_theme("moon").is_empty(), "find_theme returns {} for unknown ids")
		var rng := RandomNumberGenerator.new()
		var seen := {}
		for i in 60:
			seen[catalog.pick_variant("beach", rng)] = true
		check(seen.size() == 2 and seen.has("beach_1") and seen.has("beach_2"), "every variant of a theme can be picked")
		check(catalog.pick_variant("moon", rng) == "", "an unknown theme has no variant")

	_expect_bad_catalog("a non-object", "nope")
	_expect_bad_catalog("a wrong format", {"format": 9, "themes": []})
	_expect_bad_catalog("no themes", {"format": 1, "themes": []})
	_expect_bad_catalog("a duplicate id", {"format": 1, "themes": [_theme("a"), _theme("a")]})
	_expect_bad_catalog("a theme with no variants", {"format": 1, "themes": [
			{"id": "a", "title": "A", "variants": []}]})
	_expect_bad_catalog("a variant that is a path", {"format": 1, "themes": [
			{"id": "a", "title": "A", "variants": ["../secret"]}]})

	# The shipped catalog must load and every variant must be a loadable scenario.
	errors = []
	var shipped: Catalog = Storage.load_catalog(errors)
	check(shipped != null, "data/catalog.json loads: %s" % "; ".join(errors))
	if shipped != null:
		var all_load := true
		for entry in shipped.themes:
			for variant: String in entry["variants"]:
				var scenario_errors: Array[String] = []
				if ScenarioLoader.load_file(ScenarioLoader.path_for(variant), scenario_errors) == null:
					all_load = false
					print("  ", variant, ": ", scenario_errors)
		check(all_load, "every variant in the shipped catalog loads")


func _test_records() -> void:
	var progress := Progress.new()
	check(progress.completed("beach") == 0 and progress.best_stars("beach") == 0
			and progress.best_time("beach") < 0.0, "a new player has no records")
	var first := progress.record("beach", 2, 90.0)
	check(first["new_best_time"] and first["new_best_stars"], "the first round sets both records")
	var slower_better := progress.record("beach", 3, 120.0)
	check(not slower_better["new_best_time"] and slower_better["new_best_stars"], "more stars but slower")
	var faster_worse := progress.record("beach", 1, 60.0)
	check(faster_worse["new_best_time"] and not faster_worse["new_best_stars"], "faster but fewer stars")
	check(progress.completed("beach") == 3 and progress.best_stars("beach") == 3
			and is_equal_approx(progress.best_time("beach"), 60.0), "records keep the best of each")
	progress.record("city", 99, 10.0)
	check(progress.best_stars("city") == 3, "stars are capped at 3")


func _test_unlocking() -> void:
	var order: Array[String] = ["beach", "city", "farm", "space"]
	var progress := Progress.new()
	check(progress.is_unlocked(order, "beach") and progress.is_unlocked(order, "city"), "two themes are open from the start")
	check(not progress.is_unlocked(order, "farm") and not progress.is_unlocked(order, "space"), "the rest start locked")
	progress.record("beach", 3, 50.0)
	check(not progress.is_unlocked(order, "farm"), "completing the first theme does not open the third")
	progress.record("city", 1, 300.0)
	check(progress.is_unlocked(order, "farm"), "completing a theme opens the next one")
	check(not progress.is_unlocked(order, "space"), "but not the one after")
	check(not progress.is_unlocked(order, "moon"), "an unknown theme is never unlocked")


func _test_round_trip() -> void:
	var progress := Progress.new()
	progress.record("beach", 2, 75.5)
	var copy: Progress = Progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	check(copy.completed("beach") == 1 and copy.best_stars("beach") == 2
			and is_equal_approx(copy.best_time("beach"), 75.5), "progress survives a JSON round trip")

	check(Progress.from_dict(null).themes.is_empty(), "no data means empty progress")
	check(Progress.from_dict("garbage").themes.is_empty(), "garbage means empty progress")
	check(Progress.from_dict({"themes": [1, 2]}).themes.is_empty(), "a wrong shape means empty progress")
	var messy: Progress = Progress.from_dict({"themes": {
		"beach": {"completed": 2.0, "best_stars": 7.0, "best_time": -5.0},
		"city": "nope",
		"farm": {"completed": 0.0, "best_stars": 3.0, "best_time": 10.0},
		"space": {"completed": "many"},
	}})
	check(messy.themes.size() == 1 and messy.best_stars("beach") == 3 and messy.best_time("beach") < 0.0,
			"damaged entries are dropped or repaired")


func _test_storage() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	check(Storage.load_progress(SCRATCH).themes.is_empty(), "a missing file gives empty progress")
	var progress := Progress.new()
	progress.record("beach", 3, 42.0)
	check(Storage.save_progress(progress, SCRATCH), "progress is saved")
	var loaded: Progress = Storage.load_progress(SCRATCH)
	check(loaded.best_stars("beach") == 3 and is_equal_approx(loaded.best_time("beach"), 42.0), "and read back")
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	check(Storage.load_progress(SCRATCH).themes.is_empty(), "a damaged file gives empty progress")
	DirAccess.remove_absolute(SCRATCH)


func _catalog_data() -> Dictionary:
	return {"format": 1.0, "themes": [
		{"id": "beach", "title": "Playa", "variants": ["beach_1", "beach_2", "beach_1"]},
		{"id": "city", "title": "Ciudad", "variants": ["city_1"]},
		{"id": "farm", "title": "Granja", "variants": ["farm_1"]},
	]}


func _theme(id: String) -> Dictionary:
	return {"id": id, "title": "T", "variants": ["v"]}


func _expect_bad_catalog(description: String, data: Variant) -> void:
	var errors: Array[String] = []
	check(Catalog.from_dict(data, errors) == null and not errors.is_empty(), "rejects " + description)
