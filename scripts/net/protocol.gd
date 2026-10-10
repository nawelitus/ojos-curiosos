extends RefCounted
## Wire format of the LAN game. Pure logic.
##
## A packet is 3 magic bytes, 1 version byte and one Dictionary encoded with
## var_to_bytes (never objects). decode() returns a cleaned copy holding only
## the known fields with the right types, or {} for anything else: nothing
## from the network is used before it passes here.

const VERSION := 1
const MAGIC: Array[int] = [0x4F, 0x4A, 0x43]  # "OJC"
const HEADER_BYTES := 4
const MAX_PACKET_BYTES := 4096

const GAME_PORT := 24842
const DISCOVERY_PORT := 24843
const MIN_PLAYERS := 2
const MAX_PLAYERS := 8
const AVATAR_COUNT := 8
const MAX_TARGETS := 16
const MAX_ID_LENGTH := 40
const MAX_ROUND_SECONDS := 3600

enum Header { OK, NOT_OURS, WRONG_VERSION }

const REJECT_REASONS: Array[String] = ["full", "in_game", "version"]
const END_REASONS: Array[String] = ["all_found", "time", "players_left"]


static func encode(message: Dictionary) -> PackedByteArray:
	var bytes := PackedByteArray(MAGIC)
	bytes.append(VERSION)
	bytes.append_array(var_to_bytes(message))
	return bytes


static func header(bytes: PackedByteArray) -> Header:
	if bytes.size() < HEADER_BYTES:
		return Header.NOT_OURS
	for i in MAGIC.size():
		if bytes[i] != MAGIC[i]:
			return Header.NOT_OURS
	return Header.OK if bytes[MAGIC.size()] == VERSION else Header.WRONG_VERSION


## `from_host` selects which message types are acceptable: a client must never
## be able to send a host-only message, and the other way round.
static func decode(bytes: PackedByteArray, from_host: bool) -> Dictionary:
	if bytes.size() > MAX_PACKET_BYTES or header(bytes) != Header.OK:
		return {}
	var payload := bytes.slice(HEADER_BYTES)
	# bytes_to_var prints errors when fed garbage, so only real dictionaries get there.
	if payload.size() < 8 or (payload.decode_u32(0) & 0xFFFF) != TYPE_DICTIONARY:
		return {}
	var value: Variant = bytes_to_var(payload)
	if typeof(value) != TYPE_DICTIONARY or typeof(value.get("t")) != TYPE_STRING:
		return {}
	return _from_host(value) if from_host else _from_client(value)


static func _from_client(raw: Dictionary) -> Dictionary:
	match raw["t"]:
		"probe", "leave":
			return {"t": raw["t"]}
		"hello", "avatar":
			var avatar := _int(raw.get("avatar"), 0, AVATAR_COUNT - 1)
			return {} if avatar < 0 else {"t": raw["t"], "avatar": avatar}
		"tap":
			# "" means the player tapped where there is nothing to find.
			var object: Variant = raw.get("object")
			if typeof(object) != TYPE_STRING or (object != "" and not _is_id(object)):
				return {}
			return {"t": "tap", "object": object}
	return {}


static func _from_host(raw: Dictionary) -> Dictionary:
	match raw["t"]:
		"closing":
			return {"t": "closing"}
		"room":
			var port := _int(raw.get("port"), 1, 65535)
			var count := _int(raw.get("players"), 1, MAX_PLAYERS)
			var avatar := _int(raw.get("avatar"), 0, AVATAR_COUNT - 1)
			if port < 0 or count < 0 or avatar < 0 or typeof(raw.get("open")) != TYPE_BOOL:
				return {}
			return {"t": "room", "port": port, "players": count, "avatar": avatar, "open": raw["open"]}
		"reject":
			var reason: Variant = raw.get("reason")
			if typeof(reason) != TYPE_STRING or not REJECT_REASONS.has(reason):
				return {}
			return {"t": "reject", "reason": reason}
		"welcome":
			var you := _int(raw.get("you"), 1, 0x7FFFFFFF)
			var players := _players(raw.get("players"))
			return {} if you < 0 or players.is_empty() else {"t": "welcome", "you": you, "players": players}
		"players":
			var players := _players(raw.get("players"))
			return {} if players.is_empty() else {"t": "players", "players": players}
		"start":
			var players := _players(raw.get("players"))
			var targets := _id_list(raw.get("targets"))
			var seconds := _int(raw.get("seconds"), 1, MAX_ROUND_SECONDS)
			var scenario: Variant = raw.get("scenario")
			if players.is_empty() or targets.is_empty() or seconds < 0 \
					or typeof(scenario) != TYPE_STRING or not _is_id(scenario):
				return {}
			return {"t": "start", "scenario": scenario, "targets": targets, "seconds": seconds, "players": players}
		"found":
			var players := _players(raw.get("players"))
			var player := _int(raw.get("player"), 1, 0x7FFFFFFF)
			var object: Variant = raw.get("object")
			if players.is_empty() or player < 0 or typeof(object) != TYPE_STRING or not _is_id(object):
				return {}
			return {"t": "found", "object": object, "player": player, "players": players}
		"time":
			var left: Variant = raw.get("left")
			if (typeof(left) != TYPE_FLOAT and typeof(left) != TYPE_INT) or not is_finite(left) \
					or left < 0.0 or left > MAX_ROUND_SECONDS:
				return {}
			return {"t": "time", "left": float(left)}
		"end":
			var players := _players(raw.get("players"))
			var reason: Variant = raw.get("reason")
			if players.is_empty() or typeof(reason) != TYPE_STRING or not END_REASONS.has(reason):
				return {}
			return {"t": "end", "reason": reason, "players": players}
	return {}


## List of { id, avatar, score, rank }; [] if anything in it is wrong.
static func _players(raw: Variant) -> Array:
	if typeof(raw) != TYPE_ARRAY or raw.is_empty() or raw.size() > MAX_PLAYERS:
		return []
	var result: Array = []
	var seen := {}
	for entry: Variant in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			return []
		var id := _int(entry.get("id"), 1, 0x7FFFFFFF)
		var avatar := _int(entry.get("avatar"), 0, AVATAR_COUNT - 1)
		var score := _int(entry.get("score"), 0, MAX_TARGETS)
		var rank := _int(entry.get("rank"), 0, MAX_PLAYERS)
		if id < 0 or avatar < 0 or score < 0 or rank < 0 or seen.has(id):
			return []
		seen[id] = true
		result.append({"id": id, "avatar": avatar, "score": score, "rank": rank})
	return result


static func _id_list(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(raw) != TYPE_ARRAY or raw.is_empty() or raw.size() > MAX_TARGETS:
		return result
	for entry: Variant in raw:
		if typeof(entry) != TYPE_STRING or not _is_id(entry) or result.has(entry):
			return []
		result.append(entry)
	return result


## Whole number within [low, high], or -1.
static func _int(value: Variant, low: int, high: int) -> int:
	if typeof(value) != TYPE_INT or value < low or value > high:
		return -1
	return value


## Scenario and object ids: lower-case letters, digits and underscores.
static func _is_id(text: String) -> bool:
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for i in text.length():
		var code := text.unicode_at(i)
		var ok := (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95
		if not ok:
			return false
	return true
