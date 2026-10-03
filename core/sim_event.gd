class_name SimEvent
extends RefCounted
## A typed hint of what happened on a tick. Presentation may announce or animate
## one; it never infers state from one — the snapshot is the truth (D5).

enum Kind {
	SEAT_OUT,
	MATCH_ENDED,
	VAULTED,
	FELL,
	LANDED,
	SHOVE_LANDED,
	SHIP_LURCHING,
	SHIP_LURCHED,
	PLATFORM_COLLAPSING,
	PLATFORM_COLLAPSED,
	RAILING_BROKE,
	PLUNGE_BEGAN,
	ENTERED_WATER,
	CLIMBED_OUT,
	KNOCKED_BACK_IN,
	CRATE_HIT,
	CRATE_LOST,
}

var kind: Kind
var tick: int
## SEAT_OUT: who went out. MATCH_ENDED: the winner, or -1 for a draw. VAULTED:
## who tipped over a railing. FELL: who went off an edge. LANDED: who came down.
## SHOVE_LANDED: the shover. ENTERED_WATER: who started swimming. CLIMBED_OUT: who
## stood up out of the sea. KNOCKED_BACK_IN: the climber a shove sent back.
## CRATE_HIT: the seat a crate ran into. RAILING_BROKE: the seat whose vault broke
## the span, or -1. The sinking's events and CRATE_LOST: -1.
var seat: int
var place: int
var cause: PlayerState.Cause = PlayerState.Cause.NONE
## SEAT_OUT: the seat whose shove last landed on the one going out — or that shoved
## the crate credited — or -1. KNOCKED_BACK_IN: the shover.
var credit: int = -1
## SEAT_OUT: the crate that last ran into the one going out, or -1. CRATE_HIT,
## CRATE_LOST: the crate. RAILING_BROKE: the crate that broke the span, or -1. By
## its index in the layout's props.
var prop: int = -1
## LANDED: the surface it came down on. CLIMBED_OUT: the surface it stands on.
var surface: int = Surfaces.NONE
## LANDED: the ticks of stagger the drop cost.
var stagger_ticks: int
## SHOVE_LANDED: the seat the shove hit.
var target: int = -1
## SHIP_LURCHING, SHIP_LURCHED: the heel the lurch swings by, signed as the pose's.
var heel_deg: float
## PLATFORM_COLLAPSING, PLATFORM_COLLAPSED: the name of the platforms giving way.
var platform: StringName
## RAILING_BROKE: the layout's railing, by index.
var railing: int = -1


func _init(event_kind: Kind, event_tick: int, event_seat: int) -> void:
	kind = event_kind
	tick = event_tick
	seat = event_seat


static func seat_out(
	event_tick: int,
	out_seat: int,
	out_place: int,
	out_cause: PlayerState.Cause,
	by: int,
	by_crate: int = -1
) -> SimEvent:
	var event := SimEvent.new(Kind.SEAT_OUT, event_tick, out_seat)
	event.place = out_place
	event.cause = out_cause
	event.credit = by
	event.prop = by_crate
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


static func shove_landed(event_tick: int, shover: int, hit: int) -> SimEvent:
	var event := SimEvent.new(Kind.SHOVE_LANDED, event_tick, shover)
	event.target = hit
	return event


## What the sinking announces of [param event] on [param event_tick]: its telegraph
## starting when [param telegraph] says so, else its happening.
static func sinking(event_tick: int, event: SinkEvent, telegraph: bool) -> SimEvent:
	var kind := Kind.PLUNGE_BEGAN
	match event.kind:
		SinkEvent.Kind.LURCH:
			kind = Kind.SHIP_LURCHING if telegraph else Kind.SHIP_LURCHED
		SinkEvent.Kind.COLLAPSE:
			kind = Kind.PLATFORM_COLLAPSING if telegraph else Kind.PLATFORM_COLLAPSED
		SinkEvent.Kind.RAILING_FAIL:
			kind = Kind.RAILING_BROKE
	var announced := SimEvent.new(kind, event_tick, -1)
	announced.heel_deg = event.heel_deg
	announced.platform = event.platform
	if event.kind == SinkEvent.Kind.RAILING_FAIL:
		announced.railing = event.railing
	return announced


static func entered_water(event_tick: int, swimming_seat: int) -> SimEvent:
	return SimEvent.new(Kind.ENTERED_WATER, event_tick, swimming_seat)


static func climbed_out(event_tick: int, climbing_seat: int, on_surface: int) -> SimEvent:
	var event := SimEvent.new(Kind.CLIMBED_OUT, event_tick, climbing_seat)
	event.surface = on_surface
	return event


static func knocked_back_in(event_tick: int, climbing_seat: int, by: int) -> SimEvent:
	var event := SimEvent.new(Kind.KNOCKED_BACK_IN, event_tick, climbing_seat)
	event.credit = by
	return event


## The match breaking [param broken] (SH10): a vault by [param by], or a crate
## [param by_crate] running into it.
static func railing_broke(event_tick: int, broken: int, by: int, by_crate: int) -> SimEvent:
	var event := SimEvent.new(Kind.RAILING_BROKE, event_tick, by)
	event.railing = broken
	event.prop = by_crate
	return event


static func crate_hit(event_tick: int, hit_seat: int, crate: int) -> SimEvent:
	var event := SimEvent.new(Kind.CRATE_HIT, event_tick, hit_seat)
	event.prop = crate
	return event


static func crate_lost(event_tick: int, crate: int) -> SimEvent:
	var event := SimEvent.new(Kind.CRATE_LOST, event_tick, -1)
	event.prop = crate
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
		"target": target,
		"heel": heel_deg,
		"platform": platform,
		"railing": railing,
		"prop": prop,
	}
