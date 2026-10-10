extends RefCounted
## Reads scenario data files and their illustrations.

const Scenario := preload("res://scripts/core/scenario.gd")

const SCENARIO_FOLDER := "res://data/scenarios"


static func path_for(scenario_id: String) -> String:
	return "%s/%s.json" % [SCENARIO_FOLDER, scenario_id]


## Returns the parsed scenario, or null with the reasons in `errors`.
static func load_file(path: String, errors: Array[String]) -> Scenario:
	if not FileAccess.file_exists(path):
		errors.append("scenario file not found: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("invalid JSON in %s: %s" % [path, json.get_error_message()])
		return null
	var scenario: Scenario = Scenario.from_dict(json.data, errors)
	if scenario == null:
		return null

	# Object positions are in picture pixels, so the declared size must be the real one.
	var texture := illustration(scenario)
	if texture == null:
		errors.append("missing illustration: %s" % scenario.image_path)
		return null
	if texture.get_width() != scenario.width or texture.get_height() != scenario.height:
		errors.append("illustration is %dx%d but the data says %dx%d" % [
				texture.get_width(), texture.get_height(), scenario.width, scenario.height])
		return null
	for object in scenario.objects:
		if not ResourceLoader.exists(scenario.icon_path(object["id"])):
			errors.append("missing icon: %s" % scenario.icon_path(object["id"]))
	return scenario if errors.is_empty() else null


static func illustration(scenario: Scenario) -> Texture2D:
	if not ResourceLoader.exists(scenario.image_path):
		return null
	return load(scenario.image_path)


## Picture of one object for the target list: its cut-out, with no background.
static func object_icon(scenario: Scenario, object_id: String) -> Texture2D:
	return load(scenario.icon_path(object_id))
