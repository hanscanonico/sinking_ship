class_name MatchTranscript
extends RefCounted
## A match told as text, one line per exit and per sinking event, and one for the end:
##   00:52.3 seat 4 out · water · place 6
##   02:12.4 bridge collapsing
##   winner seat 2 at 02:21.0 · digest 9f3c…
## What `make match` prints and what the golden files hold. Seats are sim seat ids.

const CAUSES := {PlayerState.Cause.NONE: "none", PlayerState.Cause.WATER: "water"}
const DIGEST_LENGTH := 16

var _lines := PackedStringArray()
var _ended: SimEvent


## Match time as mm:ss.t, from the tick count — tenths rounded down.
static func clock(tick: int) -> String:
	var tenths := tick * 10 / Ticks.RATE
	return "%02d:%02d.%d" % [tenths / 600, tenths / 10 % 60, tenths % 10]


func add(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SEAT_OUT:
				_lines.append(
					(
						"%s seat %d out · %s · place %d"
						% [clock(event.tick), event.seat, CAUSES[event.cause], event.place]
					)
				)
			SimEvent.Kind.MATCH_ENDED:
				_ended = event
			SimEvent.Kind.SHIP_LURCHING:
				_lines.append("%s lurch coming · heel %+.0f°" % [clock(event.tick), event.heel_deg])
			SimEvent.Kind.SHIP_LURCHED:
				_lines.append("%s lurched · heel %+.0f°" % [clock(event.tick), event.heel_deg])
			SimEvent.Kind.PLATFORM_COLLAPSING:
				_lines.append("%s %s collapsing" % [clock(event.tick), event.platform])
			SimEvent.Kind.PLATFORM_COLLAPSED:
				_lines.append("%s %s collapsed" % [clock(event.tick), event.platform])
			SimEvent.Kind.RAILING_BROKE:
				_lines.append("%s railing %d broke" % [clock(event.tick), event.railing])
			SimEvent.Kind.PLUNGE_BEGAN:
				_lines.append("%s the plunge" % clock(event.tick))


## The closing line: the verdict, or where the match was stopped, and the digest.
func finish(runner: MatchRunner) -> void:
	var digest := runner.digest.hex().substr(0, DIGEST_LENGTH)
	if _ended == null:
		_lines.append("unfinished at %s · digest %s" % [clock(runner.tick()), digest])
	elif _ended.seat == -1:
		_lines.append("draw at %s · digest %s" % [clock(_ended.tick), digest])
	else:
		_lines.append(
			"winner seat %d at %s · digest %s" % [_ended.seat, clock(_ended.tick), digest]
		)


func text() -> String:
	return "\n".join(_lines) + "\n"
