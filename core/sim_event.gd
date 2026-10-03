class_name SimEvent
extends RefCounted
## A typed hint of what happened on a tick. Presentation may announce or animate
## one; it never infers state from one — the snapshot is the truth (D5).

enum Kind { SEAT_OUT, MATCH_ENDED, VAULTED, FELL, LANDED }

var kind: Kind
var tick: int
## SEAT_OUT: who went out. MATCH_ENDED: the winner, or -1 for a draw. VAULTED:
## who tipped over a railing. FELL: who went off an edge. LANDED: who came down.
var seat: int
var place: int
var cause: PlayerState.Cause = PlayerState.Cause.NONE
## SEAT_OUT: the seat whose shove last landed on the one going out, or -1.
var credit: int = -1
## LANDED: the surface it came down on.
var surface: int = Surfaces.NONE
## LANDED: the ticks of stagger the drop cost.
var stagger_ticks: int


func _init(event_kind: Kind, event_tick: int, event_seat: int) -> void:
	kind = event_kind
	tick = event_tick
	seat = event_seat


static func seat_out(
	event_tick: int, out_seat: int, out_place: int, out_cause: PlayerState.Cause, by: int
) -> SimEvent:
	var event := SimEvent.new(Kind.SEAT_OUT, event_tick, out_seat)
	event.place = out_place
	event.cause = out_cause
	event.credit = by
	return event


static func vaulted(event_tick: int, vaulting_seat: int) -> SimEvent:
	return SimEvent.new(Kind.VAULTED, event_tick, vaulting_seat)


static func fell(event_tick: int, falling_seat: int) -> SimEvent:
	return SimEvent.new(Kind.FELL, event_tick, falling_seat)


static func landed(event_tick: int, landing_seat: int, on_surface: int, stagger: int) -> SimEvent:
	var event := SimEvent.new(Kind.LANDED, event_tick, landing_seat)
	event.surface = on_surface
	event.stagger_ticks = stagger
	return event


static func match_ended(event_tick: int, winner: int) -> SimEvent:
	var event := SimEvent.new(Kind.MATCH_ENDED, event_tick, winner)
	event.place = 1
	return event


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"tick": tick,
		"seat": seat,
		"place": place,
		"cause": cause,
		"credit": credit,
		"surface": surface,
		"stagger": stagger_ticks,
	}
