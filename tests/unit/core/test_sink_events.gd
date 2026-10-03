extends GutTest
## SH6's scheduled events: lurches, collapses, failing railings, the plunge and the
## hard cap, all pure in (scenario, seed, tick) (D7) and none of them snapshot state
## (D5).

const SEEDS := 10


func _steamer_schedule(seed_value: int, scenario: SinkScenario = null) -> SinkSchedule:
	return SinkSchedule.new(
		scenario if scenario != null else load(SimFixtures.STEAMER_SINKING),
		SimFixtures.steamer().freeboard,
		SeedStreams.derive(seed_value, "sink")
	)


## Every event [param schedule] holds, happened or not.
func _all(schedule: SinkSchedule) -> Array[SinkSchedule.Scheduled]:
	return schedule.fired(1 << 30)


## The kinds of [param events], in order.
func _kinds(events: Array[SimEvent]) -> Array[SimEvent.Kind]:
	var kinds: Array[SimEvent.Kind] = []
	for event: SimEvent in events:
		kinds.append(event.kind)
	return kinds


## The highest world height, under [param pose], of [param layout]'s surfaces.
func _top(layout: ShipLayout, pose: ShipPose) -> float:
	var top := -INF
	for point: Vector3 in SimFixtures.surface_points(layout):
		top = maxf(top, pose.world_height(point))
	return top


## The steamer's scenario turned end for end and side for side: stern down,
## listing and lurching the other way. The steamer's mast stands forward and tall,
## so a stern going down lifts it: the mirror sinks deeper to put it under.
func _mirrored() -> SinkScenario:
	var steamer: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var mirror: SinkScenario = steamer.duplicate(true)
	for keyframe: SinkKeyframe in mirror.keyframes:
		keyframe.trim_deg = -keyframe.trim_deg
		keyframe.heel_deg = -keyframe.heel_deg
	mirror.keyframes.back().sink = 21.5
	for event: SinkEvent in mirror.events:
		event.heel_deg = -event.heel_deg
	return mirror


func test_events_are_pure_in_seed_and_tick() -> void:
	var first := _steamer_schedule(1701)
	var second := _steamer_schedule(1701)
	var ticks: Array[int] = []
	for tick in range(0, 220 * Ticks.RATE, 7):
		ticks.append(tick)
	ticks.reverse()
	var told := {}
	for tick: int in ticks:
		told[tick] = [_kinds(first.events_at(tick)), first.pose_at(tick).transform]
	# Array.shuffle() draws on the global RNG; this order is seeded.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	for index in range(ticks.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := ticks[index]
		ticks[index] = ticks[other]
		ticks[other] = held
	for tick: int in ticks:
		assert_eq(_kinds(second.events_at(tick)), told[tick][0], "events at %d" % tick)
		assert_eq(second.pose_at(tick).transform, told[tick][1], "pose at %d" % tick)
	var other := _steamer_schedule(1702)
	var moved := false
	for index in _all(first).size():
		moved = moved or _all(first)[index].at != _all(other)[index].at
	assert_true(moved, "another seed moves the events")


func test_jitter_stays_within_bounds() -> void:
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	var start := Ticks.from_seconds(scenario.starts_at)
	var seen := {}
	for seed_value in 50:
		var schedule := _steamer_schedule(seed_value)
		var placed := _all(schedule)
		assert_eq(placed.size(), scenario.events.size())
		for index in placed.size():
			var event := scenario.events[index]
			var authored := start + Ticks.from_seconds(event.at)
			var bound := Ticks.from_seconds(event.jitter)
			assert_between(placed[index].at, authored - bound, authored + bound)
			assert_eq(placed[index].at - placed[index].warned_at, Ticks.from_seconds(event.warning))
			seen[placed[index].at - authored] = true
	assert_gt(seen.size(), 10, "the jitter varies from seed to seed")


func test_telegraph_comes_first_then_the_event() -> void:
	var lurch := SimFixtures.lurch(2.0, 18.0)
	var going := SimFixtures.collapse(4.0, &"bridge")
	var scenario := SimFixtures.with_events(SimFixtures.calm(), [lurch, going])
	var schedule := SinkSchedule.new(scenario, 3.4, SeedStreams.derive(1, "sink"))
	var announced := {}
	for tick in 6 * Ticks.RATE:
		for event: SimEvent in schedule.events_at(tick):
			announced[event.kind] = tick
			assert_eq(event.seat, -1)
	assert_eq(announced[SimEvent.Kind.SHIP_LURCHING], Ticks.from_seconds(1.0))
	assert_eq(announced[SimEvent.Kind.SHIP_LURCHED], Ticks.from_seconds(2.0))
	assert_eq(announced[SimEvent.Kind.PLATFORM_COLLAPSING], Ticks.from_seconds(1.0))
	assert_eq(announced[SimEvent.Kind.PLATFORM_COLLAPSED], Ticks.from_seconds(4.0))
	var warned := schedule.pose_at(Ticks.from_seconds(1.5))
	assert_eq(warned.lurch_warning, 18.0, "the telegraph names the heel to come")
	assert_eq(warned.heel_deg, 0.0, "and moves nothing yet")
	assert_eq(warned.collapsing, [&"bridge"] as Array[StringName])
	var swinging := schedule.pose_at(Ticks.from_seconds(3.5))
	assert_almost_eq(swinging.heel_deg, 18.0, 0.01, "the height of the swing")
	assert_eq(swinging.lurch, 18.0)
	assert_eq(schedule.pose_at(Ticks.from_seconds(5.0)).heel_deg, 0.0, "and back")
	assert_eq(schedule.pose_at(Ticks.from_seconds(5.0)).collapsed, [&"bridge"] as Array[StringName])


func test_lurch_slides_bodies_downhill() -> void:
	# The pose swings, nothing pushes: an idle body slides toward the side the lurch
	# puts down, whichever that is, and a braced one holds.
	for heel: float in [20.0, -20.0]:
		var lifted := SimFixtures.tilted(2.0, 0.0)
		var sim := SimFixtures.sim(
			2, SimFixtures.with_events(lifted, [SimFixtures.lurch(2.0, heel)])
		)
		SimFixtures.place(sim, 0, Vector3(-8.0, 0.0, 0.0))
		SimFixtures.place(sim, 1, Vector3(8.0, 0.0, 0.0))
		var brace := SimFixtures.frame(1, Vector2.ZERO, InputFrame.BRACE)
		SimFixtures.step(sim, {1: brace}, Ticks.from_seconds(2.0))
		assert_eq(sim.state.seats[0].pos.z, 0.0, "nothing moves during the telegraph")
		SimFixtures.step(sim, {1: brace}, Ticks.from_seconds(3.0))
		var low := ShipPose.low_side(heel).y
		assert_gt(sim.state.seats[0].pos.z * low, 0.3, "heel %s: slid to the low side" % heel)
		assert_almost_eq(sim.state.seats[1].pos.z, 0.0, 0.0001, "heel %s: the brace held" % heel)


func test_collapse_drops_the_bodies_on_it() -> void:
	var layout := SimFixtures.steamer()
	var rules := SimFixtures.rules()
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(2.0, &"bridge", 1.0)]
	)
	var sim := SimFixtures.sim(3, scenario, layout)
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var boat_deck := SimFixtures.platform_named(layout, &"boat deck")
	SimFixtures.place(sim, 0, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.place(sim, 1, Vector3(-2.5, 2.5, 0.6))
	SimFixtures.place(sim, 2, Vector3(-17.0, 1.2, 0.0))
	assert_eq(sim.state.seats[0].surface, bridge)
	var falls := Ticks.from_seconds(2.0)
	var before := SimFixtures.step(sim, {}, falls)
	assert_false(SimEvent.Kind.FELL in _kinds(before), "the bridge stands through its warning")
	assert_true(SimEvent.Kind.PLATFORM_COLLAPSING in _kinds(before))
	var events := SimFixtures.step(sim)
	assert_eq(_kinds(events).slice(0, 2), [SimEvent.Kind.PLATFORM_COLLAPSED, SimEvent.Kind.FELL])
	assert_eq(events[1].seat, 0, "the body on the bridge falls")
	assert_eq(sim.state.seats[0].body, PlayerState.Body.AIRBORNE)
	assert_eq(sim.surfaces.under(Vector3(-2.5, 4.7, 0.0), rules.step_height), Surfaces.NONE)
	# The wheelhouse walls stood flush under the roof; their tops went with it.
	assert_eq(sim.surfaces.under(Vector3(-3.9, 4.7, 0.0), rules.step_height), Surfaces.NONE)
	var landed: SimEvent = null
	for _tick in Ticks.RATE:
		for event: SimEvent in SimFixtures.step(sim):
			if event.kind == SimEvent.Kind.LANDED:
				landed = event
	assert_not_null(landed, "it lands")
	assert_eq(landed.surface, boat_deck, "on the wheelhouse floor beneath")
	assert_eq(landed.stagger_ticks, Ticks.from_seconds(2.2 * rules.fall_stagger_per_m))
	assert_eq(layout.room_at(sim.state.seats[0].pos, rules.step_height), _wheelhouse(layout))
	assert_false(sim.state.seats[0].is_out())
	assert_eq(sim.state.seats[1].pos.y, 2.5, "the one inside stays on its floor")
	assert_false(sim.state.seats[1].is_out())


func _wheelhouse(layout: ShipLayout) -> int:
	for index in layout.rooms.size():
		if layout.rooms[index].name == &"wheelhouse":
			return index
	return -1


## Steps [param sim] with an empty frame until [param seat] is grounded again;
## returns the highest its feet went.
func _land(sim: MatchSim, seat: int) -> float:
	var player := sim.state.seats[seat]
	var apex := player.pos.y
	var ticks := 0
	while player.body == PlayerState.Body.AIRBORNE and ticks < 2 * Ticks.RATE:
		SimFixtures.step(sim)
		apex = maxf(apex, player.pos.y)
		ticks += 1
	return apex


func test_a_collapsed_roof_no_longer_caps_a_jump() -> void:
	var layout := SimFixtures.steamer()
	var rules := SimFixtures.rules()
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(1.0, &"bridge", 0.5)]
	)
	var sim := SimFixtures.sim(1, scenario, layout)
	SimFixtures.place(sim, 0, Vector3(-2.5, 2.5, 0.0))
	SimFixtures.step(sim, {}, 2 * Ticks.RATE)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
	var apex := _land(sim, 0)
	assert_almost_eq(apex, 2.5 + rules.jump_height, 0.02, "a full jump: no roof overhead")
	assert_eq(sim.state.seats[0].pos.y, 2.5, "back on the wheelhouse floor")


func test_a_jumper_in_the_air_as_the_bridge_goes_lands_in_the_wheelhouse() -> void:
	var layout := SimFixtures.steamer()
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(2.0, &"bridge", 1.0)]
	)
	var sim := SimFixtures.sim(1, scenario, layout)
	SimFixtures.place(sim, 0, Vector3(-2.5, 4.7, 0.0))
	var jumper := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.from_seconds(2.0) - 3)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 2)
	assert_eq(jumper.body, PlayerState.Body.AIRBORNE, "in the air as the bridge goes")
	assert_gt(jumper.vel.y, 0.0, "still rising")
	var landed: SimEvent = null
	for _tick in 2 * Ticks.RATE:
		for event: SimEvent in SimFixtures.step(sim):
			if event.kind == SimEvent.Kind.LANDED:
				landed = event
	assert_not_null(landed, "it lands")
	assert_eq(landed.surface, SimFixtures.platform_named(layout, &"boat deck"))
	assert_eq(jumper.pos.y, 2.5, "on the wheelhouse floor")
	assert_eq(layout.room_at(jumper.pos, SimFixtures.rules().step_height), _wheelhouse(layout))
	assert_false(jumper.is_out())


func test_a_jump_in_a_lurch_keeps_the_downhill_pull() -> void:
	# Mid-swing, past the grip angle: a body that jumps is pulled toward the low side
	# all the way through the air, as on any steep deck.
	for heel: float in [20.0, -20.0]:
		var lifted := SimFixtures.tilted(2.0, 0.0)
		var sim := SimFixtures.sim(
			1, SimFixtures.with_events(lifted, [SimFixtures.lurch(2.0, heel)])
		)
		SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.0))
		var brace := SimFixtures.frame(0, Vector2.ZERO, InputFrame.BRACE)
		SimFixtures.step(sim, {0: brace}, Ticks.from_seconds(3.2))
		var jumper := sim.state.seats[0]
		var low := ShipPose.low_side(heel).y
		var took_off := jumper.pos.z
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
		assert_eq(jumper.body, PlayerState.Body.AIRBORNE, "heel %s: off the deck" % heel)
		_land(sim, 0)
		assert_gt((jumper.pos.z - took_off) * low, 0.05, "heel %s: came down downhill" % heel)
		assert_gt(jumper.vel.z * low, 0.0, "heel %s: still sliding that way" % heel)


func test_highest_platform_reads_the_pose_it_is_handed() -> void:
	var layout := SimFixtures.steamer()
	var surfaces := Surfaces.new(layout)
	var bridge := SimFixtures.platform_named(layout, &"bridge")
	var standing := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	var gone := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	gone.collapsed = [&"bridge"] as Array[StringName]
	assert_eq(surfaces.highest_platform(standing), bridge)
	assert_ne(surfaces.highest_platform(gone), bridge, "gone in the pose, never honoured")
	surfaces.honour(gone)
	assert_eq(surfaces.highest_platform(standing), bridge, "standing in the pose, honoured gone")


func test_body_frozen_on_a_collapse_falls_when_its_stop_ends() -> void:
	var layout := SimFixtures.steamer()
	var scenario := SimFixtures.with_events(
		SimFixtures.calm(), [SimFixtures.collapse(1.0, &"bridge", 0.5)]
	)
	var sim := SimFixtures.sim(2, scenario, layout)
	SimFixtures.place(sim, 0, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.place(sim, 1, Vector3(-17.0, 1.2, 0.0))
	SimFixtures.step(sim, {}, Ticks.RATE)
	var frozen := sim.state.seats[0]
	frozen.hitstop = 3
	frozen.held_vel = Vector3(0.5, 0.0, 0.0)
	SimFixtures.step(sim)
	assert_eq(frozen.body, PlayerState.Body.AIRBORNE, "off the deck as it goes")
	SimFixtures.step(sim)
	assert_almost_eq(frozen.pos.y, 4.7, 0.0001, "held where it stood while the stop runs")
	SimFixtures.step(sim, {}, 2)
	assert_false(frozen.is_frozen())
	SimFixtures.step(sim)
	assert_lt(frozen.pos.y, 4.69, "falling once it ends")
	assert_gt(frozen.vel.x, 0.0, "with the velocity it held")


func test_failed_railing_stops_holding() -> void:
	var deck := SimFixtures.deck()
	var fail := SinkEvent.new()
	fail.kind = SinkEvent.Kind.RAILING_FAIL
	fail.at = 1.0
	fail.railing = 0
	var sim := SimFixtures.sim(2, SimFixtures.with_events(SimFixtures.calm(), [fail]), deck)
	var railing := deck.railings[0]
	var on_it := (railing.from + railing.to) * 0.5
	var near := Vector3(on_it.x, 0.0, on_it.y + 0.3)
	var rules := SimFixtures.rules()
	assert_false(sim.surfaces.rail_contacts(near, rules.body_radius, 0).is_empty())
	var events := SimFixtures.step(sim, {}, Ticks.RATE + 1)
	assert_true(SimEvent.Kind.RAILING_BROKE in _kinds(events))
	assert_true(sim.surfaces.rail_contacts(near, rules.body_radius, 0).is_empty(), "gone")
	var other := deck.railings[1]
	var by_other := (other.from + other.to) * 0.5
	assert_false(
		sim.surfaces.rail_contacts(Vector3(by_other.x, 0.0, by_other.y + 0.3), 0.4, 0).is_empty(),
		"the others hold"
	)


func test_every_surface_is_under_by_the_cap() -> void:
	var layout := SimFixtures.steamer()
	for seed_value in SEEDS:
		var schedule := _steamer_schedule(seed_value)
		assert_eq(schedule.cap_tick(), Ticks.from_seconds(210.0), "the cap is 3:30")
		var top := _top(layout, schedule.pose_at(schedule.cap_tick()))
		assert_lte(top, -0.5, "seed %d: every surface 0.5 m under" % seed_value)


func test_cap_puts_everyone_left_out_together() -> void:
	var lifted := SimFixtures.tilted(0.0, 0.0)
	var sim := SimFixtures.sim(3, SimFixtures.with_events(lifted, [], 2.0))
	var events := SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	assert_true(sim.is_over())
	var cap := Ticks.from_seconds(2.0)
	for player: PlayerState in sim.state.seats:
		assert_eq([player.out_tick, player.place], [cap, 1], "seat %d" % player.seat)
	assert_eq(events.back().kind, SimEvent.Kind.MATCH_ENDED)
	assert_eq(events.back().seat, -1, "a draw: the sea wins")


func test_the_cap_settles_swimmers_by_cold() -> void:
	var rules := SimFixtures.rules()
	var cap := Ticks.from_seconds(2.0)
	# One seat still on deck, two swimming: the deck's is the lone warmest — at the cap
	# nobody has to be swimming — and the swimmers place by the cold they have left.
	var sim := SimFixtures.sim(3, SimFixtures.with_events(SimFixtures.calm(), [], 2.0))
	SimFixtures.swim(sim, 1, Vector3(0.0, 0.0, 8.0))
	SimFixtures.swim(sim, 2, Vector3(0.0, 0.0, -8.0))
	sim.state.seats[1].cold = rules.cold_meter - 0.5
	sim.state.seats[2].cold = rules.cold_meter - 1.0
	var events := SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	assert_true(sim.is_over())
	assert_eq(events.back().kind, SimEvent.Kind.MATCH_ENDED)
	assert_eq(events.back().seat, 0, "the lone warmest wins")
	for seat: int in [1, 2]:
		var player := sim.state.seats[seat]
		assert_eq([player.out_tick, player.out_cause], [cap, PlayerState.Cause.COLD])
	assert_eq([sim.state.seats[1].place, sim.state.seats[2].place], [2, 3], "warmer places higher")

	# Two swimmers as warm as each other and warmer than the third: a draw.
	var tied := SimFixtures.sim(3, SimFixtures.with_events(SimFixtures.calm(), [], 2.0))
	for seat: int in 3:
		SimFixtures.swim(tied, seat, Vector3(-6.0 + 6.0 * seat, 0.0, 8.0))
	tied.state.seats[2].cold = rules.cold_meter - 1.0
	var ended := SimFixtures.step(tied, {}, 3 * Ticks.RATE)
	assert_true(tied.is_over())
	assert_eq(ended.back().seat, -1, "a tie for the warmest is the sea's")
	var places := tied.state.seats.map(func(player: PlayerState) -> int: return player.place)
	assert_eq(places, [1, 1, 3])


func test_a_climb_whose_deck_collapses_drops_the_climber_back_in() -> void:
	# The sea 0.4 m under the steamer's bridge, which goes while a swimmer beside it is
	# climbing onto it: it lets go, back into the sea.
	var layout := SimFixtures.steamer()
	var rules := SimFixtures.rules()
	var sea := 4.7 - 0.4
	var sinking := SimFixtures.with_events(
		SimFixtures.scenario([[0.0, layout.freeboard + sea, 0.0, 0.0]]),
		[SimFixtures.collapse(0.3, &"bridge", 0.2)]
	)
	var sim := SimFixtures.sim(1, sinking, layout)
	SimFixtures.swim(sim, 0, Vector3(-2.5, 0.0, 1.5 + rules.body_radius + 0.2))
	var climber := sim.state.seats[0]
	var press := {0: SimFixtures.frame(0, Vector2(0.0, -1.0))}
	SimFixtures.step(sim, press, 2)
	assert_true(climber.is_climbing(), "it started up onto the bridge")
	var events := SimFixtures.step(sim, press, Ticks.RATE)
	var kinds := _kinds(events)
	assert_true(SimEvent.Kind.PLATFORM_COLLAPSED in kinds, "the bridge went")
	assert_false(SimEvent.Kind.CLIMBED_OUT in kinds, "it never stood on it")
	assert_false(climber.is_climbing())
	assert_eq(climber.body, PlayerState.Body.SWIMMING, "back in the sea")
	assert_lt(climber.pos.y, sea, "under the surface's height, afloat")
	assert_false(climber.is_out())


func test_mirrored_scenario_also_ends_by_its_cap() -> void:
	var layout := SimFixtures.steamer()
	var mirror := _mirrored()
	var schedule := SinkSchedule.new(mirror, layout.freeboard, SeedStreams.derive(7, "sink"))
	var lurches := 0
	for scheduled: SinkSchedule.Scheduled in _all(schedule):
		if scheduled.event.kind != SinkEvent.Kind.LURCH:
			continue
		lurches += 1
		var middle := (scheduled.at + scheduled.ends_at) / 2
		var swing := schedule.pose_at(middle).heel_deg - schedule.pose_at(scheduled.at).heel_deg
		assert_eq(signf(swing), signf(scheduled.event.heel_deg), "the lurch swings its own way")
	assert_eq(lurches, 3)
	var bow := Vector3(18.0, 1.8, 0.0)
	var stern := Vector3(-18.0, 1.2, 0.0)
	var late := schedule.pose_at(Ticks.from_seconds(200.0))
	assert_gt(late.world_height(bow), late.world_height(stern), "stern down")
	assert_lte(_top(layout, schedule.pose_at(schedule.cap_tick())), -0.5, "all under")
	var sim := MatchSim.create(SimFixtures.config(3, mirror, 7, layout))
	SimFixtures.place(sim, 0, Vector3(16.0, 1.8, 0.0))
	SimFixtures.place(sim, 1, Vector3(-2.0, 2.5, 0.0))
	SimFixtures.place(sim, 2, Vector3(-2.5, 4.7, 0.0))
	var collapsed := false
	while not sim.is_over():
		for event: SimEvent in SimFixtures.step(sim):
			collapsed = collapsed or event.kind == SimEvent.Kind.PLATFORM_COLLAPSED
	assert_true(collapsed, "the bridge went")
	assert_lte(sim.state.tick, schedule.cap_tick() + 1, "over by its cap")


## Resumed from a snapshot taken in a lurch's telegraph, mid-lurch, on the collapse
## tick and as the bodies fall, a match steps on exactly as the one it came from (D5):
## nothing of the sinking is in a snapshot, and none of it has to be.
func test_continues_across_a_lurch_and_a_collapse() -> void:
	var layout := SimFixtures.steamer()
	var scenario := SimFixtures.with_events(
		SimFixtures.tilted(3.0, 0.0),
		[SimFixtures.lurch(1.0, 18.0), SimFixtures.collapse(3.0, &"bridge", 1.0)]
	)
	var config := SimFixtures.config(4, scenario, 3, layout)
	var sim := MatchSim.create(config)
	SimFixtures.place(sim, 0, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.place(sim, 1, Vector3(-3.0, 4.7, 1.0))
	SimFixtures.place(sim, 2, Vector3(-4.0, 2.5, 2.5))
	SimFixtures.place(sim, 3, Vector3(-2.5, 2.5, 0.5))
	var walk: Array[InputFrame] = [
		SimFixtures.frame(0, Vector2.ZERO, 0, 0.0),
		SimFixtures.frame(1, Vector2.LEFT, 0, 180.0),
		SimFixtures.frame(2, Vector2.UP, 0, 270.0),
		SimFixtures.frame(3, Vector2.ZERO, InputFrame.BRACE, 0.0),
	]
	var snapshots: Array[Dictionary] = [sim.snapshot()]
	for _tick in 5 * Ticks.RATE:
		sim.step(walk)
		snapshots.append(sim.snapshot())
	var schedule := sim.schedule
	var lurch := _all(schedule)[0]
	var going := _all(schedule)[1]
	var starts := {
		"telegraph": lurch.warned_at + 5,
		"mid-lurch": (lurch.at + lurch.ends_at) / 2,
		"collapse tick": going.at,
		"falling": going.at + 2,
	}
	for label: String in starts:
		var start: int = starts[label]
		assert_eq(snapshots[start]["tick"], start)
		var resumed := MatchSim.from_snapshot(snapshots[start], config)
		if start >= going.at:
			# Asked before its first step — a client drawing what it resumed — the ship
			# already stands as the pose says.
			assert_eq(
				resumed.surfaces.under(Vector3(-2.5, 4.7, 0.0), SimFixtures.rules().step_height),
				Surfaces.NONE,
				"%s: resumed without the bridge" % label
			)
		for tick in range(start, mini(start + Ticks.RATE, snapshots.size() - 1)):
			resumed.step(walk)
			assert_eq(resumed.snapshot(), snapshots[tick + 1], "%s, tick %d" % [label, tick + 1])
			if resumed.snapshot() != snapshots[tick + 1]:
				return
	var fell := false
	for snapshot: Dictionary in snapshots:
		fell = fell or snapshot["seats"][0]["state"] == PlayerState.Body.AIRBORNE
	assert_true(fell, "the bridge's body fell within the window")
