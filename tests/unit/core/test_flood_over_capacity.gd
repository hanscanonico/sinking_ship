extends GutTest
## No cell keeps water its box cannot hold while the cell over it has room: past its
## capacity a cell holds only the thin surface's few m³, however its held cells' solve
## together ends. Where that solve does not close, a pocket of squeezed air one small pipe
## away must not leave the rest of the group holding each other at one level, the water
## each should have passed on stuck in its box.

const STEP := 5.0
## A wing tank 2 m deep under a hold 5 m deep, each 10 × 10 m, a hole of half their floor
## between them; beside both, closed but for a pipe low in its side, a tank whose water
## stands over that pipe, so its air is trapped. The barge's sea stands at 0.
const WING_LOW := Vector3(-5.0, -10.0, -5.0)
const WING_HIGH := Vector3(5.0, -8.0, 5.0)
const HOLD_LOW := Vector3(-5.0, -8.0, -5.0)
const HOLD_HIGH := Vector3(5.0, -3.0, 5.0)
const POCKET_LOW := Vector3(5.0, -10.0, -5.0)
const POCKET_HIGH := Vector3(10.0, -3.0, 5.0)
const WING_FULL := 200.0
## What the wing holds at the start: three times its box.
const WING_START := 600.0
const POCKET_START := 100.0
## A little in the hold, or nothing would hold its head with the wing's.
const HOLD_START := 50.0
## The most a full wing holds past its box here: its thin surface of 1 m², over its ceiling
## as far as the hold's ceiling stands.
const THIN := 5.0


## A stepper whose solve together never closes, so every group of held cells takes the
## way out it takes on a real ship's kinks.
class NeverCloses:
	extends SinkStepper

	func _solve_together(
		_held_cells: PackedInt32Array,
		_state: FloodState,
		_heads: PackedFloat64Array,
		_sea: float,
		_seconds: float
	) -> bool:
		return false


func _sea() -> SeaPhysics:
	var sea: SeaPhysics = SeaPhysics.load_default().duplicate()
	sea.attitude = false
	return sea


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


func _stepper() -> SinkStepper:
	var barge := BoxBarge.new(1000.0, 1000.0, 40.0, 20.0, 10.0)
	barge.section_length = 100.0
	barge.cell(&"wing", WING_LOW, WING_HIGH)
	barge.cell(&"hold", HOLD_LOW, HOLD_HIGH)
	barge.cell(&"pocket", POCKET_LOW, POCKET_HIGH)
	barge.vent(&"hold", Vector3(0.0, HOLD_HIGH.y, 0.0), 1.0)
	var hole := Vector3(sqrt(50.0), 0.0, sqrt(50.0))
	barge.openings.append(_opening(&"wide", &"wing", &"hold", Vector3(0.0, WING_HIGH.y, 0.0), hole))
	var pipe := _opening(
		&"pipe", &"wing", &"pocket", Vector3(POCKET_LOW.x, -9.5, 0.0), Vector3(0.0, 0.5, 0.5)
	)
	barge.openings.append(pipe)
	return NeverCloses.new(barge.structure(), HitDamage.new(), _sea())


## The state with the wing over its capacity, as a slip leaves it, and the pocket's air
## trapped under its water.
func _overfilled(stepper: SinkStepper) -> FloodState:
	var state := stepper.start()
	state.water[0] = WING_START
	state.water[1] = HOLD_START
	state.water[2] = POCKET_START
	state.heads[0] = stepper.head(0, WING_START)
	state.heads[1] = stepper.head(1, HOLD_START)
	state.heads[2] = stepper.head(2, POCKET_START)
	state.air[2] = 250.0
	return state


func test_a_cell_over_capacity_gives_it_up_to_the_room_above() -> void:
	var stepper := _stepper()
	var state := _overfilled(stepper)
	assert_gt(state.water[0], stepper.capacity_of(0), "the wing starts over its box")
	for _step in 4:
		state = stepper.step(state, STEP)
	assert_lte(state.water[0], WING_FULL + THIN, "the wing is back within its box")
	assert_gt(state.water[1], WING_START - WING_FULL, "and the hold has what it gave up")


func test_the_water_is_conserved_on_the_way() -> void:
	var stepper := _stepper()
	var state := _overfilled(stepper)
	var before := state.total()
	for _step in 4:
		state = stepper.step(state, STEP)
	assert_almost_eq(
		state.total(), before + state.sea_given, 1e-6, "water is neither made nor lost"
	)
