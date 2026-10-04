class_name Transport
extends RefCounted
## One end of a wire between a host and its clients (D11): packets out to a peer,
## packets in from any. A packet may be late, out of order or never arrive; nothing
## above this assumes otherwise. LoopbackTransport is the in-process one; WebSocket
## comes behind the same door (SH12, Q8).


## A packet that has arrived: who sent it, and its bytes.
class Packet:
	extends RefCounted
	var peer: int
	var bytes: PackedByteArray

	func _init(from_peer: int, payload: PackedByteArray) -> void:
		peer = from_peer
		bytes = payload


## Sends [param bytes] to [param peer].
func send(_peer: int, _bytes: PackedByteArray) -> void:
	pass


## Every packet that has arrived since the last call, in the order it arrived.
func receive() -> Array[Packet]:
	return []


## Whether every packet arrives, in order, the moment it is sent — as between a host
## and a client in one process with nothing in between: a client then needs neither
## a lead nor an interpolation delay.
func instant() -> bool:
	return false
