class_name SeatBuffer
extends InputSource
## A client's seat on the host (D11): the frames heard from it, keyed by tick, behind
## the same door as every other seat's source (D3). A tick whose frame has not come is
## answered null, and the sim repeats the seat's last frame; a frame that comes after
## its tick was stepped is dropped, never rewound.

var seat: int
## The tick of the last frame of this seat's that was applied, or -1: its ack.
var applied := -1
## The newest tick a frame has been heard for, or -1.
var heard := -1
## How many ticks before its tick was stepped that newest frame arrived; below zero
## it came late, and was dropped.
var early := 0

var _frames := {}


func _init(seat_id: int) -> void:
	seat = seat_id


## Keeps each of [param frames] whose tick is [param next_tick] — the next to be
## stepped — or later, and has not been heard before. Of a packet, only its last
## input_redundancy frames count, and none past what a client may predict to: a
## frame further ahead is not heard of at all.
func take(frames: Array[InputFrame], next_tick: int, net_rules: NetRules) -> void:
	var horizon := next_tick + net_rules.prediction_cap_ticks()
	var newest := -1
	for frame: InputFrame in frames.slice(-net_rules.input_redundancy):
		if frame.tick > horizon:
			continue
		newest = maxi(newest, frame.tick)
		if frame.tick >= next_tick and not _frames.has(frame.tick):
			_frames[frame.tick] = frame
	if newest > heard:
		heard = newest
		early = newest - next_tick


func next_frame(tick: int) -> InputFrame:
	var frame: InputFrame = _frames.get(tick)
	for buffered: int in _frames.keys():
		if buffered <= tick:
			_frames.erase(buffered)
	if frame != null:
		applied = tick
	return frame
