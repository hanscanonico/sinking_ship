class_name RoomServer
extends RefCounted
## The server (SH12): rooms over one Transport, stepped a beat at a time — each beat
## one tick of every match on — by whatever keeps its time. Nothing here is a Node:
## the tests drive it over a loopback, a headless Godot over a WebSocket.
##
## Every client is hostile until it is not (R9). Its first packet must be a HELLO of
## this protocol and data with a display name ServerRules accepts, or it is refused —
## VERSION and DATA name the mismatch — and its connection closed. After that, a
## packet too big, unreadable or of a kind a client never sends ends the connection,
## as do too many packets a second, too many CREATEs and JOINs, a silence too long
## and a backlog a client has stopped reading. A client's input only ever reaches its
## own seat: the seat is the connection's, never the packet's. Rooms and connections
## are capped — a client past the cap is told so — an idle room is closed, a finished
## match let go, a player silent too long given up for gone, and the matches built in
## a second, and by one connection, are capped.
##
## A room code is all that keeps a room to those it is given to, and every player is
## shown the match seeds: codes and seeds come from separate Draws, so no seed seen
## says anything of a code.
##
## The log, line by line through [signal logged]: who came and went, each room's
## match, its transcript, and every log_interval each running room's tick time,
## round trips and snapshot bandwidth.

## A line for the server's log.
signal logged(line: String)
## A room's match has finished and been let go: its linger over, or everyone gone.
signal match_finished(code: String)

## Where a connection is: waiting for its HELLO, welcomed and in no room, in a room,
## or refused and about to be closed.
enum Stage { HELLO, LOBBY, ROOM, LEAVING }

## The most round trips a connection keeps, oldest dropped first.
const RTT_SAMPLES := 512
## Codes drawn for one room before the server gives up on it: a free one comes at the
## first draw but for a sliver of the time, unless the Draws are broken.
const CODE_DRAWS := 16


## One client's connection.
class Connection:
	extends RefCounted
	var peer: int
	var stage := RoomServer.Stage.HELLO
	var name := ""
	var room: Room
	## The beat its stage began at.
	var since: int
	## The beat it last sent an input or a pong at, or its stage began at if later.
	var heard: int
	## The CREATEs and JOINs it has used of room_attempts, and the beat the next one
	## given back is counted from: one each attempt_refill.
	var attempts := 0
	var attempts_from: int
	## The beat it last started a match at; -1 when it never has.
	var started := -1
	## The beat the current second of its packets began at, and how many came in it.
	var window_from: int
	var window_packets := 0
	## The last PING's stamp, the beat it went at and when, in microseconds; -1 when
	## none is out.
	var ping_stamp := -1
	var ping_beat := 0
	var ping_usec := 0
	var rtt_ms := PackedFloat64Array()

	func _init(peer_id: int, beat: int) -> void:
		peer = peer_id
		since = beat
		heard = beat
		attempts_from = beat
		window_from = beat


var _wire: Transport
var _rules: ServerRules
var _net: NetRules
var _match_rules: MatchRules
var _codec: RoomCodec
var _seeds: Draws
var _codes: Draws
var _beat := 0
var _pings := 0
## The beat the current second of STARTs began at, and how many came in it.
var _starts_from := 0
var _starts := 0
## Peer id → Connection.
var _connections := {}
## Peer id → the beat it was turned away at, the server full: closed refusal_linger
## later, once it has read why. Never more than max_connections at once.
var _full := {}
## Code → Room.
var _rooms := {}


## A server of [param match_rules]' matches over [param wire], drawing match seeds
## from [param seeds] and room codes' letters from [param codes].
func _init(
	wire: Transport,
	server_rules: ServerRules,
	net_rules: NetRules,
	match_rules: MatchRules,
	seeds: Draws,
	codes: Draws
) -> void:
	_wire = wire
	_rules = server_rules
	_net = net_rules
	_match_rules = match_rules
	_seeds = seeds
	_codes = codes
	_codec = RoomCodec.new(data_hash(match_rules, net_rules))


## The hash a client's data must match: every match of [param match_rules] played to
## [param net_rules] has it, whatever its seed or seats (WireCodec.match_hash).
static func data_hash(match_rules: MatchRules, net_rules: NetRules) -> String:
	return WireCodec.match_hash(MatchConfig.from_rules(match_rules, 0), net_rules)


## Every reason a server of these rules cannot run; empty when it can.
static func problems(
	server_rules: ServerRules, net_rules: NetRules, match_rules: MatchRules
) -> PackedStringArray:
	var found := server_rules.problems()
	found.append_array(net_rules.problems())
	found.append_array(match_rules.problems())
	if found.is_empty():
		found.append_array(MatchConfig.from_rules(match_rules, 0).problems())
		if server_rules.players_per_room > match_rules.seats:
			found.append("server: players_per_room must be at most the match's seats")
		var profile := BotProfile.for_tier(match_rules.bot_tier)
		if profile == null:
			found.append("bot: no profile for the tier %s" % match_rules.bot_tier)
		else:
			found.append_array(profile.problems())
	return found


func room(code: String) -> Room:
	return _rooms.get(code)


func room_count() -> int:
	return _rooms.size()


func connection_count() -> int:
	return _connections.size()


## One beat: what has come taken in, every room's match a tick on, then the clocks —
## timeouts, pings, idle rooms, the log.
func step() -> void:
	_beat += 1
	take_in()
	for code: String in _rooms.keys():
		_step_room(_rooms[code])
	_keep_time()


## Connections opened and closed, and packets taken in, between beats as well as on
## them: a pong is timed as it comes, and a frame waits in its seat's buffer. A peer
## that opened and closed since the last look is never a connection at all.
func take_in() -> void:
	var gone := {}
	for peer: int in _wire.closed():
		gone[peer] = true
		_forget(peer)
	for peer: int in _wire.opened():
		if not gone.has(peer):
			_accept(peer)
	for packet: Transport.Packet in _wire.receive():
		_take(packet)


## Makes [param peer] a connection, or — the server full — tells it so and lets it
## go: closed at once when as many are already waiting to be.
func _accept(peer: int) -> void:
	if _connections.size() < _rules.max_connections:
		_connections[peer] = Connection.new(peer, _beat)
		return
	_say("peer %d turned away: %d connections already" % [peer, _connections.size()])
	if _full.size() < _rules.max_connections:
		_wire.send(peer, _codec.encode_refused(RoomCodec.Refusal.SERVER_FULL))
		_full[peer] = _beat
	else:
		_wire.close(peer)


func _forget(peer: int) -> void:
	_full.erase(peer)
	var connection: Connection = _connections.get(peer)
	if connection == null:
		return
	_connections.erase(peer)
	if connection.stage != Stage.LEAVING:
		_say("%s disconnected" % _who(connection))
	_leave_room(connection)


func _take(packet: Transport.Packet) -> void:
	var connection: Connection = _connections.get(packet.peer)
	if connection == null or connection.stage == Stage.LEAVING:
		return
	if _beat - connection.window_from >= Ticks.RATE:
		connection.window_from = _beat
		connection.window_packets = 0
	connection.window_packets += 1
	if connection.window_packets > _rules.packets_per_second:
		_turn_away(connection, RoomCodec.Refusal.FLOOD)
		return
	if packet.bytes.size() > _rules.packet_bytes:
		_turn_away(connection, RoomCodec.Refusal.MALFORMED)
		return
	if connection.stage == Stage.HELLO:
		_hello(connection, packet.bytes)
		return
	var message := _codec.decode(packet.bytes)
	if message == null:
		_turn_away(connection, RoomCodec.Refusal.MALFORMED)
		return
	match message.kind:
		WireCodec.Kind.INPUT:
			# Only a seated player's, to their room's match — whose host reads it as the
			# connection's seat's; late ones from a room left are dropped unread.
			connection.heard = _beat
			var at := connection.room
			if at != null and at.phase == Room.Phase.PLAYING:
				at.wire.deliver(packet)
		WireCodec.Kind.PONG:
			connection.heard = _beat
			_pong(connection, message.value)
		WireCodec.Kind.CREATE:
			_create(connection)
		WireCodec.Kind.JOIN:
			_join(connection, message.text)
		WireCodec.Kind.START:
			_start(connection)
		WireCodec.Kind.LEAVE:
			_leave(connection)
		_:
			_turn_away(connection, RoomCodec.Refusal.MALFORMED)


func _hello(connection: Connection, bytes: PackedByteArray) -> void:
	match _codec.wire.mismatch(bytes):
		WireCodec.Mismatch.VERSION:
			_turn_away(connection, RoomCodec.Refusal.VERSION)
			return
		WireCodec.Mismatch.DATA:
			_turn_away(connection, RoomCodec.Refusal.DATA)
			return
	var message := _codec.decode(bytes)
	if message == null or message.kind != WireCodec.Kind.HELLO:
		_turn_away(connection, RoomCodec.Refusal.MALFORMED)
		return
	var cleaned := _rules.clean_name(message.text)
	if cleaned.is_empty():
		_turn_away(connection, RoomCodec.Refusal.NAME)
		return
	connection.name = cleaned
	_enter(connection, Stage.LOBBY)
	_wire.send(connection.peer, _codec.encode_bare(WireCodec.Kind.WELCOME))
	_say("%s said hello" % _who(connection))


func _create(connection: Connection) -> void:
	if connection.room != null:
		_refuse(connection, RoomCodec.Refusal.IN_ROOM)
		return
	if not _attempt(connection):
		return
	if _rooms.size() >= _rules.max_rooms:
		_refuse(connection, RoomCodec.Refusal.SERVER_FULL)
		return
	var code := _new_code()
	if code.is_empty():
		_say("no free room code drawn for %s" % _who(connection))
		_refuse(connection, RoomCodec.Refusal.BUSY)
		return
	var created := Room.new(code, _wire, _beat)
	_rooms[created.code] = created
	_say("room %s created by %s" % [created.code, _who(connection)])
	_seat(connection, created)


func _join(connection: Connection, typed: String) -> void:
	if connection.room != null:
		_refuse(connection, RoomCodec.Refusal.IN_ROOM)
		return
	if not _attempt(connection):
		return
	var joined: Room = _rooms.get(RoomCodec.normalize_code(typed))
	if joined == null:
		_refuse(connection, RoomCodec.Refusal.NO_ROOM)
	elif joined.phase != Room.Phase.WAITING:
		_refuse(connection, RoomCodec.Refusal.PLAYING)
	elif joined.members.size() >= _rules.players_per_room:
		_refuse(connection, RoomCodec.Refusal.ROOM_FULL)
	else:
		_seat(connection, joined)


## Counts a CREATE or JOIN of [param connection]'s, one of those used given back each
## attempt_refill; false, and the connection turned away, when it is one too many.
func _attempt(connection: Connection) -> bool:
	var refill := ServerRules.beats(_rules.attempt_refill)
	var back := (_beat - connection.attempts_from) / refill
	if back >= connection.attempts:
		connection.attempts = 0
		connection.attempts_from = _beat
	else:
		connection.attempts -= back
		connection.attempts_from += back * refill
	connection.attempts += 1
	if connection.attempts > _rules.room_attempts:
		_turn_away(connection, RoomCodec.Refusal.ATTEMPTS)
		return false
	return true


func _seat(connection: Connection, into: Room) -> void:
	into.add(connection.peer, connection.name, _beat)
	connection.room = into
	_enter(connection, Stage.ROOM)
	_say(
		(
			"room %s: %s is in (%d/%d)"
			% [into.code, _who(connection), into.members.size(), _rules.players_per_room]
		)
	)
	_send_rosters(into)


func _start(connection: Connection) -> void:
	var at := connection.room
	if at == null:
		_refuse(connection, RoomCodec.Refusal.NO_ROOM)
		return
	if at.host_peer() != connection.peer:
		_refuse(connection, RoomCodec.Refusal.NOT_HOST)
		return
	if at.phase != Room.Phase.WAITING:
		_refuse(connection, RoomCodec.Refusal.PLAYING)
		return
	if not _may_build(connection):
		_refuse(connection, RoomCodec.Refusal.BUSY)
		return
	var match_seed := _seeds.u32()
	if match_seed < 0:
		_say("room %s: no match seed drawn" % at.code)
		_refuse(connection, RoomCodec.Refusal.BUSY)
		return
	_count_build(connection)
	var config := MatchConfig.from_rules(_match_rules, match_seed)
	var bots := BotInputSource.fill(config, BotProfile.for_tier(config.bot_tier))
	at.start(config, _net, bots, _beat)
	var players := PackedStringArray()
	for player: Room.Member in at.members:
		# Its silence counts from here: loading the match may take its client a while.
		var member: Connection = _connections.get(player.peer)
		if member != null:
			member.heard = _beat
		players.append("%s seat %d" % [player.name, player.seat])
		var begin := _codec.encode_begin(config.match_seed, config.seats, player.seat)
		_wire.send(player.peer, begin)
	_say(
		(
			"room %s: match begins · seed %d · %d seats · %s · bots on the rest"
			% [at.code, config.match_seed, config.seats, ", ".join(players)]
		)
	)
	_send_rosters(at)


## Whether a match may be built for [param connection] now: no sooner than
## start_cooldown after its last, and no more than starts_per_second on the whole
## server.
func _may_build(connection: Connection) -> bool:
	var cooldown := ServerRules.beats(_rules.start_cooldown)
	if connection.started >= 0 and _beat - connection.started < cooldown:
		return false
	if _beat - _starts_from >= Ticks.RATE:
		_starts_from = _beat
		_starts = 0
	return _starts < _rules.starts_per_second


## Counts a match built for [param connection] against both of _may_build's limits:
## only once its seed is drawn, as a START refused before that built nothing.
func _count_build(connection: Connection) -> void:
	_starts += 1
	connection.started = _beat


func _leave(connection: Connection) -> void:
	if connection.room == null:
		return
	_leave_room(connection)
	_enter(connection, Stage.LOBBY)


## Takes [param connection] out of its room, if it is in one: the room's other
## players are told, or the room is closed when nobody is left in it.
func _leave_room(connection: Connection) -> void:
	var left := connection.room
	if left == null:
		return
	connection.room = null
	var seat := left.member(connection.peer).seat
	left.remove(connection.peer, _beat)
	if left.phase == Room.Phase.PLAYING:
		_say("room %s: %s left · seat %d to a bot" % [left.code, connection.name, seat])
	else:
		_say("room %s: %s left" % [left.code, connection.name])
	if left.present().is_empty():
		_close_room(left, "everyone left")
	else:
		_send_rosters(left)


func _step_room(stepped: Room) -> void:
	match stepped.phase:
		Room.Phase.PLAYING:
			stepped.step(_beat)
			if stepped.phase == Room.Phase.FINISHED:
				_say("room %s: match over at tick %d" % [stepped.code, stepped.host.tick()])
				for line: String in stepped.transcript.text().strip_edges().split("\n"):
					_say("room %s | %s" % [stepped.code, line])
				_report(stepped, "match")
		Room.Phase.FINISHED:
			stepped.step(_beat)
			if _beat - stepped.since >= ServerRules.beats(_rules.finished_linger):
				stepped.reopen(_beat)
				_say("room %s: waiting for its host again" % stepped.code)
				_send_rosters(stepped)
				match_finished.emit(stepped.code)


## Timeouts, backlogs, pings, idle rooms and the periodic log.
func _keep_time() -> void:
	var linger := ServerRules.beats(_rules.refusal_linger)
	var silence := ServerRules.beats(_rules.silence_timeout)
	for peer: int in _full.keys():
		if _beat - _full[peer] >= linger:
			_full.erase(peer)
			_wire.close(peer)
	var ping_beats := ServerRules.beats(_rules.ping_interval)
	var pinging := _beat % ping_beats == 0
	for connection: Connection in _connections.values():
		var waited := _beat - connection.since
		if connection.stage == Stage.LEAVING:
			if waited >= linger:
				_connections.erase(connection.peer)
				_wire.close(connection.peer)
		elif connection.stage == Stage.HELLO:
			if waited >= ServerRules.beats(_rules.hello_timeout):
				_turn_away(connection, RoomCodec.Refusal.TIMEOUT)
		elif connection.stage == Stage.LOBBY and waited >= ServerRules.beats(_rules.lobby_timeout):
			_turn_away(connection, RoomCodec.Refusal.TIMEOUT)
		elif connection.stage == Stage.ROOM and _beat - connection.heard >= silence:
			_say("%s went silent" % _who(connection))
			_turn_away(connection, RoomCodec.Refusal.TIMEOUT)
		elif _wire.backlog(connection.peer) > _rules.outbound_backlog:
			_say("%s stopped reading" % _who(connection))
			_connections.erase(connection.peer)
			_wire.close(connection.peer)
			_leave_room(connection)
		elif (
			pinging
			and (connection.ping_stamp == -1 or _beat - connection.ping_beat >= 2 * ping_beats)
		):
			# One out twice the interval was lost, or its pong was: a new one replaces it.
			_ping(connection)
	for waiting: Room in _rooms.values():
		var idle := _beat - waiting.since
		if (
			waiting.phase == Room.Phase.WAITING
			and idle >= ServerRules.beats(_rules.idle_room_timeout)
		):
			_close_room(waiting, "idle")
	if _beat % ServerRules.beats(_rules.log_interval) == 0:
		for running: Room in _rooms.values():
			if running.phase == Room.Phase.PLAYING:
				_report(running, "so far")


func _close_room(closing: Room, why: String) -> void:
	_rooms.erase(closing.code)
	if closing.phase == Room.Phase.FINISHED:
		match_finished.emit(closing.code)
	for player: Room.Member in closing.present():
		var connection: Connection = _connections.get(player.peer)
		if connection != null and connection.room == closing:
			connection.room = null
			_enter(connection, Stage.LOBBY)
			_refuse(connection, RoomCodec.Refusal.ROOM_CLOSED)
	_say("room %s closed: %s" % [closing.code, why])


## A code no room has: CODE_LENGTH letters of CODE_LETTERS from the codes' Draws,
## drawn until one is free — max_rooms being a sliver of the codes there are — or ""
## when the Draws cannot draw, or CODE_DRAWS codes were all taken.
func _new_code() -> String:
	for _draw in CODE_DRAWS:
		var code := ""
		for _letter in RoomCodec.CODE_LENGTH:
			var drawn := _codes.below(RoomCodec.CODE_LETTERS.length())
			if drawn < 0:
				return ""
			code += RoomCodec.CODE_LETTERS[drawn]
		if not _rooms.has(code):
			return code
	return ""


func _ping(connection: Connection) -> void:
	# The stamp travels as a u32: the count wraps with it, or no pong would match.
	_pings = (_pings + 1) & 0xFFFFFFFF
	connection.ping_stamp = _pings
	connection.ping_beat = _beat
	connection.ping_usec = Time.get_ticks_usec()
	_wire.send(connection.peer, _codec.encode_stamp(WireCodec.Kind.PING, _pings))


func _pong(connection: Connection, stamp: int) -> void:
	if stamp != connection.ping_stamp:
		return
	connection.ping_stamp = -1
	if connection.rtt_ms.size() >= RTT_SAMPLES:
		connection.rtt_ms.remove_at(0)
	connection.rtt_ms.append((Time.get_ticks_usec() - connection.ping_usec) / 1000.0)


## Logs [param about] [param reported]'s match: its tick time, and each player's round
## trip and the snapshots sent them — payload bytes, before the 2 to 4 bytes a
## WebSocket frame adds to each.
func _report(reported: Room, about: String) -> void:
	var ticks := reported.step_usec.size()
	if ticks == 0:
		return
	var tick_ms := PackedFloat64Array()
	for usec: int in reported.step_usec:
		tick_ms.append(usec / 1000.0)
	var head := "room %s %s" % [reported.code, about]
	_say("%s: %d ticks · tick ms %s" % [head, ticks, _spread(tick_ms)])
	var seconds := Ticks.to_seconds(ticks)
	for player: Room.Member in reported.members:
		var sent: int = reported.wire.sent_bytes.get(player.peer, 0)
		var packets: int = reported.wire.sent_packets.get(player.peer, 0)
		var connection: Connection = _connections.get(player.peer)
		var rtt := "none"
		if connection != null and not connection.rtt_ms.is_empty():
			rtt = _spread(connection.rtt_ms)
		_say(
			(
				"%s: %s seat %d%s · rtt ms %s · %d snapshots of %.0f B · %.2f kB/s"
				% [
					head,
					player.name,
					player.seat,
					" (gone, a bot's)" if player.gone else "",
					rtt,
					packets,
					float(sent) / maxi(packets, 1),
					sent / seconds / 1000.0,
				]
			)
		)


## "mean m · p50 a · p95 b · max c" of [param values].
static func _spread(values: PackedFloat64Array) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += value
	var count := sorted.size()
	return (
		"mean %.2f · p50 %.2f · p95 %.2f · max %.2f"
		% [
			total / count,
			sorted[int(count * 0.5)],
			sorted[mini(count - 1, int(count * 0.95))],
			sorted[-1],
		]
	)


func _enter(connection: Connection, stage: Stage) -> void:
	connection.stage = stage
	connection.since = _beat
	connection.heard = _beat


func _refuse(connection: Connection, reason: RoomCodec.Refusal) -> void:
	_wire.send(connection.peer, _codec.encode_refused(reason))


## Refuses [param connection] for [param reason] and closes it once it has had
## refusal_linger to read why: a socket closed at once can lose what was sent last.
func _turn_away(connection: Connection, reason: RoomCodec.Refusal) -> void:
	_refuse(connection, reason)
	_say("%s turned away: %s" % [_who(connection), RoomCodec.Refusal.keys()[reason]])
	_leave_room(connection)
	_enter(connection, Stage.LEAVING)


func _send_rosters(changed: Room) -> void:
	for player: Room.Member in changed.present():
		_wire.send(player.peer, _codec.encode_roster(changed.roster_for(player.peer)))


func _who(connection: Connection) -> String:
	if connection.name.is_empty():
		return "peer %d" % connection.peer
	return "%s (peer %d)" % [connection.name, connection.peer]


func _say(line: String) -> void:
	logged.emit(line)
