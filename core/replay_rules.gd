class_name ReplayRules
extends Resource
## How a replay is played back (data/match/replay.tres): the numbers the timeline and
## the viewer tune by. No match reads them, so a match's data hash leaves them out: a
## replay stays playable whatever they become.

const PATH := "res://data/match/replay.tres"

## Ticks between the snapshots a timeline keeps to seek from (ReplayTimeline). Fewer
## ticks seek faster and keep more: a snapshot every 60 ticks of an 8-seat match is
## about a kilobyte a second of match.
@export var keyframe_every: int = 60
## How many saved replays are kept: the newest so many, the rest pruned as one is
## saved (ReplayRecorder).
@export var keep_newest: int = 20
## The speeds a replay is watched at, slowest first, as multiples of match time
## (ReplayClock); the viewer starts at 1×.
@export var speeds := PackedFloat32Array([0.25, 0.5, 1.0, 2.0, 4.0, 8.0])


static func load_default() -> ReplayRules:
	return load(PATH)
