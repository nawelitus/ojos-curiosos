extends Control
## End of a LAN round: the ranking of everybody in the room.

signal lobby_pressed
signal leave_pressed

const Ui := preload("res://scripts/ui.gd")
const Avatars := preload("res://scripts/net/avatars.gd")
const AvatarBadge := preload("res://scripts/net/avatar_badge.gd")

var players: Array = []
var my_id: int = 0
var reason: String = "all_found"
var is_host: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.04, 0.05, 0.12, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var frame := Ui.margin("Frame", 36)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", Ui.card(30))
	frame.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var headline := Ui.label("Headline", _headline(), Ui.FONT_TITLE, Ui.skin.accent)
	headline.add_theme_font_override("font", Ui.font(700))
	column.add_child(headline)
	var why := _reason_text()
	if not why.is_empty():
		column.add_child(Ui.label("ReasonLabel", why, Ui.FONT_SMALL, Ui.skin.panel_muted))

	for player: Dictionary in players:
		column.add_child(_ranking_row(player))

	var again := Ui.button("LobbyButton", "Volver a la sala", Ui.skin.accent)
	again.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		lobby_pressed.emit())
	column.add_child(again)
	var leave := Ui.button("LeaveButton", "Salir", Ui.skin.neutral)
	leave.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		leave_pressed.emit())
	column.add_child(leave)

	if not DisplayServer.get_name() == "headless":
		Ui.notify(self, "win")


func my_rank() -> int:
	for player: Dictionary in players:
		if player["id"] == my_id:
			return player["rank"]
	return 0


func _headline() -> String:
	var winners := 0
	for player: Dictionary in players:
		if player["rank"] == 1:
			winners += 1
	if my_rank() == 1 and winners == 1:
		return "¡Ganaste!"
	if my_rank() == 1:
		return "¡Empate!"
	return "¡Buen juego!"


func _reason_text() -> String:
	match reason:
		"time":
			return "Se acabó el tiempo"
		"players_left":
			return "Los demás jugadores se fueron"
	return ""


func _ranking_row(player: Dictionary) -> Control:
	var is_me: bool = player["id"] == my_id
	var pill := PanelContainer.new()
	pill.name = "Rank_%d" % player["id"]
	var tint: Color = Avatars.color_of(player["avatar"])
	pill.add_theme_stylebox_override("panel", Ui.box(Color(tint, 0.22 if is_me else 0.1), -1, 10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	pill.add_child(row)

	var place := Ui.label("Place", "%d" % player["rank"], Ui.FONT_HEADING, Ui.skin.panel_text)
	place.custom_minimum_size = Vector2(56, 0)
	row.add_child(place)
	var badge := AvatarBadge.new()
	badge.avatar = player["avatar"]
	badge.diameter = 68.0
	row.add_child(badge)
	var text := Avatars.name_of(player["avatar"]) + (" (tú)" if is_me else "")
	var name_label := Ui.label("Name", text, Ui.FONT_BODY, Ui.skin.panel_text)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(Ui.label("Score", "%d" % player["score"], Ui.FONT_HEADING, Ui.skin.panel_text))
	return pill
