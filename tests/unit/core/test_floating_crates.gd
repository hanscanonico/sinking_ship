extends GutTest
## Crates afloat (SH10): as she heels and trims her water runs to her low side and
## carries a floating crate there, whatever its height in her — into her railings and
## walls, or off an open edge into the sea — a shove or a push sends one farther than
## one standing, a body may stand on its lid, and all of it is in the snapshot (D5).

const SHOVE := InputFrame.SHOVE
## Clear of the flat deck's railing gaps on either side.
const RAILED_X := -8.0
## Where she turns about: her centre of mass, under her deck, as a ship's is.
const UNDER_DECK := -3.0


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func _steamer_crate() -> ShipProp:
	return SimFixtures.steamer().props[0]


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## The sea from the flat deck's edge rising [param metres] over it in [param seconds],
## then held — and, from [param falls_at] seconds when it is given, back down to the
## deck's edge by [param falls_by].
func _rising(metres: float, seconds: float, falls_at := -1.0, falls_by := -1.0) -> SinkScenario:
	var edge := SimFixtures.deck().freeboard
	var rows := [[0.0, edge, 0.0, 0.0], [seconds, edge + metres, 0.0, 0.0]]
	if falls_at >= 0.0:
		rows.append([falls_at, edge + metres, 0.0, 0.0])
		rows.append([falls_by, edge, 0.0, 0.0])
	return SimFixtures.scenario(rows)


## The water over [param point] as [param sim]'s last step had it.
func _water(sim: MatchSim, point: Vector3) -> float:
	return sim.schedule.pose_at(sim.state.tick - 1).water_height(point)


## The flat deck carrying one crate at [param at], with a roof [param roof] metres over
## the deck from x -2 to 2 across her beam — none when it is not given: test data.
func _roofed(at: Vector3, roof := -1.0) -> ShipLayout:
	var crates: Array[ShipProp] = [SimFixtures.crate(at)]
	var layout := SimFixtures.crated(crates)
	if roof >= 0.0:
		layout.platforms = layout.platforms.duplicate()
		var over := ShipPlatform.new()
		over.name = &"roof"
		over.area = Rect2(-2.0, -4.0, 4.0, 8.0)
		over.height = roof
		layout.platforms.append(over)
	return layout


## Steps [param sim] a tick at a time, up to [param ticks], until its crate 0 is
## [param body]; the events of every tick stepped.
func _until(sim: MatchSim, body: PropState.Body, ticks: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _tick in ticks:
		events.append_array(SimFixtures.step(sim))
		if sim.state.props[0].body == body:
			break
	return events


## Rebuilds a sim from [param snapshots] at [param start] and steps it up to a
## second on, fed [param frames_at] for each tick; false, failing the test, when
## it leaves the recorded snapshots.
func _continues(
	snapshots: Array[Dictionary], start: int, config: MatchConfig, frames_at: Callable
) -> bool:
	var resumed := MatchSim.from_snapshot(snapshots[start], config)
	for offset in range(1, mini(Ticks.RATE, snapshots.size() - 1 - start) + 1):
		var tick := start + offset - 1
		resumed.step(frames_at.call(tick))
		if resumed.snapshot() != snapshots[start + offset]:
			fail_test("continuation from tick %d diverged at tick %d" % [start, tick])
			return false
	return true


## The sea [param metres] over the flat deck from the start, held, while she heels from
## level to [param heel_deg] and trims to [param trim_deg] between [param from] and
## [param to] seconds about a point [param pivot_y] metres over her deck — under it, her
## centre of mass, unless given: test data.
func _heeling(
	metres: float, heel_deg: float, from := 1.0, to := 2.0, pivot_y := UNDER_DECK, trim_deg := 0.0
) -> SinkScenario:
	var sea := SimFixtures.deck().freeboard + metres
	var made := SimFixtures.scenario(
		[[0.0, sea, 0.0, 0.0], [from, sea, 0.0, 0.0], [to, sea, trim_deg, heel_deg]]
	)
	made.pivot = Vector3(0.0, pivot_y, 0.0)
	return made


## The flat deck carrying one crate at [param at], the water [param metres] over it
## and her heeling 5° to starboard over a second from one second in, about
## [param pivot_y] over her deck.
func _drifting(at: Vector3, metres := 0.45, pivot_y := UNDER_DECK) -> MatchSim:
	var sim := SimFixtures.sim(1, _heeling(metres, 5.0, 1.0, 2.0, pivot_y), _roofed(at))
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -2.0))
	return sim


func test_a_floating_crate_drifts_to_the_low_side_as_she_heels_and_the_railing_holds_it() -> void:
	var crate_def := _steamer_crate()
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var start := Vector3(RAILED_X, 0.0, edge - crate_def.radius - 0.2)
	var sim := _drifting(start)
	var crate := sim.state.props[0]
	SimFixtures.step(sim, {}, Ticks.RATE / 2)
	assert_eq(crate.body, PropState.Body.FLOATING, "afloat before she heels")
	assert_eq(Vector2(crate.pos.x, crate.pos.z), Vector2(start.x, start.z), "still while level")
	SimFixtures.step(sim, {}, 4 * Ticks.RATE)
	assert_eq(crate.body, PropState.Body.FLOATING, "aboard, the railing between it and the sea")
	var low := ShipPose.low_side(sim.pose().heel_deg)
	assert_eq(low, Vector2(0.0, 1.0), "she heels to starboard")
	assert_gt(crate.pos.z, start.z + 0.1, "her water carried it nearer her low side")
	assert_lte(crate.pos.z, edge - crate_def.radius + 0.0001, "no farther than her railing")
	assert_almost_eq(crate.pos.x, start.x, 0.0001, "a heel moves it athwartships only")


func test_a_floating_crate_goes_downhill_whatever_its_height_against_her_turn() -> void:
	# Over her centre of mass, as on an open deck, and under where she turns, as in a
	# hold: either way her water carries it down her heel and her trim.
	var start := Vector3.ZERO
	for pivot_y: float in [UNDER_DECK, 12.0]:
		var scenario := _heeling(0.6, 5.0, 1.0, 2.0, pivot_y, 3.0)
		var sim := SimFixtures.sim(1, scenario, _roofed(start))
		SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -2.0))
		var crate := sim.state.props[0]
		SimFixtures.step(sim, {}, 3 * Ticks.RATE)
		assert_eq(crate.body, PropState.Body.FLOATING, "afloat, pivot %.1f" % pivot_y)
		assert_gt(crate.pos.z, start.z + 0.1, "to starboard, she heeling so: %.1f" % pivot_y)
		assert_gt(crate.pos.x, start.x + 0.05, "forward, she down by the head: %.1f" % pivot_y)


func test_a_floating_crate_holds_its_place_on_an_even_keel() -> void:
	# Level the whole time while the sea rises over her deck: nothing runs anywhere.
	var sea := SimFixtures.deck().freeboard
	var scenario := SimFixtures.scenario([[0.0, sea, 0.0, 0.0], [3.0, sea + 0.8, 0.0, 0.0]])
	scenario.pivot = Vector3(0.0, UNDER_DECK, 0.0)
	var at := Vector3(RAILED_X, 0.0, 0.0)
	var sim := SimFixtures.sim(1, scenario, _roofed(at))
	SimFixtures.place(sim, 0, Vector3(-12.0, 0.0, -2.0))
	var crate := sim.state.props[0]
	_until(sim, PropState.Body.FLOATING, 3 * Ticks.RATE)
	assert_eq(crate.body, PropState.Body.FLOATING)
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_eq(crate.body, PropState.Body.FLOATING)
	assert_eq(Vector2(crate.pos.x, crate.pos.z), Vector2(at.x, at.z), "where it lifted")
	assert_eq(crate.vel, Vector3.ZERO, "and not moving")


func test_a_floating_crate_drifting_through_a_railing_gap_is_lost() -> void:
	var rules := _rules()
	var crate_def := _steamer_crate()
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	var sim := _drifting(Vector3(gap.x, 0.0, gap.y - crate_def.radius - 0.2))
	var crate := sim.state.props[0]
	var events: Array[SimEvent] = []
	var deepest := 0.0
	for _tick in 5 * Ticks.RATE:
		events.append_array(SimFixtures.step(sim))
		if crate.is_lost():
			break
		deepest = maxf(deepest, _water(sim, crate.pos))
	assert_eq(_of(events, SimEvent.Kind.PROP_AFLOAT).size(), 1, "afloat first")
	assert_eq(_of(events, SimEvent.Kind.PROP_LOST).size(), 1, "then over the side")
	assert_gt(crate.pos.z, gap.y, "lost out past her deck's edge, through the gap")
	assert_lt(deepest, rules.crate_adrift_depth, "never swept off by the water's depth")


func test_a_shove_sends_a_floating_crate_farther_than_a_standing_one() -> void:
	var rules := _rules()
	var crate_def := _steamer_crate()
	# A quay 0.5 m over the deck aft of x -0.6, as a floating crate's walker had: the
	# shover stands on it, the crate on the deck — dry, or afloat in 0.6 m of sea.
	var went: Array[float] = []
	for scenario: SinkScenario in [SimFixtures.calm(), _rising(0.6, 1.0)]:
		var layout := _roofed(Vector3.ZERO)
		layout.platforms = layout.platforms.duplicate()
		var quay := ShipPlatform.new()
		quay.name = &"quay"
		quay.area = Rect2(-12.0, -4.0, 11.4, 8.0)
		quay.height = 0.5
		layout.platforms.append(quay)
		var sim := SimFixtures.sim(1, scenario, layout)
		SimFixtures.place(sim, 0, Vector3(-crate_def.radius - rules.body_radius - 0.2, 0.5, 0.0))
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 2 * Ticks.RATE)
		var crate := sim.state.props[0]
		var from := crate.pos.x
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3 * Ticks.RATE)
		assert_eq(crate.shoved_by, 0, "the shove landed")
		went.append(crate.pos.x - from)
	assert_gt(went[0], 0.0, "a shove moves a standing crate")
	assert_gt(went[1], went[0], "and one afloat farther: the water drags less than the deck")


func test_a_body_stands_on_a_floating_crate_s_lid_and_rises_with_it() -> void:
	var crate_def := _steamer_crate()
	var sim := SimFixtures.sim(1, _rising(0.9, 3.0), _roofed(Vector3.ZERO))
	SimFixtures.place(sim, 0, Vector3(-10.0, 0.0, 0.0))
	var crate := sim.state.props[0]
	_until(sim, PropState.Body.FLOATING, 3 * Ticks.RATE)
	assert_eq(crate.body, PropState.Body.FLOATING)
	var lid := sim.surfaces.count()
	SimFixtures.place(sim, 0, Vector3(0.0, crate.pos.y + crate_def.height, 0.0))
	var player := sim.state.seats[0]
	assert_eq(player.surface, lid, "on the floating crate's lid")
	var from := player.pos.y
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_eq(crate.body, PropState.Body.FLOATING)
	assert_eq(player.body, PlayerState.Body.GROUNDED, "still standing")
	assert_eq(player.surface, lid, "on its lid")
	assert_gt(player.pos.y, from, "risen with it")
	assert_almost_eq(
		player.pos.y, crate.pos.y + crate_def.height, 0.05, "riding its lid, a tick behind"
	)


func test_a_drifting_crate_survives_snapshot_continuation() -> void:
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var sim := _drifting(Vector3(RAILED_X, 0.0, edge - _steamer_crate().radius - 0.6))
	var played: Array[Dictionary] = [sim.snapshot()]
	var drifting := []
	for _tick in 3 * Ticks.RATE:
		SimFixtures.step(sim)
		played.append(sim.snapshot())
		var crate := sim.state.props[0]
		if crate.body == PropState.Body.FLOATING and crate.vel != Vector3.ZERO:
			drifting.append(played.size() - 1)
	assert_gt(drifting.size(), 2, "the crate drifts a while")
	var no_input := func(_tick: int) -> Array[InputFrame]:
		var row: Array[InputFrame] = []
		row.resize(1)
		return row
	for start: int in [drifting[0] - 1, drifting[0], drifting[drifting.size() / 2], drifting[-1]]:
		if not _continues(played, start, sim.config, no_input):
			return
