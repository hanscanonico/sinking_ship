class_name RoomClient
extends RefCounted
## A player's side of a server's rooms (SH12), Node-free, so the menu, a headless
## autoplayer and the tests drive the same one. It says HELLO with the display name
## as the connection opens; then, on the caller's word, it creates a room, joins one
## by its code, starts the match as the room's host, or leaves. What the server says
## comes back as signals and in [member state] and [member roster]. As a match
## begins, [signal began] gives its config and this client's seat, and play() the
## RemoteMatch a SimDriver steps, the server's snapshots routed to it from here.
## poll() reads the wire: call it every frame, a match on or not.
##
## A packet of another protocol version or another match's data is the server's
## refusal of this client, and closes it with VERSION or DATA; so is any refusal before
## the server's WELCOME.

## The server took the HELLO: rooms may be created and joined.
signal welcomed
## The server refused what was asked — a RoomCodec.Refusal — and the client stays
## where it was; one that ends the connection comes as [signal closed] instead.
signal refused(reason: int)
## The room changed, or was left or closed: [member roster] is null then.
signal roster_changed(roster: RoomRoster)
## The room's match began: [param config] is the match, [param seat] this client's.
signal began(config: MatchConfig, seat: int)
## The connection is over: a RoomCodec.Refusal, or -1 when it was lost or never made.
signal closed(reason: int)

enum State { CONNECTING, LOBBY, ROOM, PLAYING, CLOSED }

var state := State.CONNECTING
## The room this client is in, as last sent; null in none.
var roster: RoomRoster
## Why the connection is over, as [signal closed] said.
var close_reason := -1

var _wire: Transport
var _codec: RoomCodec
var _match_rules: MatchRules
var _net: NetRules
var _name: String
var _server := -1
## The match begun, until play() takes it.
var _config: MatchConfig
var _seat := -1
## The playing match's share of the wire; null while none is played.
var _share: SharedTransport


## A client over [param wire] of [param match_rules]' matches, played to
## [param net_rules] — the data the server must have too — known as
## [param display_name].
func _init(
	wire: Transport, match_rules: MatchRules, net_rules: NetRules, display_name: String
) -> void:
	_wire = wire
	_match_rules = match_rules
	_net = net_rules
	_name = display_name
	_codec = RoomCodec.new(RoomServer.data_hash(match_rules, net_rules))


func create_room() -> void:
	_send(_codec.encode_bare(WireCodec.Kind.CREATE))


## Joins the room [param code] names, however it is cased.
func join_room(code: String) -> void:
	_send(_codec.encode_join(code))


## Starts the room's match: the host's alone to do.
func start_match() -> void:
	_send(_codec.encode_bare(WireCodec.Kind.START))


func leave_room() -> void:
	if state != State.ROOM and state != State.PLAYING:
		return
	_send(_codec.encode_bare(WireCodec.Kind.LEAVE))
	_share = null
	state = State.LOBBY
	roster = null
	roster_changed.emit(roster)


## Ends the connection.
func hang_up() -> void:
	if _server >= 0:
		_wire.close(_server)
	_close(-1)


## The match [signal began] announced, played with [param source]'s frames for this
## client's seat: the RemoteMatch to step.
func play(source: InputSource) -> RemoteMatch:
	_share = SharedTransport.new(_wire)
	return RemoteMatch.new(MatchClient.new(_config, _net, _share, _server, _seat, source))


## Reads what has come: the connection opening or closing, the server's answers, its
## pings — answered at once — and the playing match's snapshots, handed on to it.
func poll() -> void:
	if state == State.CLOSED:
		return
	for peer: int in _wire.opened():
		if _server < 0:
			_server = peer
			_send(_codec.encode_hello(_name))
	for peer: int in _wire.closed():
		if peer == _server or _server < 0:
			_close(-1)
			return
	for packet: Transport.Packet in _wire.receive():
		if packet.peer != _server:
			continue
		match _codec.wire.mismatch(packet.bytes):
			WireCodec.Mismatch.VERSION:
				_refused(RoomCodec.Refusal.VERSION)
			WireCodec.Mismatch.DATA:
				_refused(RoomCodec.Refusal.DATA)
			WireCodec.Mismatch.NONE:
				_read(packet)
		if state == State.CLOSED:
			return


func _read(packet: Transport.Packet) -> void:
	var message := _codec.decode(packet.bytes)
	if message == null:
		return
	match message.kind:
		WireCodec.Kind.WELCOME:
			state = State.LOBBY
			welcomed.emit()
		WireCodec.Kind.REFUSED:
			_refused(message.value)
		WireCodec.Kind.ROSTER:
			roster = message.roster
			if not roster.playing:
				_share = null
				state = State.ROOM
			elif state != State.PLAYING:
				state = State.ROOM
			roster_changed.emit(roster)
		WireCodec.Kind.BEGIN:
			_begin(message)
		WireCodec.Kind.SNAPSHOT:
			if _share != null:
				_share.deliver(packet)
		WireCodec.Kind.PING:
			_send(_codec.encode_stamp(WireCodec.Kind.PONG, message.value))


func _refused(reason: int) -> void:
	if RoomCodec.ends_connection(reason) or state == State.CONNECTING:
		_wire.close(_server)
		_close(reason)
		return
	if reason == RoomCodec.Refusal.ROOM_CLOSED:
		_share = null
		state = State.LOBBY
		roster = null
		roster_changed.emit(roster)
	refused.emit(reason)


## Takes up the match BEGIN announces, when it is one this client's data can play.
func _begin(message: RoomCodec.Message) -> void:
	var seats := message.seats
	if seats < _match_rules.min_seats or seats > _match_rules.max_seats:
		return
	_config = MatchConfig.from_rules(_match_rules, message.value, seats)
	_seat = message.seat
	state = State.PLAYING
	began.emit(_config, _seat)


func _send(bytes: PackedByteArray) -> void:
	if _server >= 0 and state != State.CLOSED:
		_wire.send(_server, bytes)


func _close(reason: int) -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	close_reason = reason
	_share = null
	closed.emit(reason)
