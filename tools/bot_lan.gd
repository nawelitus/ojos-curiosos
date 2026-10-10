extends SceneTree
## A console player for testing the LAN game against real devices.
##
## Host bot:   godot --headless --path . -s tools/bot_lan.gd -- host [finds] [avatar]
##   opens a room, waits for a second player, starts a round on beach_1 and
##   finds `finds` objects (default 3), one every few seconds.
## Guest bot:  godot --headless --path . -s tools/bot_lan.gd -- join <ip> [finds] [avatar]
##   joins the room at <ip> and finds `finds` objects when a round starts.
##
## Use the Godot executable WITHOUT "_console" for the host bot: Windows asks
## for a firewall rule per executable. Always pass --quit-after, or a script
## error leaves the process running.

const LanHost := preload("res://scripts/net/lan_host.gd")
const LanClient := preload("res://scripts/net/lan_client.gd")
const Protocol := preload("res://scripts/net/protocol.gd")
const FindRound := preload("res://scripts/core/find_round.gd")
const ScenarioLoader := preload("res://scripts/scenario_loader.gd")

const SCENARIO := "beach_1"
const SECONDS_BETWEEN_FINDS := 4.0
const WAIT_FOR_PLAYERS_SECONDS := 240.0
const ROUND_LOG_SECONDS := 200.0


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not ["host", "join"].has(args[0]):
		print("usage: -- host [finds] [avatar]   |   -- join <ip> [finds] [avatar]")
		quit(2)
		return
	if args[0] == "host":
		await _run_host(int(args[1]) if args.size() > 1 else 3, int(args[2]) if args.size() > 2 else 6)
	else:
		if args.size() < 2:
			print("join needs an address")
			quit(2)
			return
		await _run_guest(args[1], int(args[2]) if args.size() > 2 else 3, int(args[3]) if args.size() > 3 else 7)
	quit()


func _run_host(finds: int, avatar: int) -> void:
	var host: LanHost = LanHost.new()
	root.add_child(host)
	if not host.open(avatar):
		print("BOT host: cannot open the room (port in use?)")
		return
	print("BOT host: room open on port %d, waiting for a player" % Protocol.GAME_PORT)
	host.lobby_changed.connect(func(players: Array) -> void: print("BOT host: players -> %d" % players.size()))
	host.object_found.connect(func(object_id: String, player: int, _p: Array) -> void:
		print("BOT host: %s found by player %d" % [object_id, player]))
	var summary := {"ended": false}
	host.round_ended.connect(func(reason: String, players: Array) -> void:
		summary["ended"] = true
		print("BOT host: round ended (%s)" % reason)
		for player: Dictionary in players:
			print("  rank %d  avatar %d  score %d" % [player["rank"], player["avatar"], player["score"]]))

	if not await _wait_for(func() -> bool: return host.can_start(), WAIT_FOR_PLAYERS_SECONDS):
		print("BOT host: nobody joined, giving up")
		host.close()
		await _seconds(1.0)
		return
	await _seconds(2.0)

	var errors: Array[String] = []
	var scenario := ScenarioLoader.load_file(ScenarioLoader.path_for(SCENARIO), errors)
	if scenario == null:
		print("BOT host: cannot load the scenario: %s" % "; ".join(errors))
		return
	var pool: Array[String] = []
	for object in scenario.objects:
		pool.append(object["id"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var targets := FindRound.draw_targets(pool, 8, rng)
	print("BOT host: starting the round with %s" % str(targets))
	host.start_round(SCENARIO, targets)

	var deadline := Time.get_ticks_msec() + int(ROUND_LOG_SECONDS * 1000.0)
	var done := 0
	var next_find := Time.get_ticks_msec() + int(SECONDS_BETWEEN_FINDS * 1000.0)
	while not summary["ended"] and Time.get_ticks_msec() < deadline:
		if done < finds and Time.get_ticks_msec() >= next_find:
			var pending: Array[String] = []
			for target in targets:
				if not host.session.found.has(target):
					pending.append(target)
			if pending.size() > 1:
				host.tap(pending[rng.randi_range(0, pending.size() - 1)])
				done += 1
			next_find = Time.get_ticks_msec() + int(SECONDS_BETWEEN_FINDS * 1000.0)
		await process_frame
	await _seconds(3.0)
	host.close()
	await _seconds(1.0)
	print("BOT host: done")


func _run_guest(ip: String, finds: int, avatar: int) -> void:
	var client: LanClient = LanClient.new()
	root.add_child(client)
	var state := {"targets": [], "ended": false, "found": {}}
	client.joined.connect(func(you: int, players: Array) -> void:
		print("BOT guest: joined as %d (%d players)" % [you, players.size()]))
	client.round_started.connect(func(scenario: String, targets: Array, seconds: int, _p: Array) -> void:
		state["targets"] = targets
		print("BOT guest: round started on %s, %d s, %s" % [scenario, seconds, str(targets)]))
	client.object_found.connect(func(object_id: String, player: int, _p: Array) -> void:
		state["found"][object_id] = player
		print("BOT guest: %s found by player %d" % [object_id, player]))
	client.round_ended.connect(func(reason: String, players: Array) -> void:
		state["ended"] = true
		print("BOT guest: round ended (%s)" % reason)
		for player: Dictionary in players:
			print("  rank %d  avatar %d  score %d" % [player["rank"], player["avatar"], player["score"]]))
	client.rejected.connect(func(reason: String) -> void: print("BOT guest: rejected (%s)" % reason))
	client.host_closed.connect(func() -> void: print("BOT guest: the room closed"))
	if not client.join(ip, Protocol.GAME_PORT, avatar):
		print("BOT guest: bad address")
		return
	if not await _wait_for(func() -> bool: return not state["targets"].is_empty(), WAIT_FOR_PLAYERS_SECONDS):
		print("BOT guest: no round started")
		client.leave()
		await _seconds(1.0)
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var done := 0
	var deadline := Time.get_ticks_msec() + int(ROUND_LOG_SECONDS * 1000.0)
	while not state["ended"] and Time.get_ticks_msec() < deadline:
		await _seconds(SECONDS_BETWEEN_FINDS)
		if done < finds and not state["ended"]:
			var pending: Array = []
			for target: String in state["targets"]:
				if not state["found"].has(target):
					pending.append(target)
			if pending.size() > 1:
				client.tap(pending[rng.randi_range(0, pending.size() - 1)])
				done += 1
	await _seconds(2.0)
	client.leave()
	await _seconds(1.0)
	print("BOT guest: done")


func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _seconds(amount: float) -> void:
	var deadline := Time.get_ticks_msec() + int(amount * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
