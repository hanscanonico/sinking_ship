class_name LoopbackTransport
extends Transport
## One end of an in-process wire that lies as NetConditions say: each packet it sends
## is lost, or comes latency ± jitter later by the clock, rolled from this end's own
## seeded stream — so the same seed loses and delays the same packets (D4's habit,
## though nothing here is the sim's). Jitter can deliver packets out of order, as a
## real network may.

## Who this end is to the ends it is linked to.
var peer: int

var _clock: NetClock
var _conditions: NetConditions
var _rng: RandomNumberGenerator
## Peer id → the LoopbackTransport at the other end.
var _links := {}
## Packets on their way here: [arrives_at, order sent in, Packet], unsorted.
var _in_flight: Array[Array] = []
var _queued := 0
var _opened := PackedInt32Array()
var _closed := PackedInt32Array()


func _init(
	peer_id: int, clock: NetClock, conditions: NetConditions, stream: RandomNumberGenerator
) -> void:
	peer = peer_id
	_clock = clock
	_conditions = conditions
	_rng = stream


## Joins [param a] and [param b], each reaching the other by its peer id.
static func link(a: LoopbackTransport, b: LoopbackTransport) -> void:
	a._links[b.peer] = b
	b._links[a.peer] = a
	a._opened.append(b.peer)
	b._opened.append(a.peer)


## Parts [param a] and [param b], each told the other has gone. What is already on
## its way still arrives, as a closing socket delivers what was sent before it closed.
static func unlink(a: LoopbackTransport, b: LoopbackTransport) -> void:
	if not a._links.has(b.peer):
		return
	a._links.erase(b.peer)
	b._links.erase(a.peer)
	a._closed.append(b.peer)
	b._closed.append(a.peer)


func send(to_peer: int, bytes: PackedByteArray) -> void:
	var other: LoopbackTransport = _links.get(to_peer)
	if other == null:
		return
	if _conditions.loss > 0.0 and _rng.randf() < _conditions.loss:
		return
	var delay := _conditions.latency
	if _conditions.jitter > 0.0:
		delay += _rng.randf_range(-_conditions.jitter, _conditions.jitter)
	other._queued += 1
	other._in_flight.append([_clock.now + maxf(delay, 0.0), other._queued, Packet.new(peer, bytes)])


func instant() -> bool:
	return _conditions.latency == 0.0 and _conditions.jitter == 0.0 and _conditions.loss == 0.0


func opened() -> PackedInt32Array:
	var peers := _opened
	_opened = PackedInt32Array()
	return peers


func closed() -> PackedInt32Array:
	var peers := _closed
	_closed = PackedInt32Array()
	return peers


func close(to_peer: int) -> void:
	var other: LoopbackTransport = _links.get(to_peer)
	if other != null:
		unlink(self, other)


func receive() -> Array[Packet]:
	var due: Array[Array] = []
	var waiting: Array[Array] = []
	for flight: Array in _in_flight:
		if flight[0] <= _clock.now:
			due.append(flight)
		else:
			waiting.append(flight)
	_in_flight = waiting
	due.sort_custom(_arrives_first)
	var packets: Array[Packet] = []
	for flight: Array in due:
		packets.append(flight[2])
	return packets


static func _arrives_first(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
