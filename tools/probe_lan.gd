extends SceneTree
## Diagnostic: asks the network who is hosting a room and prints every answer.
##
##   godot --headless --path . --quit-after 3000 -s tools/probe_lan.gd -- unicast <ip>
##   godot --headless --path . --quit-after 3000 -s tools/probe_lan.gd -- broadcast
##   godot --headless --path . --quit-after 3000 -s tools/probe_lan.gd -- scan
##
## unicast   one probe straight to <ip>
## broadcast probes to the broadcast addresses of this machine
## scan      one probe to each address of the local /24 (no broadcast involved)
## Use the Godot executable WITHOUT "_console" so the firewall rule applies.

const Protocol := preload("res://scripts/net/protocol.gd")
const LanDiscovery := preload("res://scripts/net/lan_discovery.gd")

const SECONDS := 7.0


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "broadcast"
	var targets: Array[String] = []
	var local: Array = Array(IP.get_local_addresses())
	print("PROBE local addresses: ", local)
	match mode:
		"unicast":
			if args.size() < 2:
				print("PROBE unicast needs an address")
				quit(2)
				return
			targets.append(args[1])
		"broadcast":
			targets = LanDiscovery.broadcast_addresses(local)
		"scan":
			targets = LanDiscovery.subnet_hosts(local)
	print("PROBE mode=%s, %d target(s)" % [mode, targets.size()])

	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	if udp.bind(0) != OK:
		print("PROBE cannot open a socket")
		quit(1)
		return
	var packet := Protocol.encode({"t": "probe"})
	var heard := {}
	var deadline := Time.get_ticks_msec() + int(SECONDS * 1000.0)
	var next_send := 0
	while Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() >= next_send:
			next_send = Time.get_ticks_msec() + 1000
			for address in targets:
				udp.set_dest_address(address, Protocol.DISCOVERY_PORT)
				udp.put_packet(packet)
		while udp.get_available_packet_count() > 0:
			var bytes := udp.get_packet()
			var ip := udp.get_packet_ip()
			var message := Protocol.decode(bytes, true)
			if not heard.has(ip):
				heard[ip] = true
				print("PROBE reply from %s: %s" % [ip, str(message)])
		await process_frame
	print("PROBE done: %d room(s) answered" % heard.size())
	quit()
