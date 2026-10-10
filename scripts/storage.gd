extends RefCounted
## Reads the catalog and reads/writes the player's progress.

const Catalog := preload("res://scripts/core/catalog.gd")
const Progress := preload("res://scripts/core/progress.gd")

const CATALOG_PATH := "res://data/catalog.json"
const PROGRESS_PATH := "user://progress.json"


static func load_catalog(errors: Array[String], path: String = CATALOG_PATH) -> Catalog:
	var data: Variant = _read_json(path)
	if data == null:
		errors.append("cannot read catalog: %s" % path)
		return null
	return Catalog.from_dict(data, errors)


## A missing or damaged file gives empty progress, never an error.
static func load_progress(path: String = PROGRESS_PATH) -> Progress:
	return Progress.from_dict(_read_json(path))


static func save_progress(progress: Progress, path: String = PROGRESS_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot save progress to %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(progress.to_dict()))
	file.close()
	return true


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data
