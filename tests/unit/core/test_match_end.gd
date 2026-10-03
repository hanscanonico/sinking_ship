extends GutTest
## Every match ends (§5, Q5). The cap makes it so by construction, whatever the seed:
## on the cap tick every seat still in goes out together
## (test_sink_events.gd::test_cap_puts_everyone_left_out_together), the default
## scenario's cap is 3:30 on every seed's jitter
## (test_sink_events.gd::test_every_surface_is_under_by_the_cap) and a mirrored
## scenario meets its own (test_mirrored_scenario_also_ends_by_its_cap). What is left
## to show is that real matches get there — the default match carries the cap and
## eight bots step through it — so two seeded eight-seat matches stand in for the
## plan's ten: each costs about half a minute of the gate, and the eight more would
## prove nothing the cap does not.

const RunMatch := preload("res://tools/run_match.gd")

const SEEDS: Array[int] = [1, 2]
const SEATS := 8


func test_match_always_ends() -> void:
	for seed_value: int in SEEDS:
		var runner := RunMatch.bots_only(RunMatch.default_config(seed_value, SEATS))
		var cap := runner.sim.schedule.cap_tick()
		assert_eq(cap, Ticks.from_seconds(210.0), "the cap is 3:30")
		var ended: SimEvent = null
		while not runner.is_over() and runner.tick() <= cap:
			for event: SimEvent in runner.step():
				if event.kind == SimEvent.Kind.MATCH_ENDED:
					ended = event
		assert_not_null(ended, "seed %d ends" % seed_value)
		if ended != null:
			assert_lte(ended.tick, cap, "seed %d over by 3:30" % seed_value)
