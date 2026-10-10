extends Node
## Looks for rooms on the Wi-Fi network: sends a small probe by UDP broadcast
## and lists whoever answers. Rooms that stop answering disappear.

signal rooms_changed

const Protocol := preload("res://scripts/net/protocol.gd")

const PROBE_EVERY := 1.5
const SCAN_EVERY := 3.0
const SCAN_PER_FRAME := 64
## A room that has not answered for this long leaves the list. Longer than a
## whole scan, so rooms found only by the scan do not blink.
const ROOM_TTL := 7.0
const MAX_ROOMS := 12

## Array of { "ip": String, "port": int, "players": int, "avatar": int, "open": bool }
var rooms: Array[Dictionary] = []

var _udp: PacketPeerUDP
var _clock: float = 0.0
var _since_probe: float = PROBE_EVERY
var _seen: Dictionary = {}   # ip -> clock at last answer
## Where probes are sent every PROBE_EVERY seconds: the broadcast addresses by
## default. Tests point it at the loopback address.
var targets: Array[String] = []
## Addresses asked one by one every SCAN_EVERY seconds: by default every other
## address of the local /24 network. Tests can set their own list.
var scan_targets: Array[String] = []
## Tests that must not scan the real network switch it off.
var scan_enabled: bool = true

var _since_scan: float = SCAN_EVERY
var _scan_index: int = -1
var _sent: int = 0
var _send_errors: int = 0
var _last_send_error: int = OK
var _received: int = 0
var _answers: int = 0


func _init() -> void:
	set_process(false)


func start() -> bool:
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	if _udp.bind(0) != OK:
		_udp = null
		return false
	var local := Array(IP.get_local_addresses())
	if targets.is_empty():
		targets = broadcast_addresses(local)
	if scan_enabled and scan_targets.is_empty():
		scan_targets = subnet_hosts(local)
	set_process(true)
	return true


func stop() -> void:
	set_process(false)
	if _udp != null:
		_udp.close()
		_udp = null
	rooms.clear()
	_seen.clear()


## The limited broadcast address, plus the subnet broadcast of every private
## IPv4 address this device has (some networks drop the first).
static func broadcast_addresses(local_addresses: Array) -> Array[String]:
	var result: Array[String] = ["255.255.255.255"]
	for address: String in local_addresses:
		var parts := address.split(".")
		if parts.size() != 4 or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var private_range := address.begins_with("10.") or address.begins_with("192.168.") \
				or (address.begins_with("172.") and int(parts[1]) >= 16 and int(parts[1]) <= 31)
		if not private_range:
			continue
		var broadcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not result.has(broadcast):
			result.append(broadcast)
	return result


## Every other address of the /24 network of each private IPv4 address this
## device has. Unlike a broadcast, a packet sent straight to an address is
## never filtered by the Wi-Fi chip or the router, so it finds rooms on
## networks where broadcasts do not arrive.
static func subnet_hosts(local_addresses: Array) -> Array[String]:
	var result: Array[String] = []
	for address: String in local_addresses:
		var parts := address.split(".")
		if parts.size() != 4 or not _is_private(address):
			continue
		for last in range(1, 255):
			if last == int(parts[3]):
				continue
			var host := "%s.%s.%s.%d" % [parts[0], parts[1], parts[2], last]
			if not result.has(host):
				result.append(host)
	return result


static func _is_private(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4 or address.begins_with("127.") or address.begins_with("169.254."):
		return false
	return address.begins_with("10.") or address.begins_with("192.168.") \
			or (address.begins_with("172.") and int(parts[1]) >= 16 and int(parts[1]) <= 31)


func _process(delta: float) -> void:
	if _udp == null:
		return
	_clock += delta
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var bytes := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		_received += 1
		var message := Protocol.decode(bytes, true)
		if message.get("t", "") == "room":
			_answers += 1
			changed = _remember(ip, message) or changed

	for index in range(rooms.size() - 1, -1, -1):
		if _clock - _seen.get(rooms[index]["ip"], 0.0) > ROOM_TTL:
			_seen.erase(rooms[index]["ip"])
			rooms.remove_at(index)
			changed = true
	if changed:
		rooms_changed.emit()

	var probe := Protocol.encode({"t": "probe"})
	_since_probe += delta
	if _since_probe >= PROBE_EVERY:
		_since_probe = 0.0
		for address in targets:
			_send_probe(address, probe)

	# Second way in, independent of broadcasts: ask every address of the local
	# network one by one, a few per frame so the Wi-Fi does not get a burst.
	if scan_targets.is_empty():
		return
	_since_scan += delta
	if _scan_index < 0 and _since_scan >= SCAN_EVERY:
		_since_scan = 0.0
		_scan_index = 0
	if _scan_index >= 0:
		var end := mini(_scan_index + SCAN_PER_FRAME, scan_targets.size())
		for index in range(_scan_index, end):
			_send_probe(scan_targets[index], probe)
		_scan_index = end if end < scan_targets.size() else -1


func _send_probe(address: String, probe: PackedByteArray) -> void:
	_udp.set_dest_address(address, Protocol.DISCOVERY_PORT)
	_sent += 1
	var result := _udp.put_packet(probe)
	if result != OK:
		_send_errors += 1
		_last_send_error = result


## What the search has done so far, to tell apart "no room exists" from "this
## device cannot reach the network". Shown on the LAN menu for a parent.
func diagnostics() -> Dictionary:
	var own: Array[String] = []
	for address: String in IP.get_local_addresses():
		if _is_private(address):
			own.append(address)
	return {
		"addresses": own,
		"sent": _sent,
		"send_errors": _send_errors,
		"last_error": _last_send_error,
		"received": _received,
		"answers": _answers,
		"rooms": rooms.size(),
	}


## True if the list changed.
func _remember(ip: String, message: Dictionary) -> bool:
	_seen[ip] = _clock
	var room := {"ip": ip, "port": message["port"], "players": message["players"],
			"avatar": message["avatar"], "open": message["open"]}
	for index in rooms.size():
		if rooms[index]["ip"] == ip:
			var different := rooms[index] != room
			rooms[index] = room
			return different
	if rooms.size() >= MAX_ROOMS:
		return false
	rooms.append(room)
	return true
