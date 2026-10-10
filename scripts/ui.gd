extends RefCounted
## Shared look of every screen: the active skin, type sizes and widget
## builders. Screens never hard-code colours or styles; they ask here.

const GameSkin := preload("res://scripts/game_skin.gd")
const Backdrop := preload("res://scripts/backdrop.gd")

const SKIN_IDS: Array[String] = ["light", "dark", "kids"]
const DEFAULT_SKIN := "light"
const FONT_FILE := preload("res://assets/fonts/fredoka/Fredoka.ttf")

const FONT_TITLE := 84
const FONT_HEADING := 46
const FONT_BODY := 32
const FONT_SMALL := 24
const BUTTON_HEIGHT := 116
const MARGIN := 24

## The skin every builder below uses. Change it with use_skin().
static var skin: GameSkin = preload("res://skins/light.tres")


static func load_skin(skin_id: String) -> GameSkin:
	var path := "res://skins/%s.tres" % skin_id
	if not SKIN_IDS.has(skin_id) or not ResourceLoader.exists(path):
		return null
	return load(path)


## Screens built after this call use the new skin; existing ones keep theirs.
static func use_skin(skin_id: String) -> void:
	var loaded := load_skin(skin_id)
	skin = loaded if loaded != null else load_skin(DEFAULT_SKIN)


static func next_skin_id() -> String:
	return SKIN_IDS[(SKIN_IDS.find(skin.id) + 1) % SKIN_IDS.size()]


## Theme for the root of the game: gives every label and button the game font.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(skin.font_weight)
	return theme


static func font(weight: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = FONT_FILE
	# Axis tags are numbers, not names: {"wght": weight} is silently ignored.
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	variation.variation_opentype = {weight_axis: weight}
	return variation


static func font_size(base: int) -> int:
	return roundi(base * skin.font_scale)


## Animated gradient that fills the screen behind everything else.
static func background() -> Control:
	var backdrop := Backdrop.new()
	backdrop.name = "Background"
	backdrop.top_color = skin.background_top
	backdrop.bottom_color = skin.background_bottom
	backdrop.decoration_color = skin.decoration
	return backdrop


## Text on the background. Pass a colour for text on panels or for emphasis.
static func label(node_name: String, text: String, size: int, color: Variant = null) -> Label:
	var result := Label.new()
	result.name = node_name
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", font_size(size))
	result.add_theme_color_override("font_color", skin.text if color == null else color)
	return result


## Big raised button, sized for small fingers. It sinks when pressed.
static func button(node_name: String, text: String, color: Variant = null,
		size: int = FONT_HEADING) -> Button:
	var base: Color = skin.primary if color == null else color
	var result := Button.new()
	result.name = node_name
	result.text = text
	result.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", font_size(size))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, skin.button_text)
	result.add_theme_color_override("font_disabled_color", Color(skin.button_text, 0.7))
	result.add_theme_stylebox_override("normal", raised_box(base, false))
	result.add_theme_stylebox_override("hover", raised_box(base, false))
	result.add_theme_stylebox_override("pressed", raised_box(base, true))
	result.add_theme_stylebox_override("disabled", raised_box(skin.neutral.lerp(skin.background_bottom, 0.35), false))
	return result


## Button face with a darker lower edge; `pressed` removes the edge and moves
## the label down by the same amount, so the button looks pushed in.
static func raised_box(color: Color, pressed: bool) -> StyleBoxFlat:
	var style := box(color.darkened(0.12) if pressed else color)
	var depth := skin.button_depth
	style.border_color = color.darkened(0.3)
	style.border_width_bottom = 0 if pressed else depth
	style.content_margin_top = 16 + (depth if pressed else 0)
	style.content_margin_bottom = 16 + (0 if pressed else depth)
	if not pressed:
		style.shadow_color = Color(0, 0, 0, 0.18)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 4)
	return style


static func box(color: Color, radius: int = -1, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(skin.corner_radius if radius < 0 else radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style


## Card for content: panel colour, rounded, with a soft shadow.
static func card(padding: int = 24) -> StyleBoxFlat:
	var style := box(skin.panel, -1, padding)
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style


static func margin(node_name: String, amount: int = MARGIN) -> MarginContainer:
	var container := MarginContainer.new()
	container.name = node_name
	for side: String in ["left", "right", "top", "bottom"]:
		container.add_theme_constant_override("margin_" + side, amount)
	return container


## Lets a finger drag that starts on a button or panel scroll the list it is in.
## A control that "stops" touches keeps the whole gesture and the scroll
## container never sees it, so everything inside a ScrollContainer must pass
## touches on. Buttons still react to a tap.
static func pass_touches(root: Node) -> void:
	if root is Control and (root as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		(root as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in root.get_children():
		pass_touches(child)


## 75 -> "1:15"
static func format_time(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]


## Sound and vibration for an event, if the Feedback autoload is running.
static func notify(from: Node, event: String) -> void:
	var feedback := from.get_node_or_null("/root/Feedback")
	if feedback != null:
		feedback.notify(event)


## Relative luminance contrast between two colours (1 to 21), as in WCAG.
static func contrast(a: Color, b: Color) -> float:
	var first := _luminance(a)
	var second := _luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


static func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
