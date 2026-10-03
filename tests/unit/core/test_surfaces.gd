extends GutTest
## Surfaces as the steamer's spatial authority: heights, steps, falls, landings and
## the wet test, all asked of Surfaces and stepped through MatchSim.


func _steamer() -> ShipLayout:
	return SimFixtures.steamer()


func _platform(platform_name: StringName) -> int:
	return SimFixtures.platform_named(_steamer(), platform_name)


## The steamer's ramp whose start end joins [param start] and end end joins
## [param end], as a surface number.
func _ramp_between(surfaces: Surfaces, start: int, end: int) -> int:
	for ramp in _steamer().ramps.size():
		var surface := surfaces.ramp_surface(ramp)
		var joined := surfaces.joins(surface)
		if joined[0] == start and joined[1] == end:
			return surface
	return Surfaces.NONE


## A steamer match held level and unsunk, seat 1 parked out of the way on the poop.
func _steamer_sim() -> MatchSim:
	var sim := SimFixtures.sim(2, null, _steamer())
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 0.0))
	return sim


func _kinds(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## Seat 0 starts standing at [param from] and walks [param direction] until it
## lands somewhere; returns the events of the walk.
func _walk_off(sim: MatchSim, from: Vector3, direction: Vector2) -> Array[SimEvent]:
	SimFixtures.place(sim, 0, from)
	var events: Array[SimEvent] = []
	for _tick in 3 * Ticks.RATE:
		var stepped := SimFixtures.step(sim, {0: SimFixtures.frame(0, direction)})
		events.append_array(stepped)
		if not _kinds(stepped, SimEvent.Kind.LANDED).is_empty() or sim.state.seats[0].is_out():
			break
	return events


func test_ramp_height_interpolates() -> void:
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	assert_gt(layout.ramps.size(), 0)
	for ramp_index in layout.ramps.size():
		var ramp := layout.ramps[ramp_index]
		var surface := surfaces.ramp_surface(ramp_index)
		var start := ramp.end_point(0)
		var end := ramp.end_point(1)
		for weight: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var point := start.lerp(end, weight)
			var expected := lerpf(ramp.start_height, ramp.end_height, weight)
			assert_almost_eq(
				surfaces.height_at(surface, point),
				expected,
				0.0001,
				"ramp %d at %s" % [ramp_index, weight]
			)
		# Halfway up, standing on it, the ramp is what is underfoot.
		var middle := start.lerp(end, 0.5)
		middle.y = surfaces.height_at(surface, middle)
		assert_eq(surfaces.under(middle, SimFixtures.rules().step_height), surface)


func test_step_height_picks_upper_or_lower() -> void:
	var surfaces := Surfaces.new(_steamer())
	var step := SimFixtures.rules().step_height
	var main_deck := _platform(&"main deck")
	var boat_deck := _platform(&"boat deck")
	# A ramp from the main deck up to the boat deck stands on the main deck.
	var ramp := _ramp_between(surfaces, boat_deck, main_deck)
	assert_ne(ramp, Surfaces.NONE)
	var layout_ramp := _steamer().ramps[ramp - surfaces.platform_count()]
	var foot := layout_ramp.end_point(1)
	var head := layout_ramp.end_point(0)
	var rise := head.y - foot.y
	var low := foot.lerp(head, step * 0.5 / rise)
	var high := foot.lerp(head, step * 2.0 / rise)
	low.y = 0.0
	high.y = 0.0
	assert_eq(surfaces.under(low, step), ramp, "the ramp within a step above: up onto it")
	assert_eq(surfaces.under(high, step), main_deck, "the ramp out of a step's reach: stay low")
	high.y = surfaces.height_at(ramp, high)
	assert_eq(surfaces.under(high, step), ramp, "standing on the ramp: the ramp")
	# Where the boat deck stands over the main deck, the feet decide which.
	var over := Vector3(-5.0, 0.0, 2.0)
	assert_eq(surfaces.under(over, step), main_deck)
	over.y = surfaces.height_at(boat_deck, over)
	assert_eq(surfaces.under(over, step), boat_deck)
	over.y -= step * 2.0
	assert_eq(surfaces.under(over, step), Surfaces.NONE, "between the two: falling")
	over.y -= step * 0.5
	assert_eq(surfaces.landing(over), main_deck, "and it lands on the main deck")


func test_walking_off_the_boat_deck_lands_on_the_main_deck() -> void:
	var sim := _steamer_sim()
	var main_deck := _platform(&"main deck")
	var boat_deck := _platform(&"boat deck")
	# Off its open after edge, abaft the funnel.
	var edge := _steamer().platforms[boat_deck].area.position.x
	var events := _walk_off(sim, Vector3(edge + 0.6, 2.5, 2.0), Vector2.LEFT)
	var fell := _kinds(events, SimEvent.Kind.FELL)
	var landed := _kinds(events, SimEvent.Kind.LANDED)
	assert_eq(fell.size(), 1, "it fell once")
	assert_eq(landed.size(), 1, "and landed once")
	if fell.is_empty() or landed.is_empty():
		return
	assert_eq(fell[0].seat, 0)
	assert_gt(landed[0].tick, fell[0].tick)
	assert_eq(landed[0].surface, main_deck)
	var walker := sim.state.seats[0]
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(walker.surface, main_deck)
	assert_eq(walker.pos.y, 0.0, "on the main deck's planks")
	assert_lt(walker.pos.x, edge, "abaft the deckhouse, not inside it")
	assert_gt(walker.stagger_ticks, 0, "staggered by the drop")
	assert_false(walker.is_out())


func test_landing_stagger_scales_with_the_drop() -> void:
	var per_m := SimFixtures.rules().fall_stagger_per_m
	var layout := _steamer()
	var bridge := layout.platforms[_platform(&"bridge")]
	var boat_deck := layout.platforms[_platform(&"boat deck")]
	var poop_deck := layout.platforms[_platform(&"poop deck")]
	# Off the poop deck's open forward edge onto the main deck, off the bridge's
	# forward edge beside its ramp onto the boat deck, off the boat deck's after edge
	# onto the main deck.
	var falls := [
		[
			Vector3(poop_deck.area.end.x - 0.6, poop_deck.height, 0.0),
			Vector2.RIGHT,
			poop_deck.height
		],
		[
			Vector3(bridge.area.end.x - 0.6, bridge.height, bridge.area.end.y - 0.35),
			Vector2.RIGHT,
			bridge.height - boat_deck.height
		],
		[
			Vector3(boat_deck.area.position.x + 0.6, boat_deck.height, 2.0),
			Vector2.LEFT,
			boat_deck.height
		],
	]
	var staggers: Array[int] = []
	for fall: Array in falls:
		var sim := _steamer_sim()
		var landed := _kinds(_walk_off(sim, fall[0], fall[1]), SimEvent.Kind.LANDED)
		assert_eq(landed.size(), 1, "a fall of %s m lands" % fall[2])
		if landed.is_empty():
			return
		var expected := Ticks.from_seconds(float(fall[2]) * per_m)
		assert_eq(landed[0].stagger_ticks, expected, "a drop of %s m" % fall[2])
		assert_eq(sim.state.seats[0].stagger_ticks, expected)
		staggers.append(expected)
	assert_lt(staggers[0], staggers[1], "a deeper drop staggers longer")
	assert_lt(staggers[1], staggers[2])
	assert_eq(staggers[2], Ticks.from_seconds(0.2), "off the boat deck costs 0.2 s (§6)")


func test_a_fall_past_every_surface_reaches_the_sea() -> void:
	var layout := _steamer()
	var sim := _steamer_sim()
	var surfaces := sim.surfaces
	var highest := -INF
	var lowest := INF
	for platform: ShipPlatform in layout.platforms:
		highest = maxf(highest, platform.height)
		lowest = minf(lowest, platform.height)
	# Abeam of the bridge, just outboard of the main deck's railing, above every deck.
	var start := Vector3(
		-2.5, highest + 1.0, layout.platforms[_platform(&"main deck")].area.end.y + 0.5
	)
	assert_eq(surfaces.landing(start), Surfaces.NONE, "nothing under it at any height")
	SimFixtures.place(sim, 0, start)
	var faller := sim.state.seats[0]
	faller.body = PlayerState.Body.AIRBORNE
	faller.surface = Surfaces.NONE
	faller.fall_from = start.y
	var events: Array[SimEvent] = []
	var passed_every_deck := false
	for _tick in 3 * Ticks.RATE:
		events.append_array(SimFixtures.step(sim))
		passed_every_deck = passed_every_deck or faller.pos.y < lowest
		if faller.is_out():
			break
	assert_true(passed_every_deck, "it fell past the lowest deck")
	assert_true(faller.is_out(), "into the sea")
	assert_eq(faller.out_cause, PlayerState.Cause.WATER)
	assert_true(_kinds(events, SimEvent.Kind.LANDED).is_empty(), "it never landed")


func test_stern_down_scenario_floods_the_poop_deck_first() -> void:
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var bow_down: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	# The shipped scenario with its trim and heel signs flipped: by the stern, the
	# other way over.
	var rows := []
	for keyframe: SinkKeyframe in bow_down.keyframes:
		rows.append([keyframe.at, keyframe.sink, -keyframe.trim_deg, -keyframe.heel_deg])
	var stern_down := SimFixtures.scenario(rows, bow_down.starts_at)
	var firsts := []
	for scenario: SinkScenario in [stern_down, bow_down]:
		var schedule := SinkSchedule.new(scenario, layout.freeboard, SeedStreams.derive(1, "sink"))
		var first := Surfaces.NONE
		for tick in 240 * Ticks.RATE:
			var pose := schedule.pose_at(tick)
			for platform in layout.platforms.size():
				if surfaces.flooded(platform, pose):
					first = platform
					break
			if first != Surfaces.NONE:
				break
		firsts.append(first)
	assert_eq(firsts[0], _platform(&"poop deck"), "stern down: the poop deck goes first")
	assert_eq(firsts[1], _platform(&"forecastle"), "bow down: the forecastle goes first")
