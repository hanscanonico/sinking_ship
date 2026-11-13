extends GutTest
## A tiny cell held between two big rooms, its whole ends open to both, as the Titanic's
## tunnels stand between their boiler rooms: water runs through it from the room filling
## from the sea to the dry one beyond. Its solve passes the step's water in and on out, and
## the sweep, turning round every step, reaches the way out first one step in two: there
## the tiny cell must not give only what it held, then take all the step's water in and
## stand metres past its box (the Titanic's tunnel 5, 20 m³ in its 11.5 on seed 3, #627).

## The room filling, 14 × 10 × 26 m, its floor 8 m under the barge's sea, holed to the sea
## low in its side; the tiny cell abaft it, 2.6 × 2.44 × 1.9 m; the dry room abaft that.
const FULL_LOW := Vector3(0.0, -8.0, -13.0)
const FULL_HIGH := Vector3(14.0, 2.0, 13.0)
const TINY_LOW := Vector3(-2.6, -8.0, 0.0)
const TINY_HIGH := Vector3(0.0, -5.56, 1.9)
const DRY_LOW := Vector3(-16.6, -8.0, -13.0)
const DRY_HIGH := Vector3(-2.6, 2.0, 13.0)
## The filling room's water at the start: its surface 1.9 m over its floor.
const FULL_START := 700.0
const STEPS := 60
## How much past its box the tiny cell may go: the slip of its solve, in m³.
const OVER := 0.2


func _opening(
	opening_name: StringName, first: StringName, second: StringName, centre: Vector3, size: Vector3
) -> ShipOpening:
	var made := ShipOpening.new()
	made.name = opening_name
	made.kind = ShipOpening.Kind.GASH
	made.joins = [first, second]
	made.centre = centre
	made.size = size
	made.area = size.x * size.y + size.y * size.z + size.x * size.z
	return made


## With [param twice], a second tiny cell abaft the first, the dry room abaft that: the
## sweep turned round reaches both ways out before either way in.
func _stepper(twice := false) -> SinkStepper:
	var barge := BoxBarge.new(1000.0, 1000.0, 40.0, 20.0, 10.0)
	barge.section_length = 100.0
	var shift := Vector3(-TINY_HIGH.x + TINY_LOW.x, 0.0, 0.0) if twice else Vector3.ZERO
	barge.cell(&"full", FULL_LOW, FULL_HIGH)
	barge.cell(&"tiny", TINY_LOW, TINY_HIGH)
	barge.cell(&"dry", DRY_LOW + shift, DRY_HIGH + shift)
	barge.vent(&"full", Vector3(7.0, FULL_HIGH.y, 0.0), 1.0)
	barge.vent(&"tiny", Vector3(-1.3, TINY_HIGH.y, 1.0), 0.05)
	barge.vent(&"dry", Vector3(-9.6, DRY_HIGH.y, 0.0) + shift, 1.0)
	barge.openings.append(
		_opening(&"gash", &"full", &"sea", Vector3(7.0, -7.0, FULL_LOW.z), Vector3(0.6, 0.0, 1.0))
	)
	barge.openings.append(
		_opening(&"in", &"tiny", &"full", Vector3(0.0, -6.78, 0.95), Vector3(0.0, 2.44, 1.9))
	)
	var last := &"tiny"
	if twice:
		barge.cell(&"tiny_aft", TINY_LOW + shift, TINY_HIGH + shift)
		barge.vent(&"tiny_aft", Vector3(-3.9, TINY_HIGH.y, 1.0), 0.05)
		barge.openings.append(
			_opening(
				&"between",
				&"tiny_aft",
				&"tiny",
				Vector3(-2.6, -6.78, 0.95),
				Vector3(0.0, 2.44, 1.9)
			)
		)
		last = &"tiny_aft"
	barge.openings.append(
		_opening(&"out", &"dry", last, Vector3(-2.6, -6.78, 0.95) + shift, Vector3(0.0, 2.44, 1.9))
	)
	var sea: SeaPhysics = SeaPhysics.load_default().duplicate()
	sea.attitude = false
	return SinkStepper.new(barge.structure(), HitDamage.new(), sea)


func _started(stepper: SinkStepper) -> FloodState:
	var state := stepper.start()
	state.water[0] = FULL_START
	state.heads[0] = stepper.head(0, FULL_START)
	return state


func test_water_running_through_a_tiny_cell_keeps_it_within_its_box() -> void:
	var stepper := _stepper()
	var state := _started(stepper)
	var most := 0.0
	for _step in STEPS:
		state = stepper.advance(state)
		most = maxf(most, state.water[1])
	assert_lte(most, stepper.capacity_of(1) + OVER, "within its box by a small slip")


func test_water_running_through_two_tiny_cells_keeps_both_within_their_boxes() -> void:
	var stepper := _stepper(true)
	var state := _started(stepper)
	var most := 0.0
	for _step in STEPS:
		state = stepper.advance(state)
		for cell in stepper.capacities().size():
			if String(stepper.cell_name(cell)).begins_with("tiny"):
				most = maxf(most, state.water[cell] - stepper.capacity_of(cell))
	assert_lte(most, OVER, "within their boxes by a small slip")


func test_water_running_through_a_tiny_cell_is_conserved() -> void:
	var stepper := _stepper()
	var state := _started(stepper)
	var before := state.total()
	for _step in STEPS:
		state = stepper.advance(state)
	assert_almost_eq(state.total(), before + state.sea_given, 1e-6, "neither made nor lost")
