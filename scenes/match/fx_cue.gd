class_name FxCue
extends RefCounted
## One thing the sinking shows (FxPlanner), as an AudioCue is one thing the match
## sounds: what, where in ship space, which way and how hard. SinkingFx plays it;
## nothing here reaches the sim (D12).

## SPRAY: white water thrown up where the sea meets the ship, at a point or in a
## sheet along a line. WASH: the white water along the line where the sea crosses a
## deck, for this step. SPLASH: something going into the sea. VENT: air blown out of
## an opening as the room behind it floods. STEAM: a plume for a while, then wisps.
## BUBBLES: air boiling up through the sea for a while. DUST, SPLINTERS: a burst.
## CHUNKS: wreckage falling from a deck to the floor beneath. FLOTSAM: a piece
## thrown onto the sea, to float. SMOKE: how thick the funnel's smoke is now, and
## which way it leaves the funnel. BELCH: the funnel coughing. CLOUD: the dust of a
## deck giving way, billowing up and drifting off. SIFT: dust shaken down from a
## room's ceiling. DEBRIS: bits of wreckage thrown up to rain on the decks round.
## SLIDE: loose gear sent sliding down a deck. RAIN: spray blown over the ship from
## where the sea breaks over it, raining down, for this step.
enum Kind {
	SPRAY,
	WASH,
	SPLASH,
	VENT,
	STEAM,
	BUBBLES,
	DUST,
	SPLINTERS,
	CHUNKS,
	FLOTSAM,
	SMOKE,
	BELCH,
	CLOUD,
	SIFT,
	DEBRIS,
	SLIDE,
	RAIN,
}
## What a FLOTSAM piece is.
enum Piece { PLANK, CRATE, CHAIR, LIFEBELT }

var kind: Kind
var tick: int
## Ship-local: where it happens; WASH, SPRAY: one end of the line; FLOTSAM: where the
## piece leaves the ship from; SIFT: the middle of the room's ceiling; SLIDE: the
## middle of the deck.
var position: Vector3
## Ship-local. WASH: the line's other end. SPRAY: the sheet's other end, or its
## position again for a burst. FLOTSAM: where the piece comes down, outboard of every
## deck. CHUNKS, SIFT, SLIDE: the half-extent of the deck or room it covers.
var end: Vector3
## Ship-local and unit: the way it is thrown; FLOTSAM: the way it drifts off; WASH:
## the way the sea climbs the deck, in its plane; SMOKE: the way the smoke leaves the
## funnel; SLIDE: the deck's downhill.
var toward := Vector3.UP
## 0…1.
var strength := 1.0
## Metres it spreads over round its position. CHUNKS: how far they fall. SIFT: how
## far its dust falls to the floor. DEBRIS: how far round it the pieces come down.
var radius := 0.0
## SPRAY, SPLASH: how high over the sea its white water may climb, in metres.
var rise := 0.0
## STEAM, BUBBLES: seconds it keeps going at full.
var seconds := 0.0
var piece: Piece = Piece.PLANK
## SPLASH: the seat that went in, or -1.
var seat := -1
## SIFT: the room it falls in, by index in the layout.
var room := -1
## Whether it happens on the sea: drawn on the world plane under its position (D7).
var on_sea := false


func _init(cue_kind: Kind, cue_tick: int, at: Vector3 = Vector3.ZERO) -> void:
	kind = cue_kind
	tick = cue_tick
	position = at
	end = at


func describe() -> String:
	var line := "tick %d %s at %s" % [tick, Kind.keys()[kind], position.snappedf(0.01)]
	if kind in [Kind.WASH, Kind.FLOTSAM, Kind.SPRAY] and end != position:
		line += " to %s" % end.snappedf(0.01)
	if kind == Kind.FLOTSAM:
		line += " %s" % Piece.keys()[piece]
	if seat >= 0:
		line += " seat %d" % seat
	return line + " strength %.2f" % strength
