extends "res://tools/testing/harness.gd"

const LanSession := preload("res://scripts/net/lan_session.gd")
const Protocol := preload("res://scripts/net/protocol.gd")

const TARGETS: Array[String] = ["crab", "duck", "kite"]


func run() -> void:
	_test_lobby()
	_test_taps()
	_test_ranking()
	_test_ending()


func _room(count: int) -> LanSession:
	var session := LanSession.new()
	for i in count:
		session.add_player(i + 1, i)
	return session


func _test_lobby() -> void:
	var session := LanSession.new()
	check(session.add_player(1, 2) == LanSession.Join.OK and session.avatar_of(1) == 2, "the host joins with its avatar")
	check(session.add_player(1, 3) == LanSession.Join.DUPLICATE, "the same id cannot join twice")
	session.add_player(2, 2)
	check(session.avatar_of(2) != 2 and session.avatar_of(2) >= 0, "a taken avatar gives the next free one")
	check(session.set_avatar(2, 5) and session.avatar_of(2) == 5, "an avatar can be changed")
	check(not session.set_avatar(2, 2), "but not to a taken one")
	check(not session.set_avatar(2, 9) and not session.set_avatar(2, -1), "nor out of range")
	check(not session.can_start() or session.player_count() >= 2, "starting needs at least two players")

	var full := _room(Protocol.MAX_PLAYERS)
	check(full.player_count() == 8, "eight players fit")
	var avatars := {}
	for id in 8:
		avatars[full.avatar_of(id + 1)] = true
	check(avatars.size() == 8, "each has a different avatar")
	check(full.add_player(99, 0) == LanSession.Join.FULL, "the ninth is refused")

	var alone := _room(1)
	check(not alone.can_start() and not alone.start("beach", TARGETS), "one player cannot start")
	var pair := _room(2)
	check(pair.start("beach", TARGETS) and pair.state == LanSession.State.PLAYING, "two players can")
	check(pair.add_player(3, 0) == LanSession.Join.IN_GAME, "nobody joins during a round")
	check(not pair.set_avatar(1, 6), "avatars are frozen during a round")
	check(not pair.start("beach", TARGETS), "a round in progress cannot be started again")
	var empty: Array[String] = []
	check(not _room(2).start("beach", empty), "a round needs targets")


func _test_taps() -> void:
	var session := _room(3)
	check(session.tap(1, "crab") == LanSession.Tap.IGNORED, "taps before the start are ignored")
	session.start("beach", TARGETS)
	check(session.tap(99, "crab") == LanSession.Tap.IGNORED, "taps from strangers are ignored")
	check(session.tap(1, "crab") == LanSession.Tap.FOUND, "the first to tap finds it")
	check(session.tap(2, "crab") == LanSession.Tap.LATE, "the second finds nothing")
	check(session.found == {"crab": 1}, "and the object is credited to the first")
	check(session.tap(2, "") == LanSession.Tap.MISS, "tapping nothing is a miss")
	check(session.tap(2, "duck") == LanSession.Tap.LOCKED, "and pauses that player")
	check(session.tap(3, "duck") == LanSession.Tap.FOUND, "but not the others")
	session.tick(LanSession.LOCKOUT_SECONDS - 0.1)
	check(session.tap(2, "kite") == LanSession.Tap.LOCKED, "the pause lasts its full length")
	session.tick(0.2)
	check(session.tap(2, "lifebuoy") == LanSession.Tap.MISS, "an object outside the round is a miss")
	check(session.tap(1, "lifebuoy") == LanSession.Tap.MISS, "for everybody")
	var scores := {}
	for player in session.player_list():
		scores[player["id"]] = player["score"]
	check(scores == {1: 1, 2: 0, 3: 1}, "scores follow the finds, misses cost nothing")


func _test_ranking() -> void:
	var session := _room(4)
	session.start("beach", TARGETS)
	session.tick(1.0)
	session.tap(2, "crab")
	session.tick(2.0)
	session.tap(3, "duck")
	session.tick(1.0)
	var list := session.player_list()
	check(list[0]["id"] == 2 and list[0]["rank"] == 1, "same points: whoever got there first ranks first")
	check(list[1]["id"] == 3 and list[1]["rank"] == 2, "the other one is second")
	check(list[2]["rank"] == 3 and list[3]["rank"] == 3, "players with nothing share a rank")

	var scoreless := _room(2)
	scoreless.start("beach", TARGETS)
	var none := scoreless.player_list()
	check(none[0]["rank"] == 1 and none[1]["rank"] == 1, "nobody scoring is a draw")

	var lobby := _room(3).player_list()
	check(lobby.size() == 3 and lobby[0]["rank"] == 0, "the lobby list has no ranks")


func _test_ending() -> void:
	var all_found := _room(2)
	all_found.start("beach", TARGETS)
	all_found.tap(1, "crab")
	all_found.tap(2, "duck")
	check(all_found.state == LanSession.State.PLAYING, "the round goes on while objects remain")
	all_found.tap(1, "kite")
	check(all_found.state == LanSession.State.RESULTS and all_found.end_reason == "all_found",
			"finding everything ends the round")
	check(all_found.tap(2, "") == LanSession.Tap.IGNORED, "taps after the end are ignored")

	var timed := _room(2)
	timed.start("beach", TARGETS, 3)
	check(not timed.tick(2.0) and timed.time_left > 0.9, "the clock counts down")
	check(timed.tick(1.5) and timed.end_reason == "time" and timed.time_left == 0.0, "and ends the round at zero")
	check(timed.back_to_lobby() and timed.state == LanSession.State.LOBBY, "the room goes back to the lobby")
	check(timed.player_count() == 2 and timed.start("beach", TARGETS), "with the same players, ready to play again")
	check(timed.found.is_empty() and timed.player_list()[0]["score"] == 0, "the new round starts clean")

	var leaving := _room(3)
	leaving.start("beach", TARGETS)
	check(not leaving.remove_player(3) and leaving.state == LanSession.State.PLAYING, "a round goes on with two left")
	check(leaving.remove_player(2) and leaving.end_reason == "players_left", "but ends when only one is left")
	check(not _room(2).remove_player(77), "removing a stranger changes nothing")
