extends GutTest
## A funnel coming down knocks down every body in the strip it lands across on the tick
## it lands (SH31, D12): a rule, as a crate's impact is — staggered, sent out of the strip
## to the side its centre is on, no brace taking anything off — and nothing else.

const SEED := 1701


## A funnel 5 m tall and 0.5 m round standing at the flat deck's middle, falling toward
## her bow and landing on [param tick].
func _fall(tick: int) -> FunnelFall:
	var funnel := ShipFitting.new()
	funnel.kind = ShipFitting.Kind.FUNNEL
	funnel.name = &"funnel"
	funnel.base = Vector3.ZERO
	funnel.height = 5.0
	funnel.radius = 0.5
	return FunnelFall.new(funnel, Vector2(1.0, 0.0), tick - 60, tick - 30, tick)


func test_bodies_in_the_strip_are_knocked_down_as_it_lands() -> void:
	var rules := SimFixtures.rules()
	var sim := MatchSim.create(SimFixtures.config(4, null, SEED))
	SimFixtures.place(sim, 0, Vector3(2.0, 0.0, 0.3))
	SimFixtures.place(sim, 1, Vector3(4.0, 0.0, -0.4))
	SimFixtures.place(sim, 2, Vector3(2.0, 0.0, 2.5))
	SimFixtures.place(sim, 3, Vector3(7.0, 0.0, 0.0))
	sim.state.seats[1].bracing = true
	var hazards := Hazards.new(sim.config, sim.surfaces)
	var tick := sim.state.tick
	var pose := sim.pose()
	var falls: Array[FunnelFall] = [_fall(tick + 1)]
	pose.falls = falls
	var events: Array[SimEvent] = []
	hazards.step(sim.state, pose, tick, events)
	assert_eq(events.size(), 0, "nothing before it lands")
	hazards.step(sim.state, pose, tick + 1, events)
	var struck: Array[int] = []
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.KNOCKED_DOWN:
			struck.append(event.seat)
	assert_eq(struck, [0, 1], "the two in its strip, in seat order")
	var stagger := Ticks.from_seconds(rules.struck_stagger)
	for seat: int in [0, 1]:
		var player := sim.state.seats[seat]
		assert_eq(player.stagger_ticks, stagger, "seat %d staggered" % seat)
		assert_false(player.bracing, "seat %d's brace broken" % seat)
		var sent := player.held_vel if player.is_frozen() else player.vel
		var aside := 1.0 if player.pos.z > 0.0 else -1.0
		assert_almost_eq(sent.z, aside * rules.struck_knockback, 1e-4, "out to its side")
		assert_almost_eq(sent.x, 0.0, 1e-4, "never along the strip")
	for seat: int in [2, 3]:
		assert_eq(sim.state.seats[seat].stagger_ticks, 0, "seat %d clear of it" % seat)
