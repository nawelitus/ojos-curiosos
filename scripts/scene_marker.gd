extends Node2D
## A mark drawn on the scene, sized in picture pixels: a ring around a found
## object or a hint area, or a cross where a wrong tap landed.

enum Shape { RING, CROSS }

var shape: Shape = Shape.RING
var radius: float = 24.0
var line_width: float = 4.0
var color: Color = Color("ef476f")


func _draw() -> void:
	if shape == Shape.CROSS:
		for direction: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(-direction * radius, direction * radius, Color.WHITE, line_width * 1.8, true)
			draw_line(-direction * radius, direction * radius, color, line_width, true)
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color.WHITE, line_width * 1.8, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, line_width, true)
