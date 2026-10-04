class_name PlayedMatch
extends RefCounted
## A match as one player's client plays it, a beat at a time: what SimDriver steps,
## whether its host is in this process (LoopbackMatch) or on a server (RemoteMatch).

var client: MatchClient


## One beat of the match's 30 Hz; returns the events the client's view reached.
func step() -> Array[SimEvent]:
	return []
