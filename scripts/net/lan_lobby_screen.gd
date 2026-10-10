extends Control
## Waiting room: who is in, and (for the host) which scenario to play and the
## button that starts the round.

signal start_pressed(theme_id: String)
signal leave_pressed

const Ui := preload("res://scripts/ui.gd")
const Avatars := preload("res://scripts/net/avatars.gd")
const AvatarBadge := preload("res://scripts/net/avatar_badge.gd")
const Protocol := preload("res://scripts/net/protocol.gd")

var is_host: bool = false
var my_id: int = 0
## [{ "id": String, "title": String }], the themes the host may pick.
var themes: Array = []
## The host's address, shown so guests can type it if discovery fails.
var address_text: String = ""

var _players_box: VBoxContainer
var _start: Button
var _status: Label
var _count: int = 0
var _selected_theme: int = 0
var _theme_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var frame := Ui.margin("Frame")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 20)
	frame.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)
	var leave := Ui.button("LeaveButton", "Salir", Ui.skin.neutral, Ui.FONT_BODY)
	leave.custom_minimum_size = Vector2(150, 88)
	leave.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		leave_pressed.emit())
	top.add_child(leave)
	var title := Ui.label("TitleLabel", "Sala", Ui.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(title)

	if is_host and not address_text.is_empty():
		var address_label := Ui.label("AddressLabel", "Si no te encuentran, que escriban esta dirección: %s" % address_text,
				Ui.FONT_SMALL, Ui.skin.text)
		address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(address_label)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card(20))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	_players_box = VBoxContainer.new()
	_players_box.name = "Players"
	_players_box.add_theme_constant_override("separation", 10)
	card.add_child(_players_box)

	if is_host:
		if themes.size() > 1:
			column.add_child(_build_theme_row())
		_start = Ui.button("StartButton", "Esperando jugadores…", Ui.skin.accent, Ui.FONT_HEADING)
		_start.custom_minimum_size = Vector2(0, 130)
		_start.pressed.connect(func() -> void:
			Ui.notify(self, "button")
			if _count >= Protocol.MIN_PLAYERS and not themes.is_empty():
				start_pressed.emit(themes[_selected_theme]["id"]))
		column.add_child(_start)
	else:
		_status = Ui.label("StatusLabel", "Esperando a que empiece la partida…", Ui.FONT_BODY)
		_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(_status)


func set_players(players: Array) -> void:
	_count = players.size()
	for child in _players_box.get_children():
		_players_box.remove_child(child)  # out of the tree now, so names do not clash
		child.queue_free()
	for player: Dictionary in players:
		_players_box.add_child(_player_row(player))
	if _start != null:
		var ready := _count >= Protocol.MIN_PLAYERS and not themes.is_empty()
		_start.disabled = not ready
		_start.text = "¡Empezar!" if ready else "Esperando jugadores…"


func _player_row(player: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Player_%d" % player["id"]
	row.add_theme_constant_override("separation", 16)
	var badge := AvatarBadge.new()
	badge.avatar = player["avatar"]
	badge.diameter = 80.0
	row.add_child(badge)
	var text := Avatars.name_of(player["avatar"])
	if player["id"] == my_id:
		text += " (tú)"
	var name_label := Ui.label("Name", text, Ui.FONT_BODY, Ui.skin.panel_text)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	return row


func _build_theme_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "Themes"
	row.add_theme_constant_override("separation", 12)
	for index in themes.size():
		var button := Ui.button("Theme_%s" % themes[index]["id"], themes[index]["title"],
				Ui.skin.primary if index == _selected_theme else Ui.skin.neutral, Ui.FONT_SMALL)
		button.custom_minimum_size = Vector2(0, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_theme.bind(index))
		row.add_child(button)
		_theme_buttons.append(button)
	return row


func _select_theme(index: int) -> void:
	Ui.notify(self, "button")
	_selected_theme = index
	for i in _theme_buttons.size():
		var color: Color = Ui.skin.primary if i == index else Ui.skin.neutral
		_theme_buttons[i].add_theme_stylebox_override("normal", Ui.raised_box(color, false))
		_theme_buttons[i].add_theme_stylebox_override("hover", Ui.raised_box(color, false))
