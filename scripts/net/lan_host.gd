extends Node
## Hosts a LAN room. The host is the authority: it owns the session, decides
## who found each object first and tells everyone. It also plays, as player 1.
##
## Raw ENet packets (no scene replication) on GAME_PORT, plus a UDP responder
## on DISCOVERY_PORT so nearby devices can list the room without typing an
## address. Everything arriving is rate limited and validated by Protocol.

signal lobby_changed(players: Array)
signal round_started(scenario_id: String, targets: Array, seconds: int, players: Array)
signal object_found(object_id: String, player_id: int, players: Array)
signal time_changed(left: float)
signal round_ended(reason: String, players: Array)
## The local player's tap hit nothing (so the screen can show it).
signal missed
signal closed

const Protocol := preload("res://scripts/net/protocol.gd")
const LanSession := preload("res://scripts/net/lan_session.gd")
const RateLimiter := preload("res://scripts/net/rate_limiter.gd")

const LOCAL_ID := 1
## A device that connects but never says hello is dropped after this long.
const PENDING_TIMEOUT := 5.0
const TIME_BROADCAST_EVERY := 1.0
## After announcing the close, the sockets stay open this long so the message
## gets out; closing is never blocking.
const CLOSE_GRACE := 0.4
const MAX_PROBES_PER_FRAME := 8
const KICK_DELAY := 0.3

var session: LanSession = LanSession.new()
var is_open: bool = false

var _peer: ENetMultiplayerPeer
var _udp: PacketPeerUDP
var _limiter: RateLimiter = RateLimiter.new()
var _pending: Dictionary = {}   # peer id -> seconds waiting for hello
var _kicks: Dictionary = {}     # peer id -> seconds until its connection is cut
var _clock: float = 0.0
var _since_time: float = 0.0
var _closing_left: float = -1.0


func _init() -> void:
	set_process(false)


## Opens the room. False if the port is taken (another room on this device).
func open(avatar: int) -> bool:
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_server(Protocol.GAME_PORT, Protocol.MAX_PLAYERS - 1) != OK:
		_peer = null
		return false
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	session.add_player(LOCAL_ID, avatar)
	_udp = PacketPeerUDP.new()
	if _udp.bind(Protocol.DISCOVERY_PORT) != OK:
		_udp = null  # still playable: guests can type the address
	is_open = true
	set_process(true)
	return true


func can_start() -> bool:
	return is_open and session.can_start()


func start_round(scenario_id: String, targets: Array[String]) -> bool:
	if not is_open or not session.start(scenario_id, targets):
		return false
	_since_time = 0.0
	var players := session.player_list()
	_broadcast({
		"t": "start", "scenario": scenario_id, "targets": targets,
		"seconds": LanSession.ROUND_SECONDS, "players": players,
	})
	round_started.emit(scenario_id, targets, LanSession.ROUND_SECONDS, players)
	return true


## The local player tapped. "" means nothing to find there.
func tap(object_id: String) -> void:
	_apply_tap(LOCAL_ID, object_id)


func back_to_lobby() -> void:
	if session.back_to_lobby():
		var players := session.player_list()
		_broadcast({"t": "players", "players": players})
		lobby_changed.emit(players)


## Tells everybody the room is closing and shuts down a moment later, without
## blocking.
func close() -> void:
	if not is_open or _closing_left >= 0.0:
		return
	_broadcast({"t": "closing"})
	_closing_left = CLOSE_GRACE


func _process(delta: float) -> void:
	if _peer == null:
		return
	_clock += delta
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var sender := _peer.get_packet_peer()
		var bytes := _peer.get_packet()
		if _closing_left < 0.0:
			_handle(sender, bytes)
	_answer_probes()

	if _closing_left >= 0.0:
		_closing_left -= delta
		if _closing_left <= 0.0:
			_shutdown()
		return

	for id: int in _pending.keys():
		_pending[id] += delta
		if _pending[id] > PENDING_TIMEOUT:
			_pending.erase(id)
			_peer.disconnect_peer(id, true)
	for id: int in _kicks.keys():
		_kicks[id] -= delta
		if _kicks[id] <= 0.0:
			_kicks.erase(id)
			_peer.disconnect_peer(id, true)

	if session.state == LanSession.State.PLAYING:
		if session.tick(delta):
			_broadcast_end()
		else:
			_since_time += delta
			if _since_time >= TIME_BROADCAST_EVERY:
				_since_time = 0.0
				_broadcast({"t": "time", "left": session.time_left})
				time_changed.emit(session.time_left)


func _handle(sender: int, bytes: PackedByteArray) -> void:
	if sender == LOCAL_ID or not _limiter.allow(sender, _clock):
		return
	if Protocol.header(bytes) == Protocol.Header.WRONG_VERSION:
		_reject(sender, "version")
		return
	var message := Protocol.decode(bytes, false)
	if message.is_empty():
		return
	match message["t"]:
		"hello":
			if _pending.has(sender):
				_pending.erase(sender)
				_join(sender, message["avatar"])
		"avatar":
			if session.set_avatar(sender, message["avatar"]):
				_publish_players()
		"tap":
			_apply_tap(sender, message["object"])
		"leave":
			# The guest closes its own end; the cut below only catches one that does not.
			_drop(sender)
			_kicks[sender] = KICK_DELAY * 3.0


func _join(id: int, avatar: int) -> void:
	match session.add_player(id, avatar):
		LanSession.Join.OK:
			_send(id, {"t": "welcome", "you": id, "players": session.player_list()})
			_publish_players()
		LanSession.Join.FULL:
			_reject(id, "full")
		LanSession.Join.IN_GAME:
			_reject(id, "in_game")


func _apply_tap(id: int, object_id: String) -> void:
	match session.tap(id, object_id):
		LanSession.Tap.FOUND:
			var players := session.player_list()
			_broadcast({"t": "found", "object": object_id, "player": id, "players": players})
			object_found.emit(object_id, id, players)
			if session.state == LanSession.State.RESULTS:
				_broadcast_end()
		LanSession.Tap.MISS:
			if id == LOCAL_ID:
				missed.emit()


func _drop(id: int) -> void:
	_limiter.forget(id)
	_pending.erase(id)
	if not session.has_player(id):
		return
	var ended := session.remove_player(id)
	_publish_players()
	if ended:
		_broadcast_end()


func _publish_players() -> void:
	var players := session.player_list()
	_broadcast({"t": "players", "players": players})
	lobby_changed.emit(players)


func _broadcast_end() -> void:
	var players := session.player_list()
	_broadcast({"t": "end", "reason": session.end_reason, "players": players})
	round_ended.emit(session.end_reason, players)


## ENet drops what is still queued when a disconnection is requested, so the
## connection is cut a moment later, after the reject has been sent.
func _reject(id: int, reason: String) -> void:
	_send(id, {"t": "reject", "reason": reason})
	_pending.erase(id)
	_kicks[id] = KICK_DELAY


func _answer_probes() -> void:
	if _udp == null:
		return
	var handled := 0
	while _udp.get_available_packet_count() > 0 and handled < MAX_PROBES_PER_FRAME:
		handled += 1
		var bytes := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		if Protocol.decode(bytes, false).get("t", "") != "probe":
			continue
		var open_for_players := session.state == LanSession.State.LOBBY \
				and session.player_count() < Protocol.MAX_PLAYERS
		_udp.set_dest_address(ip, port)
		_udp.put_packet(Protocol.encode({
			"t": "room", "port": Protocol.GAME_PORT, "players": session.player_count(),
			"avatar": session.avatar_of(LOCAL_ID), "open": open_for_players,
		}))


func _send(id: int, message: Dictionary) -> void:
	_peer.set_target_peer(id)
	_peer.put_packet(Protocol.encode(message))


func _broadcast(message: Dictionary) -> void:
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(Protocol.encode(message))


func _on_peer_connected(id: int) -> void:
	_pending[id] = 0.0


func _on_peer_disconnected(id: int) -> void:
	_kicks.erase(id)
	_drop(id)


func _shutdown() -> void:
	set_process(false)
	if _udp != null:
		_udp.close()
		_udp = null
	if _peer != null:
		_peer.close()
		_peer = null
	is_open = false
	closed.emit()
