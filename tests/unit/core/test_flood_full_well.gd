extends GutTest
## A full open well whose edges stand under the still sea is the sea's own: nothing comes
## over its edges (ShippedWater.ship), and the solve of its head counts nothing coming
## over them either — or its freeing ports pass out what that solve counted on coming in,
## and the well drains under the sea it stands open to (#619: the tug's towing deck, 14 cm
## under the sea in one step of her seed 1's bake).

## A barge so broad the water in her well barely moves the sea up her.
const BROAD := 1000.0
## The well: 20 m along her, 10 m across, its deck 0.6 m under the sea and its edges 0.1 m
## under it, full; its freeing ports at its deck; waves cresting 0.25 m over the sea.
const WELL_LENGTH := 20.0
const WELL_BREADTH := 10.0
const WELL_DECK := -0.6
const WELL_EDGE := -0.1
const PORTS := 16.0
const CREST := 0.25
const STEP := 5.0


func _stepper() -> WatchedStepper:
	var barge := BoxBarge.new(BROAD, BROAD, 20.0, 10.0, 0.0)
	barge.section_length = BROAD / 4.0
	var well := barge.cell(
		&"well", Vector3(0.0, WELL_DECK, 0.0), Vector3(WELL_LENGTH, WELL_EDGE, WELL_BREADTH)
	)
	well.kind = FloodCell.Kind.OPEN_WELL
	well.shipping_edges = PackedVector3Array(
		[
			Vector3(0.0, WELL_EDGE, 0.0),
			Vector3(WELL_LENGTH, WELL_EDGE, 0.0),
			Vector3(0.0, WELL_EDGE, WELL_BREADTH),
			Vector3(WELL_LENGTH, WELL_EDGE, WELL_BREADTH),
		]
	)
	var port := ShipOpening.new()
	port.name = &"freeing_ports"
	port.kind = ShipOpening.Kind.FREEING_PORT
	port.joins = [&"well", ShipOpening.SEA]
	port.centre = Vector3(WELL_LENGTH * 0.5, WELL_DECK + 0.05, 0.0)
	port.size = Vector3(2.0, 0.1, 0.0)
	port.area = PORTS
	barge.openings.append(port)
	var sea: SeaPhysics = SeaPhysics.load_default().duplicate()
	sea.attitude = false
	sea.air = false
	var damage := HitDamage.new()
	damage.wave_height = CREST / sea.wave_reach
	return WatchedStepper.new(barge.structure(), damage, sea)


func test_a_full_well_under_the_sea_stays_full() -> void:
	var stepper := _stepper()
	var state := stepper.start()
	var full := stepper.capacity_of(0)
	state.water[0] = full
	state.heads[0] = stepper.head(0, full)
	var next := stepper.step(state, STEP)
	var watch := stepper.watch
	assert_gte(
		next.water[0], full - SinkStepper.SURPLUS_TOLERANCE, "it stays full, the sea over it"
	)
	assert_gte(next.heads[0], next.sea - 1e-3, "its water stands no lower than the sea")
	watch.close()
	# A step taken outside advance is a cut one, its breaches counted apart.
	var law := FloodWatch.Law.DOWNHILL_CUT
	assert_eq(
		watch.counts[law],
		0,
		"its ports pass no water up its head: %s" % "; ".join(watch.breaches(law))
	)
