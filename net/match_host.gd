class_name MatchHost
extends RefCounted
## The authority (D11): it steps a MatchRunner exactly as the offline game always has
## — the same sim, the same one loop (D13), bots among its sources (D10) — with each
## client's seat a SeatBuffer fed from the wire, and every snapshot_interval ticks it
## sends each client the snapshot and what it has of that client's input. Each
## snapshot repeats the events of the last input_redundancy snapshots' ticks, so a
## lost one loses none; once the match is over, the last snapshot goes out every step.

var runner: MatchRunner

var _wire: Transport
var _rules: NetRules
var _codec: WireCodec
## Peer id → its seat's SeatBuffer.
var _clients := {}
## The events of the ticks the next snapshot repeats.
var _recent: Array[SimEvent] = []


func _init(match_runner: MatchRunner, wire: Transport, net_rules: NetRules) -> void:
	runner = match_runner
	_wire = wire
	_rules = net_rules
	_codec = WireCodec.new(WireCodec.match_hash(runner.sim.config, net_rules))


## Seats the client at [param peer] on [param buffer] — the source the runner was
## handed for that seat — or, with none, lets it watch.
func admit(peer: int, buffer: SeatBuffer) -> void:
	_clients[peer] = buffer


## Stops serving [param peer], gone: nothing more of its is read, nor sent to it. Its
## seat's source plays on — a ClientSeat hands it to a bot (SH12).
func release(peer: int) -> void:
	_clients.erase(peer)


func is_over() -> bool:
	return runner.is_over()


func tick() -> int:
	return runner.tick()


## Takes in what the clients sent, steps the match one tick and sends the snapshot
## when it is due; returns the tick's events.
func step() -> Array[SimEvent]:
	for packet: Transport.Packet in _wire.receive():
		var buffer: SeatBuffer = _clients.get(packet.peer)
		if buffer != null:
			buffer.take(_codec.decode_inputs(packet.bytes, buffer.seat), runner.tick(), _rules)
	var events := runner.step()
	_recent.append_array(events)
	if runner.is_over() or runner.tick() % _rules.snapshot_interval == 0:
		_send_snapshots()
	return events


func _send_snapshots() -> void:
	var since := runner.tick() - _rules.input_redundancy * _rules.snapshot_interval
	var repeated: Array[SimEvent] = []
	var events: Array[Dictionary] = []
	for event: SimEvent in _recent:
		if event.tick >= since:
			repeated.append(event)
			events.append(event.to_dict())
	_recent = repeated
	var snapshot := runner.snapshot.duplicate()
	snapshot["events"] = events
	for peer: int in _clients:
		var buffer: SeatBuffer = _clients[peer]
		if buffer == null:
			_wire.send(peer, _codec.encode_snapshot(snapshot, -1, -1, 0))
		else:
			_wire.send(
				peer, _codec.encode_snapshot(snapshot, buffer.applied, buffer.heard, buffer.early)
			)
