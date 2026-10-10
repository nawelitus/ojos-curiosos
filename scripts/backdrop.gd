extends Control
## Screen background: a vertical gradient with a few soft circles drifting
## slowly upwards. Purely decorative; it never takes touches.

const BUBBLE_COUNT := 9

var top_color: Color = Color.WHITE
var bottom_color: Color = Color.WHITE
var decoration_color: Color = Color(1, 1, 1, 0.25)

var _bubbles: Array[Dictionary] = []
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Fixed seed: the same calm pattern every time, on every device.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	for i in BUBBLE_COUNT:
		_bubbles.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"radius": rng.randf_range(0.05, 0.19),
			"speed": rng.randf_range(0.006, 0.02),
			"sway": rng.randf_range(0.0, TAU),
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var colors := PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	draw_polygon(corners, colors)
	for bubble in _bubbles:
		var radius: float = bubble["radius"] * size.x
		# Wraps around: leaves at the top and comes back from below.
		var travel := fposmod(bubble["y"] - _time * bubble["speed"], 1.0)
		var y := travel * (size.y + radius * 2.0) - radius
		var x: float = bubble["x"] * size.x + sin(_time * 0.3 + bubble["sway"]) * radius * 0.3
		draw_circle(Vector2(x, y), radius, decoration_color)
