extends Control
## Credits and licences: who made what, what the illustrations are, and the
## licence of each third-party piece (typeface and engine).

signal back_pressed

const Ui := preload("res://scripts/ui.gd")

const FONT_LICENSE_PATH := "res://assets/fonts/fredoka/OFL.txt"
const AUTHOR_LINE := "© 2026 nawelitus. Todos los derechos reservados."

## Sections shown as plain paragraphs: [title, text].
const SECTIONS: Array = [
	["Ojos Curiosos", "Un juego para encontrar objetos escondidos en escenas llenas de detalles."],
	["Ilustraciones", "Las ilustraciones de los escenarios fueron creadas con inteligencia artificial (ChatGPT, de OpenAI) a partir de descripciones escritas para este juego. No son dibujos hechos a mano."],
	["Sin anuncios ni datos", "El juego no tiene anuncios ni compras, no pide cuentas y no recopila información. Las partidas en red funcionan solo dentro de tu red Wi-Fi."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var frame := Ui.margin("Frame")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
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
	var title := Ui.label("TitleLabel", "Créditos", Ui.FONT_HEADING)
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
	cards.add_theme_constant_override("separation", 16)
	scroll.add_child(cards)

	for section: Array in SECTIONS:
		cards.add_child(_card(section[0], section[1]))
	cards.add_child(_card("Derechos", AUTHOR_LINE))
	cards.add_child(_card("Tipografía", "Fredoka, de Milena Brandão y Hafontia, con licencia SIL Open Font 1.1.",
			font_license()))
	cards.add_child(_card("Motor de juego", "Hecho con Godot Engine, con licencia MIT.",
			engine_license()))
	Ui.pass_touches(cards)


## Text of the typeface licence, shipped with the game.
static func font_license() -> String:
	if not FileAccess.file_exists(FONT_LICENSE_PATH):
		return ""
	return FileAccess.get_file_as_string(FONT_LICENSE_PATH).strip_edges()


## The engine's own licence plus the list of components bundled in it, each
## with its licence, as the engine reports them.
static func engine_license() -> String:
	var text := Engine.get_license_text().strip_edges()
	var components: Array[String] = []
	for component: Dictionary in Engine.get_copyright_info():
		var licenses := {}
		for part: Dictionary in component["parts"]:
			licenses[str(part["license"])] = true
		components.append("• %s (%s)" % [component["name"], ", ".join(PackedStringArray(licenses.keys()))])
	if components.is_empty():
		return text
	return "%s\n\nComponentes de terceros incluidos en el motor:\n%s" % [text, "\n".join(components)]


## A card with a title, a paragraph and, when there is one, a button that
## shows or hides the full licence text.
func _card(heading: String, body: String, license_text: String = "") -> Control:
	var card := PanelContainer.new()
	card.name = "Card_%s" % heading.replace(" ", "")
	card.add_theme_stylebox_override("panel", Ui.card(20))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	card.add_child(rows)

	var title := Ui.label("Heading", heading, Ui.FONT_BODY, Ui.skin.panel_text)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rows.add_child(title)
	var paragraph := Ui.label("Body", body, Ui.FONT_SMALL, Ui.skin.panel_muted)
	paragraph.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(paragraph)

	if not license_text.is_empty():
		var full := Ui.label("LicenseText", license_text, Ui.FONT_SMALL - 4, Ui.skin.panel_muted)
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		full.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		full.visible = false
		var toggle := Ui.button("LicenseButton", "Ver la licencia", Ui.skin.primary, Ui.FONT_SMALL)
		toggle.custom_minimum_size = Vector2(0, 80)
		toggle.pressed.connect(func() -> void:
			Ui.notify(self, "button")
			full.visible = not full.visible
			toggle.text = "Ocultar la licencia" if full.visible else "Ver la licencia")
		rows.add_child(toggle)
		rows.add_child(full)
	return card
