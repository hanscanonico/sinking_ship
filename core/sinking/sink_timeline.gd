class_name SinkTimeline
extends RefCounted
## The bake (§5b.1, D7): SinkStepper run once, from the hit, in steps of one simulated
## second, to the end — she is gone, or the water has stopped coming in — or the bake's
## cap, every second's state kept: where the sea stands up her and the head of every
## cell's water, and every event at the second it happens. SH26's simplest driver: the
## whole sinking in memory, read between its seconds (SinkSchedule). Match data like
## the ship's: derived from (ship, scenario, seed), never in a snapshot (D5).

## How a bake ends (§5b.1): she is gone — wholly under the sea and still going down;
## the water has stopped coming in and she floats; or the cap came first.
enum End { GONE, AFLOAT, CAPPED }
## What the physics announces: a cell takes its first water, a cell is full, water
## first passes over a low wall or down a stair or hatch, she is gone, and her main
## deck goes under the sea — the plunge begins, her last minutes.
enum Kind { FLOODING, FULL, SPILLING, GONE, PLUNGING }
## A cell's water this far over its floor, in metres, is its first.
const FIRST_WATER := 0.01
## Her main deck's height: ship space's origin stands on it (D6).
const MAIN_DECK := 0.0
## Less than this many m³ a second passing anywhere, and no door still moving: the
## water has stopped coming in (est.: a litre a second, under 20 t in the bake's whole
## cap, where sinking her within it takes hundreds).
const STILL := 1e-3


## One thing the physics did, at its second.
class Event:
	var seconds: float
	var kind: Kind
	## The cell, or for SPILLING the opening, it names; nothing for GONE or PLUNGING.
	var name: StringName

	func _init(at: float, event_kind: Kind, event_name: StringName) -> void:
		seconds = at
		kind = event_kind
		name = event_name


## The seconds between two kept states, and how many cells each keeps.
var step := 1.0
var cells := 0
## Per kept state, from the hit on: the sea's height up her, and then every cell's
## head in her cells' order.
var seas := PackedFloat64Array()
var heads := PackedFloat64Array()
var events: Array[Event] = []
var end := End.CAPPED
## The physics second she was wholly under, or -1 for never.
var gone_at := -1.0
## Where the sea stands up her at rest, with no water in her: her level ship.
var rest := 0.0
## The steps the bake took.
var steps := 0


## The timeline of [param stepper] from the hit to the end, or to [param cap] physics
## seconds, in steps of [param seconds].
static func bake(
	stepper: SinkStepper, sea: SeaPhysics, cap: float, seconds: float = 1.0
) -> SinkTimeline:
	var timeline := SinkTimeline.new()
	timeline.step = seconds
	timeline.rest = stepper.rest()
	var state := stepper.start()
	timeline.cells = state.water.size()
	timeline._keep(state)
	var wet := PackedByteArray()
	wet.resize(timeline.cells)
	var full := PackedByteArray()
	full.resize(timeline.cells)
	var names := stepper.opening_names()
	var spilled := PackedByteArray()
	spilled.resize(names.size())
	var top := stepper.top()
	var doors_move_until := stepper.last_door()
	var plunged := false
	while state.seconds < cap:
		state = stepper.step(state, seconds)
		timeline.steps += 1
		timeline._keep(state)
		var at := state.seconds
		var passed := 0.0
		for index in names.size():
			var moved := absf(state.moved[index])
			passed += moved
			if moved > 0.0 and spilled[index] == 0 and _spills(stepper.opening_kind(index)):
				spilled[index] = 1
				timeline.events.append(Event.new(at, Kind.SPILLING, names[index]))
		for cell in timeline.cells:
			var head := state.heads[cell]
			if wet[cell] == 0 and head >= stepper.floor_of(cell) + FIRST_WATER:
				wet[cell] = 1
				timeline.events.append(Event.new(at, Kind.FLOODING, stepper.cell_name(cell)))
			if full[cell] == 0 and head >= stepper.ceiling_of(cell):
				full[cell] = 1
				timeline.events.append(Event.new(at, Kind.FULL, stepper.cell_name(cell)))
		if state.sea > MAIN_DECK and not plunged:
			plunged = true
			timeline.events.append(Event.new(at, Kind.PLUNGING, &""))
		if timeline.gone_at < 0.0 and state.sea > top:
			timeline.gone_at = at
			timeline.events.append(Event.new(at, Kind.GONE, &""))
		if timeline.gone_at >= 0.0 and state.sea - top >= sea.gone_depth:
			timeline.end = End.GONE
			break
		if timeline.gone_at < 0.0 and passed < STILL * seconds and at >= doors_move_until:
			timeline.end = End.AFLOAT
			break
	return timeline


## Whether water first passing an opening of [param kind] is news: over a low wall,
## down a stair or a hatch, through a doorway between cells.
static func _spills(kind: ShipOpening.Kind) -> bool:
	return kind in [ShipOpening.Kind.OVER_WALL, ShipOpening.Kind.STAIRWELL, ShipOpening.Kind.HATCH]


func _keep(state: FloodState) -> void:
	seas.append(state.sea)
	heads.append_array(state.heads)


## How many states it keeps, the hit's first.
func count() -> int:
	return seas.size()


## The physics seconds it runs for.
func length() -> float:
	return (count() - 1) * step


## Whether she was wholly under before it ended.
func is_gone() -> bool:
	return end == End.GONE


## A hash of everything it keeps: two bakes of the same hit agree on it exactly.
func digest() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(seas.to_byte_array())
	hashing.update(heads.to_byte_array())
	return hashing.finish().hex_encode()
