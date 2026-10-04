class_name NetConditions
extends RefCounted
## What a loopback pretends the wire does to each packet: how late it comes, how
## much that varies either way, and how often it never comes. The offline game's are
## all zero; `--net-sim=latency:120,jitter:20,loss:5` (milliseconds, and a
## percentage) makes it lie (SH11).

## Seconds each packet takes, one way.
var latency: float
## Up to this many seconds more or less, drawn per packet.
var jitter: float
## The chance, 0…1, that a packet is lost.
var loss: float


func _init(latency_s: float = 0.0, jitter_s: float = 0.0, loss_chance: float = 0.0) -> void:
	latency = latency_s
	jitter = jitter_s
	loss = loss_chance


## The conditions [param text] names, as `latency:MS,jitter:MS,loss:PERCENT` in any
## order, any of them left out at zero; null when it is not that.
static func parse(text: String) -> NetConditions:
	var parsed := NetConditions.new()
	for part: String in text.split(",", false):
		var pair := part.split(":")
		if pair.size() != 2 or not pair[1].is_valid_float() or pair[1].to_float() < 0.0:
			return null
		var value := pair[1].to_float()
		match pair[0]:
			"latency":
				parsed.latency = value / 1000.0
			"jitter":
				parsed.jitter = value / 1000.0
			"loss":
				if value > 100.0:
					return null
				parsed.loss = value / 100.0
			_:
				return null
	return parsed
