extends GutTest
## A side's lifeboats go useless as news once (§5b.1): the ferry and the Titanic hang
## several boats a side, and the timeline — so the transcript and the HUD — says it once.

var _structure: ShipStructure
var _sea: SeaPhysics
var _scenario: SinkScenario


func before_all() -> void:
	_structure = SimFixtures.steamer().structure
	_sea = SeaPhysics.load_default()
	_scenario = load(SimFixtures.STEAMER_SINKING)


func test_a_side_with_two_boats_is_announced_useless_once() -> void:
	# heavy_list with a second boat hung on each side, as the ferry and the Titanic hang
	# several: her high side's boats go useless together, and the timeline says so once.
	var structure: ShipStructure = _structure.duplicate()
	structure.fittings = _structure.fittings.duplicate()
	for fitting: ShipFitting in _structure.fittings:
		if fitting.kind == ShipFitting.Kind.LIFEBOAT:
			var second: ShipFitting = fitting.duplicate()
			second.name = StringName("%s_2" % fitting.name)
			structure.fittings.append(second)
	var choice := SimFixtures.match_hit(PinnedSeeds.seed_named(&"heavy_list"))
	var stepper := SinkStepper.new(structure, choice.damage, _sea)
	var timeline := SinkBake.new(stepper, _sea, _scenario.bake_cap).uncompacted()
	var told := {}
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == SinkTimeline.Kind.BOATS_USELESS:
			told[event.name] = told.get(event.name, 0) + 1
	assert_false(told.is_empty(), "her high side's boats go useless")
	for side: StringName in told:
		assert_eq(told[side], 1, "her %s boats announced useless once" % side)
