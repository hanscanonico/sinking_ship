extends GutTest
## Cells held together whose solve does not close (#632): in a deep plunge a group of full
## cells beside a squeezed pocket has slopes Newton's method cannot follow, and let go to
## the capped sweep its water ran up its head — 52 m of it on the small Titanic's seed 1,
## after_hold_fwd into electric_room at 2920 s. Solved alone in turn until they creep to
## their heads, then by Newton's method from there, the group closes instead.

## How far a flow through a cell let go may run against its head, in metres.
const AGAINST := 0.1


func test_a_stiff_group_let_go_runs_no_water_up_its_head() -> void:
	var structure := Fleet.layout(&"small_titanic").structure
	var scenario := Fleet.setting(&"small_titanic_open_sea")
	var sea := SeaPhysics.load_default()
	var stream := SeedStreams.derive(1, "sink")
	var damage := MustSink.choose(structure, scenario, stream, sea).damage
	damage.sea_depth = scenario.sea_depth
	var stepper := WatchedStepper.new(structure, damage, sea)
	var bake := SinkBake.new(stepper, sea, scenario.bake_cap, HullBreak.of(structure, damage, sea))
	bake.run(1 << 62)
	var watch := stepper.watch
	watch.close()
	assert_gt(watch.steps, 0, "her bake was watched")
	assert_lte(
		watch.worst[FloodWatch.Law.RELEASED],
		AGAINST,
		"; ".join(watch.breaches(FloodWatch.Law.RELEASED))
	)
