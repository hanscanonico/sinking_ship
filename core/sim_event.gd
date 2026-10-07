class_name SimEvent
extends RefCounted
## A typed hint of what happened on a tick. Presentation may announce or animate
## one; it never infers state from one — the snapshot is the truth (D5). HOLED is the
## iceberg striking: where, the match's SinkSchedule says. CELL_FLOODING, CELL_FULL,
## WATER_SPILLING and SHIP_GONE are the physics' (SinkTimeline): a cell takes its first
## water or is full, water first passes an opening over a low wall or down a stair, and
## she is wholly under; the physics announces PLUNGE_BEGAN too, as her deck goes under,
## SHIP_LURCHING and SHIP_LURCHED by §5b.4's lurch rule, BOATS_USELESS as one side's
## lifeboats stand too high to lower — a label, never a rule — and AIR_TRAPPED and
## AIR_VENTED as a cell's air is trapped under its ceiling and a pocket's air let out;
## from SH31 what gives way: an opening or a wall's panel starts to leak, or gives way,
## a funnel creaks and falls, her generator stops or runs again, her lights go out, a
## cell's water drowns its lamps, her hull creaks under its bending; from SH32
## GROUNDED as her hull first touches the bottom; and from SH33 HULL_HINGING as a hinge
## starts at a weak spot of hers, HULL_PARTED as her hull parts there. KNOCKED_DOWN is a
## rule's: a falling funnel landing on a body (Hazards, D12).

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
	HOLED,
	CELL_FLOODING,
	CELL_FULL,
	WATER_SPILLING,
	SHIP_GONE,
	BOATS_USELESS,
	AIR_TRAPPED,
	AIR_VENTED,
	OPENING_LEAKING,
	OPENING_GAVE_WAY,
	FUNNEL_STRAINING,
	FUNNEL_FALLING,
	POWER_LOST,
	POWER_BACK,
	LIGHTS_OUT,
	LAMPS_DROWNED,
	HULL_STRESSED,
	KNOCKED_DOWN,
	GROUNDED,
	HULL_HINGING,
	HULL_PARTED,
}

var kind: Kind
var tick: int
## SEAT_OUT: who went out. MATCH_ENDED: the winner, or -1 for a draw. VAULTED:
## who tipped over a railing. FELL: who went off an edge. LANDED: who came down.
## SHOVE_LANDED: the shover. ENTERED_WATER: who started swimming. CLIMBED_OUT: who
## stood up out of the sea. KNOCKED_BACK_IN: the climber a shove sent back.
## CRATE_HIT: the seat a crate ran into. RAILING_BROKE: the seat whose vault broke
## the span, or -1. KNOCKED_DOWN: the seat a funnel landed on. The sinking's events and
## CRATE_LOST: -1.
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
## CELL_FLOODING, CELL_FULL, LAMPS_DROWNED: the cell, by name. WATER_SPILLING,
## OPENING_LEAKING, OPENING_GAVE_WAY: the opening, or the wall's panel. BOATS_USELESS:
## the side, port or starboard. FUNNEL_STRAINING, FUNNEL_FALLING, KNOCKED_DOWN: the
## funnel. POWER_LOST, POWER_BACK: her generator.
var cell: StringName


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


## The iceberg striking the ship on [param event_tick].
static func holed(event_tick: int) -> SimEvent:
	return SimEvent.new(Kind.HOLED, event_tick, -1)


## What the physics announces at [param event_tick]: [param physics_kind], a
## SinkTimeline.Kind, naming [param named]; a lurch swinging her by [param heel].
static func physics(
	event_tick: int, physics_kind: int, named: StringName, heel: float = 0.0
) -> SimEvent:
	var kinds: Array[Kind] = [
		Kind.CELL_FLOODING,
		Kind.CELL_FULL,
		Kind.WATER_SPILLING,
		Kind.SHIP_GONE,
		Kind.PLUNGE_BEGAN,
		Kind.SHIP_LURCHING,
		Kind.SHIP_LURCHED,
		Kind.BOATS_USELESS,
		Kind.AIR_TRAPPED,
		Kind.AIR_VENTED,
		Kind.OPENING_LEAKING,
		Kind.OPENING_GAVE_WAY,
		Kind.FUNNEL_STRAINING,
		Kind.FUNNEL_FALLING,
		Kind.POWER_LOST,
		Kind.POWER_BACK,
		Kind.LIGHTS_OUT,
		Kind.LAMPS_DROWNED,
		Kind.HULL_STRESSED,
		Kind.GROUNDED,
		Kind.HULL_HINGING,
		Kind.HULL_PARTED,
	]
	var event := SimEvent.new(kinds[physics_kind], event_tick, -1)
	event.cell = named
	event.heel_deg = heel
	return event


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


## [param funnel] landing on [param struck_seat] (Hazards).
static func knocked_down(event_tick: int, struck_seat: int, funnel: StringName) -> SimEvent:
	var event := SimEvent.new(Kind.KNOCKED_DOWN, event_tick, struck_seat)
	event.cell = funnel
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
		"cell": cell,
	}


## The event [param entry] — a to_dict() of one, as a snapshot carries it — again.
static func from_dict(entry: Dictionary) -> SimEvent:
	var event := SimEvent.new(entry["kind"], entry["tick"], entry["seat"])
	event.place = entry["place"]
	event.cause = entry["cause"]
	event.credit = entry["credit"]
	event.surface = entry["surface"]
	event.stagger_ticks = entry["stagger"]
	event.target = entry["target"]
	event.heel_deg = entry["heel"]
	event.platform = entry["platform"]
	event.railing = entry["railing"]
	event.prop = entry["prop"]
	event.cell = entry["cell"]
	return event
