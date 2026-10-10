extends "res://tools/testing/harness.gd"

const Scenario := preload("res://scripts/core/scenario.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Storage := preload("res://scripts/storage.gd")


func run() -> void:
	var errors: Array[String] = []
	var scenario: Scenario = Scenario.from_dict(_valid(), errors)
	check(scenario != null and errors.is_empty(), "valid data parses")
	if scenario != null:
		check(scenario.world_size() == Vector2(200, 300), "world size is the picture size")
		check(scenario.objects.size() == 1, "objects are read")
		check(scenario.objects[0]["position"] == Vector2(50, 60), "object position is in picture pixels")
		check(scenario.find_object("key")["name"] == "Llave", "find_object returns the object")
		check(scenario.find_object("nope").is_empty(), "find_object returns {} for unknown ids")
		check(scenario.icon_path("key") == "res://assets/scenarios/mini_icons/key.png",
				"icon path is <icons folder>/<object id>.png")

	_expect_invalid("a non-object root", [1, 2, 3])
	_expect_invalid("an unknown format", _with("format", 99))
	_expect_invalid("the old tile format", _with("format", 1))
	_expect_invalid("a missing id", _with("id", ""))
	_expect_invalid("a missing title", _with("title", ""))
	_expect_invalid("an image outside res://", _with("image", "user://beach.png"))
	_expect_invalid("an icons folder outside res://", _with("icons", "icons"))
	_expect_invalid("zero width", _with("width", 0))
	_expect_invalid("a fractional height", _with("height", 300.5))
	_expect_invalid("no objects", _with("objects", []))
	_expect_invalid("duplicate object ids", _with("objects", [_object("key"), _object("key")]))
	var outside := _object("key")
	outside["x"] = 999.0
	_expect_invalid("an object outside the picture", _with("objects", [outside]))
	var nameless := _object("key")
	nameless["name"] = ""
	_expect_invalid("an object with no name", _with("objects", [nameless]))
	var tiny := _object("key")
	tiny["radius"] = 1.0
	_expect_invalid("an object with a tiny radius", _with("objects", [tiny]))
	var text_position := _object("key")
	text_position["y"] = "60"
	_expect_invalid("an object with a text coordinate", _with("objects", [text_position]))

	# The shipped sample must load, with its illustration present and the right size.
	errors = []
	var beach: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for("beach_1"), errors)
	check(beach != null, "beach_1.json loads: %s" % "; ".join(errors))
	if beach != null:
		check(beach.objects.size() == 15, "beach_1 has 15 objects, each with its cut-out")
		check(beach.world_size() == Vector2(1024, 1536), "beach_1 is 1024x1536")
		var apart := true
		for a in beach.objects:
			for b in beach.objects:
				if a["id"] != b["id"] and a["position"].distance_to(b["position"]) < a["radius"] + b["radius"]:
					apart = false
		check(apart, "no two objects overlap")
		var icon := ScenarioLoader.object_icon(beach, "crab")
		check(icon != null and icon.get_width() > 0, "object icons load")

	# The city must load too, and its objects must not overlap each other.
	errors = []
	var city: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for("city_1"), errors)
	check(city != null, "city_1.json loads: %s" % "; ".join(errors))
	if city != null:
		check(city.objects.size() == 26, "city_1 has 26 objects, each with its cut-out")
		var city_apart := true
		for a in city.objects:
			for b in city.objects:
				if a["id"] != b["id"] and a["position"].distance_to(b["position"]) < (a["radius"] + b["radius"]) * 0.6:
					city_apart = false
					print("  overlap: ", a["id"], " / ", b["id"])
		check(city_apart, "city_1 objects are well apart")

	# Every shipped scenario: loads, has enough objects and none sit on top of another.
	errors = []
	var shipped: Catalog = Storage.load_catalog(errors)
	check(shipped != null and shipped.themes.size() == 6, "the catalog lists the six themes")
	if shipped != null:
		var all_ids: Array[String] = []
		for entry in shipped.themes:
			check(entry["variants"].size() == 2, "theme '%s' has two variants" % entry["id"])
			for variant: String in entry["variants"]:
				all_ids.append(variant)
		for scenario_id in all_ids:
			var load_errors: Array[String] = []
			var loaded: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(scenario_id), load_errors)
			check(loaded != null, "%s loads: %s" % [scenario_id, "; ".join(load_errors)])
			if loaded == null:
				continue
			check(loaded.objects.size() >= 15, "%s has at least 15 objects (%d)" % [scenario_id, loaded.objects.size()])
			var apart := true
			for a in loaded.objects:
				for b in loaded.objects:
					if a["id"] != b["id"] and a["position"].distance_to(b["position"]) < (a["radius"] + b["radius"]) * 0.6:
						apart = false
						print("  overlap in ", scenario_id, ": ", a["id"], " / ", b["id"])
			check(apart, "%s objects are well apart" % scenario_id)

	errors = []
	check(ScenarioLoader.load_file("res://data/scenarios/does_not_exist.json", errors) == null
			and errors.size() == 1, "a missing file is reported, not crashed on")


func _valid() -> Dictionary:
	return {
		"format": 2.0,
		"id": "mini",
		"title": "Mini",
		"image": "res://assets/scenarios/mini.png",
		"icons": "res://assets/scenarios/mini_icons/",
		"width": 200.0,
		"height": 300.0,
		"objects": [_object("key")],
	}


func _object(object_id: String) -> Dictionary:
	return {"id": object_id, "name": "Llave", "x": 50.0, "y": 60.0, "radius": 20.0}


func _with(key: String, value: Variant) -> Dictionary:
	var data := _valid()
	data[key] = value
	return data


func _expect_invalid(description: String, data: Variant) -> void:
	var errors: Array[String] = []
	var result: Scenario = Scenario.from_dict(data, errors)
	check(result == null and not errors.is_empty(), "rejects " + description)
