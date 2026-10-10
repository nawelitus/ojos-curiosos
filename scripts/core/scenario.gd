extends RefCounted
## One scenario parsed from its data file (data/scenarios/<id>.json). Pure
## logic: it validates and holds the data; loading the picture is done elsewhere.
##
## A scenario is one large illustration with the findable objects painted in.
## File format 2:
##   format, id, title
##   image          "res://..." path of the illustration
##   icons          "res://..." folder with one cut-out per object: <object id>.png
##   width, height  size of the illustration in pixels
##   objects [ { id, name, x, y, radius } ]  centre and radius in image pixels

const FORMAT := 2
const MAX_SIDE := 8192
const MIN_RADIUS := 4.0

var id: String
var title: String
var image_path: String
var icons_path: String
var width: int
var height: int
## Array of { "id": String, "name": String, "position": Vector2, "radius": float }
var objects: Array[Dictionary] = []


func world_size() -> Vector2:
	return Vector2(width, height)


func find_object(object_id: String) -> Dictionary:
	for object in objects:
		if object["id"] == object_id:
			return object
	return {}


## Picture of one object on its own, for the target list. It is a cut-out with
## no background: a plain crop would show the sand or water around the object
## and give its place away.
func icon_path(object_id: String) -> String:
	return "%s/%s.png" % [icons_path, object_id]


## Builds a scenario from parsed JSON. Returns null and fills `errors` if the
## data is not valid; a scenario is never returned half-checked.
static func from_dict(data: Variant, errors: Array[String]) -> RefCounted:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("root must be an object")
		return null
	var source: Dictionary = data
	if _int_of(source.get("format")) != FORMAT:
		errors.append("unsupported format: %s" % str(source.get("format")))
		return null

	var scenario: RefCounted = new()
	scenario.id = _string_of(source.get("id"))
	scenario.title = _string_of(source.get("title"))
	scenario.image_path = _string_of(source.get("image"))
	scenario.icons_path = _string_of(source.get("icons")).trim_suffix("/")
	scenario.width = _int_of(source.get("width"))
	scenario.height = _int_of(source.get("height"))
	if scenario.id.is_empty():
		errors.append("id is missing")
	if scenario.title.is_empty():
		errors.append("title is missing")
	if not scenario.image_path.begins_with("res://"):
		errors.append("image must be a res:// path")
	if not scenario.icons_path.begins_with("res://"):
		errors.append("icons must be a res:// folder")
	if scenario.width < 1 or scenario.width > MAX_SIDE:
		errors.append("width out of range")
	if scenario.height < 1 or scenario.height > MAX_SIDE:
		errors.append("height out of range")
	if not errors.is_empty():
		return null

	_parse_objects(source.get("objects"), scenario, errors)
	return scenario if errors.is_empty() else null


static func _parse_objects(raw: Variant, scenario: RefCounted, errors: Array[String]) -> void:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		errors.append("objects must be a non-empty array")
		return
	var seen := {}
	for index in (raw as Array).size():
		var entry: Variant = raw[index]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("object %d must be an object" % index)
			continue
		var object_id := _string_of(entry.get("id"))
		var object_name := _string_of(entry.get("name"))
		var x := _float_of(entry.get("x"))
		var y := _float_of(entry.get("y"))
		var radius := _float_of(entry.get("radius"))
		if object_id.is_empty() or seen.has(object_id):
			errors.append("object %d needs a unique id" % index)
			continue
		if object_name.is_empty():
			errors.append("object '%s' has no name" % object_id)
			continue
		if is_nan(x) or is_nan(y) or x < 0.0 or y < 0.0 or x > scenario.width or y > scenario.height:
			errors.append("object '%s' is outside the picture" % object_id)
			continue
		if is_nan(radius) or radius < MIN_RADIUS or radius > maxf(scenario.width, scenario.height):
			errors.append("object '%s' has an invalid radius" % object_id)
			continue
		seen[object_id] = true
		scenario.objects.append({
			"id": object_id,
			"name": object_name,
			"position": Vector2(x, y),
			"radius": radius,
		})


## JSON numbers arrive as floats; only whole numbers count as ints.
static func _int_of(value: Variant, fallback: int = -1) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value):
		return int(value)
	return fallback


static func _float_of(value: Variant) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value) if is_finite(value) else NAN
	return NAN


static func _string_of(value: Variant) -> String:
	return value if typeof(value) == TYPE_STRING else ""
