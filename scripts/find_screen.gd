extends Control
## A solo round: the objects to find at the top, the scene in the middle, and
## the hint and zoom buttons in a bar below it, so nothing covers the picture.

## Emitted once when the round ends, with what was recorded.
signal round_finished(stars: int, seconds: float)
signal replay_requested
signal exit_requested

const Ui := preload("res://scripts/ui.gd")
const Scenario := preload("res://scripts/core/scenario.gd")
const FindRound := preload("res://scripts/core/find_round.gd")
const Progress := preload("res://scripts/core/progress.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const SceneView := preload("res://scripts/scene_view.gd")
const ResultPanel := preload("res://scripts/result_panel.gd")
const Storage := preload("res://scripts/storage.gd")

const TARGETS_PER_ROUND := 8
const CHIP_COLUMNS := 4
const ICON_SIZE := 84
const ZOOM_BUTTON_STEP := 1.5
## The hint circle is this wide and is not centred on the object, so it shows
## the area without pointing at the exact spot.
const HINT_RADIUS := 110.0
const HINT_MAX_OFFSET := 60.0

var scenario_id: String = ""
## Theme the result is recorded under.
var theme_id: String = ""
## Objects to look for. Left empty, a random set is drawn from the scenario.
var target_ids: Array[String] = []
## Where progress is saved. Tests point it at a scratch file.
var progress_path: String = Storage.PROGRESS_PATH

var scenario: Scenario
var game_round: FindRound
var scene_view: SceneView

var _rng := RandomNumberGenerator.new()
var _chips := {}          # object id -> Control
var _status: Label
var _timer: Label
var _hint_button: Button
var _shown_second: int = -1
var _finished := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())
	_rng.randomize()

	var errors: Array[String] = []
	scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(scenario_id), errors)
	if scenario == null:
		push_error("Cannot load scenario '%s': %s" % [scenario_id, "; ".join(errors)])
		_show_load_error()
		return
	if target_ids.is_empty():
		var pool: Array[String] = []
		for object in scenario.objects:
			pool.append(object["id"])
		target_ids = FindRound.draw_targets(pool, TARGETS_PER_ROUND, _rng)
	game_round = FindRound.new(target_ids)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	column.add_child(_build_header())

	scene_view = SceneView.new()
	scene_view.name = "SceneView"
	scene_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scene_view)
	scene_view.setup(scenario)
	scene_view.set_targets(target_ids)
	scene_view.tapped.connect(_on_tapped)

	column.add_child(_build_bottom_bar())
	_update_status()
	_update_clock()


func _process(delta: float) -> void:
	if game_round == null or _finished:
		return
	game_round.tick(delta)
	_update_clock()


func _build_header() -> Control:
	var frame := Ui.margin("Header", 12)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	frame.add_child(rows)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	rows.add_child(top)
	var back := Ui.button("BackButton", "Salir", Ui.skin.neutral, Ui.FONT_SMALL)
	back.custom_minimum_size = Vector2(120, 64)
	back.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		exit_requested.emit())
	top.add_child(back)
	_status = Ui.label("StatusLabel", "", Ui.FONT_BODY)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)
	_timer = Ui.label("TimerLabel", "", Ui.FONT_BODY, Ui.skin.muted)
	_timer.custom_minimum_size = Vector2(120, 0)
	top.add_child(_timer)

	var chips := GridContainer.new()
	chips.name = "Chips"
	chips.columns = CHIP_COLUMNS
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	rows.add_child(chips)
	for object_id in target_ids:
		var chip := _build_chip(scenario.find_object(object_id))
		chips.add_child(chip)
		_chips[object_id] = chip
	return frame


## One entry of the list: the picture of the object, cut out, and its name.
func _build_chip(object: Dictionary) -> Control:
	var chip := VBoxContainer.new()
	chip.name = "Chip_%s" % object["id"]
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_constant_override("separation", 0)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = ScenarioLoader.object_icon(scenario, object["id"])
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(icon)

	# Long names must not widen the chip and push the grid off the screen.
	# Long names (Espantapájaros, Transbordador) get a smaller type so they fit whole.
	var name_size := Ui.FONT_SMALL if String(object["name"]).length() <= 9 else Ui.FONT_SMALL - 6
	var name_label := Ui.label("Name", object["name"], name_size)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.add_child(name_label)
	return chip


func _build_bottom_bar() -> Control:
	var frame := Ui.margin("BottomBar", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)

	_hint_button = Ui.button("HintButton", "Pista", Ui.skin.accent, Ui.FONT_BODY)
	_hint_button.custom_minimum_size = Vector2(240, 96)
	_hint_button.pressed.connect(_on_hint_pressed)
	row.add_child(_hint_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_make_zoom_button("ZoomOut", "−", 1.0 / ZOOM_BUTTON_STEP))
	row.add_child(_make_zoom_button("ZoomIn", "+", ZOOM_BUTTON_STEP))
	return frame


func _make_zoom_button(node_name: String, text: String, factor: float) -> Button:
	var button := Ui.button(node_name, text, Ui.skin.primary, 56)
	button.custom_minimum_size = Vector2(110, 96)
	button.pressed.connect(func() -> void: scene_view.zoom_by(factor))
	return button


func _on_tapped(object_id: String, world_point: Vector2) -> void:
	match game_round.register_tap(object_id):
		FindRound.Tap.FOUND:
			scene_view.mark_found(object_id)
			var chip: Control = _chips[object_id]
			chip.modulate = Color(1, 1, 1, 0.3)
			_update_status()
			if game_round.is_complete():
				_finish()
			else:
				Ui.notify(self, "found")
		FindRound.Tap.MISS:
			scene_view.show_miss(world_point, FindRound.LOCKOUT_SECONDS)
			Ui.notify(self, "miss")


func _on_hint_pressed() -> void:
	var object_id := game_round.use_hint(_rng)
	if object_id.is_empty():
		return
	var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * HINT_MAX_OFFSET
	scene_view.show_hint(scenario.find_object(object_id)["position"] + offset, HINT_RADIUS)
	Ui.notify(self, "hint")
	_shown_second = -1
	_update_clock()


func _finish() -> void:
	_finished = true
	_hint_button.disabled = true
	var stars := game_round.stars()
	var progress: Progress = Storage.load_progress(progress_path)
	var beaten := progress.record(theme_id, stars, game_round.elapsed)
	Storage.save_progress(progress, progress_path)
	Ui.notify(self, "win")

	var panel := ResultPanel.new()
	panel.name = "ResultPanel"
	panel.stars = stars
	panel.seconds = game_round.elapsed
	panel.best_seconds = progress.best_time(theme_id)
	panel.new_best_time = beaten["new_best_time"]
	panel.wrong_taps = game_round.wrong_taps
	panel.hints_used = game_round.hints_used
	panel.replay_pressed.connect(func() -> void: replay_requested.emit())
	panel.scenarios_pressed.connect(func() -> void: exit_requested.emit())
	add_child(panel)
	round_finished.emit(stars, game_round.elapsed)


func _update_status() -> void:
	_status.text = "Encuentra: %d de %d" % [game_round.found.size(), game_round.targets.size()]


## Refreshes the clock and the hint button once per second, not every frame.
func _update_clock() -> void:
	var second := int(game_round.elapsed)
	if second == _shown_second:
		return
	_shown_second = second
	_timer.text = Ui.format_time(game_round.elapsed)
	var wait := game_round.hint_wait()
	_hint_button.disabled = not game_round.can_hint()
	_hint_button.text = "Pista" if wait <= 0.0 else "Pista en %d" % ceili(wait)


func _show_load_error() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	column.add_child(Ui.label("ErrorLabel", "No se pudo cargar el escenario.", Ui.FONT_BODY, Ui.skin.accent))
	var back := Ui.button("BackButton", "Volver", Ui.skin.neutral, Ui.FONT_BODY)
	back.pressed.connect(func() -> void: exit_requested.emit())
	column.add_child(back)
