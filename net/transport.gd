class_name Transport
extends RefCounted
## One end of a wire between a host and its clients (D11): packets out to a peer,
## packets in from any. A packet may be late, out of order or never arrive; nothing
## above this assumes otherwise. LoopbackTransport is the in-process one;
## WebSocketTransport the one between processes (SH12, Q8). Each peer is a
## connection that opens and closes, and whoever holds the other end may be hostile.


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


## The peers whose connection has opened since the last call.
func opened() -> PackedInt32Array:
	return PackedInt32Array()


## The peers whose connection has closed since the last call, whichever end closed
## it; a connection that never opened is reported closed too.
func closed() -> PackedInt32Array:
	return PackedInt32Array()


## Ends the connection to [param peer]; it is reported closed.
func close(_peer: int) -> void:
	pass


## The bytes sent to [param peer] that have not yet left this end: what a peer that
## has stopped reading leaves behind.
func backlog(_peer: int) -> int:
	return 0
