extends Control
## Scenario picker: one big card per theme, with its best result. Locked themes
## say what opens them.

signal theme_chosen(theme_id: String)
signal back_pressed

const Ui := preload("res://scripts/ui.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Progress := preload("res://scripts/core/progress.gd")
const Scenario := preload("res://scripts/core/scenario.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const StarRow := preload("res://scripts/star_row.gd")

const CARD_HEIGHT := 300
const THUMBNAIL_WIDTH := 200

var catalog: Catalog
var progress: Progress


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var frame := Ui.margin("Frame")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	frame.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)
	var back := Ui.button("BackButton", "Volver", Ui.skin.neutral, Ui.FONT_BODY)
	back.custom_minimum_size = Vector2(170, 88)
	back.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		back_pressed.emit())
	top.add_child(back)
	var title := Ui.label("TitleLabel", "Escenarios", Ui.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var cards := VBoxContainer.new()
	cards.name = "Cards"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 20)
	scroll.add_child(cards)

	var order := catalog.theme_ids()
	for index in catalog.themes.size():
		var entry: Dictionary = catalog.themes[index]
		var unlocked := progress.is_unlocked(order, entry["id"])
		var opened_by: String = "" if index == 0 else catalog.themes[index - 1]["title"]
		cards.add_child(_build_card(entry, unlocked, opened_by))
	Ui.pass_touches(cards)


func _build_card(entry: Dictionary, unlocked: bool, opened_by: String) -> Button:
	var theme_id: String = entry["id"]
	var card := Button.new()
	card.name = "Card_%s" % theme_id
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not unlocked
	for state: String in ["normal", "hover", "disabled"]:
		card.add_theme_stylebox_override(state, Ui.card(16))
	card.add_theme_stylebox_override("pressed", Ui.box(Ui.skin.panel.darkened(0.08)))
	card.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		theme_chosen.emit(theme_id))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)

	var thumbnail := TextureRect.new()
	thumbnail.name = "Thumbnail"
	thumbnail.texture = _thumbnail(entry)
	thumbnail.custom_minimum_size = Vector2(THUMBNAIL_WIDTH, 0)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.45)
	row.add_child(thumbnail)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 14)
	row.add_child(info)

	info.add_child(Ui.label("Title", entry["title"], Ui.FONT_HEADING, Ui.skin.panel_text))
	if not unlocked:
		var hint := Ui.label("LockLabel", "Completa %s para abrirlo" % opened_by, Ui.FONT_SMALL, Ui.skin.panel_muted)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(hint)
		return card

	var stars := StarRow.new()
	stars.name = "Stars"
	stars.star_size = 52.0
	stars.filled = progress.best_stars(theme_id)
	info.add_child(stars)
	var best := progress.best_time(theme_id)
	var best_text := "Sin jugar todavía" if best < 0.0 else "Mejor tiempo: %s" % Ui.format_time(best)
	info.add_child(Ui.label("BestLabel", best_text, Ui.FONT_SMALL, Ui.skin.panel_muted))
	return card


## Picture of the theme: the illustration of its first variant.
func _thumbnail(entry: Dictionary) -> Texture2D:
	var errors: Array[String] = []
	var scenario: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(entry["variants"][0]), errors)
	return null if scenario == null else ScenarioLoader.illustration(scenario)
