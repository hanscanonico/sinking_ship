extends GutTest
## The water's cues the cargo and the climbers make (D12): a crate the water lifts
## splashes soft and then drifts silent, and a body climbing out lands wet and drips.


func _planner(sim: MatchSim) -> CuePlanner:
	var planner := CuePlanner.new(sim.config, sim.surfaces, sim.schedule, 0)
	planner.listener_seat = 0
	return planner


func _of(cues: Array[AudioCue], kind: AudioCue.Kind) -> Array[AudioCue]:
	return cues.filter(func(cue: AudioCue) -> bool: return cue.kind == kind)


## A match on the flat deck carrying one crate at [param at], seat 0 well clear.
func _crated(at: Vector3) -> MatchSim:
	var crates: Array[ShipProp] = [SimFixtures.crate(at)]
	var sim := SimFixtures.sim(1, null, SimFixtures.crated(crates))
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -2.0))
	return sim


## The crate of [param sim] stepping from [param was] to [param state], at
## [param from] m/s then [param to] m/s along the deck: the cues it makes.
func _crate_step(
	sim: MatchSim, was: PropState.Body, state: PropState.Body, from: float = 0.0, to: float = 0.0
) -> Array[AudioCue]:
	var then := sim.snapshot().duplicate(true)
	then["props"][0]["state"] = was
	then["props"][0]["vel"] = Vector3(from, 0.0, 0.0)
	var now := sim.snapshot().duplicate(true)
	now["tick"] = 1
	now["props"][0]["state"] = state
	now["props"][0]["vel"] = Vector3(to, 0.0, 0.0)
	return _planner(sim).plan(then, now)


func test_a_crate_the_water_lifts_splashes_soft() -> void:
	var sim := _crated(Vector3.ZERO)
	var heard := _crate_step(sim, PropState.Body.GROUNDED, PropState.Body.FLOATING)
	var splashes := _of(heard, AudioCue.Kind.SPLASH)
	assert_eq(splashes.size(), 1, "one splash as she lifts")
	assert_true(splashes[0].positional, "from the crate")
	assert_eq(splashes[0].seat, -1)
	assert_eq(splashes[0].gain, CuePlanner.AFLOAT_GAIN)
	assert_true(_of(heard, AudioCue.Kind.THUD).is_empty(), "and no thud")


func test_a_floating_crate_never_thuds_or_scrapes() -> void:
	var sim := _crated(Vector3.ZERO)
	var heard := _crate_step(sim, PropState.Body.FLOATING, PropState.Body.FLOATING, 3.0, 0.0)
	assert_true(_of(heard, AudioCue.Kind.THUD).is_empty(), "stopped short afloat: no thud")
	assert_true(_of(heard, AudioCue.Kind.SPLASH).is_empty(), "already afloat: no splash")
	var planner := _planner(sim)
	var drifting: Array[AudioCue] = []
	var previous := sim.snapshot().duplicate(true)
	previous["props"][0]["state"] = PropState.Body.FLOATING
	for tick in 2 * Ticks.RATE:
		var current := previous.duplicate(true)
		current["tick"] = tick + 1
		current["props"][0]["vel"] = Vector3(2.0, 0.0, 0.0)
		drifting.append_array(planner.plan(previous, current))
		previous = current
	assert_true(_of(drifting, AudioCue.Kind.SCRAPE).is_empty(), "drifting: no scrape")


func test_a_crate_lost_while_afloat_makes_no_second_splash() -> void:
	var sim := _crated(Vector3.ZERO)
	var heard := _crate_step(sim, PropState.Body.FLOATING, PropState.Body.LOST)
	assert_true(_of(heard, AudioCue.Kind.SPLASH).is_empty(), "it splashed as the water lifted it")


func test_climbing_out_of_the_water_lands_wet_and_drips() -> void:
	var sim := SimFixtures.sim(2)
	var then := sim.snapshot().duplicate(true)
	var now := sim.snapshot().duplicate(true)
	now["tick"] = 1
	now["events"] = [SimEvent.climbed_out(1, 0, 0).to_dict()]
	var heard := _planner(sim).plan(then, now)
	var landings := _of(heard, AudioCue.Kind.LANDING)
	assert_eq(landings.size(), 1, "one landing as it hauls out")
	assert_eq(landings[0].seat, 0)
	assert_eq(landings[0].ground, AudioCue.Ground.WET)
	assert_eq(landings[0].gain, CuePlanner.LANDING_SOFT)
	var splashes := _of(heard, AudioCue.Kind.SPLASH)
	assert_eq(splashes.size(), 1, "and the water running off it")
	assert_eq(splashes[0].seat, 0)
	assert_eq(splashes[0].gain, CuePlanner.CLIMB_OUT_SPLASH)
