extends "res://tools/testing/harness.gd"
## A real host and two real clients talking over the loopback network of this
## machine: join, discovery, a whole round, rejection and closing.

const LanHost := preload("res://scripts/net/lan_host.gd")
const LanClient := preload("res://scripts/net/lan_client.gd")
const LanDiscovery := preload("res://scripts/net/lan_discovery.gd")
const Protocol := preload("res://scripts/net/protocol.gd")

const TARGETS: Array[String] = ["crab", "duck", "kite"]
const LOCALHOST := "127.0.0.1"


class Recorder extends RefCounted:
	var lobbies: Array = []
	var started: Array = []
	var found: Array = []
	var ended: Array = []
	var rejected: Array = []
	var times: int = 0
	var host_closed: int = 0
	var failed: int = 0
	var joined_you: int = 0

	func watch(source: Object) -> void:
		for signal_name: String in ["lobby_changed", "round_started", "object_found", "round_ended",
				"rejected", "time_changed", "host_closed", "connection_failed", "joined"]:
			if source.has_signal(signal_name):
				source.connect(signal_name, Callable(self, "_on_" + signal_name))

	func _on_lobby_changed(players: Array) -> void: lobbies.append(players)
	func _on_round_started(scenario: String, targets: Array, seconds: int, players: Array) -> void:
		started.append({"scenario": scenario, "targets": targets, "seconds": seconds, "players": players})
	func _on_object_found(object_id: String, player: int, players: Array) -> void:
		found.append({"object": object_id, "player": player, "players": players})
	func _on_round_ended(reason: String, players: Array) -> void: ended.append({"reason": reason, "players": players})
	func _on_rejected(reason: String) -> void: rejected.append(reason)
	func _on_time_changed(_left: float) -> void: times += 1
	func _on_host_closed() -> void: host_closed += 1
	func _on_connection_failed() -> void: failed += 1
	func _on_joined(you: int, _players: Array) -> void: joined_you = you


func run() -> void:
	var host: LanHost = LanHost.new()
	root.add_child(host)
	check(host.open(2), "the host opens the room")
	var second_host: LanHost = LanHost.new()
	root.add_child(second_host)
	check(not second_host.open(0), "a second room on the same device is refused (port taken)")
	second_host.queue_free()
	var host_log := Recorder.new()
	host_log.watch(host)

	# --- discovery -------------------------------------------------------------
	var discovery: LanDiscovery = LanDiscovery.new()
	discovery.targets = [LOCALHOST]
	discovery.scan_enabled = false
	root.add_child(discovery)
	check(discovery.start(), "discovery starts")
	check(await _until(func() -> bool: return discovery.rooms.size() == 1), "the room is found")
	if discovery.rooms.size() == 1:
		var room: Dictionary = discovery.rooms[0]
		check(room["port"] == Protocol.GAME_PORT and room["players"] == 1 and room["avatar"] == 2 and room["open"],
				"with its port, players, avatar and open flag")
	# The scan must find a room WITHOUT any broadcast: the direct probe list points
	# at an address that cannot answer, and only the scan list reaches the host.
	var scanner: LanDiscovery = LanDiscovery.new()
	scanner.targets = ["192.0.2.1"]
	scanner.scan_targets = ["127.0.0.1"]
	root.add_child(scanner)
	check(scanner.start(), "a second discovery starts")
	check(await _until(func() -> bool: return scanner.rooms.size() == 1), "the scan alone finds the room")
	var stats := scanner.diagnostics()
	check(stats["sent"] > 0 and stats["send_errors"] == 0 and stats["answers"] >= 1 and stats["rooms"] == 1,
			"the diagnostics count what was sent and answered (%s)" % str(stats))
	scanner.stop()
	scanner.queue_free()

	var hosts := LanDiscovery.subnet_hosts(["192.168.1.8", "127.0.0.1", "8.8.8.8", "fe80::1", "169.254.1.1"])
	check(hosts.size() == 253, "the scan covers the other 253 addresses of the /24 (%d)" % hosts.size())
	check(not hosts.has("192.168.1.8") and hosts.has("192.168.1.1") and hosts.has("192.168.1.254"),
			"it skips the device itself and keeps both ends of the range")
	var one_prefix := true
	for address in hosts:
		if not address.begins_with("192.168.1."):
			one_prefix = false
	check(one_prefix, "and stays inside the device's own network")
	check(LanDiscovery.subnet_hosts(["8.8.8.8", "127.0.0.1"]).is_empty(), "no private address means no scan")

	check(LanDiscovery.broadcast_addresses(["192.168.1.37", "10.0.0.5", "127.0.0.1", "8.8.8.8", "fe80::1",
			"169.254.3.4", "172.20.4.4", "172.40.1.1"]) == ["255.255.255.255", "192.168.1.255", "10.0.0.255", "172.20.4.255"],
			"broadcast addresses come from private IPv4 addresses only")

	# --- joining ---------------------------------------------------------------
	var anna: LanClient = LanClient.new()
	var ben: LanClient = LanClient.new()
	root.add_child(anna)
	root.add_child(ben)
	var anna_log := Recorder.new()
	var ben_log := Recorder.new()
	anna_log.watch(anna)
	ben_log.watch(ben)
	check(not anna.join("not an ip", Protocol.GAME_PORT, 0), "a bad address is refused at once")
	check(anna.join(LOCALHOST, Protocol.GAME_PORT, 2), "the first guest connects (asking for a taken avatar)")
	check(await _until(func() -> bool: return anna.is_connected_to_room), "and is welcomed")
	check(anna.you > 1 and host.session.has_player(anna.you), "with its own id")
	check(host.session.avatar_of(anna.you) != 2, "and was given a free avatar")
	check(ben.join(LOCALHOST, Protocol.GAME_PORT, 5), "the second guest connects")
	check(await _until(func() -> bool: return ben.is_connected_to_room and host.session.player_count() == 3),
			"and the room has three players")
	check(await _until(func() -> bool: return not anna_log.lobbies.is_empty() and anna_log.lobbies.back().size() == 3),
			"everybody sees the full list")

	# --- a round ---------------------------------------------------------------
	check(host.can_start() and host.start_round("beach_1", TARGETS), "the host starts a round")
	check(await _until(func() -> bool: return anna_log.started.size() == 1 and ben_log.started.size() == 1),
			"both guests are told")
	if anna_log.started.size() == 1:
		var start: Dictionary = anna_log.started[0]
		check(start["scenario"] == "beach_1" and start["targets"] == TARGETS and start["seconds"] == 180,
				"with the scenario, the same targets and the round length")
	check(await _until(func() -> bool: return anna_log.times > 0), "and the clock is announced")

	anna.tap("crab")
	ben.tap("crab")
	check(await _until(func() -> bool: return not host_log.found.is_empty() and not ben_log.found.is_empty()),
			"a find reaches everyone")
	check(host_log.found.size() == 1 and host_log.found[0]["player"] != host.LOCAL_ID, "only one of the two got it")
	var winner: int = host_log.found[0]["player"]
	check(winner == anna.you or winner == ben.you, "a guest")
	check(ben_log.found[0]["player"] == winner and anna_log.found[0]["player"] == winner, "and all agree who")

	host.tap("duck")
	check(await _until(func() -> bool: return host_log.found.size() == 2), "the host can find objects too")
	ben.tap("")
	await _wait(0.2)
	ben.tap("kite")
	await _wait(0.3)
	check(host.session.found.size() == 2, "a guest tapping during its pause finds nothing")
	anna.tap("kite")
	var everybody_told := func() -> bool:
		return not anna_log.ended.is_empty() and not ben_log.ended.is_empty() and not host_log.ended.is_empty()
	check(await _until(everybody_told), "finding the last object ends the round for everybody")
	if not anna_log.ended.is_empty():
		check(anna_log.ended[0]["reason"] == "all_found", "because all were found")
		var ranks := {}
		var total := 0
		for player: Dictionary in anna_log.ended[0]["players"]:
			ranks[player["id"]] = player["rank"]
			total += player["score"]
		check(total == 3 and ranks.size() == 3, "and the scores add up to the three objects")

	# --- going back to the lobby, a late joiner --------------------------------
	host.back_to_lobby()
	var cleo: LanClient = LanClient.new()
	root.add_child(cleo)
	var cleo_log := Recorder.new()
	cleo_log.watch(cleo)
	cleo.join(LOCALHOST, Protocol.GAME_PORT, 0)
	check(await _until(func() -> bool: return cleo.is_connected_to_room), "a new player can join between rounds")
	check(host.start_round("beach_1", TARGETS), "a second round starts with four players")
	await _wait(0.3)
	var late: LanClient = LanClient.new()
	root.add_child(late)
	var late_log := Recorder.new()
	late_log.watch(late)
	late.join(LOCALHOST, Protocol.GAME_PORT, 0)
	check(await _until(func() -> bool: return not late_log.rejected.is_empty()), "joining during a round is rejected")
	check(late_log.rejected[0] == "in_game" and not late.is_connected_to_room, "with the reason")

	# --- leaving and closing -----------------------------------------------------
	cleo.leave()
	check(await _until(func() -> bool: return host.session.player_count() == 3), "a guest leaving is noticed")
	host.close()
	check(await _until(func() -> bool: return anna_log.host_closed == 1 and ben_log.host_closed == 1),
			"closing the room tells the guests")
	check(await _until(func() -> bool: return not host.is_open), "and the host shuts down")

	var orphan: LanClient = LanClient.new()
	root.add_child(orphan)
	var orphan_log := Recorder.new()
	orphan_log.watch(orphan)
	orphan.join(LOCALHOST, Protocol.GAME_PORT, 0)
	check(await _until(func() -> bool: return orphan_log.failed == 1, 9.0), "connecting to nobody ends in a failure")
	discovery.stop()


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
