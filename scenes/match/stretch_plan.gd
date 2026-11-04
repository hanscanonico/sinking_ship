class_name StretchPlan
extends RefCounted
## Which of her stretches (ShipPieces.cuts_of) her dressing builds before her match starts
## and which behind it, as the match is played (ShipDressing, #411). Her sinking is known
## before the match (D7), so when she first parts is too: until then every piece of her
## rides as one, and her whole art, built first, draws her; the stretches take its place
## at once, every one, when the last is in — so each is first needed at her first parting
## and they are built aft to fore. One that could not be built behind the match by then,
## BEHIND as slowly as before it and MARGIN to spare, is built before the start; when none
## could, her first stretch is drawn from the start and the rest built before it, as a
## match that breaks her always was. Pure: what a match's sinking and her rooms make it.

## What a stretch of her art costs to build, measured on the Titanic on a Windows laptop
## (#411): about a second for her outside and decks, and SECONDS_PER_ROOM for each of her
## rooms whose middle stands on it (PieceClip.holds), in seconds.
const SECONDS_EACH := 1.0
const SECONDS_PER_ROOM := 0.03
## How many times longer a stretch takes to build behind the match than before it, and
## the seconds a stretch built behind it is to be ready by ahead of her first parting.
const BEHIND := 2.0
const MARGIN := 30.0

## Whether her art is first drawn whole, the stretches in later to take its place; and
## the stretches, by their index in ShipPieces.cuts_of, built before the match starts and
## those built behind it, in the order they are built.
var whole := false
var before := PackedInt32Array()
var later := PackedInt32Array()


## The plan for stretches costing [param costs] seconds each to build, aft to fore,
## where she first parts [param parting] seconds into the match (INF: never).
static func of(costs: PackedFloat64Array, parting: float) -> StretchPlan:
	var plan := StretchPlan.new()
	var behind := 0.0
	for stretch in costs.size():
		if (behind + costs[stretch]) * BEHIND + MARGIN <= parting:
			behind += costs[stretch]
			plan.later.append(stretch)
		else:
			plan.before.append(stretch)
	plan.whole = not plan.later.is_empty()
	if not plan.whole:
		plan.before = PackedInt32Array(range(costs.size()))
	return plan


## The plan for [param ship]'s stretches as [param schedule]'s sinking cuts her.
static func for_schedule(schedule: SinkSchedule, ship: ShipLayout) -> StretchPlan:
	var costs := PackedFloat64Array()
	for cut: Vector2 in ShipPieces.cuts_of(schedule):
		var rooms := 0
		for room: ShipRoom in ship.rooms:
			if PieceClip.holds(cut, room.area.get_center().x):
				rooms += 1
		costs.append(estimate(rooms))
	return of(costs, parting_of(schedule))


## How long a stretch of [param rooms] rooms takes to build, in seconds.
static func estimate(rooms: int) -> float:
	return SECONDS_EACH + rooms * SECONDS_PER_ROOM


## The seconds into the match [param schedule]'s sinking first parts her; INF when it
## never does.
static func parting_of(schedule: SinkSchedule) -> float:
	var timeline := schedule.timeline()
	if timeline == null:
		return INF
	var first := INF
	for piece in range(1, timeline.born.size()):
		first = minf(first, schedule.physics_tick(timeline.born[piece]) * Ticks.SECONDS_PER_TICK)
	return first
