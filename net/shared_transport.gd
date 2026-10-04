class_name SharedTransport
extends Transport
## One user's share of a Transport several share (SH12): a room's match on the
## server, or the match beside its room on a client. The owner reads the transport and
## hands in the packets that are this share's; what the share sends goes straight out,
## counted per peer.

## Peer id → the bytes, and the packets, this share has sent it.
var sent_bytes := {}
var sent_packets := {}

var _through: Transport
var _arrived: Array[Packet] = []


func _init(through: Transport) -> void:
	_through = through


## Hands this share [param packet], as if it had come to it alone.
func deliver(packet: Packet) -> void:
	_arrived.append(packet)


func send(peer: int, bytes: PackedByteArray) -> void:
	sent_bytes[peer] = sent_bytes.get(peer, 0) + bytes.size()
	sent_packets[peer] = sent_packets.get(peer, 0) + 1
	_through.send(peer, bytes)


func receive() -> Array[Packet]:
	var arrived := _arrived
	_arrived = []
	return arrived


func instant() -> bool:
	return _through.instant()
