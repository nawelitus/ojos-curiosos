extends RefCounted
## State of a LAN room, as the host sees it: who is in, the round being
## played, who found what and the final ranking. Pure logic; the host feeds
## it joins, taps and time, and sends the outcome to everybody.

enum State { LOBBY, PLAYING, RESULTS }
enum Join { OK, FULL, IN_GAME, DUPLICATE }
enum Tap {
	FOUND,     ## first to tap a pending object: one point
	LATE,      ## somebody else already found it: nothing happens
	MISS,      ## nothing to find there: starts that player's pause
	LOCKED,    ## tapped during their own pause
	IGNORED,   ## not playing, or unknown player
}

const Protocol := preload("res://scripts/net/protocol.gd")

const ROUND_SECONDS := 180
const LOCKOUT_SECONDS := 1.0

var state: State = State.LOBBY
var scenario_id: String = ""
var targets: Array[String] = []
## object id -> id of the player who found it
var found: Dictionary = {}
var time_left: float = 0.0
var end_reason: String = ""

## player id -> { "avatar": int, "score": int, "reached_at": float, "locked_until": float }
var _players: Dictionary = {}
var _order: Array[int] = []   # join order
var _elapsed: float = 0.0


func player_count() -> int:
	return _order.size()


func has_player(id: int) -> bool:
	return _players.has(id)


func avatar_of(id: int) -> int:
	return _players[id]["avatar"] if _players.has(id) else -1


## Adds a player with the wanted avatar, or the first free one if it is taken.
func add_player(id: int, wanted_avatar: int) -> Join:
	if _players.has(id):
		return Join.DUPLICATE
	if state != State.LOBBY:
		return Join.IN_GAME
	if _order.size() >= Protocol.MAX_PLAYERS:
		return Join.FULL
	_players[id] = {"avatar": _free_avatar(wanted_avatar), "score": 0, "reached_at": 0.0, "locked_until": 0.0}
	_order.append(id)
	return Join.OK


## Returns true if this ended the round (too few players left to compete).
func remove_player(id: int) -> bool:
	if not _players.has(id):
		return false
	_players.erase(id)
	_order.erase(id)
	if state == State.PLAYING and _order.size() < Protocol.MIN_PLAYERS:
		_finish("players_left")
		return true
	return false


## Avatars are unique in a room and can only change in the lobby.
func set_avatar(id: int, avatar: int) -> bool:
	if state != State.LOBBY or not _players.has(id) or avatar < 0 or avatar >= Protocol.AVATAR_COUNT:
		return false
	if _avatar_taken(avatar, id):
		return false
	_players[id]["avatar"] = avatar
	return true


func can_start() -> bool:
	return state == State.LOBBY and _order.size() >= Protocol.MIN_PLAYERS


func start(p_scenario_id: String, p_targets: Array[String], seconds: int = ROUND_SECONDS) -> bool:
	if not can_start() or p_targets.is_empty():
		return false
	scenario_id = p_scenario_id
	targets = p_targets.duplicate()
	found.clear()
	time_left = float(seconds)
	end_reason = ""
	_elapsed = 0.0
	for id: int in _order:
		_players[id]["score"] = 0
		_players[id]["reached_at"] = 0.0
		_players[id]["locked_until"] = 0.0
	state = State.PLAYING
	return true


## Advances the round clock. Returns true if the time just ran out.
func tick(delta: float) -> bool:
	if state != State.PLAYING:
		return false
	_elapsed += maxf(delta, 0.0)
	time_left = maxf(time_left - maxf(delta, 0.0), 0.0)
	if time_left <= 0.0:
		_finish("time")
		return true
	return false


## `object_id` is "" when the player tapped where there is nothing to find.
func tap(id: int, object_id: String) -> Tap:
	if state != State.PLAYING or not _players.has(id):
		return Tap.IGNORED
	var player: Dictionary = _players[id]
	if _elapsed < player["locked_until"]:
		return Tap.LOCKED
	if found.has(object_id):
		return Tap.LATE
	if not targets.has(object_id):
		player["locked_until"] = _elapsed + LOCKOUT_SECONDS
		return Tap.MISS
	found[object_id] = id
	player["score"] += 1
	player["reached_at"] = _elapsed
	if found.size() >= targets.size():
		_finish("all_found")
	return Tap.FOUND


func back_to_lobby() -> bool:
	if state != State.RESULTS:
		return false
	state = State.LOBBY
	return true


## Players as sent over the network, best first once a round has been played:
## more points wins; with equal points, whoever got there first. Players with
## the same points at the same moment (or nobody scoring) share a rank.
func player_list() -> Array:
	var ids := _order.duplicate()
	if state != State.LOBBY:
		ids.sort_custom(func(a: int, b: int) -> bool: return _beats(a, b))
	var result: Array = []
	var rank := 0
	for index in ids.size():
		var id: int = ids[index]
		if index == 0 or _beats(ids[index - 1], id):
			rank = index + 1
		result.append({
			"id": id,
			"avatar": _players[id]["avatar"],
			"score": _players[id]["score"],
			"rank": 0 if state == State.LOBBY else rank,
		})
	return result


func _beats(a: int, b: int) -> bool:
	var first: Dictionary = _players[a]
	var second: Dictionary = _players[b]
	if first["score"] != second["score"]:
		return first["score"] > second["score"]
	return first["score"] > 0 and first["reached_at"] < second["reached_at"]


func _finish(reason: String) -> void:
	state = State.RESULTS
	end_reason = reason


func _free_avatar(wanted: int) -> int:
	if wanted >= 0 and wanted < Protocol.AVATAR_COUNT and not _avatar_taken(wanted, -1):
		return wanted
	for avatar in Protocol.AVATAR_COUNT:
		if not _avatar_taken(avatar, -1):
			return avatar
	return 0


func _avatar_taken(avatar: int, except_id: int) -> bool:
	for id: int in _order:
		if id != except_id and _players[id]["avatar"] == avatar:
			return true
	return false
