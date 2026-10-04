class_name Room
extends RefCounted
## One room of a server (SH12): its code, the players in it — the first of them its
## host — and, once the host starts it, one match: a MatchHost whose seats are the
## players', in the order they joined, and bots' after them (D10). A player who goes
## mid-match leaves their seat to a bot that has watched it all along (ClientSeat);
## the match never waits for anyone. Once it is over the room waits again for its
## host. The room keeps what it measures — each tick's time, and in its wire what it
## sent each player — for the server's log.

enum Phase { WAITING, PLAYING, FINISHED }


## A player in the room.
class Member:
	extends RefCounted
	var peer: int
	var name: String
	## The seat the match gives this player; -1 while the room waits.
	var seat := -1
	## Whether the client has gone mid-match, its seat a bot's.
	var gone := false

	func _init(peer_id: int, display_name: String) -> void:
		peer = peer_id
		name = display_name


var code: String
var phase := Phase.WAITING
var members: Array[Member] = []
## The match while it plays and lingers; null while the room waits.
var host: MatchHost
## The room's share of the server's transport: its players' inputs in, its snapshots
## out.
var wire: SharedTransport
var transcript: MatchTranscript
## The server beat the room last changed at: what idles it, or ends its linger.
var since: int
## Microseconds each tick of the match took to step, bots, sim and snapshots.
var step_usec := PackedInt64Array()

## Seat → the ClientSeat a player's frames come through.
var _seats := {}


func _init(room_code: String, through: Transport, beat: int) -> void:
	code = room_code
	wire = SharedTransport.new(through)
	since = beat


## The players whose clients are still here, in seat order.
func present() -> Array[Member]:
	var here: Array[Member] = []
	for member: Member in members:
		if not member.gone:
			here.append(member)
	return here


## The peer that starts the match: the first player still here; -1 with none.
func host_peer() -> int:
	var here := present()
	return here[0].peer if not here.is_empty() else -1


func member(peer: int) -> Member:
	for each: Member in members:
		if each.peer == peer:
			return each
	return null


func add(peer: int, display_name: String, beat: int) -> void:
	members.append(Member.new(peer, display_name))
	since = beat


## Takes [param peer] out of the room: struck from the list while it waits, its seat
## handed to a bot while its match is on.
func remove(peer: int, beat: int) -> void:
	var leaving := member(peer)
	if leaving == null:
		return
	since = beat
	if phase == Phase.WAITING:
		members.erase(leaving)
		return
	leaving.gone = true
	host.release(peer)
	var seat: ClientSeat = _seats.get(leaving.seat)
	if seat != null:
		seat.hand_to_bot()


## Starts [param config]'s match: a seat for each player, in order, from
## [param bots] — one per seat, by id — the rest of them bots.
func start(config: MatchConfig, net_rules: NetRules, bots: Array[InputSource], beat: int) -> void:
	var sources := bots.duplicate()
	_seats.clear()
	for index in members.size():
		var player := members[index]
		player.seat = index
		var seat := ClientSeat.new(SeatBuffer.new(index), bots[index])
		_seats[index] = seat
		sources[index] = seat
	host = MatchHost.new(MatchRunner.new(MatchSim.create(config), sources), wire, net_rules)
	for player: Member in members:
		host.admit(player.peer, _seats[player.seat].buffer)
	wire.sent_bytes.clear()
	wire.sent_packets.clear()
	step_usec.clear()
	transcript = MatchTranscript.new()
	phase = Phase.PLAYING
	since = beat


## Whether [param seat] of the match on is played by a bot.
func is_bot(seat: int) -> bool:
	var played: ClientSeat = _seats.get(seat)
	return played == null or played.handed_over


## One tick of the match, timed: it plays on, or — finished — sends its last snapshot
## again. Returns the tick's events.
func step(beat: int) -> Array[SimEvent]:
	var started := Time.get_ticks_usec()
	var events := host.step()
	if phase == Phase.PLAYING:
		step_usec.append(Time.get_ticks_usec() - started)
		transcript.add(events)
		if host.is_over():
			transcript.finish(host.runner)
			phase = Phase.FINISHED
			since = beat
	return events


## Back to waiting for the host, the players who went struck off.
func reopen(beat: int) -> void:
	for gone: Member in members.duplicate():
		if gone.gone:
			members.erase(gone)
	for player: Member in members:
		player.seat = -1
	host = null
	_seats.clear()
	phase = Phase.WAITING
	since = beat


## The roster as [param peer] is shown it.
func roster_for(peer: int) -> RoomRoster:
	var roster := RoomRoster.new()
	roster.code = code
	roster.playing = phase != Phase.WAITING
	var hosting := host_peer()
	for index in members.size():
		var player := members[index]
		roster.players.append(
			RoomRoster.Player.new(player.name, player.peer == hosting, player.gone)
		)
		if player.peer == peer:
			roster.you = index
	return roster
