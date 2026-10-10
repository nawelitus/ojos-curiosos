extends Control
## Entry point: shows one screen at a time and moves between them, for the
## solo game and for the LAN game.

const Ui := preload("res://scripts/ui.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const FindRound := preload("res://scripts/core/find_round.gd")
const Scenario := preload("res://scripts/core/scenario.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")
const Storage := preload("res://scripts/storage.gd")
const HomeScreen := preload("res://scripts/home_screen.gd")
const SelectScreen := preload("res://scripts/select_screen.gd")
const FindScreen := preload("res://scripts/find_screen.gd")
const CreditsScreen := preload("res://scripts/credits_screen.gd")
const LanHost := preload("res://scripts/net/lan_host.gd")
const LanClient := preload("res://scripts/net/lan_client.gd")
const LanDiscovery := preload("res://scripts/net/lan_discovery.gd")
const LanMenuScreen := preload("res://scripts/net/lan_menu_screen.gd")
const LanLobbyScreen := preload("res://scripts/net/lan_lobby_screen.gd")
const LanRoundScreen := preload("res://scripts/net/lan_round_screen.gd")

var catalog: Catalog

var _screen: Control
var _rng := RandomNumberGenerator.new()

# LAN game. At most one of _host and _client exists at a time.
var _host: LanHost
var _client: LanClient
var _discovery: LanDiscovery
var _lobby: LanLobbyScreen
var _avatar: int = 0
var _my_id: int = 0
var _last_players: Array = []


func _ready() -> void:
	_rng.randomize()
	var errors: Array[String] = []
	catalog = Storage.load_catalog(errors)
	if catalog == null:
		push_error("Cannot load the catalog: %s" % "; ".join(errors))
	var settings := get_node_or_null("/root/GameSettings")
	_apply_skin(Ui.DEFAULT_SKIN if settings == null else settings.skin_id)
	show_home()


func show_home() -> void:
	var home := HomeScreen.new()
	home.name = "HomeScreen"
	home.hero_texture = _hero_texture()
	home.play_pressed.connect(show_select)
	home.lan_pressed.connect(show_lan_menu)
	home.credits_pressed.connect(show_credits)
	home.skin_change_pressed.connect(_on_skin_change_pressed)
	_show(home)


func show_credits() -> void:
	var credits := CreditsScreen.new()
	credits.name = "CreditsScreen"
	credits.back_pressed.connect(show_home)
	_show(credits)


func show_select() -> void:
	if catalog == null:
		return
	var select := SelectScreen.new()
	select.name = "SelectScreen"
	select.catalog = catalog
	select.progress = Storage.load_progress()
	select.theme_chosen.connect(start_round)
	select.back_pressed.connect(show_home)
	_show(select)


func start_round(theme_id: String) -> void:
	var find := FindScreen.new()
	find.name = "FindScreen"
	find.theme_id = theme_id
	find.scenario_id = catalog.pick_variant(theme_id, _rng)
	find.replay_requested.connect(start_round.bind(theme_id))
	find.exit_requested.connect(show_select)
	_show(find)


# --- LAN game ----------------------------------------------------------------

func show_lan_menu(message: String = "") -> void:
	var menu := LanMenuScreen.new()
	menu.name = "LanMenuScreen"
	menu.avatar = _avatar
	menu.create_pressed.connect(_create_room)
	menu.join_pressed.connect(_join_room)
	menu.back_pressed.connect(func() -> void:
		_stop_discovery()
		show_home())
	_show(menu)
	if not message.is_empty():
		menu.show_message(message)
	_stop_discovery()
	_discovery = LanDiscovery.new()
	add_child(_discovery)
	menu.diagnostics_provider = _discovery.diagnostics
	if _discovery.start():
		_discovery.rooms_changed.connect(func() -> void:
			if is_instance_valid(menu) and _discovery != null:
				menu.set_rooms(_discovery.rooms))
	else:
		menu.show_message("No se pueden buscar salas. Revisa tu conexión Wi-Fi.")


func _create_room(avatar: int) -> void:
	_avatar = avatar
	_stop_discovery()
	var host := LanHost.new()
	add_child(host)
	if not host.open(avatar):
		host.queue_free()
		show_lan_menu("No se pudo crear la sala. Puede que ya haya una abierta en este dispositivo.")
		return
	_host = host
	_my_id = LanHost.LOCAL_ID
	host.lobby_changed.connect(_on_lobby_changed)
	host.round_started.connect(_on_round_started)
	host.round_ended.connect(_on_round_ended)
	host.closed.connect(host.queue_free)
	_show_lobby(host.session.player_list())


func _join_room(ip: String, port: int, avatar: int) -> void:
	_avatar = avatar
	_stop_discovery()
	var client := LanClient.new()
	add_child(client)
	if not client.join(ip, port, avatar):
		client.queue_free()
		show_lan_menu("No se pudo conectar a esa sala.")
		return
	_client = client
	client.joined.connect(_on_joined)
	client.lobby_changed.connect(_on_lobby_changed)
	client.round_started.connect(_on_round_started)
	client.round_ended.connect(_on_round_ended)
	client.rejected.connect(_on_rejected)
	client.host_closed.connect(_on_host_closed)
	client.connection_failed.connect(_on_connection_failed)
	client.closed.connect(client.queue_free)
	if _screen is LanMenuScreen:
		(_screen as LanMenuScreen).show_message("Conectando…")


func _on_joined(you: int, players: Array) -> void:
	_my_id = you
	_last_players = players
	_show_lobby(players)


func _on_rejected(reason: String) -> void:
	_forget_room()
	match reason:
		"full":
			show_lan_menu("La sala está llena.")
		"in_game":
			show_lan_menu("La partida ya empezó. Prueba cuando termine.")
		_:
			show_lan_menu("Esa sala usa otra versión del juego.")


func _on_host_closed() -> void:
	_forget_room()
	show_lan_menu("La sala se cerró.")


func _on_connection_failed() -> void:
	_forget_room()
	show_lan_menu("No se pudo conectar. Revisa que estés en la misma red Wi-Fi.")


func _show_lobby(players: Array) -> void:
	var lobby := LanLobbyScreen.new()
	lobby.name = "LanLobbyScreen"
	lobby.is_host = _host != null
	lobby.my_id = _my_id
	if _host != null:
		lobby.themes = _unlocked_themes()
		lobby.address_text = _local_address()
	lobby.start_pressed.connect(_start_round_as_host)
	lobby.leave_pressed.connect(_leave_room)
	_lobby = lobby
	_show(lobby)
	lobby.set_players(players)


func _on_lobby_changed(players: Array) -> void:
	_last_players = players
	if is_instance_valid(_lobby) and _screen == _lobby:
		_lobby.set_players(players)


func _on_round_ended(_reason: String, players: Array) -> void:
	_last_players = players


## The host draws the objects once and sends the same list to everybody.
func _start_round_as_host(theme_id: String) -> void:
	if _host == null or catalog == null:
		return
	var variant := catalog.pick_variant(theme_id, _rng)
	var errors: Array[String] = []
	var scenario: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(variant), errors)
	if scenario == null:
		push_error("Cannot start LAN round: %s" % "; ".join(errors))
		return
	var pool: Array[String] = []
	for object in scenario.objects:
		pool.append(object["id"])
	_host.start_round(variant, FindRound.draw_targets(pool, FindScreen.TARGETS_PER_ROUND, _rng))


func _on_round_started(scenario_id: String, targets: Array, seconds: int, players: Array) -> void:
	var ids: Array[String] = []
	for target: String in targets:
		ids.append(target)
	var round_screen := LanRoundScreen.new()
	round_screen.name = "LanRoundScreen"
	round_screen.net = _host if _host != null else _client
	round_screen.is_host = _host != null
	round_screen.my_id = _my_id
	round_screen.scenario_id = scenario_id
	round_screen.target_ids = ids
	round_screen.seconds = seconds
	round_screen.players = players
	round_screen.leave_requested.connect(_leave_room)
	round_screen.lobby_requested.connect(_back_to_lobby)
	_show(round_screen)


func _back_to_lobby() -> void:
	if _host != null:
		_host.back_to_lobby()
		_show_lobby(_host.session.player_list())
	else:
		_show_lobby(_last_players)


func _leave_room() -> void:
	if _host != null:
		_host.close()
	if _client != null:
		_client.leave()
	_forget_room()
	show_lan_menu()


## The nodes free themselves when their connection is closed.
func _forget_room() -> void:
	_host = null
	_client = null
	_lobby = null
	_last_players = []


func _stop_discovery() -> void:
	if _discovery != null:
		_discovery.stop()
		_discovery.queue_free()
		_discovery = null


func _unlocked_themes() -> Array:
	var progress := Storage.load_progress()
	var order := catalog.theme_ids()
	var result: Array = []
	for entry in catalog.themes:
		if progress.is_unlocked(order, entry["id"]):
			result.append({"id": entry["id"], "title": entry["title"]})
	return result


## First private IPv4 address of this device, to show to the other players.
func _local_address() -> String:
	for address: String in IP.get_local_addresses():
		var parts := address.split(".")
		if parts.size() != 4:
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") \
				or (address.begins_with("172.") and int(parts[1]) >= 16 and int(parts[1]) <= 31):
			return address
	return ""


## Android back button or gesture: one screen back, and out of the game from home.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _screen is FindScreen:
		show_select()
	elif _screen is SelectScreen or _screen is CreditsScreen:
		show_home()
	elif _screen is LanLobbyScreen or _screen is LanRoundScreen:
		_leave_room()
	elif _screen is LanMenuScreen:
		_stop_discovery()
		show_home()
	else:
		get_tree().quit()


func _on_skin_change_pressed() -> void:
	var next := Ui.next_skin_id()
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		settings.skin_id = next
	_apply_skin(next)
	show_home()  # rebuilt, so the change is visible at once


func _apply_skin(skin_id: String) -> void:
	Ui.use_skin(skin_id)
	theme = Ui.build_theme()


## Illustration for the home screen: the first scenario of the catalog.
func _hero_texture() -> Texture2D:
	if catalog == null or catalog.themes.is_empty():
		return null
	var errors: Array[String] = []
	var first: String = catalog.themes[0]["variants"][0]
	var scenario: Scenario = ScenarioLoader.load_file(ScenarioLoader.path_for(first), errors)
	return null if scenario == null else ScenarioLoader.illustration(scenario)


func _show(screen: Control) -> void:
	if _screen != null:
		# Removed at once so the new screen can reuse the name; freed later
		# because the old one may still be running the signal that got us here.
		remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	add_child(screen)
