extends Button
## Square raised button with a drawn picture instead of text, for settings a
## child can understand at a glance. `active` false draws it greyed and
## crossed out (sound off, vibration off).

const Ui := preload("res://scripts/ui.gd")

enum Icon { SOUND, VIBRATION, PALETTE }

const SIDE := 128

var icon_kind: Icon = Icon.SOUND
var active: bool = true:
	set(value):
		active = value
		_restyle()
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(SIDE, SIDE)
	focus_mode = Control.FOCUS_NONE
	_restyle()


func _restyle() -> void:
	var color: Color = Ui.skin.primary if active else Ui.skin.neutral
	for state: String in ["normal", "hover"]:
		add_theme_stylebox_override(state, Ui.raised_box(color, false))
	add_theme_stylebox_override("pressed", Ui.raised_box(color, true))


func _draw() -> void:
	var ink: Color = Ui.skin.button_text
	# Centre of the face, above the raised edge.
	var centre := Vector2(size.x, size.y - Ui.skin.button_depth) * 0.5
	var unit := SIDE * 0.01
	match icon_kind:
		Icon.SOUND:
			var body := PackedVector2Array([Vector2(-26, -10), Vector2(-12, -10), Vector2(6, -26),
					Vector2(6, 26), Vector2(-12, 10), Vector2(-26, 10)])
			draw_colored_polygon(_placed(body, centre, unit), ink)
			if active:
				for radius: float in [16.0, 28.0]:
					draw_arc(centre + Vector2(4, 0) * unit, radius * unit, -0.9, 0.9, 16, ink, 5.0 * unit, true)
		Icon.VIBRATION:
			draw_rect(Rect2(centre + Vector2(-13, -24) * unit, Vector2(26, 48) * unit), ink, false, 6.0 * unit)
			if active:
				for side: float in [-1.0, 1.0]:
					for step: float in [24.0, 34.0]:
						var x := side * step * unit
						var half := (14.0 if step < 30.0 else 8.0) * unit
						draw_line(centre + Vector2(x, -half), centre + Vector2(x, half), ink, 5.0 * unit, true)
		Icon.PALETTE:
			# Three dots in the colours of the active skin.
			var dots := [Ui.skin.accent, Ui.skin.star, Ui.skin.success]
			for index in dots.size():
				var angle := -PI / 2.0 + index * TAU / 3.0
				var spot := centre + Vector2.from_angle(angle) * 20.0 * unit
				draw_circle(spot, 15.0 * unit, ink)
				draw_circle(spot, 11.0 * unit, dots[index])
	if not active:
		draw_line(centre + Vector2(-30, 30) * unit, centre + Vector2(30, -30) * unit, ink, 7.0 * unit, true)


static func _placed(points: PackedVector2Array, centre: Vector2, unit: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(centre + point * unit)
	return result
