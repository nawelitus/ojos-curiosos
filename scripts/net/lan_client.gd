extends Node
## Joins a LAN room hosted by another device. It never decides anything: it
## sends taps and shows what the host announces. Exposes the same signals and
## tap() as the host, so the round screen does not care which one it has.

signal joined(you: int, players: Array)
signal lobby_changed(players: Array)
signal round_started(scenario_id: String, targets: Array, seconds: int, players: Array)
signal object_found(object_id: String, player_id: int, players: Array)
signal time_changed(left: float)
signal round_ended(reason: String, players: Array)
signal rejected(reason: String)
signal host_closed
signal connection_failed
signal closed

const Protocol := preload("res://scripts/net/protocol.gd")

const HOST_ID := 1
const CONNECT_TIMEOUT := 6.0
const LEAVE_GRACE := 0.3

## Own id once welcomed, 0 before.
var you: int = 0
var is_connected_to_room: bool = false

var _peer: ENetMultiplayerPeer
var _avatar: int = 0
var _waited: float = 0.0
var _hello_sent: bool = false
var _leave_left: float = -1.0


func _init() -> void:
	set_process(false)


## Starts connecting. False if the address is not usable.
func join(ip: String, port: int, avatar: int) -> bool:
	if not ip.is_valid_ip_address() or port < 1 or port > 65535:
		return false
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_client(ip, port) != OK:
		_peer = null
		return false
	_avatar = avatar
	set_process(true)
	return true


## The local player tapped. "" means nothing to find there.
func tap(object_id: String) -> void:
	_send({"t": "tap", "object": object_id})


func leave() -> void:
	if _peer == null or _leave_left >= 0.0:
		return
	_send({"t": "leave"})
	_leave_left = LEAVE_GRACE


func _process(delta: float) -> void:
	if _peer == null:
		return
	if _leave_left >= 0.0:
		# Leaving: the host may have cut the connection already, and polling a
		# closed peer is an error.
		_leave_left -= delta
		var gone := _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
		if gone or _leave_left <= 0.0:
			_shutdown()
		else:
			_peer.poll()
		return
	_peer.poll()

	# Packets first: a rejection arrives together with the disconnection, and
	# must be read before the disconnection is acted on.
	while _peer != null and _peer.get_available_packet_count() > 0:
		var sender := _peer.get_packet_peer()
		var bytes := _peer.get_packet()
		if sender == HOST_ID:
			_handle(bytes)
	if _peer == null:
		return

	var status := _peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTED and not _hello_sent:
		_hello_sent = true
		_send({"t": "hello", "avatar": _avatar})
	elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		var was_in := is_connected_to_room
		_shutdown()
		if was_in:
			host_closed.emit()
		else:
			connection_failed.emit()
		return
	if not is_connected_to_room:
		_waited += delta
		if _waited > CONNECT_TIMEOUT:
			_shutdown()
			connection_failed.emit()


func _handle(bytes: PackedByteArray) -> void:
	if Protocol.header(bytes) == Protocol.Header.WRONG_VERSION:
		rejected.emit("version")
		_shutdown()
		return
	var message := Protocol.decode(bytes, true)
	if message.is_empty():
		return
	match message["t"]:
		"welcome":
			you = message["you"]
			is_connected_to_room = true
			joined.emit(you, message["players"])
		"players":
			lobby_changed.emit(message["players"])
		"start":
			round_started.emit(message["scenario"], message["targets"], message["seconds"], message["players"])
		"found":
			object_found.emit(message["object"], message["player"], message["players"])
		"time":
			time_changed.emit(message["left"])
		"end":
			round_ended.emit(message["reason"], message["players"])
		"reject":
			rejected.emit(message["reason"])
			_shutdown()
		"closing":
			host_closed.emit()
			_shutdown()


func _send(message: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(HOST_ID)
	_peer.put_packet(Protocol.encode(message))


func _shutdown() -> void:
	set_process(false)
	if _peer != null:
		_peer.close()
		_peer = null
	is_connected_to_room = false
	closed.emit()
