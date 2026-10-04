extends GutTest
## The ship's loose cargo (SH10): crates slide on their own grip angle, meet the
## ship through Surfaces, stagger or push the brawlers they run into, take shoves,
## and go into the sea — and all of it is in the snapshot (D5).

const SHOVE := InputFrame.SHOVE
const BRACE := InputFrame.BRACE
const JUMP := InputFrame.JUMP
## Clear of the flat deck's railing gaps on either side.
const RAILED_X := -8.0


func _rules() -> BrawlRules:
	return SimFixtures.rules()


func _steamer_crate() -> ShipProp:
	return SimFixtures.steamer().props[0]


## A match of [param seats] on the flat deck — or [param layout] — carrying one crate
## at [param at], under [param sinking].
func _one_crate(
	seats: int, at: Vector3, sinking: SinkScenario = null, layout: ShipLayout = null
) -> MatchSim:
	var crates: Array[ShipProp] = [SimFixtures.crate(at)]
	return SimFixtures.sim(seats, sinking, SimFixtures.crated(crates, layout))


func _of(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


func test_crate_holds_below_its_grip_angle() -> void:
	var grip := _steamer_crate().grip_angle_deg
	assert_lt(grip, _rules().grip_angle_deg, "a crate gives before a brawler does")
	var start := Vector3(0.0, 0.0, -2.0)
	var holding := _one_crate(1, start, SimFixtures.tilted(0.0, grip - 1.0))
	SimFixtures.place(holding, 0, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.step(holding, {}, 2 * Ticks.RATE)
	var held := holding.state.props[0]
	assert_eq(held.pos, start, "below its grip angle it stays put")
	assert_eq(held.vel, Vector3.ZERO)

	var sliding := _one_crate(1, start, SimFixtures.tilted(0.0, grip + 2.0))
	SimFixtures.place(sliding, 0, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.step(sliding, {}, Ticks.RATE)
	var slid := sliding.state.props[0]
	assert_gt(slid.pos.z, start.z, "past it, it slides downhill, to starboard")
	assert_gt(slid.vel.z, 0.0)
	assert_eq(slid.body, PropState.Body.GROUNDED)
	assert_eq(sliding.state.seats[0].pos, Vector3(-10.0, 0.0, 0.0), "a brawler still holds there")


func test_sliding_crate_staggers_a_brawler() -> void:
	var rules := _rules()
	# Steep enough for the crate, not for the brawler, who stands idle in its path.
	var sim := _one_crate(1, Vector3(0.0, 0.0, -3.5), SimFixtures.tilted(0.0, 12.0))
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 1.5))
	var crate := sim.state.props[0]
	var player := sim.state.seats[0]
	var hits: Array[SimEvent] = []
	var closing := 0.0
	for _tick in 3 * Ticks.RATE:
		closing = crate.vel.z
		hits = _of(SimFixtures.step(sim), SimEvent.Kind.CRATE_HIT)
		if not hits.is_empty():
			break
	assert_eq(hits.size(), 1, "the crate runs into the brawler")
	assert_eq([hits[0].seat, hits[0].prop], [0, 0])
	assert_gte(closing, rules.crate_impact_speed, "at its impact speed or more")
	assert_eq(player.stagger_ticks, Ticks.from_seconds(rules.stagger), "staggered")
	assert_eq(player.hitstop, Ticks.from_seconds(rules.hitstop), "frozen in a hit-stop")
	assert_almost_eq(
		SimFixtures.sent(player).y, rules.crate_knockback, 0.0001, "knocked on at crate_knockback"
	)
	assert_eq(player.last_hit_crate, 0, "the crate is what hit it")
	assert_gt(crate.vel.z, 0.0, "and the crate slides on")


func test_shoved_crate_moves_less_than_a_brawler() -> void:
	var rules := _rules()
	var apart := rules.body_radius * 2.0 + 0.3
	var bodies := SimFixtures.sim(2)
	SimFixtures.place(bodies, 0, Vector3.ZERO, 0.0)
	SimFixtures.place(bodies, 1, Vector3(apart, 0.0, 0.0), 180.0)
	var crate_at := Vector3(rules.body_radius + _steamer_crate().radius + 0.3, 0.0, 0.0)
	var cargo := _one_crate(1, crate_at)
	SimFixtures.place(cargo, 0, Vector3.ZERO, 0.0)
	for sim: MatchSim in [bodies, cargo]:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE)})
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 3 * Ticks.RATE)
	var body_went := bodies.state.seats[1].pos.x - apart
	var crate := cargo.state.props[0]
	var crate_went := crate.pos.x - crate_at.x
	assert_gt(crate_went, 0.0, "a shove moves a crate")
	assert_lt(crate_went, body_went, "but less far than a brawler")
	assert_eq(crate.vel, Vector3.ZERO, "and it comes to rest")
	assert_eq(crate.shoved_by, 0, "it remembers who shoved it")
	assert_gt(cargo.state.seats[0].pos.x, -0.5, "the shover rocks back, as off a body")
	assert_lt(cargo.state.seats[0].pos.x, 0.0)


## A scripted scene carries everything a crate can be in: on the flat deck in a
## lurch to starboard, seat 0 shoves a crate into seat 1, who freezes in the hit-stop
## and staggers, while a second crate slides into the starboard rail, breaks it, goes
## over the edge and is lost in the sea — a sim rebuilt from any of it must continue.
func test_crate_state_survives_snapshot_continuation() -> void:
	var rules := _rules()
	var crates: Array[ShipProp] = [
		SimFixtures.crate(Vector3(6.0, 0.0, -1.25)), SimFixtures.crate(Vector3(RAILED_X, 0.0, 1.0))
	]
	var scenario := SimFixtures.with_events(SimFixtures.calm(), [SimFixtures.lurch(0.5, 15.0)])
	var sim := SimFixtures.sim(3, scenario, SimFixtures.crated(crates))
	SimFixtures.place(sim, 0, Vector3(6.0, 0.0, -2.4), 90.0)
	SimFixtures.place(sim, 1, Vector3(6.0, 0.0, 0.2), -90.0)
	SimFixtures.place(sim, 2, Vector3(-12.0, 0.0, -2.0), 0.0)
	var scene := func(tick: int) -> Array[InputFrame]:
		return [
			SimFixtures.frame(0, Vector2.ZERO, SHOVE if tick == 0 else 0, 90.0),
			SimFixtures.frame(1, Vector2.ZERO, 0, -90.0),
			SimFixtures.frame(2, Vector2.ZERO, BRACE, 0.0),
		]
	var played: Array[Dictionary] = [sim.snapshot()]
	for tick in 5 * Ticks.RATE:
		sim.step(scene.call(tick))
		played.append(sim.snapshot())
	var covered := {
		"shoved crate": false,
		"sliding crate": false,
		"falling crate": false,
		"lost crate": false,
		"damaged railing": false,
		"crate hit": false,
	}
	for start in range(played.size() - 1):
		var snapshot := played[start]
		var in_flight := {"damaged railing": snapshot["railing_hp"][2] < rules.railing_hp}
		for entry: Dictionary in snapshot["props"]:
			var vel: Vector3 = entry["vel"]
			in_flight["shoved crate"] = (
				in_flight.get("shoved crate", false)
				or (entry["shoved_by"] != -1 and vel != Vector3.ZERO)
			)
			in_flight["sliding crate"] = (
				in_flight.get("sliding crate", false)
				or (entry["shoved_by"] == -1 and vel != Vector3.ZERO)
			)
			in_flight["falling crate"] = (
				in_flight.get("falling crate", false) or entry["state"] == PropState.Body.AIRBORNE
			)
			in_flight["lost crate"] = (
				in_flight.get("lost crate", false) or entry["state"] == PropState.Body.LOST
			)
		for entry: Dictionary in snapshot["seats"]:
			in_flight["crate hit"] = (
				in_flight.get("crate hit", false)
				or entry["last_hit_crate"] != -1 and entry["hitstop"] > 0
			)
		var seen := false
		for field: String in in_flight:
			if in_flight[field]:
				covered[field] = true
				seen = true
		if seen and not _continues(played, start, sim.config, scene):
			return
	for field: String in covered:
		assert_true(covered[field], "the scene resumes from a %s" % field)
	# Every field is in the digest, not only the snapshot.
	var middle := played[Ticks.RATE]
	for change: Callable in [
		func(copy: Dictionary) -> void: copy["props"][0]["pos"] += Vector3(0.01, 0.0, 0.0),
		func(copy: Dictionary) -> void: copy["props"][0]["vel"] += Vector3(0.0, 0.0, 0.1),
		func(copy: Dictionary) -> void: copy["props"][1]["state"] = PropState.Body.LOST,
		func(copy: Dictionary) -> void: copy["props"][0]["surface"] = Surfaces.NONE,
		func(copy: Dictionary) -> void: copy["props"][0]["shoved_by"] = 2,
		func(copy: Dictionary) -> void: copy["props"][0]["shoved_at"] = 99,
		func(copy: Dictionary) -> void: copy["railing_hp"][0] = 0.5,
		func(copy: Dictionary) -> void: copy["seats"][1]["last_hit_crate"] = 1,
	]:
		var changed := middle.duplicate(true)
		change.call(changed)
		assert_ne(SnapshotDigest.quantized(changed), SnapshotDigest.quantized(middle))


func test_a_wall_stops_a_crate() -> void:
	var wall := ShipBlocker.new()
	wall.area = Rect2(2.0, -1.0, 0.2, 2.0)
	wall.top = 2.0
	var layout := SimFixtures.deck().duplicate()
	var blockers: Array[ShipBlocker] = [wall]
	layout.blockers = blockers
	var sim := _one_crate(1, Vector3(0.0, 0.0, 0.0), SimFixtures.tilted(12.0, 0.0), layout)
	SimFixtures.place(sim, 0, Vector3(-10.0, 0.0, -3.0))
	SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	var crate := sim.state.props[0]
	assert_almost_eq(crate.pos.x, 2.0 - _steamer_crate().radius, 0.0001, "against the wall")
	assert_almost_eq(crate.vel.x, 0.0, 0.0001, "with no speed into it")
	assert_eq(crate.body, PropState.Body.GROUNDED)


func test_a_crate_breaks_a_span_and_goes_through_it_into_the_sea() -> void:
	var rules := _rules()
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var sim := _one_crate(1, Vector3(RAILED_X, 0.0, edge - 1.5))
	SimFixtures.place(sim, 0, Vector3(10.0, 0.0, -2.0))
	var crate := sim.state.props[0]
	crate.vel = Vector3(0.0, 0.0, 4.0)
	var events := SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	var broke := _of(events, SimEvent.Kind.RAILING_BROKE)
	assert_eq(broke.size(), 1, "the span it runs into breaks")
	assert_eq([broke[0].railing, broke[0].prop, broke[0].seat], [2, 0, -1])
	assert_eq(sim.state.railing_hp[2], 0.0)
	assert_eq(sim.state.railing_hp[0], rules.railing_hp, "the others stand whole")
	assert_eq(_of(events, SimEvent.Kind.CRATE_LOST).size(), 1, "over the edge and lost to the sea")
	assert_eq(crate.body, PropState.Body.LOST)
	assert_gt(crate.pos.z, edge)


func test_a_slow_crate_is_held_by_a_span() -> void:
	var rules := _rules()
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var radius := _steamer_crate().radius
	var sim := _one_crate(1, Vector3(RAILED_X, 0.0, edge - radius - 0.1))
	SimFixtures.place(sim, 0, Vector3(10.0, 0.0, -2.0))
	var crate := sim.state.props[0]
	crate.vel = Vector3(0.0, 0.0, rules.railing_break_speed - 0.5)
	var events := SimFixtures.step(sim, {}, Ticks.RATE)
	assert_true(_of(events, SimEvent.Kind.RAILING_BROKE).is_empty())
	assert_eq(sim.state.railing_hp[2], rules.railing_hp, "no damage below the break speed")
	assert_almost_eq(crate.pos.z, edge - radius, 0.0001, "held at the rail")
	assert_eq(crate.body, PropState.Body.GROUNDED)


## Two crates sliding together into a span, too slowly to break it: the first is
## moved by nothing but the railing's hold, and the second, close behind, meets it
## where the railing left it, not where it slid to.
func test_a_crate_meets_another_where_a_railing_held_it() -> void:
	var rules := _rules()
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var radius := _steamer_crate().radius
	var first_at := Vector3(RAILED_X, 0.0, edge - radius - 0.03)
	var crates: Array[ShipProp] = [
		SimFixtures.crate(first_at), SimFixtures.crate(first_at - Vector3(0.0, 0.0, radius * 2.0))
	]
	var sim := SimFixtures.sim(1, null, SimFixtures.crated(crates))
	SimFixtures.place(sim, 0, Vector3(10.0, 0.0, -2.0))
	# A tick at rest first: a crate meets its deck's railings once it stands on the deck.
	SimFixtures.step(sim)
	var slide := Vector3(0.0, 0.0, rules.railing_break_speed - 0.5)
	assert_gt(
		slide.z * Ticks.SECONDS_PER_TICK, 0.03, "a tick's slide takes the first past the rail"
	)
	for crate: PropState in sim.state.props:
		crate.vel = slide
	SimFixtures.step(sim)
	var first := sim.state.props[0]
	var second := sim.state.props[1]
	assert_almost_eq(first.pos.z, edge - radius, 0.0001, "the railing holds the first")
	assert_almost_eq(second.pos.z, first.pos.z - radius * 2.0, 0.0001, "the second meets it there")


## A sim reset to a snapshot (MatchSim.restore) whose span is whole holds its crate
## at that span, though a crate broke it in the same sim ticks before: what a client's
## prediction does every snapshot. It goes on exactly as a sim rebuilt from the
## snapshot does.
func test_a_restored_crate_meets_the_spans_its_snapshot_has() -> void:
	var rules := _rules()
	var edge := SimFixtures.deck().platforms[0].area.end.y
	var radius := _steamer_crate().radius
	var used := _one_crate(1, Vector3(RAILED_X, 0.0, edge - radius - 0.1))
	SimFixtures.place(used, 0, Vector3(10.0, 0.0, -2.0))
	used.state.props[0].vel = Vector3(0.0, 0.0, rules.railing_break_speed - 0.5)
	var whole := used.snapshot()
	used.state.props[0].vel = Vector3(0.0, 0.0, 4.0)
	var events := SimFixtures.step(used, {}, Ticks.RATE)
	assert_eq(_of(events, SimEvent.Kind.RAILING_BROKE).size(), 1, "the used sim's crate broke it")
	used.restore(whole)
	var rebuilt := MatchSim.from_snapshot(whole, used.config)
	for tick in Ticks.RATE:
		SimFixtures.step(used)
		SimFixtures.step(rebuilt)
		if used.snapshot() != rebuilt.snapshot():
			fail_test("the reset sim left the rebuilt one %d ticks after the reset" % (tick + 1))
			return
	var crate := used.state.props[0]
	assert_almost_eq(crate.pos.z, edge - radius, 0.0001, "held at the span")
	assert_eq(crate.body, PropState.Body.GROUNDED)


## Seat 0 standing idle, seat 1 braced and looking at the crate: both staggered, the
## brace halving the knockback and shortening the stop.
func test_a_brace_halves_a_crate_s_knockback_but_does_not_stop_it() -> void:
	var rules := _rules()
	var sent := PackedFloat64Array()
	var stops := PackedInt32Array()
	for braced: bool in [false, true]:
		var sim := _one_crate(1, Vector3(0.0, 0.0, -1.0))
		SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.5), -90.0)
		sim.state.props[0].vel = Vector3(0.0, 0.0, 4.0)
		var frame := SimFixtures.frame(0, Vector2.ZERO, BRACE if braced else 0)
		var hits: Array[SimEvent] = []
		for _tick in Ticks.RATE:
			hits = _of(SimFixtures.step(sim, {0: frame}), SimEvent.Kind.CRATE_HIT)
			if not hits.is_empty():
				break
		assert_eq(hits.size(), 1, "braced: %s, hit" % braced)
		var player := sim.state.seats[0]
		assert_true(player.is_staggered(), "braced: %s, staggered all the same" % braced)
		assert_false(player.bracing, "a hit takes the brace")
		sent.append(SimFixtures.sent(player).y)
		stops.append(player.hitstop)
	assert_almost_eq(sent[1], sent[0] * (1.0 - rules.crate_brace_reduction), 0.0001)
	assert_eq(stops[0], Ticks.from_seconds(rules.hitstop))
	assert_eq(stops[1], Ticks.from_seconds(rules.hitstop_braced))


func test_a_crate_hit_freezes_the_brawler_and_the_crate_keeps_moving() -> void:
	var rules := _rules()
	var sim := _one_crate(1, Vector3(0.0, 0.0, -1.0))
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.5))
	var crate := sim.state.props[0]
	crate.vel = Vector3(0.0, 0.0, 4.0)
	var player := sim.state.seats[0]
	var hits: Array[SimEvent] = []
	for _tick in Ticks.RATE:
		hits = _of(SimFixtures.step(sim), SimEvent.Kind.CRATE_HIT)
		if not hits.is_empty():
			break
	assert_eq(hits.size(), 1, "the crate runs into the brawler")
	var stop := Ticks.from_seconds(rules.hitstop)
	var held := player.held_vel
	assert_eq(player.hitstop, stop)
	assert_eq(player.vel, Vector3.ZERO, "the brawler holds still")
	assert_gt(held.z, crate.vel.z, "holding back more speed than the crate keeps")
	var crate_at := crate.pos
	for frozen in stop:
		var player_at := player.pos
		SimFixtures.step(sim)
		assert_eq(player.pos.x, player_at.x, "frozen tick %d: still" % frozen)
		assert_gt(crate.pos.z, crate_at.z, "frozen tick %d: the crate moves on" % frozen)
		crate_at = crate.pos
	assert_false(player.is_frozen())
	assert_eq(player.vel, held, "the knockback, held back till now")


func test_a_slow_crate_pushes_a_brawler_without_staggering_it() -> void:
	var rules := _rules()
	var sim := _one_crate(1, Vector3(0.0, 0.0, -1.0))
	SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.0))
	var crate := sim.state.props[0]
	crate.vel = Vector3(0.0, 0.0, rules.crate_impact_speed - 0.5)
	var player := sim.state.seats[0]
	var events: Array[SimEvent] = []
	for _tick in Ticks.RATE:
		events.append_array(SimFixtures.step(sim))
		if player.pos.z > 0.0:
			break
	assert_gt(player.pos.z, 0.0, "pushed along")
	assert_eq(player.last_hit_crate, 0, "by the crate")
	assert_gt(player.vel.z, 0.0, "at the speed they share")
	assert_almost_eq(player.vel.z, crate.vel.z, 0.0001)
	events.append_array(SimFixtures.step(sim, {}, Ticks.RATE))
	assert_true(_of(events, SimEvent.Kind.CRATE_HIT).is_empty(), "no impact")
	assert_false(player.is_staggered())
	assert_false(player.is_frozen())
	assert_gte(
		player.pos.z - crate.pos.z,
		rules.body_radius + _steamer_crate().radius - 0.0001,
		"and out of the crate"
	)


## Seat 0 staggered by a shove of seat 1's that landed [since] ticks ago, a slow crate
## drifting into it: within credit_window the push takes nothing from seat 1; past it,
## the crate is credited.
func test_a_push_takes_no_credit_from_a_fresh_shove() -> void:
	var rules := _rules()
	var window := Ticks.from_seconds(rules.credit_window)
	for since: int in [0, window]:
		var sim := _one_crate(2, Vector3(0.0, 0.0, -1.0))
		SimFixtures.place(sim, 0, Vector3.ZERO)
		SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
		var player := sim.state.seats[0]
		player.stagger_ticks = Ticks.from_seconds(rules.stagger)
		player.last_hit_by = 1
		player.last_hit_at = sim.state.tick - since
		sim.state.props[0].vel = Vector3(0.0, 0.0, rules.crate_impact_speed - 0.5)
		for _tick in Ticks.RATE:
			SimFixtures.step(sim)
			if player.pos.z > 0.0:
				break
		assert_gt(player.pos.z, 0.0, "pushed along")
		var credit := [player.last_hit_by, player.last_hit_crate]
		if since < window:
			assert_eq(credit, [1, -1], "still seat 1's shove")
		else:
			assert_eq(credit, [-1, 0], "past the window, the crate's push")


## Seat 0 staggered by crate 0 [since] ticks ago, which seat 1 had shoved; seat 1's shove
## of the crate is now past credit_window, and the crate drifts back into seat 0:
## within the window of the hit the push keeps seat 1's credit; past it, the crate's
## alone.
func test_a_push_keeps_its_crate_s_fresh_shover_credit() -> void:
	var rules := _rules()
	var window := Ticks.from_seconds(rules.credit_window)
	for since: int in [0, window]:
		var sim := _one_crate(2, Vector3(0.0, 0.0, -1.0))
		SimFixtures.place(sim, 0, Vector3.ZERO)
		SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
		var player := sim.state.seats[0]
		player.stagger_ticks = Ticks.from_seconds(rules.stagger)
		player.last_hit_by = 1
		player.last_hit_crate = 0
		player.last_hit_at = sim.state.tick - since
		var crate := sim.state.props[0]
		crate.shoved_by = 1
		crate.shoved_at = sim.state.tick - window
		crate.vel = Vector3(0.0, 0.0, rules.crate_impact_speed - 0.5)
		for _tick in Ticks.RATE:
			SimFixtures.step(sim)
			if player.pos.z > 0.0:
				break
		assert_gt(player.pos.z, 0.0, "pushed along")
		var credit := [player.last_hit_by, player.last_hit_crate]
		if since < window:
			assert_eq(credit, [1, 0], "the crate's hit, still seat 1's")
		else:
			assert_eq(credit, [-1, 0], "past the window, the crate's push alone")


## Seat 1 stands in the railing gap with a crate sliding at it; in one match seat 0
## has shoved the crate on its way, in the other nobody has.
func test_an_exit_a_crate_causes_credits_the_crate_and_its_shover() -> void:
	var gap := SimFixtures.rail_gap(SimFixtures.deck().platforms[0].area.end.y)
	var crate_at := Vector3(gap.x, 0.0, -2.5)
	for shoved: bool in [false, true]:
		var sim := _one_crate(2, crate_at, SimFixtures.tilted(0.0, 12.0))
		var shover_z := crate_at.z - _rules().body_radius - _steamer_crate().radius - 0.3
		SimFixtures.place(sim, 0, Vector3(gap.x, 0.0, shover_z), 90.0)
		SimFixtures.place(sim, 1, Vector3(gap.x, 0.0, gap.y - 0.7))
		var told := MatchTranscript.new()
		var outs: Array[SimEvent] = []
		for tick in 10 * Ticks.RATE:
			var buttons := SHOVE if shoved and tick == 0 else 0
			var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)})
			told.add(events)
			outs.append_array(_of(events, SimEvent.Kind.SEAT_OUT))
			if sim.is_over():
				break
		assert_eq(outs.size(), 1, "shoved: %s, the crate puts seat 1 out" % shoved)
		assert_eq([outs[0].seat, outs[0].prop], [1, 0], "credited to the crate")
		assert_eq(outs[0].credit, 0 if shoved else -1, "and to its shover, if any")
		var line := "credit crate 0 shoved by seat 0" if shoved else "credit crate 0"
		assert_string_contains(told.text(), line)


func test_a_crate_the_sea_floats_off_is_lost() -> void:
	var sinking := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [2.0, 4.0, 0.0, 0.0]])
	var sim := _one_crate(1, Vector3(0.0, 0.0, 0.0), sinking)
	SimFixtures.place(sim, 0, Vector3(-10.0, 0.0, 0.0))
	var events := SimFixtures.step(sim, {}, 2 * Ticks.RATE)
	var lost := _of(events, SimEvent.Kind.CRATE_LOST)
	assert_eq(lost.size(), 1, "the sea floats it off")
	assert_eq(lost[0].prop, 0)
	var crate := sim.state.props[0]
	assert_eq(crate.body, PropState.Body.LOST)
	var feet := Vector3(0.0, 0.0, 0.0)
	var rules := _rules()
	assert_true(
		sim.surfaces.obstacle_contacts(feet, rules.body_radius, rules.body_height, 0.0).is_empty(),
		"and nothing stands where it was"
	)


## A run-up at three metres a second and a jump from 1.3 m short lands on a still
## crate's lid; once the crate slides off under it, the brawler drops to the deck.
func test_a_brawler_jumps_onto_a_still_crate_and_drops_off_a_sliding_one() -> void:
	var rules := _rules()
	var crate_def := _steamer_crate()
	assert_lt(crate_def.height, rules.jump_height, "a jump clears a crate's lid")
	var sim := _one_crate(1, Vector3.ZERO)
	SimFixtures.place(sim, 0, Vector3(-1.3, 0.0, 0.0))
	var player := sim.state.seats[0]
	player.vel = Vector3(3.0, 0.0, 0.0)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(0.6, 0.0), JUMP)})
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	var lid := sim.surfaces.count()
	assert_eq(player.body, PlayerState.Body.GROUNDED, "landed")
	assert_eq(player.surface, lid, "on the crate's lid")
	assert_almost_eq(player.pos.y, crate_def.height, 0.0001)
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_eq(player.surface, lid, "and stays there")

	sim.state.props[0].vel = Vector3(0.0, 0.0, 2.0)
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_eq(_of(events, SimEvent.Kind.FELL).size(), 1, "a sliding crate carries nobody")
	assert_eq(player.body, PlayerState.Body.GROUNDED)
	assert_eq(player.surface, 0, "down on the deck")
	assert_eq(player.pos.y, 0.0)
	assert_true(_of(events, SimEvent.Kind.CRATE_HIT).is_empty(), "the lid slid out from under it")


func test_a_crate_goes_down_a_stair_opening() -> void:
	var layout := SimFixtures.steamer()
	var bow_down := SimFixtures.tilted(12.0, 0.0)
	var sim := _one_crate(1, Vector3(8.6, 0.0, 1.45), bow_down, layout)
	SimFixtures.place(sim, 0, Vector3(-17.5, 1.2, -2.5))
	SimFixtures.step(sim, {}, 4 * Ticks.RATE)
	var crate := sim.state.props[0]
	assert_eq(crate.body, PropState.Body.GROUNDED)
	assert_eq(SimFixtures.name_of(layout, crate.surface), &"lower deck", "down in the hold")
	assert_almost_eq(crate.pos.y, -2.6, 0.0001)


func test_the_steamer_s_crates_stand_clear_by_the_hatch() -> void:
	var layout := SimFixtures.steamer()
	var rules := _rules()
	var surfaces := Surfaces.new(layout)
	assert_eq(layout.props.size(), 4, "the hatch carries four crates")
	var hatch := Rect2(4.0, -1.0, 4.0, 2.0)
	var on_the_lid := 0
	for index in layout.props.size():
		var prop := layout.props[index]
		var under := surfaces.under(prop.pos, rules.step_height)
		assert_ne(under, Surfaces.NONE, "crate %d stands on something" % index)
		assert_almost_eq(surfaces.height_at(under, prop.pos), prop.pos.y, 0.0001)
		var contacts := surfaces.obstacle_contacts(
			prop.pos, prop.radius, prop.height, rules.step_height
		)
		assert_true(contacts.is_empty(), "crate %d is clear of everything" % index)
		if hatch.has_point(Vector2(prop.pos.x, prop.pos.z)):
			on_the_lid += 1
		else:
			assert_lt(prop.pos.z, hatch.position.y, "crate %d stowed to port" % index)
			assert_gt(prop.pos.x, hatch.end.x, "forward of the hatch")
		assert_true(prop.problems().is_empty())
	assert_eq(on_the_lid, 2, "two on the hatch's lid")


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
