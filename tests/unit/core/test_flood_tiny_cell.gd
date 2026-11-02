extends GutTest
## A tiny cell held beside a big room filling from the sea, joined by a wide open hole, as
## the Titanic's tunnels stand beside their boiler rooms: it follows the room's level. Held
## for its stiffness it passes what its solve said, not all the room's rise in the step, so
## its water neither swings each step nor runs past its box and reads as metres of head.

## The big room, 14 × 26 m, its floor 8 m under the barge's sea, holed to the sea low in its
## side and vented; the tiny cell abaft it, 2.6 × 1.9 × 2.44 m, its whole after end open.
const BIG_LOW := Vector3(0.0, -8.0, -13.0)
const BIG_HIGH := Vector3(14.0, 2.0, 13.0)
const TINY_LOW := Vector3(-2.6, -8.0, 0.0)
const TINY_HIGH := Vector3(0.0, -5.56, 1.9)
## The room's water at the start: its surface 1.9 m over its floor.
const BIG_START := 700.0
const STEPS := 80
## How far a held tiny cell may stand from the room, how much past its box it may go, and
## how much its water may move in a step, the room rising a few cm: the slips of the solve,
## in metres and m³.
const LEVEL := 0.1
const OVER := 0.2
const SWING := 1.0


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
	barge.cell(&"big", BIG_LOW, BIG_HIGH)
	barge.cell(&"tiny", TINY_LOW, TINY_HIGH)
	barge.vent(&"big", Vector3(7.0, BIG_HIGH.y, 0.0), 1.0)
	barge.vent(&"tiny", Vector3(-1.3, TINY_HIGH.y, 1.0), 0.05)
	barge.openings.append(
		_opening(&"gash", &"big", &"sea", Vector3(7.0, -7.0, BIG_LOW.z), Vector3(0.18, 0.0, 1.0))
	)
	barge.openings.append(
		_opening(&"join", &"tiny", &"big", Vector3(0.0, -6.78, 0.95), Vector3(0.0, 2.44, 1.9))
	)
	var sea: SeaPhysics = SeaPhysics.load_default().duplicate()
	sea.attitude = false
	return SinkStepper.new(barge.structure(), HitDamage.new(), sea)


func _started(stepper: SinkStepper) -> FloodState:
	var state := stepper.start()
	state.water[0] = BIG_START
	state.heads[0] = stepper.head(0, BIG_START)
	state.water[1] = stepper.volume_at(1, state.heads[0])
	state.heads[1] = stepper.head(1, state.water[1])
	return state


func test_a_tiny_cell_stays_within_its_box() -> void:
	var stepper := _stepper()
	var state := _started(stepper)
	var most := 0.0
	for _step in STEPS:
		state = stepper.advance(state)
		most = maxf(most, state.water[1])
	assert_lte(most, stepper.capacity_of(1) + OVER, "within its box by a small slip")


func test_a_tiny_cell_stands_at_the_room_s_level() -> void:
	var stepper := _stepper()
	var state := _started(stepper)
	var furthest := 0.0
	for _step in STEPS:
		state = stepper.advance(state)
		furthest = maxf(furthest, absf(state.heads[1] - state.heads[0]))
	assert_lte(furthest, LEVEL, "no metres of head a slip past its box would read as")


func test_a_tiny_cell_s_water_does_not_swing() -> void:
	var stepper := _stepper()
	var state := _started(stepper)
	var widest := 0.0
	for _step in STEPS:
		var was := state.water[1]
		state = stepper.advance(state)
		widest = maxf(widest, absf(state.water[1] - was))
	assert_lte(widest, SWING, "it rises with the room, not to and fro")


func test_the_water_is_conserved_on_the_way() -> void:
	var stepper := _stepper()
	var state := _started(stepper)
	var before := state.total()
	for _step in STEPS:
		state = stepper.advance(state)
	assert_almost_eq(state.total(), before + state.sea_given, 1e-6, "neither made nor lost")
