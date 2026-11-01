extends GutTest
## A wall gives way to the water's true push (SinkFailures). A cell's head over its
## ceiling is water past its box on the thin surface there, so a slip of a few m³ reads as
## metres of head: true only where a surface somewhere in her stands that high to drive it.

const COLLAPSE_HEAD := 3.0
## Three tanks over the barge's sea, which stands at 0: "tall" beside "wet" beside "dry",
## a shut door between wet and dry, up from their floor. Each tank 10 × 10 m.
const FLOOR := 1.0
const CEILING := 3.0
const TALL_CEILING := 12.0
## A slip of wet's: 5 m³ over its 200, on its 1 m² of thin surface.
const WET := 205.0


func _stepper() -> SinkStepper:
	var barge := BoxBarge.new(1000.0, 1000.0, 40.0, 20.0, 10.0)
	barge.section_length = 250.0
	barge.cell(&"wet", Vector3(0.0, FLOOR, 0.0), Vector3(10.0, CEILING, 10.0))
	barge.cell(&"dry", Vector3(10.0, FLOOR, 0.0), Vector3(20.0, CEILING, 10.0))
	barge.cell(&"tall", Vector3(-10.0, FLOOR, 0.0), Vector3(0.0, TALL_CEILING, 10.0))
	var door := ShipOpening.new()
	door.name = &"door"
	door.kind = ShipOpening.Kind.DOOR
	door.joins = [&"wet", &"dry"]
	door.centre = Vector3(10.0, FLOOR + 1.0, 5.0)
	door.size = Vector3(0.0, 2.0, 1.0)
	door.starts = ShipOpening.Start.SHUT
	door.collapse_head = COLLAPSE_HEAD
	var sea: SeaPhysics = SeaPhysics.load_default().duplicate()
	sea.attitude = false
	sea.air = false
	barge.openings.append(door)
	return SinkStepper.new(barge.structure(), HitDamage.new(), sea)


## Whether the door has given way at [param state], its heads worked out from its water.
func _bursts(stepper: SinkStepper, state: FloodState) -> bool:
	for cell in state.water.size():
		state.heads[cell] = stepper.head(cell, state.water[cell])
	stepper.pressures(state)
	var next := state.copy()
	stepper.failures().follow(state, next, 1.0, stepper)
	return next.opened[stepper.opening_names().find(&"door")] >= SinkFailures.GAVE_WAY


func test_a_slip_past_the_box_bursts_nothing() -> void:
	var stepper := _stepper()
	var state := stepper.start()
	state.water[0] = WET
	assert_gt(stepper.head(0, WET), FLOOR + COLLAPSE_HEAD, "it reads over the door's head")
	assert_false(_bursts(stepper, state), "yet nothing drives it: the door holds")


func test_a_full_cell_a_surface_stands_over_still_bursts() -> void:
	var stepper := _stepper()
	var state := stepper.start()
	state.water[0] = WET
	# Tall's surface over wet's head: the same head is true now.
	state.water[2] = 900.0
	assert_gt(stepper.head(2, 900.0), stepper.head(0, WET), "a surface higher still")
	assert_true(_bursts(stepper, state), "the door gives way")
