extends GutTest
## §5b.4 layer 1, split from test_flood_stepper so CI's shards run it alongside: the
## bake held to the longest step the physics takes still makes no water of nothing.

## The match hits the step is checked on, and the water under nothing a cell may hold:
## rounding's, in m³.
const MATCH_SEEDS := 20
const NOTHING := 1e-6


func test_no_cell_gives_more_than_it_holds_at_the_longest_step() -> void:
	# The stiff cells' solve can miss at a long step: its cells then go back to the capped
	# sweep, and a held cell never gives more than it holds — on twenty match hits held
	# to the longest step the physics takes, no cell's water ever goes under nothing.
	var structure: ShipStructure = SimFixtures.steamer().structure
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var longest := SimFixtures.held_at(SeaPhysics.load_default().step_max)
	var under := PackedStringArray()
	for index in MATCH_SEEDS:
		var damage: HitDamage = SimFixtures.match_hits(MATCH_SEEDS)[index].damage
		var stepper := SinkStepper.new(structure, damage, longest)
		var state := stepper.start()
		var least := 0.0
		while state.seconds < scenario.bake_cap and state.above > -longest.gone_depth:
			state = stepper.advance(state)
			for water: float in state.water:
				least = minf(least, water)
		if least < -NOTHING:
			under.append("seed %d: %.3f m³" % [index + 1, least])
	assert_eq(under, PackedStringArray(), "no cell under nothing at a %s s step" % longest.step_max)
