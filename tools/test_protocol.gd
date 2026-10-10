extends "res://tools/testing/harness.gd"

const Protocol := preload("res://scripts/net/protocol.gd")
const RateLimiter := preload("res://scripts/net/rate_limiter.gd")


func run() -> void:
	_test_header()
	_test_client_messages()
	_test_host_messages()
	_test_limits()
	_test_rate_limiter()


func _test_header() -> void:
	var bytes := Protocol.encode({"t": "probe"})
	check(Protocol.header(bytes) == Protocol.Header.OK, "an encoded packet has a valid header")
	check(Protocol.header(PackedByteArray([1, 2])) == Protocol.Header.NOT_OURS, "a short packet is not ours")
	check(Protocol.header(PackedByteArray([0x41, 0x42, 0x43, 1, 9])) == Protocol.Header.NOT_OURS,
			"a packet with another magic is not ours")
	var other := bytes.duplicate()
	other[3] = Protocol.VERSION + 1
	check(Protocol.header(other) == Protocol.Header.WRONG_VERSION, "another version is detected")
	check(Protocol.decode(other, false).is_empty(), "and not decoded")
	check(Protocol.decode(PackedByteArray(), false).is_empty(), "an empty packet decodes to nothing")
	var junk := PackedByteArray(Protocol.MAGIC)
	junk.append(Protocol.VERSION)
	junk.append_array(PackedByteArray([255, 255, 255, 255, 1, 2, 3, 4, 5, 6]))
	check(Protocol.decode(junk, false).is_empty(), "garbage after a valid header decodes to nothing")
	var not_a_dictionary := PackedByteArray(Protocol.MAGIC)
	not_a_dictionary.append(Protocol.VERSION)
	not_a_dictionary.append_array(var_to_bytes([1, 2, 3]))
	check(Protocol.decode(not_a_dictionary, false).is_empty(), "a packet holding a list decodes to nothing")


func _test_client_messages() -> void:
	check(_client({"t": "probe"}) == {"t": "probe"}, "probe")
	check(_client({"t": "leave"}) == {"t": "leave"}, "leave")
	check(_client({"t": "hello", "avatar": 3}) == {"t": "hello", "avatar": 3}, "hello with an avatar")
	check(_client({"t": "hello", "avatar": 8}).is_empty(), "hello with an avatar out of range is refused")
	check(_client({"t": "hello", "avatar": "3"}).is_empty(), "hello with a text avatar is refused")
	check(_client({"t": "hello", "avatar": 2.0}).is_empty(), "hello with a float avatar is refused")
	check(_client({"t": "tap", "object": "crab"}) == {"t": "tap", "object": "crab"}, "tap on an object")
	check(_client({"t": "tap", "object": ""}) == {"t": "tap", "object": ""}, "tap on nothing")
	check(_client({"t": "tap", "object": "Crab!"}).is_empty(), "tap with a bad id is refused")
	check(_client({"t": "tap", "object": "a".repeat(41)}).is_empty(), "tap with a long id is refused")
	check(_client({"t": "tap", "object": 7}).is_empty(), "tap with a number is refused")
	check(_client({"t": "tap"}).is_empty(), "tap with no object is refused")
	var extra := _client({"t": "tap", "object": "crab", "evil": "x"})
	check(extra == {"t": "tap", "object": "crab"}, "unknown fields are dropped")
	check(_client({"t": "start", "scenario": "a", "targets": ["a"], "seconds": 5, "players": _players()}).is_empty(),
			"a client cannot send host messages")
	check(_client({"t": "nope"}).is_empty(), "unknown types are refused")


func _test_host_messages() -> void:
	check(_host({"t": "closing"}) == {"t": "closing"}, "closing")
	check(_host({"t": "reject", "reason": "full"}) == {"t": "reject", "reason": "full"}, "reject")
	check(_host({"t": "reject", "reason": "because"}).is_empty(), "reject with an unknown reason is refused")
	var room := {"t": "room", "port": 24842, "players": 2, "avatar": 1, "open": true}
	check(_host(room) == room, "room")
	check(_host({"t": "room", "port": 0, "players": 2, "avatar": 1, "open": true}).is_empty(), "room with port 0")
	check(_host({"t": "room", "port": 24842, "players": 2, "avatar": 1, "open": "yes"}).is_empty(),
			"room with a text flag")
	check(_host({"t": "welcome", "you": 77, "players": _players()}).get("you", 0) == 77, "welcome")
	check(_host({"t": "welcome", "you": 0, "players": _players()}).is_empty(), "welcome with id 0 is refused")
	check(_host({"t": "welcome", "you": 5, "players": []}).is_empty(), "welcome with no players is refused")
	check(_host({"t": "players", "players": _players()}).has("players"), "players")

	var start := {"t": "start", "scenario": "beach_1", "targets": ["crab", "duck"], "seconds": 180,
			"players": _players()}
	check(_host(start) == start, "start")
	var no_targets := start.duplicate()
	no_targets["targets"] = []
	check(_host(no_targets).is_empty(), "start with no targets is refused")
	var repeated := start.duplicate()
	repeated["targets"] = ["crab", "crab"]
	check(_host(repeated).is_empty(), "start with a repeated target is refused")
	var bad_seconds := start.duplicate()
	bad_seconds["seconds"] = 100000
	check(_host(bad_seconds).is_empty(), "start with a huge round length is refused")
	var bad_scenario := start.duplicate()
	bad_scenario["scenario"] = "../../etc"
	check(_host(bad_scenario).is_empty(), "start with a path as scenario is refused")

	var found := {"t": "found", "object": "crab", "player": 77, "players": _players()}
	check(_host(found) == found, "found")
	check(_host({"t": "time", "left": 12.5}) == {"t": "time", "left": 12.5}, "time")
	check(_host({"t": "time", "left": 12}).get("left", -1.0) == 12.0, "time given as a whole number")
	check(_host({"t": "time", "left": -1.0}).is_empty(), "negative time is refused")
	check(_host({"t": "time", "left": NAN}).is_empty(), "NaN time is refused")
	check(_host({"t": "end", "reason": "time", "players": _players()}).get("reason", "") == "time", "end")
	check(_host({"t": "end", "reason": "boredom", "players": _players()}).is_empty(), "end with an unknown reason")
	check(_host({"t": "tap", "object": "crab"}).is_empty(), "the host cannot send client messages")


func _test_limits() -> void:
	var too_many: Array = []
	for i in 9:
		too_many.append({"id": i + 1, "avatar": i % 8, "score": 0, "rank": 0})
	check(_host({"t": "players", "players": too_many}).is_empty(), "more than 8 players is refused")
	var repeated_id: Array = [{"id": 5, "avatar": 0, "score": 0, "rank": 0}, {"id": 5, "avatar": 1, "score": 0, "rank": 0}]
	check(_host({"t": "players", "players": repeated_id}).is_empty(), "a repeated player id is refused")
	var bad_score: Array = [{"id": 5, "avatar": 0, "score": 99, "rank": 0}]
	check(_host({"t": "players", "players": bad_score}).is_empty(), "an impossible score is refused")
	var not_dict: Array = [5]
	check(_host({"t": "players", "players": not_dict}).is_empty(), "a player that is not an object is refused")
	var huge := PackedByteArray(Protocol.MAGIC)
	huge.append(Protocol.VERSION)
	huge.resize(Protocol.MAX_PACKET_BYTES + 10)
	check(Protocol.decode(huge, true).is_empty(), "an oversized packet is refused")


func _test_rate_limiter() -> void:
	var limiter := RateLimiter.new()
	var allowed := 0
	for i in 40:
		if limiter.allow(5, 10.0):
			allowed += 1
	check(allowed == RateLimiter.MAX_PER_SECOND, "a burst is cut at the limit (%d allowed)" % allowed)
	check(limiter.allow(6, 10.0), "another peer is not affected")
	check(limiter.allow(5, 11.2), "the budget comes back after a second")
	limiter.forget(5)
	check(limiter.allow(5, 11.3), "a forgotten peer starts clean")


func _client(raw: Dictionary) -> Dictionary:
	return Protocol.decode(Protocol.encode(raw), false)


func _host(raw: Dictionary) -> Dictionary:
	return Protocol.decode(Protocol.encode(raw), true)


func _players() -> Array:
	return [{"id": 1, "avatar": 0, "score": 2, "rank": 1}, {"id": 77, "avatar": 3, "score": 1, "rank": 2}]
