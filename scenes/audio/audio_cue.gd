class_name AudioCue
extends RefCounted
## One sound the match asks for on a tick: what, whose, where in ship space, and
## how loud. CuePlanner makes them from snapshots, events and the ship's pose;
## MatchAudio plays them. A cue is presentation only (D12): nothing reads it back.

enum Kind {
	FOOTSTEP,
	GRUNT,
	WHOOSH,
	IMPACT,
	VAULT,
	FALL,
	LANDING,
	SPLASH,
	WIN_STING,
	LOSS_STING,
	CREAK,
	GROAN,
	FLOOD,
	## A lurch's telegraph (SH6): the horn, a second ahead of the swing.
	HORN,
	## A deck giving way (SH6): as its collapse is telegraphed, and as it goes.
	COLLAPSE,
}
## What a footfall or a landing comes down on.
enum Ground { WOOD, METAL, WET }

var kind: Kind
var tick: int
## The seat it comes from, or -1 for the ship and the match.
var seat: int = -1
## Ship space, where a positional cue sounds from.
var position: Vector3
## False for the listener's own body and for the match's stings: those sound in
## the head, not from a place.
var positional: bool
## Linear, 0…1, on top of the kind's own level.
var gain: float = 1.0
var ground: Ground = Ground.WOOD
## A fully charged shove's whoosh and impact: lower and louder than a tap's.
var heavy: bool


func _init(cue_kind: Kind, cue_tick: int, cue_seat: int = -1) -> void:
	kind = cue_kind
	tick = cue_tick
	seat = cue_seat


## One line for a log: tick, kind, seat, where it sounds and how loud.
func describe() -> String:
	var line := "tick %d %s" % [tick, Kind.keys()[kind]]
	if seat >= 0:
		line += " seat %d" % seat
	if kind == Kind.FOOTSTEP or kind == Kind.LANDING:
		line += " on %s" % Ground.keys()[ground]
	if heavy:
		line += " heavy"
	line += " positional" if positional else " in the head"
	return line + " gain %.2f" % gain
