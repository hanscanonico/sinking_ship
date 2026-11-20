extends GutTest
## A cell whose surface hovers at a sill it spills over (#632): the trawler's seed 1 brings
## the fish hold's water to the sill of the gaps in its floor from about 250 s, the gash
## filling it and the engine room's door taking the rest. Swept in turn, the gaps took
## the gash's water on the steps it was swept first and none on the others, so at a 5 s
## step the bilge under it filled and she lay at her list for 1593 s, at 1.25 s she rolled
## over at 885 s. Held at the sill, its head solved for the step with every opening at
## once, her end no longer hangs on the step.

## How far apart her end at step_max and at a quarter of it may stand, as a share of the
## finer one's.
const APART := 0.05


## The trawler's open-sea bake of a match on [param seed_value]'s hit, its step no longer
## than [param step_max]: when she is gone.
func _gone_at(seed_value: int, step_max: float) -> float:
	var structure := Fleet.layout(&"trawler").structure
	var scenario := Fleet.setting(&"trawler_open_sea")
	var sea := SeaPhysics.load_default()
	var stream := SeedStreams.derive(seed_value, "sink")
	var damage := MustSink.choose(structure, scenario, stream, sea).damage
	damage.sea_depth = scenario.sea_depth
	var stepped: SeaPhysics = sea.duplicate()
	stepped.step_max = step_max
	return SinkBake.of(structure, damage, stepped, scenario.bake_cap).timeline().gone_at


func test_a_cell_hovering_at_a_sill_leaves_her_end_to_the_physics() -> void:
	var step_max := SeaPhysics.load_default().step_max
	var coarse := _gone_at(1, step_max)
	var fine := _gone_at(1, step_max / 4.0)
	assert_gt(fine, 0.0, "seed 1 sinks her")
	assert_almost_eq(
		coarse,
		fine,
		APART * fine,
		(
			"gone at %.0f s at a %.2f s step, %.0f s at %.2f s"
			% [coarse, step_max, fine, step_max / 4.0]
		)
	)
