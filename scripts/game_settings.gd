extends Node
## Autoload. The player's settings, kept in user://settings.cfg.

const PATH := "user://settings.cfg"

var sound_enabled: bool = true:
	set(value):
		sound_enabled = value
		_save()
var vibration_enabled: bool = true:
	set(value):
		vibration_enabled = value
		_save()
## Id of the chosen skin (see Ui.SKIN_IDS).
var skin_id: String = "light":
	set(value):
		skin_id = value
		_save()

var _loading: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	_loading = true
	sound_enabled = bool(config.get_value("feedback", "sound", true))
	vibration_enabled = bool(config.get_value("feedback", "vibration", true))
	skin_id = str(config.get_value("look", "skin", "light"))
	_loading = false


func _save() -> void:
	if _loading:
		return
	var config := ConfigFile.new()
	config.set_value("feedback", "sound", sound_enabled)
	config.set_value("feedback", "vibration", vibration_enabled)
	config.set_value("look", "skin", skin_id)
	config.save(PATH)
