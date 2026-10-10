extends Control
## Entry to the LAN game: pick who you are (colour and animal), then create a
## room or join one of the rooms found on the Wi-Fi network.

signal create_pressed(avatar: int)
signal join_pressed(ip: String, port: int, avatar: int)
signal back_pressed

const Ui := preload("res://scripts/ui.gd")
const Avatars := preload("res://scripts/net/avatars.gd")
const AvatarBadge := preload("res://scripts/net/avatar_badge.gd")
const Protocol := preload("res://scripts/net/protocol.gd")

var avatar: int = 0

## Seconds without any room before the screen suggests typing the address.
const HINT_AFTER := 8.0
## Below this many packets sent, "nobody answers" says nothing yet.
const ENOUGH_SENT := 30

## Returns the search statistics (LanDiscovery.diagnostics). Set by the owner.
var diagnostics_provider: Callable

var _diagnostics_label: Label
var _diagnostics_panel: Control
var _diagnostics_button: Button

var _waited: float = 0.0
var _hint_shown: bool = false
var _badges: Array[Control] = []
var _rooms_box: VBoxContainer
var _message: Label
var _address_panel: Control
var _address_edit: LineEdit
var _searching: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Ui.background())

	var frame := Ui.margin("Frame")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	scroll.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)
	var back := Ui.button("BackButton", "Volver", Ui.skin.neutral, Ui.FONT_BODY)
	back.custom_minimum_size = Vector2(170, 88)
	back.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		back_pressed.emit())
	top.add_child(back)
	var title := Ui.label("TitleLabel", "Jugar en red", Ui.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(title)

	column.add_child(Ui.label("WhoLabel", "¿Quién eres?", Ui.FONT_BODY))
	column.add_child(_build_avatar_grid())

	var create := Ui.button("CreateButton", "Crear sala", Ui.skin.accent, Ui.FONT_HEADING)
	create.custom_minimum_size = Vector2(0, 130)
	create.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		create_pressed.emit(avatar))
	column.add_child(create)

	column.add_child(Ui.label("RoomsLabel", "Salas cerca", Ui.FONT_BODY))
	_searching = Ui.label("SearchingLabel", "Buscando salas…", Ui.FONT_SMALL, Ui.skin.muted)
	column.add_child(_searching)
	_rooms_box = VBoxContainer.new()
	_rooms_box.name = "Rooms"
	_rooms_box.add_theme_constant_override("separation", 14)
	column.add_child(_rooms_box)

	_message = Ui.label("MessageLabel", "", Ui.FONT_SMALL, Ui.skin.accent)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)

	var manual := Ui.button("ManualButton", "Escribir la dirección", Ui.skin.neutral, Ui.FONT_SMALL)
	manual.custom_minimum_size = Vector2(0, 80)
	manual.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		_address_panel.visible = not _address_panel.visible)
	column.add_child(manual)
	_address_panel = _build_address_panel()
	_address_panel.visible = false
	column.add_child(_address_panel)

	# Hidden until the search has found nothing for a while: children have no use
	# for it, and that is exactly when a parent does.
	_diagnostics_button = Ui.button("DiagnosticsButton", "Ver diagnóstico de red", Ui.skin.neutral, Ui.FONT_SMALL)
	_diagnostics_button.custom_minimum_size = Vector2(0, 72)
	_diagnostics_button.visible = false
	_diagnostics_button.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		_diagnostics_panel.visible = not _diagnostics_panel.visible
		_refresh_diagnostics())
	column.add_child(_diagnostics_button)
	_diagnostics_panel = PanelContainer.new()
	_diagnostics_panel.name = "DiagnosticsPanel"
	_diagnostics_panel.add_theme_stylebox_override("panel", Ui.card(16))
	_diagnostics_panel.visible = false
	_diagnostics_label = Ui.label("DiagnosticsLabel", "", Ui.FONT_SMALL, Ui.skin.panel_text)
	_diagnostics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostics_panel.add_child(_diagnostics_label)
	column.add_child(_diagnostics_panel)
	Ui.pass_touches(column)


## When no room shows up the usual cause is the network, not the game, so the
## screen says what to do instead of searching forever.
func _process(delta: float) -> void:
	_diagnostics_clock += delta
	if _diagnostics_clock >= 0.5:
		_diagnostics_clock = 0.0
		_refresh_diagnostics()
	if _hint_shown or _rooms_box == null or _rooms_box.get_child_count() > 0:
		return
	_waited += delta
	if _waited >= HINT_AFTER:
		_hint_shown = true
		_searching.text = "No aparece ninguna sala. Pídele al anfitrión la dirección que muestra su pantalla y escríbela aquí abajo."
		_searching.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_address_panel.visible = true
		_diagnostics_button.visible = true


var _diagnostics_clock: float = 0.0


func _refresh_diagnostics() -> void:
	if _diagnostics_panel == null or not _diagnostics_panel.visible or not diagnostics_provider.is_valid():
		return
	_diagnostics_label.text = format_diagnostics(diagnostics_provider.call())


## Plain-language reading of LanDiscovery.diagnostics(): the numbers, then what
## they most likely mean.
static func format_diagnostics(stats: Dictionary) -> String:
	var addresses: Array = stats.get("addresses", [])
	var sent: int = stats.get("sent", 0)
	var errors: int = stats.get("send_errors", 0)
	var received: int = stats.get("received", 0)
	var lines: Array[String] = []
	lines.append("Mi dirección: %s" % (", ".join(PackedStringArray(addresses)) if not addresses.is_empty() else "ninguna"))
	lines.append("Salas encontradas: %d" % stats.get("rooms", 0))
	lines.append("Búsquedas enviadas: %d (con error: %d)" % [sent, errors])
	lines.append("Respuestas recibidas: %d" % received)
	if addresses.is_empty():
		lines.append("→ Este dispositivo no tiene una dirección de red local. Conéctalo al Wi-Fi.")
	elif sent >= ENOUGH_SENT and errors * 2 >= sent:
		lines.append("→ El dispositivo no deja enviar por la red local. Revisa los permisos de la app (Dispositivos cercanos).")
	elif sent >= ENOUGH_SENT and received == 0:
		lines.append("→ Nadie contesta. La sala puede estar en otra red Wi-Fi (repetidor, red de invitados o banda distinta). Compara las direcciones: deben empezar igual.")
	elif received > 0 and stats.get("rooms", 0) == 0:
		lines.append("→ Llegan mensajes pero no de una sala. Revisa que todos tengan la misma versión del juego.")
	return "\n".join(lines)


func set_rooms(rooms: Array) -> void:
	for child in _rooms_box.get_children():
		_rooms_box.remove_child(child)  # out of the tree now, so names do not clash
		child.queue_free()
	_searching.visible = rooms.is_empty()
	for room: Dictionary in rooms:
		_rooms_box.add_child(_room_button(room))
	Ui.pass_touches(_rooms_box)


func show_message(text: String) -> void:
	_message.text = text


func _build_avatar_grid() -> Control:
	var grid := GridContainer.new()
	grid.name = "Avatars"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for index in Avatars.count():
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 0)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var holder := Button.new()
		holder.name = "Avatar_%d" % index
		holder.flat = true
		holder.focus_mode = Control.FOCUS_NONE
		holder.custom_minimum_size = Vector2(0, 112)
		holder.pressed.connect(_select_avatar.bind(index))
		var badge := AvatarBadge.new()
		badge.avatar = index
		badge.diameter = 100.0
		badge.selected = index == avatar
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		badge.position -= Vector2(50, 50)
		holder.add_child(badge)
		_badges.append(badge)
		item.add_child(holder)
		item.add_child(Ui.label("Name", Avatars.name_of(index), Ui.FONT_SMALL))
		grid.add_child(item)
	return grid


func _select_avatar(index: int) -> void:
	Ui.notify(self, "button")
	avatar = index
	for i in _badges.size():
		(_badges[i] as AvatarBadge).selected = i == index


func _room_button(room: Dictionary) -> Control:
	var is_open: bool = room["open"]
	var count: int = room["players"]
	var caption := "Sala de %s · %d %s" % [Avatars.name_of(room["avatar"]), count,
			"jugador" if count == 1 else "jugadores"]
	if not is_open:
		caption = "Sala de %s · en juego" % Avatars.name_of(room["avatar"])
	var button := Ui.button("Room_%s" % str(room["ip"]).replace(".", "_"), caption,
			Ui.skin.primary, Ui.FONT_BODY)
	button.custom_minimum_size = Vector2(0, 104)
	button.disabled = not is_open
	var ip: String = room["ip"]
	var port: int = room["port"]
	button.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		join_pressed.emit(ip, port, avatar))
	return button


## Numbers and dots only: there is no free text anywhere in the LAN game.
func _build_address_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "AddressPanel"
	panel.add_theme_constant_override("separation", 12)
	_address_edit = LineEdit.new()
	_address_edit.name = "AddressEdit"
	_address_edit.placeholder_text = "192.168.0.10"
	_address_edit.max_length = 15
	_address_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_address_edit.custom_minimum_size = Vector2(0, 96)
	_address_edit.add_theme_font_size_override("font_size", Ui.font_size(Ui.FONT_BODY))
	_address_edit.text_changed.connect(func(text: String) -> void:
		var clean := ""
		for character in text:
			if character == "." or (character >= "0" and character <= "9"):
				clean += character
		if clean != text:
			_address_edit.text = clean
			_address_edit.caret_column = clean.length())
	panel.add_child(_address_edit)
	var join := Ui.button("JoinAddressButton", "Unirme", Ui.skin.primary, Ui.FONT_BODY)
	join.pressed.connect(func() -> void:
		Ui.notify(self, "button")
		if _address_edit.text.is_valid_ip_address():
			join_pressed.emit(_address_edit.text, Protocol.GAME_PORT, avatar)
		else:
			show_message("Esa dirección no es válida."))
	panel.add_child(join)
	return panel
