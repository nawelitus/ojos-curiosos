extends Control
## Shown over the scene when a round ends: a card that pops in with confetti,
## stars that light up one by one, the time and what to do next.

signal replay_pressed
signal scenarios_pressed

const Ui := preload("res://scripts/ui.gd")
const StarRow := preload("res://scripts/star_row.gd")

var stars: int = 0
var seconds: float = 0.0
var best_seconds: float = -1.0
var new_best_time: bool = false
var wrong_taps: int = 0
var hints_used: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.04, 0.05, 0.12, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)  # also swallows touches meant for the scene behind

	var frame := Ui.margin("Frame", 44)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", Ui.card(36))
	frame.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)

	var headline := Ui.label("Headline", "¡Muy bien!", Ui.FONT_TITLE, Ui.skin.accent)
	headline.add_theme_font_override("font", Ui.font(700))
	column.add_child(headline)

	var star_row := StarRow.new()
	star_row.name = "Stars"
	star_row.star_size = 128.0
	star_row.filled = stars
	star_row.star_revealed.connect(func(_index: int) -> void: Ui.notify(self, "found"))
	column.add_child(star_row)

	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 16)
	column.add_child(stats)
	stats.add_child(_stat("TimeLabel", "Tiempo", Ui.format_time(seconds), Ui.skin.primary))
	var best_text := "¡Nuevo récord!" if new_best_time else Ui.format_time(best_seconds)
	stats.add_child(_stat("BestLabel", "Mejor tiempo", best_text,
			Ui.skin.accent if new_best_time else Ui.skin.primary))

	column.add_child(Ui.label("DetailLabel", _detail_text(), Ui.FONT_SMALL, Ui.skin.panel_muted))

	var replay := Ui.button("ReplayButton", "Jugar otra vez", Ui.skin.accent)
	replay.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		replay_pressed.emit())
	column.add_child(replay)

	var scenarios := Ui.button("ScenariosButton", "Escenarios", Ui.skin.primary)
	scenarios.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		scenarios_pressed.emit())
	column.add_child(scenarios)

	_animate_in(shade, panel, star_row)


## One figure with its caption, on a tinted pill.
func _stat(node_name: String, caption: String, value: String, tint: Color) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.add_theme_stylebox_override("panel", Ui.box(Color(tint, 0.14), -1, 14))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	pill.add_child(rows)
	rows.add_child(Ui.label("Caption", caption, Ui.FONT_SMALL, Ui.skin.panel_muted))
	var figure := Ui.label(node_name, value, Ui.FONT_BODY + 6, Ui.skin.panel_text)
	figure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(figure)
	return pill


## Tells the player what the stars were for.
func _detail_text() -> String:
	var mistakes := "Sin errores" if wrong_taps == 0 else ("1 error" if wrong_taps == 1 else "%d errores" % wrong_taps)
	var hints := "sin pistas" if hints_used == 0 else ("1 pista" if hints_used == 1 else "%d pistas" % hints_used)
	return "%s, %s" % [mistakes, hints]


func _animate_in(shade: ColorRect, panel: Control, star_row: StarRow) -> void:
	shade.modulate.a = 0.0
	panel.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.7, 0.7)
	var pop := create_tween().set_parallel(true)
	pop.tween_property(shade, "modulate:a", 1.0, 0.25)
	pop.tween_property(panel, "modulate:a", 1.0, 0.2)
	pop.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.chain().tween_callback(star_row.reveal)
	add_child(_confetti())


## Coloured paper falling from the top of the screen, once.
func _confetti() -> CPUParticles2D:
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	ramp.colors = PackedColorArray([Ui.skin.accent, Ui.skin.star, Ui.skin.primary, Ui.skin.success])

	var confetti := CPUParticles2D.new()
	confetti.name = "Confetti"
	confetti.position = Vector2(size.x * 0.5, -20.0)
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
	confetti.amount = 90
	confetti.lifetime = 3.5
	confetti.one_shot = true
	confetti.explosiveness = 0.55
	confetti.direction = Vector2.DOWN
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 420)
	confetti.initial_velocity_min = 120.0
	confetti.initial_velocity_max = 380.0
	confetti.angular_velocity_min = -320.0
	confetti.angular_velocity_max = 320.0
	confetti.scale_amount_min = 10.0
	confetti.scale_amount_max = 20.0
	confetti.color_initial_ramp = ramp
	confetti.emitting = true
	return confetti
