extends GutTest
## The online prediction's contact watch counts her water (#626, ContactWatch): a body a
## current carries comes faster than the rules move anything (BrawlRules.fastest_speed),
## so a seat it may reach over the span is not clear of it; far from any flowing opening
## the watch answers as it did without water.

## How long the seat's predicted path runs, in seconds.
const SPAN := 0.3
## The water through the doorway, m³ a second: u0 there is √(2 g Δh) across its 2.4 m head,
## near 6.9 m/s.
const FLOW := 20.0


## A schedule of the test's own: her poses as a calm deck's, the after half's water to the
## deckhead and the fore half's 0.6 m deep, [member flow] passing the doorway between.
class Flowing:
	extends SinkSchedule
	var structure: ShipStructure
	var levels := PackedFloat64Array()
	var flow := 0.0
	var _flowing_cells: CellMap

	func _posed(tick: int) -> ShipPose:
		var pose := super._posed(tick)
		if _flowing_cells == null:
			_flowing_cells = CellMap.new(structure)
		pose.cells = _flowing_cells
		pose.levels = levels
		pose.passages = [&"door"] as Array[StringName]
		pose.flows = PackedFloat64Array([flow])
		return pose


static func _cell(cell_name: StringName, low: Vector3, high: Vector3) -> FloodCell:
	var made := FloodCell.new()
	made.name = cell_name
	made.low = low
	made.high = high
	return made


## The flat deck's after and fore halves, joined by a doorway 1 m wide at x = 0.
static func _structure() -> ShipStructure:
	var made := ShipStructure.new()
	var cells: Array[FloodCell] = [
		_cell(&"aft", Vector3(-15.0, 0.0, -4.0), Vector3(0.0, 3.0, 4.0)),
		_cell(&"fore", Vector3(0.0, 0.0, -4.0), Vector3(15.0, 3.0, 4.0)),
	]
	made.cells = cells
	var door := ShipOpening.new()
	door.name = &"door"
	door.kind = ShipOpening.Kind.DOOR
	door.joins = [&"aft", &"fore"] as Array[StringName]
	door.centre = Vector3(0.0, 1.0, 0.0)
	door.size = Vector3(0.0, 2.0, 1.0)
	var openings: Array[ShipOpening] = [door]
	made.openings = openings
	return made


## A two-seat match on the flat deck, [param flow] m³ a second passing its doorway.
func _sim(flow: float) -> MatchSim:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	layout.structure = _structure()
	var config := SimFixtures.config(2, SimFixtures.calm(), 1, layout)
	var flowing: Flowing = config.schedule_as(Flowing)
	flowing.structure = layout.structure
	flowing.levels = PackedFloat64Array([layout.freeboard + 3.0, layout.freeboard + 0.6])
	flowing.flow = flow
	return MatchSim.create(config)


## Seat 0 standing at [param at] for SPAN, seat 1 just beyond the reach the rules alone
## give over it, at [param at] plus [param way]: whether the watch has seat 0 clear.
func _clear(sim: MatchSim, at: Vector3, way: Vector3) -> bool:
	var rules := sim.config.rules
	var path := PackedVector3Array()
	path.resize(Ticks.from_seconds(SPAN) + 1)
	path.fill(at)
	var span := (path.size() - 1) * Ticks.SECONDS_PER_TICK
	var reach := 2.0 * rules.body_radius + rules.shove_reach + rules.fastest_speed() * span
	SimFixtures.place(sim, 0, at)
	SimFixtures.place(sim, 1, at + way * (reach + 0.05))
	return ContactWatch.new(sim.config, sim.schedule).clear(sim.snapshot(), 0, path, 0)


func test_a_body_the_current_carries_toward_the_seat_is_near() -> void:
	var at := Vector3(0.5, 0.0, 0.0)
	assert_true(_clear(_sim(0.0), at, Vector3.LEFT), "still water: beyond the rules' reach")
	assert_false(_clear(_sim(FLOW), at, Vector3.LEFT), "drawn to the doorway, it may reach her")


func test_far_from_any_flowing_opening_the_watch_answers_as_without_water() -> void:
	var at := Vector3(14.0, 0.0, 0.0)
	assert_true(_clear(_sim(FLOW), at, Vector3.LEFT), "beyond the rules' reach")
	assert_true(_clear(_sim(0.0), at, Vector3.LEFT), "the same in still water")
