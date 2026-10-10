extends Control
## Three stars in a row, `filled` of them lit. Drawn in code: no font has to
## carry a star glyph. reveal() makes the lit stars pop in one after another.

signal star_revealed(index: int)

const Ui := preload("res://scripts/ui.gd")

const TOTAL := 3
const SECONDS_PER_STAR := 0.4

var filled: int = 0:
	set(value):
		filled = clampi(value, 0, TOTAL)
		_shown = float(filled)
		queue_redraw()
var star_size: float = 64.0:
	set(value):
		star_size = value
		custom_minimum_size = Vector2(star_size * TOTAL + _gap() * (TOTAL - 1), star_size * 1.15)
		queue_redraw()

## How many lit stars are visible so far; fractional while one is popping in.
var _shown: float = 0.0
var _announced: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_size = star_size


## Shows the lit stars one by one. `filled` keeps its value throughout.
func reveal() -> void:
	_shown = 0.0
	_announced = 0
	queue_redraw()
	if filled == 0:
		return
	var tween := create_tween()
	tween.tween_method(_set_shown, 0.0, float(filled), SECONDS_PER_STAR * filled)


func _set_shown(value: float) -> void:
	_shown = value
	while _announced < filled and _shown >= _announced + 0.35:
		star_revealed.emit(_announced)
		_announced += 1
	queue_redraw()


func _draw() -> void:
	var width := star_size * TOTAL + _gap() * (TOTAL - 1)
	var start := Vector2((size.x - width) * 0.5 + star_size * 0.5, size.y * 0.5)
	for index in TOTAL:
		var center := start + Vector2(index * (star_size + _gap()), 0)
		draw_colored_polygon(_star(center, star_size * 0.5), Ui.skin.star_empty)
		var progress := clampf(_shown - index, 0.0, 1.0)
		if index < filled and progress > 0.0:
			# Overshoots a little before settling: the "pop".
			var grow := 1.0 + 0.35 * sin(progress * PI)
			draw_colored_polygon(_star(center, star_size * 0.5 * progress * grow), Ui.skin.star)


func _gap() -> float:
	return star_size * 0.15


static func _star(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var length := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * TAU / 10.0
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	return points
