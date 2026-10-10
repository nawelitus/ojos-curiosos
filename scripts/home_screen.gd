extends Control
## First screen: a picture from the game, its name, one big button to play and
## three picture buttons for sound, vibration and the look of the game.

signal play_pressed
signal lan_pressed
signal credits_pressed
signal skin_change_pressed

const Ui := preload("res://scripts/ui.gd")
const IconButton := preload("res://scripts/icon_button.gd")

const TITLE_LINES: Array[String] = ["Ojos", "Curiosos"]
const HERO_MAX_SIDE := 400.0
const HERO_MIN_SIDE := 180.0
## Height taken by everything on the screen except the picture (title, buttons,
## settings, margins). The picture gets what is left, so the lowest button is
## never pushed off short screens (16:9 phones, tablets in portrait).
const OTHER_CONTENT_HEIGHT := 1040.0
const HERO_TILT := -0.07

## Illustration shown as a tilted photo. Without one, the game icon is shown.
var hero_texture: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var frame := Ui.margin("Frame", 44)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 30)
	frame.add_child(column)

	var hero := _build_hero()
	column.add_child(hero)
	column.add_child(_build_title())

	var play := Ui.button("PlayButton", "Jugar", Ui.skin.accent, 68)
	play.custom_minimum_size = Vector2(0, 170)
	play.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		play_pressed.emit())
	column.add_child(play)

	var lan := Ui.button("LanButton", "Jugar en red", Ui.skin.primary, Ui.FONT_HEADING)
	lan.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		lan_pressed.emit())
	column.add_child(lan)

	column.add_child(_build_settings_row())

	var credits := Ui.button("CreditsButton", "Créditos", Ui.skin.neutral, Ui.FONT_SMALL)
	credits.custom_minimum_size = Vector2(0, 76)
	credits.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		credits_pressed.emit())
	column.add_child(credits)
	_animate_in(hero, play)


## Side of the square picture for the height this screen has.
func hero_side() -> float:
	var available := get_viewport_rect().size.y
	return clampf(available - OTHER_CONTENT_HEIGHT, HERO_MIN_SIDE, HERO_MAX_SIDE)


## A square photo with a white border, slightly tilted, like a snapshot.
func _build_hero() -> Control:
	var photo := PanelContainer.new()
	photo.name = "Hero"
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	photo.add_theme_stylebox_override("panel", Ui.card(14))

	# The picture is clipped to rounded corners by its parent panel.
	var clip := Panel.new()
	clip.custom_minimum_size = Vector2(hero_side(), hero_side())
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	clip.add_theme_stylebox_override("panel", Ui.box(Color.WHITE, maxi(Ui.skin.corner_radius - 10, 8), 0))
	photo.add_child(clip)

	var picture := TextureRect.new()
	picture.name = "HeroPicture"
	picture.texture = hero_texture if hero_texture != null else load("res://icon.svg")
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(picture)
	return photo


func _build_title() -> Control:
	var title := VBoxContainer.new()
	title.name = "Title"
	title.add_theme_constant_override("separation", -22)
	for index in TITLE_LINES.size():
		var line := Ui.label("TitleLine%d" % index, TITLE_LINES[index], Ui.FONT_TITLE + 16,
				Ui.skin.accent if index == 1 else Ui.skin.primary)
		line.add_theme_font_override("font", Ui.font(700))
		line.add_theme_constant_override("outline_size", 18)
		line.add_theme_color_override("font_outline_color", Color.WHITE)
		title.add_child(line)
	return title


func _build_settings_row() -> Control:
	var settings := get_node_or_null("/root/GameSettings")
	var row := HBoxContainer.new()
	row.name = "SettingsRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)

	row.add_child(_setting("SoundToggle", "Sonido", IconButton.Icon.SOUND, settings, "sound_enabled"))
	row.add_child(_setting("VibrationToggle", "Vibración", IconButton.Icon.VIBRATION, settings, "vibration_enabled"))

	var palette := _captioned("SkinButton", Ui.skin.display_name, IconButton.Icon.PALETTE)
	(palette.get_node("SkinButton") as Button).pressed.connect(func() -> void:
		Ui.notify(self, "button")
		skin_change_pressed.emit())
	row.add_child(palette)
	return row


## Picture button that switches a boolean setting on and off.
func _setting(node_name: String, caption: String, icon: IconButton.Icon, settings: Node, property: String) -> Control:
	var item := _captioned(node_name, caption, icon)
	var button: IconButton = item.get_node(node_name)
	button.active = settings == null or settings.get(property)
	button.disabled = settings == null
	button.pressed.connect(func() -> void:
		button.active = not button.active
		settings.set(property, button.active)
		Ui.notify(self, "button"))
	return item


func _captioned(node_name: String, caption: String, icon: IconButton.Icon) -> Control:
	var item := VBoxContainer.new()
	item.add_theme_constant_override("separation", 6)
	var button := IconButton.new()
	button.name = node_name
	button.icon_kind = icon
	item.add_child(button)
	item.add_child(Ui.label("Caption", caption, Ui.FONT_SMALL))
	return item


## The photo settles into its tilt and the play button breathes, so the screen
## feels alive without anything demanding attention.
func _animate_in(hero: Control, play: Button) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	hero.pivot_offset = hero.size * 0.5
	hero.rotation = HERO_TILT * 3.0
	hero.scale = Vector2(0.8, 0.8)
	var settle := hero.create_tween().set_parallel(true)
	settle.tween_property(hero, "rotation", HERO_TILT, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(hero, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	play.pivot_offset = play.size * 0.5
	var breathe := play.create_tween().set_loops()
	breathe.tween_property(play, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(play, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
