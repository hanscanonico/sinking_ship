extends GutTest
## Lifebuoys (#273): hung on her side railings at the start, taken by a Grab press,
## carried at a cost, knocked loose only by a charged shove, and in the sea a slower
## cold drain — never none. Nothing brings one back once it is lost.

const GRAB := InputFrame.GRAB
const SHOVE := InputFrame.SHOVE
const BRACE := InputFrame.BRACE
## The flat deck's port railing span aft of its gap, and where along it a ring hangs.
const SPAN := 0
const STATION := Vector3(-6.0, 0.0, -4.0)


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## The flat deck — its one platform called "deck" — with a ring hung at STATION on SPAN.
func _hung_deck() -> ShipLayout:
	var layout := SimFixtures.crated([SimFixtures.lifebuoy(STATION, SPAN)])
	var deck: ShipPlatform = layout.platforms[0].duplicate()
	deck.name = &"deck"
	layout.platforms = [deck]
	return layout


func _sim(seats: int, sinking: SinkScenario = null) -> MatchSim:
	return SimFixtures.sim(seats, sinking, _hung_deck())


func _grab(seat: int) -> InputFrame:
	return SimFixtures.frame(seat, Vector2.ZERO, GRAB)


func test_a_ring_hangs_on_its_span_until_a_grab_takes_it_off() -> void:
	var sim := _sim(1, SimFixtures.tilted(0.0, 30.0))
	var ring := sim.state.props[0]
	assert_eq(ring.body, PropState.Body.HUNG, "hung from the start")
	SimFixtures.place(sim, 0, Vector3(-6.0, 0.0, -3.4), -90.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, BRACE)}, Ticks.RATE)
	assert_eq(ring.pos, STATION, "her list does not move a hung ring")
	assert_eq(ring.body, PropState.Body.HUNG)
	SimFixtures.step(sim, {0: _grab(0)})
	assert_eq(ring.holder, 0, "taken off its span from the deck")


func test_a_hung_ring_goes_into_the_sea_with_its_span() -> void:
	var failing := SinkEvent.new()
	failing.kind = SinkEvent.Kind.RAILING_FAIL
	failing.at = 1.0
	failing.railing = SPAN
	var other := SinkEvent.new()
	other.kind = SinkEvent.Kind.RAILING_FAIL
	other.at = 0.5
	other.railing = SPAN + 1
	for case: Array in [
		[SimFixtures.with_events(SimFixtures.calm(), [other, failing]), "the sinking fails it"],
		[
			SimFixtures.with_events(SimFixtures.calm(), [SimFixtures.collapse(1.0, &"deck")]),
			"its deck collapses"
		],
	]:
		var sim := _sim(1, case[0])
		SimFixtures.place(sim, 0, Vector3(10.0, 0.0, 0.0))
		var events := SimFixtures.step(sim, {}, Ticks.from_seconds(1.0) - 1)
		assert_eq(sim.state.props[0].body, PropState.Body.HUNG, "%s: not before" % case[1])
		events = SimFixtures.step(sim, {}, 2)
		assert_eq(sim.state.props[0].body, PropState.Body.LOST, case[1])
		assert_eq(_of(events, SimEvent.Kind.PROP_LOST).size(), 1, case[1])

	var broken := _sim(1)
	SimFixtures.place(broken, 0, Vector3(10.0, 0.0, 0.0))
	broken.state.railing_hp[SPAN] = 0.0
	SimFixtures.step(broken)
	assert_eq(broken.state.props[0].body, PropState.Body.LOST, "the match breaks it")


## [param seats] seats on the flat deck, seat 0 holding a ring taken at the start.
func _carrying(seats: int) -> MatchSim:
	var sim := SimFixtures.sim(
		seats, null, SimFixtures.crated([SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0))])
	)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.step(sim, {0: _grab(0)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	assert_eq(sim.state.props[0].holder, 0, "set up holding its ring")
	return sim


func test_carrying_a_ring_slows_the_walk() -> void:
	var sim := _carrying(1)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE)
	var walk := Vector2(sim.state.seats[0].vel.x, sim.state.seats[0].vel.z).length()
	assert_almost_eq(walk, PropKind.named(&"lifebuoy").carry_walk, 0.001, "at carry_walk")
	assert_lt(walk, SimFixtures.rules().walk_speed)
	assert_almost_eq(
		sim.state.props[0].pos,
		sim.state.seats[0].pos,
		Vector3.ONE * 0.001,
		"the ring rides at its holder"
	)


func test_carrying_a_ring_bars_the_brace_and_the_charge_but_keeps_the_quick_shove() -> void:
	var rules := SimFixtures.rules()
	var sim := _carrying(1)
	var player := sim.state.seats[0]
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, BRACE)}, 5)
	assert_false(player.bracing, "no brace")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)})
	var stamina := player.stamina
	var fired := false
	for _tick in Ticks.from_seconds(rules.charge_full) + 2:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
		assert_ne(player.action, PlayerState.Action.CHARGE, "no charge")
		fired = fired or player.action == PlayerState.Action.ACTIVE
	assert_true(fired, "held, its shove goes off quick")
	assert_eq(player.stamina, stamina, "and costs nothing")
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
	assert_eq(player.body, PlayerState.Body.AIRBORNE, "a jump is kept")


## Seat 1 shoves seat 0, who holds a ring and stands in front of it, with [param ticks]
## ticks of the shove held; returns the tick's events of the shove landing on.
func _shoved_for(sim: MatchSim, ticks: int) -> Array[SimEvent]:
	SimFixtures.place(sim, 1, Vector3(-1.5, 0.0, 0.0), 0.0)
	var events: Array[SimEvent] = []
	for _tick in ticks:
		events.append_array(SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, SHOVE)}))
	events.append_array(SimFixtures.step(sim, {1: SimFixtures.frame(1)}, Ticks.RATE))
	return events


func test_a_charged_shove_knocks_a_ring_loose_at_its_holders_feet() -> void:
	var rules := SimFixtures.rules()
	var sim := _carrying(2)
	var feet := sim.state.seats[0].pos
	var events := _shoved_for(sim, Ticks.from_seconds(rules.charge_full))
	assert_eq(_of(events, SimEvent.Kind.SHOVE_LANDED).size(), 1, "the charge lands")
	var ring := sim.state.props[0]
	assert_eq(ring.holder, -1, "out of its hands")
	assert_eq(ring.body, PropState.Body.GROUNDED, "onto the deck")
	assert_almost_eq(ring.pos, feet, Vector3.ONE * 0.001, "at its feet")
	var loose := _of(events, SimEvent.Kind.KNOCKED_LOOSE)
	assert_eq(loose.size(), 1)
	assert_eq([loose[0].seat, loose[0].prop, loose[0].credit], [0, 0, 1])
	assert_true(_of(events, SimEvent.Kind.PROP_LET_GO).is_empty(), "knocked, not let go")
	SimFixtures.place(sim, 1, feet - Vector3(0.8, 0.0, 0.0), 0.0)
	SimFixtures.step(sim, {1: _grab(1)})
	assert_eq(ring.holder, 1, "and the shover takes it")


func test_a_quick_shove_never_knocks_a_ring_loose() -> void:
	var sim := _carrying(2)
	var events := _shoved_for(sim, 1)
	assert_eq(_of(events, SimEvent.Kind.SHOVE_LANDED).size(), 1, "the tap lands")
	assert_eq(sim.state.props[0].holder, 0, "and the ring stays held")
	assert_true(_of(events, SimEvent.Kind.KNOCKED_LOOSE).is_empty())


## Seat 0 swimming off the flat deck's starboard side, [param freeboard] out of the sea,
## at [param x] with a ring in its hands.
func _afloat_with_a_ring(freeboard: float, z := 6.0) -> MatchSim:
	var layout := SimFixtures.crated(
		[SimFixtures.lifebuoy(Vector3(0.0, 0.0, 0.0))], SimFixtures.low_deck(freeboard)
	)
	var sim := SimFixtures.sim(1, null, layout)
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, z), 90.0)
	SimFixtures.hand(sim, 0, 0)
	return sim


func test_a_ring_in_the_sea_slows_the_cold_but_never_stops_it() -> void:
	var rules := SimFixtures.rules()
	var rate := PropKind.named(&"lifebuoy").sea_cold_rate
	assert_gt(rate, 0.0, "never none: every match still ends")
	var sim := _afloat_with_a_ring(3.0)
	var swimmer := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_almost_eq(rules.cold_meter - swimmer.cold, rate, 0.0001, "a second costs rate")
	var lasts := Ticks.from_seconds(rules.cold_meter / rate)
	var events := SimFixtures.step(sim, {}, lasts)
	assert_true(swimmer.is_out(), "the cold takes it in the end")
	var ring := sim.state.props[0]
	assert_eq(ring.body, PropState.Body.LOST, "and its ring with it")
	assert_eq(ring.holder, -1)
	assert_eq(_of(events, SimEvent.Kind.PROP_LOST).size(), 1)


func test_a_ring_in_trapped_air_drains_at_the_lower_rate_not_both() -> void:
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.props = layout.props.duplicate()
	layout.props.append(SimFixtures.lifebuoy(Vector3(13.5, 0.0, 0.0)))
	var sim := SimFixtures.sim(2, null, layout)
	var full := [1.0]
	var flooded := {
		&"hold": full,
		&"hold_bilge": full,
		&"hold_wing_p": full,
		&"hold_wing_s": full,
		&"forepeak": full,
		&"hold_fwd_top": [0.2, 0.8],
		&"engine_room": [-1.0],
	}
	HeldPose.hold(sim, HeldPose.flooded(layout, 1.0, flooded))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.swim(sim, 0, Vector3(13.5, 0.0, 0.0))
	SimFixtures.hand(sim, 0, layout.props.size() - 1)
	var swimmer := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.RATE)
	var rules := SimFixtures.rules()
	var head := swimmer.pos + Vector3.UP * rules.head_height()
	assert_true(sim.pose().in_pocket(head), "its head in the trapped air")
	var lower := minf(rules.pocket_cold_rate, PropKind.named(&"lifebuoy").sea_cold_rate)
	assert_almost_eq(rules.cold_meter - swimmer.cold, lower, 0.0001, "the lower of the two")


func test_a_ring_is_kept_through_a_climb_out() -> void:
	var rules := SimFixtures.rules()
	var sim := _afloat_with_a_ring(rules.climb_reach * 0.5, 4.3)
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(0.0, -1.0))}, Ticks.RATE)
	assert_eq(_of(events, SimEvent.Kind.CLIMBED_OUT).size(), 1, "it climbs out")
	assert_eq(sim.state.seats[0].body, PlayerState.Body.GROUNDED)
	assert_eq(sim.state.props[0].holder, 0, "its ring still in its hands")


func test_a_ring_let_go_in_the_sea_is_lost() -> void:
	var sim := _afloat_with_a_ring(3.0)
	var events := SimFixtures.step(sim, {0: _grab(0)}, 2)
	assert_eq(sim.state.props[0].body, PropState.Body.LOST)
	assert_eq(_of(events, SimEvent.Kind.PROP_LOST).size(), 1)


## A match resumed from its own snapshot (D5) — mid-carry, a ring knocked loose, a ring in
## the sea — plays on as the match it was taken from: the same snapshot every tick.
func test_a_match_with_rings_in_play_continues_from_its_snapshot() -> void:
	var props: Array[ShipProp] = [
		SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0)),
		SimFixtures.lifebuoy(STATION, SPAN),
		SimFixtures.lifebuoy(Vector3(0.0, 0.0, 0.0)),
	]
	var layout := SimFixtures.crated(props, SimFixtures.low_deck(3.0))
	var sim := SimFixtures.sim(3, null, layout)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 1, Vector3(-1.5, 0.0, 0.0), 0.0)
	SimFixtures.swim(sim, 2, Vector3(0.0, 0.0, 6.0))
	SimFixtures.hand(sim, 2, 2)
	var plan := func(tick: int) -> Dictionary:
		if tick == 0:
			return {0: _grab(0)}
		if tick < 4:
			return {0: SimFixtures.frame(0, Vector2.RIGHT * 0.3)}
		if tick < 4 + Ticks.from_seconds(SimFixtures.rules().charge_full):
			return {1: SimFixtures.frame(1, Vector2.RIGHT * 0.3, SHOVE)}
		return {1: SimFixtures.frame(1, Vector2.RIGHT), 0: SimFixtures.frame(0, Vector2.LEFT)}
	var ticks := 3 * Ticks.RATE
	var resumed: MatchSim = null
	var seen := {}
	for tick in ticks:
		if tick % 5 == 2:
			resumed = MatchSim.from_snapshot(sim.snapshot(), sim.config)
		var frames: Dictionary = plan.call(tick)
		SimFixtures.step(sim, frames)
		for event: SimEvent in sim.state.events:
			seen[event.kind] = true
		if resumed != null:
			SimFixtures.step(resumed, frames)
			assert_eq(
				SnapshotDigest.quantized(resumed.snapshot()),
				SnapshotDigest.quantized(sim.snapshot()),
				"tick %d" % tick
			)
	for kind: SimEvent.Kind in [SimEvent.Kind.PROP_GRABBED, SimEvent.Kind.KNOCKED_LOOSE]:
		assert_true(seen.has(kind), "the match played %s" % SimEvent.Kind.keys()[kind])


## `make match` tells a ring's hands (#273): taken, knocked loose by whom, let go.
func test_the_transcript_tells_who_took_a_ring_and_who_knocked_it_loose() -> void:
	var rules := SimFixtures.rules()
	var sim := _carrying(2)
	var told := MatchTranscript.new()
	told.add(_shoved_for(sim, Ticks.from_seconds(rules.charge_full)))
	SimFixtures.place(sim, 1, sim.state.props[0].pos - Vector3(0.8, 0.0, 0.0), 0.0)
	told.add(SimFixtures.step(sim, {1: _grab(1)}))
	SimFixtures.step(sim, {1: SimFixtures.frame(1)})
	told.add(SimFixtures.step(sim, {1: _grab(1)}))
	var text := told.text()
	assert_string_contains(text, "seat 0's prop 0 knocked loose by seat 1")
	assert_string_contains(text, "seat 1 grabs prop 0")
	assert_string_contains(text, "seat 1 lets go of prop 0")


## A ring loose on a deck the water rises over floats as a crate does, but rides in the
## water no deeper than half its own height: crate_draft is deeper than a ring is tall.
func test_a_loose_ring_floats_at_the_water_on_a_flooding_deck() -> void:
	var rules := SimFixtures.rules()
	var deck := SimFixtures.low_deck(0.5)
	var rising := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [2.0, 1.0, 0.0, 0.0]])
	var layout := SimFixtures.crated([SimFixtures.lifebuoy(Vector3(-5.0, 0.0, 0.0))], deck)
	var sim := SimFixtures.sim(1, rising, layout)
	SimFixtures.place(sim, 0, Vector3(10.0, 0.0, 0.0))
	var ring := sim.state.props[0]
	var events := SimFixtures.step(sim, {}, Ticks.from_seconds(2.5))
	assert_eq(ring.body, PropState.Body.FLOATING, "lifted off the deck")
	assert_eq(_of(events, SimEvent.Kind.PROP_AFLOAT).size(), 1)
	var water := sim.pose().water_height(ring.pos)
	assert_gt(water - ring.pos.y, 0.0, "in the water")
	assert_almost_eq(water - ring.pos.y, ring_height() * 0.5, 0.001, "half its height under")
	assert_lt(rules.crate_draft, 1.0)


func ring_height() -> float:
	return PropKind.named(&"lifebuoy").height


## The last swim (MatchVerdict.by_the_cold) goes to the most cold left: with every deck
## under, two swimmers on meters alike, the one holding a ring — its cold coming slower —
## wins it.
func test_holding_a_ring_to_the_end_wins_the_last_swim() -> void:
	var layout := SimFixtures.crated([SimFixtures.lifebuoy(Vector3.ZERO)])
	var sim := SimFixtures.sim(2, SimFixtures.scenario([[0.0, 5.0, 0.0, 0.0]]), layout)
	SimFixtures.swim(sim, 0, Vector3(-6.0, 0.0, 0.0))
	SimFixtures.swim(sim, 1, Vector3(6.0, 0.0, 0.0))
	SimFixtures.hand(sim, 1, 0)
	for seat in 2:
		sim.state.seats[seat].cold = 2.0
	SimFixtures.step(sim)
	assert_eq(sim.state.phase, MatchState.Phase.ENDED, "the last swim is over at once")
	assert_eq(sim.state.winner(), 1, "the ring's holder has the more cold left")
	assert_eq([sim.state.seats[0].place, sim.state.seats[1].place], [2, 1])
