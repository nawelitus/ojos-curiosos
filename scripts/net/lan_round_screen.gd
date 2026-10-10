extends Control
## A LAN round: the same picture and the same list for everybody, a clock
## counting down, the score of each player and a ring in the finder's colour on
## every object found. The host decides; this screen only shows and taps.

signal leave_requested
signal lobby_requested

const Ui := preload("res://scripts/ui.gd")
const Scenario := preload("res://scripts/core/scenario.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const SceneView := preload("res://scripts/scene_view.gd")
const Avatars := preload("res://scripts/net/avatars.gd")
const AvatarBadge := preload("res://scripts/net/avatar_badge.gd")
const LanSession := preload("res://scripts/net/lan_session.gd")
const ResultPanel := preload("res://scripts/net/lan_result_panel.gd")

const CHIP_COLUMNS := 4
const ICON_SIZE := 72
const ZOOM_BUTTON_STEP := 1.5

## The host or the client node: both have tap() and the same signals.
var net: Node
var is_host: bool = false
var my_id: int = 0
var scenario_id: String = ""
var target_ids: Array[String] = []
var seconds: int = LanSession.ROUND_SECONDS
var players: Array = []

var scenario: Scenario
var scene_view: SceneView

var _chips: Dictionary = {}        # object id -> Control
var _scores: Dictionary = {}       # player id -> Label
var _found: Dictionary = {}        # object id -> player id
var _clock: Label
var _left: float = 0.0
var _shown_second: int = -1
var _locked_left: float = 0.0
var _ended: bool = false
var _connections: Array[Array] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())
	_left = float(seconds)

	var errors: Array[String] = []
	scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(scenario_id), errors)
	if scenario != null:
		for object_id in target_ids:
			if scenario.find_object(object_id).is_empty():
				scenario = null
				break
	if scenario == null:
		push_error("Cannot play scenario '%s': %s" % [scenario_id, "; ".join(errors)])
		_show_load_error()
		return

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
	_connect(net, "object_found", _on_object_found)
	_connect(net, "time_changed", _on_time_changed)
	_connect(net, "round_ended", _on_round_ended)
	_connect(net, "lobby_changed", _on_lobby_changed)
	if net.has_signal("missed"):
		_connect(net, "missed", _on_local_miss)
	_update_scores(players)
	_update_clock()


func _exit_tree() -> void:
	for connection in _connections:
		var source: Object = connection[0]
		if is_instance_valid(source) and source.is_connected(connection[1], connection[2]):
			source.disconnect(connection[1], connection[2])


func _process(delta: float) -> void:
	if scenario == null or _ended:
		return
	_left = maxf(_left - delta, 0.0)
	_locked_left = maxf(_locked_left - delta, 0.0)
	_update_clock()


func _connect(source: Object, signal_name: String, callable: Callable) -> void:
	source.connect(signal_name, callable)
	_connections.append([source, signal_name, callable])


func _build_header() -> Control:
	var frame := Ui.margin("Header", 12)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	frame.add_child(rows)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	rows.add_child(top)
	var leave := Ui.button("LeaveButton", "Salir", Ui.skin.neutral, Ui.FONT_SMALL)
	leave.custom_minimum_size = Vector2(120, 64)
	leave.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		leave_requested.emit())
	top.add_child(leave)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_clock = Ui.label("ClockLabel", "", Ui.FONT_HEADING)
	top.add_child(_clock)

	var scoreboard := HBoxContainer.new()
	scoreboard.name = "Scoreboard"
	scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
	scoreboard.add_theme_constant_override("separation", 6)
	rows.add_child(scoreboard)

	var chips := GridContainer.new()
	chips.name = "Chips"
	chips.columns = CHIP_COLUMNS
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 2)
	rows.add_child(chips)
	for object_id in target_ids:
		var chip := _build_chip(scenario.find_object(object_id))
		chips.add_child(chip)
		_chips[object_id] = chip
	return frame


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
	var name_label := Ui.label("Name", object["name"], Ui.FONT_SMALL - 4)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.add_child(name_label)
	return chip


func _build_bottom_bar() -> Control:
	var frame := Ui.margin("BottomBar", 12)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)
	row.add_child(_make_zoom_button("ZoomOut", "−", 1.0 / ZOOM_BUTTON_STEP))
	row.add_child(_make_zoom_button("ZoomIn", "+", ZOOM_BUTTON_STEP))
	return frame


func _make_zoom_button(node_name: String, text: String, factor: float) -> Button:
	var button := Ui.button(node_name, text, Ui.skin.primary, 56)
	button.custom_minimum_size = Vector2(110, 96)
	button.pressed.connect(func() -> void: scene_view.zoom_by(factor))
	return button


## One tap. Nothing is decided here: the host says who found what.
func _on_tapped(object_id: String, world_point: Vector2) -> void:
	if _ended or _locked_left > 0.0:
		return
	if not object_id.is_empty() and _found.has(object_id):
		return  # already found by somebody: no penalty, nothing to send
	if object_id.is_empty():
		scene_view.show_miss(world_point, LanSession.LOCKOUT_SECONDS)
		_locked_left = LanSession.LOCKOUT_SECONDS
		Ui.notify(self, "miss")
	net.tap(object_id)


func _on_local_miss() -> void:
	pass  # the screen already showed it when the tap happened


func _on_object_found(object_id: String, player_id: int, players_now: Array) -> void:
	if _found.has(object_id):
		return
	_found[object_id] = player_id
	var avatar := _avatar_of(player_id, players_now)
	scene_view.mark_found(object_id, Avatars.color_of(avatar))
	var chip: Control = _chips.get(object_id)
	if chip != null:
		chip.modulate = Color(1, 1, 1, 0.3)
	_update_scores(players_now)
	Ui.notify(self, "found" if player_id == my_id else "button")


func _on_time_changed(left: float) -> void:
	_left = left


func _on_lobby_changed(players_now: Array) -> void:
	_update_scores(players_now)


func _on_round_ended(reason: String, players_now: Array) -> void:
	if _ended:
		return
	_ended = true
	_update_scores(players_now)
	var panel := ResultPanel.new()
	panel.name = "ResultPanel"
	panel.players = players_now
	panel.my_id = my_id
	panel.reason = reason
	panel.is_host = is_host
	panel.lobby_pressed.connect(func() -> void: lobby_requested.emit())
	panel.leave_pressed.connect(func() -> void: leave_requested.emit())
	add_child(panel)


func _update_scores(players_now: Array) -> void:
	if players_now.is_empty():
		return
	players = players_now
	var board: HBoxContainer = find_child("Scoreboard", true, false)
	if board == null:
		return
	for child in board.get_children():
		board.remove_child(child)  # out of the tree now, so names do not clash
		child.queue_free()
	_scores.clear()
	for player: Dictionary in players_now:
		var item := HBoxContainer.new()
		item.name = "Score_%d" % player["id"]
		item.add_theme_constant_override("separation", 2)
		var badge := AvatarBadge.new()
		badge.avatar = player["avatar"]
		badge.diameter = 52.0
		badge.selected = player["id"] == my_id
		item.add_child(badge)
		var points := Ui.label("Points", "%d" % player["score"], Ui.FONT_BODY)
		points.custom_minimum_size = Vector2(34, 0)
		item.add_child(points)
		board.add_child(item)
		_scores[player["id"]] = points


func _update_clock() -> void:
	var second := ceili(_left)
	if second == _shown_second:
		return
	_shown_second = second
	_clock.text = Ui.format_time(float(second))
	_clock.add_theme_color_override("font_color",
			Ui.skin.accent if second <= 20 else Ui.skin.text)


func _avatar_of(player_id: int, players_now: Array) -> int:
	for player: Dictionary in players_now:
		if player["id"] == player_id:
			return player["avatar"]
	return 0


func _show_load_error() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	column.add_child(Ui.label("ErrorLabel", "Este escenario no está en tu juego.", Ui.FONT_BODY, Ui.skin.accent))
	var leave := Ui.button("LeaveButton", "Salir", Ui.skin.neutral, Ui.FONT_BODY)
	leave.pressed.connect(func() -> void: leave_requested.emit())
	column.add_child(leave)
