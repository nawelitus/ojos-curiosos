extends Control
## A round badge for an avatar: its colour with the initial of its name.

const Avatars := preload("res://scripts/net/avatars.gd")
const Ui := preload("res://scripts/ui.gd")

var avatar: int = 0:
	set(value):
		avatar = value
		queue_redraw()
## Draws a thicker ring, to show the badge is chosen.
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var diameter: float = 96.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(diameter, diameter)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	diameter = diameter


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(centre, radius, Color.WHITE)
	draw_circle(centre, radius - (9.0 if selected else 5.0), Avatars.color_of(avatar))
	var font := Ui.font(700)
	var font_size := int(radius * 1.15)
	var letter := Avatars.initial_of(avatar)
	var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var baseline := centre.y + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5
	draw_string(font, Vector2(centre.x - width * 0.5, baseline), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
