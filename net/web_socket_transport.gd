class_name WebSocketTransport
extends Transport
## The wire between processes (SH12, Q8): WebSocket, through the engine's
## WebSocketMultiplayerPeer — a server listening for clients, or a client whose one
## peer is the server, SERVER_PEER. Each packet is one binary frame, its bytes exactly
## a WireCodec packet. It is reliable and ordered (TCP), so a lost segment holds up
## what follows it (R8): input redundancy and full snapshots make that cost latency,
## never a desync. The peer is no Node: whoever owns this calls poll() every frame,
## which moves what was sent and what has come.

const SERVER_PEER := 1

var _socket := WebSocketMultiplayerPeer.new()
var _serving := false
## A client that has asked to connect and has not yet: if its socket gives up, the
## server is reported closed without ever having opened.
var _dialing := false
## The peers whose connection is open, as this end knows it.
var _live := {}
var _opened := PackedInt32Array()
var _closed := PackedInt32Array()


func _init() -> void:
	_socket.peer_connected.connect(_on_connected)
	_socket.peer_disconnected.connect(_on_disconnected)


## Listens on [param bind_address]:[param port] for clients, each held to
## [param rules]: a second's packets at most unread, a frame no bigger, and
## handshake_timeout to finish its handshake. Its outbound buffer holds twice
## outbound_backlog, so RoomServer drops a client that has stopped reading before the
## buffer is full — and as many packets as that holds of the smallest, so it is the
## bytes that run out first.
func listen(port: int, bind_address: String, rules: ServerRules) -> Error:
	_socket.inbound_buffer_size = rules.packet_bytes * rules.packets_per_second
	_socket.outbound_buffer_size = rules.outbound_backlog * 2
	_socket.max_queued_packets = _socket.outbound_buffer_size / (2 + WireCodec.HASH_BYTES)
	_socket.handshake_timeout = rules.handshake_timeout
	_serving = true
	return _socket.create_server(port, bind_address)


## Connects to the server at [param url] (ws://host:port).
func dial(url: String) -> Error:
	var error := _socket.create_client(url)
	_dialing = error == OK
	return error


## Sends what was sent and takes in what has come; reports a client's failed attempt
## to connect as the server closed.
func poll() -> void:
	_socket.poll()
	if _dialing and _socket.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_dialing = false
		_closed.append(SERVER_PEER)


## Stops listening, or hangs up, and lets every connection go.
func shut() -> void:
	_socket.close()
	for peer: int in _live:
		_closed.append(peer)
	_live.clear()
	_dialing = false


func send(peer: int, bytes: PackedByteArray) -> void:
	if not _live.has(peer):
		return
	# Past the peer's own buffer the engine would refuse it loudly; RoomServer has
	# dropped the client by then.
	var held := _socket.get_peer(peer).get_current_outbound_buffered_amount()
	if held + bytes.size() > _socket.outbound_buffer_size:
		return
	_socket.set_target_peer(peer)
	_socket.put_packet(bytes)


func receive() -> Array[Packet]:
	var packets: Array[Packet] = []
	while _socket.get_available_packet_count() > 0:
		var from := _socket.get_packet_peer()
		var bytes := _socket.get_packet()
		if _live.has(from):
			packets.append(Packet.new(from, bytes))
	return packets


func opened() -> PackedInt32Array:
	var peers := _opened
	_opened = PackedInt32Array()
	return peers


func closed() -> PackedInt32Array:
	var peers := _closed
	_closed = PackedInt32Array()
	return peers


func close(peer: int) -> void:
	if not _live.erase(peer):
		return
	_closed.append(peer)
	if _serving:
		_socket.disconnect_peer(peer)
	else:
		_socket.close()


func backlog(peer: int) -> int:
	if not _live.has(peer):
		return 0
	return _socket.get_peer(peer).get_current_outbound_buffered_amount()


func _on_connected(peer: int) -> void:
	_dialing = false
	_live[peer] = true
	_opened.append(peer)


func _on_disconnected(peer: int) -> void:
	if _live.erase(peer):
		_closed.append(peer)
