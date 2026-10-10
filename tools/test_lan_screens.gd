extends "res://tools/testing/harness.gd"
## The LAN screens of a host and of a guest, connected through the real
## network layer on this machine, driven with synthetic taps.

const LanHost := preload("res://scripts/net/lan_host.gd")
const LanClient := preload("res://scripts/net/lan_client.gd")
const Protocol := preload("res://scripts/net/protocol.gd")
const LanMenuScreen := preload("res://scripts/net/lan_menu_screen.gd")
const LanLobbyScreen := preload("res://scripts/net/lan_lobby_screen.gd")
const LanRoundScreen := preload("res://scripts/net/lan_round_screen.gd")
const Ui := preload("res://scripts/ui.gd")

const TARGETS: Array[String] = ["crab", "duck", "kite"]
const POSITIONS := {"crab": Vector2(312, 1249), "duck": Vector2(970, 745), "kite": Vector2(283, 823)}


func run() -> void:
	root.size = Vector2i(720, 1280)
	await _test_menu()
	await _test_round()


func _test_menu() -> void:
	var menu: LanMenuScreen = LanMenuScreen.new()
	root.add_child(menu)
	await process_frame
	check(menu.find_child("CreateButton", true, false) != null, "the menu has the create button")
	check(menu.find_child("SearchingLabel", true, false).visible, "it says it is searching while there are no rooms")
	var avatars := 0
	for child in menu.find_child("Avatars", true, false).get_children():
		avatars += 1
	check(avatars == 8, "it offers the eight avatars")

	# With no room for a while the screen suggests typing the address.
	var address_panel: Control = menu.find_child("AddressPanel", true, false)
	var diagnostics_button: Control = menu.find_child("DiagnosticsButton", true, false)
	check(not address_panel.visible and not diagnostics_button.visible,
			"the address field and the diagnostics button start hidden")
	menu._process(menu.HINT_AFTER - 1.0)
	check(not address_panel.visible and not diagnostics_button.visible, "and stay hidden at first")
	menu._process(2.0)
	check(address_panel.visible and diagnostics_button.visible,
			"after a few seconds without rooms the address field opens and the diagnostics appear")
	check((menu.find_child("SearchingLabel", true, false) as Label).text.contains("dirección"),
			"and the searching text says what to do")
	address_panel.visible = false

	# The diagnostics panel reads the numbers and explains them.
	var shown := {"stats": {"addresses": ["192.168.1.20"], "sent": 5, "send_errors": 0,
			"last_error": 0, "received": 0, "answers": 0, "rooms": 0}}
	menu.diagnostics_provider = func() -> Dictionary: return shown["stats"]
	var panel: Control = menu.find_child("DiagnosticsPanel", true, false)
	check(panel != null and not panel.visible, "the diagnostics are hidden at first")
	(menu.find_child("DiagnosticsButton", true, false) as Button).pressed.emit()
	check(panel.visible, "the button shows them")
	var text: String = (menu.find_child("DiagnosticsLabel", true, false) as Label).text
	check(text.contains("192.168.1.20") and text.contains("Búsquedas enviadas: 5"), "with the address and the counts")
	check(not text.contains("→"), "and no conclusion while little has been sent")
	var LanMenu := preload("res://scripts/net/lan_menu_screen.gd")
	var no_network := LanMenu.format_diagnostics({"addresses": [], "sent": 0, "send_errors": 0, "received": 0, "rooms": 0})
	check(no_network.contains("no tiene una dirección"), "no address says to connect to Wi-Fi")
	var blocked := LanMenu.format_diagnostics({"addresses": ["10.0.0.5"], "sent": 100, "send_errors": 100, "received": 0, "rooms": 0})
	check(blocked.contains("no deja enviar"), "sends failing says the device is blocked")
	var silent := LanMenu.format_diagnostics({"addresses": ["10.0.0.5"], "sent": 100, "send_errors": 0, "received": 0, "rooms": 0})
	check(silent.contains("Nadie contesta"), "no answers says the room may be on another network")
	var healthy := LanMenu.format_diagnostics({"addresses": ["10.0.0.5"], "sent": 100, "send_errors": 0, "received": 4, "rooms": 1})
	check(not healthy.contains("→"), "a healthy search adds no warning")
	panel.visible = false

	var created := {"avatar": -1}
	menu.create_pressed.connect(func(avatar: int) -> void: created["avatar"] = avatar)
	(menu.find_child("Avatar_4", true, false) as Button).pressed.emit()
	(menu.find_child("CreateButton", true, false) as Button).pressed.emit()
	check(created["avatar"] == 4, "creating a room uses the chosen avatar")

	var joined := {"ip": "", "port": 0, "avatar": -1}
	menu.join_pressed.connect(func(ip: String, port: int, avatar: int) -> void:
		joined["ip"] = ip
		joined["port"] = port
		joined["avatar"] = avatar)
	menu.set_rooms([
		{"ip": "192.168.1.20", "port": 24842, "players": 3, "avatar": 1, "open": true},
		{"ip": "192.168.1.21", "port": 24842, "players": 2, "avatar": 5, "open": false},
	])
	await process_frame
	check(not menu.find_child("SearchingLabel", true, false).visible, "the searching text goes away")
	var open_room: Button = menu.find_child("Room_192_168_1_20", true, false)
	var busy_room: Button = menu.find_child("Room_192_168_1_21", true, false)
	check(open_room != null and not open_room.disabled and busy_room != null and busy_room.disabled,
			"an open room can be joined and one in play cannot")
	check(open_room.text == "Sala de Pulpo · 3 jugadores", "the room says who hosts it and how many are in")
	open_room.pressed.emit()
	check(joined["ip"] == "192.168.1.20" and joined["port"] == 24842 and joined["avatar"] == 4,
			"joining sends the address and the avatar")

	var edit: LineEdit = menu.find_child("AddressEdit", true, false)
	edit.text = "192.x168.0.5abc"
	edit.text_changed.emit(edit.text)
	check(edit.text == "192.168.0.5", "the address field keeps only digits and dots")
	joined["ip"] = ""
	edit.text = "300.1"
	(menu.find_child("JoinAddressButton", true, false) as Button).pressed.emit()
	check(joined["ip"] == "", "an invalid address is not sent")
	edit.text = "192.168.0.5"
	(menu.find_child("JoinAddressButton", true, false) as Button).pressed.emit()
	check(joined["ip"] == "192.168.0.5" and joined["port"] == Protocol.GAME_PORT, "a valid one joins the default port")
	menu.queue_free()
	await process_frame


func _test_round() -> void:
	var host: LanHost = LanHost.new()
	root.add_child(host)
	check(host.open(2), "the host opens a room")
	var guest: LanClient = LanClient.new()
	root.add_child(guest)
	check(guest.join("127.0.0.1", Protocol.GAME_PORT, 5), "a guest joins it")
	check(await _until(func() -> bool: return guest.is_connected_to_room and host.session.player_count() == 2),
			"both are in the room")

	# --- lobbies ----------------------------------------------------------------
	var host_lobby: LanLobbyScreen = LanLobbyScreen.new()
	host_lobby.is_host = true
	host_lobby.my_id = LanHost.LOCAL_ID
	host_lobby.themes = [{"id": "beach", "title": "Playa"}, {"id": "city", "title": "Ciudad"}]
	host_lobby.address_text = "192.168.0.7"
	root.add_child(host_lobby)
	await process_frame
	host_lobby.set_players([{"id": 1, "avatar": 2, "score": 0, "rank": 0}])
	var start: Button = host_lobby.find_child("StartButton", true, false)
	check(start.disabled and start.text == "Esperando jugadores…", "alone, the host cannot start")
	host_lobby.set_players(host.session.player_list())
	check(not start.disabled and start.text == "¡Empezar!", "with two players it can")
	check(host_lobby.find_child("Theme_beach", true, false) != null, "and it can pick the scenario")
	check((host_lobby.find_child("AddressLabel", true, false) as Label).text.ends_with("192.168.0.7"),
			"it shows its address for guests to type")
	var asked := {"theme": ""}
	host_lobby.start_pressed.connect(func(theme_id: String) -> void: asked["theme"] = theme_id)
	(host_lobby.find_child("Theme_city", true, false) as Button).pressed.emit()
	start.pressed.emit()
	check(asked["theme"] == "city", "starting asks for the chosen scenario")
	var rows := host_lobby.find_child("Players", true, false).get_child_count()
	check(rows == 2, "the list shows both players")
	host_lobby.queue_free()

	var guest_lobby: LanLobbyScreen = LanLobbyScreen.new()
	guest_lobby.my_id = guest.you
	root.add_child(guest_lobby)
	await process_frame
	check(guest_lobby.find_child("StartButton", true, false) == null, "a guest has no start button")
	check(guest_lobby.find_child("StatusLabel", true, false) != null, "it waits for the host instead")
	guest_lobby.queue_free()

	# --- the round on both screens -------------------------------------------------
	var guest_log := {"started": false}
	guest.round_started.connect(func(_s: String, _t: Array, _n: int, _p: Array) -> void: guest_log["started"] = true)
	check(host.start_round("beach_1", TARGETS), "the host starts the round")
	check(await _until(func() -> bool: return guest_log["started"]), "the guest is told")

	var host_screen: LanRoundScreen = _round_screen(host, true, LanHost.LOCAL_ID, host.session.player_list())
	var guest_screen: LanRoundScreen = _round_screen(guest, false, guest.you, host.session.player_list())
	root.add_child(host_screen)
	root.add_child(guest_screen)
	await process_frame
	await process_frame
	check(host_screen.scene_view != null and guest_screen.scene_view != null, "both screens loaded the scenario")
	if host_screen.scene_view == null or guest_screen.scene_view == null:
		return
	check(host_screen.find_child("Chips", true, false).get_child_count() == 3
			and guest_screen.find_child("Chips", true, false).get_child_count() == 3, "both list the same three objects")
	check(host_screen.find_child("Scoreboard", true, false).get_child_count() == 2, "and show two players on the board")
	check((host_screen.find_child("ClockLabel", true, false) as Label).text == "3:00", "with the clock at 3:00")
	check(host_screen.find_child("HintButton", true, false) == null, "there is no hint button in the LAN game")

	# The guest finds the crab: both screens ring it and score it for the guest.
	guest_screen.scene_view.tap(guest_screen.scene_view.view.world_to_screen(POSITIONS["crab"]))
	var crab_everywhere := func() -> bool:
		return host_screen.scene_view.is_found("crab") and guest_screen.scene_view.is_found("crab")
	check(await _until(crab_everywhere), "a find shows up on both screens")
	check(host_screen.find_child("Found_crab", true, false) != null, "with its ring")
	check(host.session.found.get("crab", 0) == guest.you, "credited to the guest")
	check(_score_of(host_screen, guest.you) == "1" and _score_of(guest_screen, guest.you) == "1",
			"and the board shows the point on both")
	check(_score_of(host_screen, LanHost.LOCAL_ID) == "0", "while the host still has none")

	# A miss pauses only the one who missed.
	guest_screen.scene_view.tap(guest_screen.scene_view.view.world_to_screen(Vector2(700, 420)))
	check(guest_screen.scene_view.find_child("Miss", true, false) != null, "a wrong tap leaves a mark")
	guest_screen.scene_view.tap(guest_screen.scene_view.view.world_to_screen(POSITIONS["duck"]))
	await _wait(0.4)
	check(not host.session.found.has("duck"), "and the next tap during the pause finds nothing")
	host_screen.scene_view.tap(host_screen.scene_view.view.world_to_screen(POSITIONS["duck"]))
	check(await _until(func() -> bool: return host_screen.scene_view.is_found("duck")), "the host is not paused")
	check(await _until(func() -> bool: return guest_screen.scene_view.is_found("duck")), "and the guest sees it")

	# Everything found: both screens show the ranking.
	host_screen.scene_view.tap(host_screen.scene_view.view.world_to_screen(POSITIONS["kite"]))
	var both_results := func() -> bool:
		return host_screen.find_child("ResultPanel", true, false) != null \
				and guest_screen.find_child("ResultPanel", true, false) != null
	check(await _until(both_results), "both screens show the results")
	var host_headline := (host_screen.find_child("Headline", true, false) as Label).text
	var guest_headline := (guest_screen.find_child("Headline", true, false) as Label).text
	check(host_headline == "¡Ganaste!" and guest_headline == "¡Buen juego!",
			"the host (2 finds) wins over the guest (1) (%s / %s)" % [host_headline, guest_headline])
	check(host_screen.find_child("Rank_%d" % guest.you, true, false) != null, "the ranking lists everybody")

	var asked_lobby := {"host": 0, "guest": 0}
	host_screen.lobby_requested.connect(func() -> void: asked_lobby["host"] += 1)
	guest_screen.leave_requested.connect(func() -> void: asked_lobby["guest"] += 1)
	(host_screen.find_child("LobbyButton", true, false) as Button).pressed.emit()
	(guest_screen.find_child("LeaveButton", true, false) as Button).pressed.emit()
	check(asked_lobby["host"] == 1 and asked_lobby["guest"] == 1, "the result buttons ask to go back or to leave")

	host_screen.queue_free()
	guest_screen.queue_free()
	guest.leave()
	host.close()
	await _wait(0.8)


func _round_screen(net: Node, is_host: bool, my_id: int, players: Array) -> LanRoundScreen:
	var screen: LanRoundScreen = LanRoundScreen.new()
	screen.net = net
	screen.is_host = is_host
	screen.my_id = my_id
	screen.scenario_id = "beach_1"
	screen.target_ids = TARGETS.duplicate()
	screen.seconds = 180
	screen.players = players
	return screen


func _score_of(screen: LanRoundScreen, player_id: int) -> String:
	var item := screen.find_child("Score_%d" % player_id, true, false)
	return "" if item == null else (item.find_child("Points", true, false) as Label).text


func _until(condition: Callable, seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _wait(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
