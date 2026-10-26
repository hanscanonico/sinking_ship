extends GutTest
## Steady (#307, #316): every shove a seat that took it takes, quick or charged, from any
## side and without bracing, sends it at its kind's share of the knockback — three quarters
## as shipped (test_bonus_rules holds the data to it) — before a brace takes its own share
## off. Nothing else that knocks a body about
## is touched: a crate, a falling funnel and a body bowling it over send it as they send
## anyone.

const SHOVE := InputFrame.SHOVE
const BRACE := InputFrame.BRACE


## A match of [param seats] on [param layout] — the flat deck when none is given — played
## with Steady, seat 0 with one when [param steady] says so.
func _sim(steady: bool, seats := 2, layout: ShipLayout = null) -> MatchSim:
	var deck := layout if layout != null else SimFixtures.deck()
	return SimFixtures.kind_sim(SimFixtures.steady(), steady, seats, deck)


## Seat 1 at the origin facing the bow, and seat 0 — Steady when [param steady] says so —
## within its reach in front of it, facing [param facing_deg]: toward it, or away.
func _duel(steady: bool, facing_deg := 180.0) -> MatchSim:
	var rules := SimFixtures.rules()
	var sim := _sim(steady)
	SimFixtures.place(sim, 1, Vector3.ZERO, 0.0)
	SimFixtures.place(sim, 0, Vector3(rules.body_radius * 2.0 + 0.3, 0.0, 0.0), facing_deg)
	return sim


## How fast seat 1's shove sends seat 0 in [param sim] — a tap, or held to a full charge
## when [param charged] says so — seat 0 sending [param answer] every tick; as the hit-stop
## holds it back.
func _sent(sim: MatchSim, charged: bool, answer: InputFrame) -> float:
	var rules := SimFixtures.rules()
	var held := Ticks.from_seconds(rules.charge_full) if charged else 1
	var then := Ticks.from_seconds(rules.shove_windup)
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, SHOVE), 0: answer}, held)
	SimFixtures.step(sim, {1: SimFixtures.frame(1), 0: answer}, then)
	assert_eq(sim.state.seats[0].last_hit_by, 1, "the shove landed")
	return SimFixtures.sent(sim.state.seats[0]).length()


## A quick shove and a full charge each send a Steady seat at its kind's share of what they
## send a seat without it — facing the shover or turned away — and stagger it all the same.
func test_a_steady_seat_takes_its_share_of_a_quick_shove_and_a_charged_one() -> void:
	var rules := SimFixtures.rules()
	var kind_share := SimFixtures.steady().knockback_share
	assert_lt(kind_share, 1.0, "Steady takes less than a whole shove")
	for charged: bool in [false, true]:
		var whole := rules.charged_knockback if charged else rules.knockback
		for facing: float in [180.0, 0.0]:
			for steady: bool in [false, true]:
				var sim := _duel(steady, facing)
				var what := "charged %s, facing %s, Steady %s" % [charged, facing, steady]
				var share := kind_share if steady else 1.0
				var sent := _sent(sim, charged, SimFixtures.frame(0))
				assert_almost_eq(sent, whole * share, 0.0001, what)
				assert_true(sim.state.seats[0].is_staggered(), "%s: staggered" % what)


## A front brace takes its own share off what Steady leaves of a quick shove: a braced
## Steady seat is sent at the knockback times both shares, and keeps its feet.
func test_a_brace_takes_its_share_off_what_steady_leaves() -> void:
	var rules := SimFixtures.rules()
	var braced := 1.0 - rules.brace_reduction
	for steady: bool in [false, true]:
		var sim := _duel(steady)
		var sent := _sent(sim, false, SimFixtures.frame(0, Vector2.ZERO, BRACE))
		var share := SimFixtures.steady().knockback_share if steady else 1.0
		assert_almost_eq(sent, rules.knockback * share * braced, 0.0001, "Steady %s" % steady)
		var target := sim.state.seats[0]
		assert_false(target.is_staggered(), "Steady %s: the brace keeps its feet" % steady)
		assert_true(target.bracing, "Steady %s: and stays planted" % steady)


## A crate running into a Steady seat knocks it on exactly as it knocks a seat without it.
func test_a_crate_knocks_a_steady_seat_on_as_it_knocks_anyone() -> void:
	var sent: Array[Vector2] = []
	for steady: bool in [false, true]:
		var crates: Array[ShipProp] = [SimFixtures.crate(Vector3(0.0, 0.0, -1.0))]
		var sim := _sim(steady, 1, SimFixtures.crated(crates))
		SimFixtures.place(sim, 0, Vector3(0.0, 0.0, 0.5))
		sim.state.props[0].vel = Vector3(0.0, 0.0, 4.0)
		var hit := false
		for _tick in Ticks.RATE:
			for event: SimEvent in SimFixtures.step(sim):
				hit = hit or event.kind == SimEvent.Kind.PROP_HIT
			if hit:
				break
		assert_true(hit, "Steady %s: the crate runs into it" % steady)
		assert_true(sim.state.seats[0].is_staggered(), "Steady %s: staggered" % steady)
		sent.append(SimFixtures.sent(sim.state.seats[0]))
	assert_gt(sent[0].length(), 0.0, "knocked on")
	assert_eq(sent[1], sent[0], "Steady or not, the same")


## A funnel coming down across a Steady seat knocks it out of its strip at the whole
## struck_knockback, as it knocks anyone.
func test_a_falling_funnel_knocks_a_steady_seat_down_as_it_knocks_anyone() -> void:
	var rules := SimFixtures.rules()
	for steady: bool in [false, true]:
		var sim := _sim(steady, 1)
		SimFixtures.place(sim, 0, Vector3(2.0, 0.0, 0.3))
		var funnel := ShipFitting.new()
		funnel.kind = ShipFitting.Kind.FUNNEL
		funnel.name = &"funnel"
		funnel.height = 5.0
		funnel.radius = 0.5
		var lands := sim.state.tick + 1
		var pose := SimFixtures.copy_of(sim.pose())
		var falls: Array[FunnelFall] = [FunnelFall.new(funnel, Vector2.RIGHT, -60, -30, lands)]
		pose.falls = falls
		HeldPose.hold(sim, pose)
		var struck := false
		for event: SimEvent in SimFixtures.step(sim, {}, 2):
			struck = struck or event.kind == SimEvent.Kind.KNOCKED_DOWN and event.seat == 0
		assert_true(struck, "Steady %s: knocked down" % steady)
		var sent := SimFixtures.sent(sim.state.seats[0])
		var whole := Vector2(0.0, rules.struck_knockback)
		assert_almost_eq(sent.distance_to(whole), 0.0, 0.0001, "Steady %s: the whole" % steady)


## A staggered body running into a Steady seat bowls it over as it bowls anyone, and it
## goes on exactly as fast.
func test_a_body_bowling_into_a_steady_seat_sends_it_on_as_it_sends_anyone() -> void:
	var rules := SimFixtures.rules()
	var sent: Array[Vector2] = []
	for steady: bool in [false, true]:
		var sim := _sim(steady)
		SimFixtures.place(sim, 0, Vector3(-5.0 + rules.body_radius * 2.0 + 0.05, 0.0, 0.0))
		SimFixtures.place(sim, 1, Vector3(-5.0, 0.0, 0.0))
		sim.state.seats[1].vel = Vector3(6.0, 0.0, 0.0)
		sim.state.seats[1].stagger_ticks = Ticks.from_seconds(rules.stagger)
		var bowled := false
		for event: SimEvent in SimFixtures.step(sim):
			bowled = bowled or event.kind == SimEvent.Kind.BOWLED and event.seat == 0
		assert_true(bowled, "Steady %s: bowled over" % steady)
		sent.append(SimFixtures.sent(sim.state.seats[0]))
	assert_gt(sent[0].x, 0.0, "sent on")
	assert_eq(sent[1], sent[0], "Steady or not, the same")
