extends GutTest
## §5b.4 layer 1, split from test_flood_stepper so CI's shards run it alongside: the
## step the physics chooses sinks her as the bake held to a second does.

## The match hits the step is checked on.
const MATCH_SEEDS := 20


func test_the_shipped_step_sinks_her_as_a_second_does() -> void:
	# The step the physics chooses reaches step_max while little changes: on twenty match
	# hits she is gone within a tenth of when the bake held to a second has her gone. With
	# the failures stage off, the hits chosen under it too: a door or a wall's panel the
	# water stands just under the head of, as a list lingers, may give way at one step and
	# not the other — a threshold, which no step converges across (R21); the failures' own
	# landing is test_failures'.
	var structure: ShipStructure = SimFixtures.steamer().structure
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var chosen: SeaPhysics = SeaPhysics.load_default().duplicate()
	chosen.failures = false
	var second := SimFixtures.held_at(1.0)
	second.failures = false
	var off := PackedStringArray()
	for index in MATCH_SEEDS:
		var stream := SeedStreams.derive(index + 1, "sink")
		var choice := MustSink.choose(structure, scenario, stream, chosen)
		var held := SinkTimeline.bake(
			SinkStepper.new(structure, choice.damage, second), second, scenario.bake_cap
		)
		var shipped := choice.timeline.gone_at
		if absf(shipped - held.gone_at) > held.gone_at * 0.1:
			off.append("seed %d: %.0f s against %.0f s" % [index + 1, shipped, held.gone_at])
	assert_eq(off, PackedStringArray(), "gone within 10% of the bake held to 1 s")
