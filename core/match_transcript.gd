class_name MatchTranscript
extends RefCounted
## A match told as text, one line per exit, per sinking event, per railing broken and
## per crate lost, and one for the end:
##   00:52.3 seat 4 out · cold · place 6
##   01:31.0 seat 1 out · cold · place 5 · credit crate 2
##   02:12.4 bridge collapsing
##   winner seat 2 at 02:21.0 · digest 9f3c…
## What `make match` prints and what the golden files hold. Seats are sim seat ids.

const CAUSES := {PlayerState.Cause.NONE: "none", PlayerState.Cause.COLD: "cold"}
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
						"%s seat %d out · %s · place %d%s"
						% [
							clock(event.tick),
							event.seat,
							CAUSES[event.cause],
							event.place,
							_crate_credit(event)
						]
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
			SimEvent.Kind.CRATE_LOST:
				_lines.append("%s crate %d lost" % [clock(event.tick), event.prop])
			SimEvent.Kind.PLUNGE_BEGAN:
				_lines.append("%s the plunge" % clock(event.tick))


## " · credit crate n" for an exit a crate is credited with — " shoved by seat s"
## when a seat's shove sent it — and nothing for any other.
static func _crate_credit(event: SimEvent) -> String:
	if event.prop == -1:
		return ""
	var line := " · credit crate %d" % event.prop
	if event.credit != -1:
		line += " shoved by seat %d" % event.credit
	return line


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
