class_name NetClock
extends RefCounted
## The time a loopback's packets are in flight against: seconds, moved on by whoever
## steps the match, so a wire that lies about latency lies in the match's time — the
## same under a fixed frame rate, a slow machine or a test.

var now: float


func advance(seconds: float) -> void:
	now += seconds
