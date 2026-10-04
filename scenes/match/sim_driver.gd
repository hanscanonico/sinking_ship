class_name SimDriver
extends Node
## The only thing in a scene that steps the match (D2): an accumulator that runs a
## PlayedMatch — a LoopbackMatch, the local host and this player's client over the
## wire between them (SH11), or a RemoteMatch played from a server (SH12) — at 30 Hz
## however fast frames come, and keeps the client's last two views for the scene to
## interpolate between. The scene reads the client's views, never the host (D5).

signal stepped(events: Array[SimEvent])
## The local seat's predicted body moved [param by] as the client caught up with
## the host: the view draws the jump away (D12).
signal corrected(by: Vector3)

## A long hitch is dropped rather than caught up, so a stall never fast-forwards.
const MAX_STEPS_PER_FRAME := 5

var client: MatchClient
var previous: Dictionary
var current: Dictionary
## How far the display is from [member previous] to [member current], 0…1.
var alpha: float

var _played: PlayedMatch
var _accumulator := 0.0


func start(played: PlayedMatch) -> void:
	_played = played
	client = played.client
	previous = client.view()
	current = client.view()
	alpha = 0.0
	_accumulator = 0.0


## One beat of the match, now.
func step() -> void:
	previous = current
	var events := _played.step()
	current = client.view()
	if client.correction != Vector3.ZERO:
		corrected.emit(client.correction)
	stepped.emit(events)


func _process(delta: float) -> void:
	if client == null:
		return
	if client.is_over():
		previous = current
		alpha = 0.0
		return
	_accumulator += delta
	var steps := 0
	while _accumulator >= Ticks.SECONDS_PER_TICK and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= Ticks.SECONDS_PER_TICK
		steps += 1
		step()
		if client.is_over():
			break
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = minf(_accumulator, Ticks.SECONDS_PER_TICK)
	alpha = clampf(_accumulator / Ticks.SECONDS_PER_TICK, 0.0, 1.0)
