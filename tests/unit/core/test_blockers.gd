extends GutTest
## Blockers on the steamer: they push bodies out in the deck plane, and a shove
## does not pass through one.

const SHOVE := InputFrame.SHOVE


## The steamer's blocker of [param shape] whose footprint holds [param at] (x/z).
func _blocker(shape: ShipBlocker.Shape, at: Vector2) -> ShipBlocker:
	for blocker: ShipBlocker in SimFixtures.steamer().blockers:
		if blocker.shape != shape:
			continue
		if shape == ShipBlocker.Shape.BOX and blocker.area.has_point(at):
			return blocker
		if shape == ShipBlocker.Shape.CYLINDER and blocker.centre.distance_to(at) < blocker.radius:
			return blocker
	return null


## A steamer match held level and unsunk; seats past the first are parked apart on
## the poop deck.
func _steamer_sim(seats: int) -> MatchSim:
	var sim := SimFixtures.sim(seats, null, SimFixtures.steamer())
	for seat in range(1, seats):
		SimFixtures.place(sim, seat, Vector3(-18.0, 1.2, -3.0 + 2.0 * seat))
	return sim


func test_box_stops_a_body() -> void:
	var rules := SimFixtures.rules()
	# The cargo hatch on the main deck, approached from forward.
	var hatch := _blocker(ShipBlocker.Shape.BOX, Vector2(6.0, 0.0))
	assert_not_null(hatch)
	var sim := _steamer_sim(2)
	var start := Vector3(hatch.area.end.x + rules.body_radius + 0.4, 0.0, 0.0)
	SimFixtures.place(sim, 0, start)
	var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.LEFT)}, 2 * Ticks.RATE)
	var walker := sim.state.seats[0]
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(walker.surface, SimFixtures.platform_named(SimFixtures.steamer(), &"main deck"))
	assert_almost_eq(walker.pos.x, hatch.area.end.x + rules.body_radius, 0.0001, "at its face")
	assert_almost_eq(walker.pos.z, 0.0, 0.0001, "pushed straight back")
	assert_almost_eq(walker.vel.x, 0.0, 0.0001, "no speed into it")
	assert_true(events.is_empty(), "nothing happened")


func test_cylinder_stops_a_body() -> void:
	var rules := SimFixtures.rules()
	# The funnel on the boat deck, approached square from starboard.
	var funnel := _blocker(ShipBlocker.Shape.CYLINDER, Vector2(-6.0, 0.0))
	assert_not_null(funnel)
	var reach := funnel.radius + rules.body_radius
	var sim := _steamer_sim(2)
	SimFixtures.place(
		sim, 0, Vector3(funnel.centre.x, funnel.bottom, funnel.centre.y + reach + 0.5)
	)
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.UP)}, 2 * Ticks.RATE)
	var walker := sim.state.seats[0]
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_almost_eq(walker.pos.z, funnel.centre.y + reach, 0.0001, "held at its round side")
	assert_almost_eq(walker.pos.x, funnel.centre.x, 0.0001, "on the line it came in on")
	assert_almost_eq(walker.vel.z, 0.0, 0.0001, "no speed into it")


func test_a_raised_deck_is_a_wall_from_the_deck_below() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var main_deck := SimFixtures.platform_named(layout, &"main deck")
	# Walked square into the after face of the forecastle, which stands taller than
	# a body, and the forward face of the poop deck, which does not — each clear of
	# its ramps. Neither is walked onto, under or off.
	var faces := {&"forecastle": [Vector2.RIGHT, 2.5], &"poop deck": [Vector2.LEFT, 0.0]}
	for deck_name: StringName in faces:
		var deck := layout.platforms[SimFixtures.platform_named(layout, deck_name)]
		var direction: Vector2 = faces[deck_name][0]
		var face := deck.area.position.x if direction == Vector2.RIGHT else deck.area.end.x
		var sim := _steamer_sim(2)
		SimFixtures.place(sim, 0, Vector3(face - direction.x * 1.5, 0.0, faces[deck_name][1]))
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, direction)}, 2 * Ticks.RATE)
		var walker := sim.state.seats[0]
		assert_false(walker.is_out(), "%s: still aboard" % deck_name)
		assert_eq(walker.body, PlayerState.Body.GROUNDED, "%s: never fell" % deck_name)
		assert_eq(walker.surface, main_deck, "%s: on the main deck" % deck_name)
		assert_almost_eq(
			walker.pos.x,
			face - direction.x * rules.body_radius,
			0.0001,
			"%s: at its face" % deck_name
		)
		assert_true(events.is_empty(), "%s: nothing happened" % deck_name)


func test_a_body_fits_between_the_hatch_and_the_boat_deck_ramps() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var hatch := _blocker(ShipBlocker.Shape.BOX, Vector2(6.0, 0.0))
	var deckhouse := _blocker(ShipBlocker.Shape.BOX, Vector2(0.0, 0.0))
	assert_not_null(hatch)
	assert_not_null(deckhouse)
	# The lane between the hatch's starboard side and the inboard side of the ramp
	# beside it, walked aft from forward of the hatch: the strip between the hatch and
	# the deckhouse is never a pocket a body cannot leave.
	var ramp_side := INF
	for ramp: ShipRamp in layout.ramps:
		if ramp.area.position.y >= hatch.area.end.y and ramp.area.position.x < hatch.area.end.x:
			ramp_side = minf(ramp_side, ramp.area.position.y)
	assert_gte(ramp_side - hatch.area.end.y, rules.body_radius * 2.0, "a body's width")
	var lane := (hatch.area.end.y + ramp_side) * 0.5
	var sim := _steamer_sim(2)
	SimFixtures.place(sim, 0, Vector3(hatch.area.end.x + 0.6, 0.0, lane))
	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.LEFT)}, 3 * Ticks.RATE)
	var walker := sim.state.seats[0]
	assert_almost_eq(walker.pos.x, deckhouse.area.end.x + rules.body_radius, 0.0001, "aft to it")
	assert_almost_eq(walker.pos.z, lane, 0.0001, "never pushed aside")


func test_shove_does_not_pass_through_a_blocker() -> void:
	var rules := SimFixtures.rules()
	# The mast on the forecastle: thin enough that two bodies either side of it are
	# within a shove's reach of each other.
	var mast := _blocker(ShipBlocker.Shape.CYLINDER, Vector2(16.0, 0.0))
	assert_not_null(mast)
	var deck := mast.bottom
	var apart := mast.radius + rules.body_radius + 0.1
	var gap := apart * 2.0 - rules.body_radius * 2.0
	assert_lt(gap, rules.shove_reach, "in reach of each other")

	var lanes := {"through the mast": 0.0, "beside it": mast.radius + rules.body_radius + 0.1}
	var hit := {}
	for lane: String in lanes:
		var z: float = lanes[lane]
		var sim := _steamer_sim(2)
		SimFixtures.place(sim, 0, Vector3(mast.centre.x - apart, deck, z), 0.0)
		SimFixtures.place(sim, 1, Vector3(mast.centre.x + apart, deck, z), 180.0)
		var frames := {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE), 1: SimFixtures.frame(1)}
		SimFixtures.step(sim, frames, 10)
		hit[lane] = sim.state.seats[1].is_staggered()
	assert_false(hit["through the mast"], "the mast takes the shove")
	assert_true(hit["beside it"], "the same shove beside the mast lands")

	# And a body shoved into the mast stops against it.
	var sim := _steamer_sim(2)
	var target_x := mast.centre.x - mast.radius - rules.body_radius - 0.1
	SimFixtures.place(sim, 0, Vector3(target_x - rules.body_radius * 2.0 - 0.1, deck, 0.0), 0.0)
	SimFixtures.place(sim, 1, Vector3(target_x, deck, 0.0), 180.0)
	var frames := {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE), 1: SimFixtures.frame(1)}
	var farthest := -INF
	for _tick in Ticks.RATE:
		SimFixtures.step(sim, frames)
		farthest = maxf(farthest, sim.state.seats[1].pos.x)
	assert_gt(farthest, target_x, "the shove landed and sent it toward the mast")
	assert_almost_eq(
		farthest, mast.centre.x - mast.radius - rules.body_radius, 0.0001, "stopped at the mast"
	)


## The surface number of the steamer's blocker [param blocker]'s top: after every
## platform and ramp, in layout order.
func _top_of(blocker: ShipBlocker) -> int:
	var layout := SimFixtures.steamer()
	for index in layout.blockers.size():
		if (
			layout.blockers[index].area == blocker.area
			and layout.blockers[index].top == blocker.top
		):
			return layout.platforms.size() + layout.ramps.size() + index
	return Surfaces.NONE


## Seat 0 walks [param move] every tick until it lands somewhere; returns the
## events of the walk.
func _walk_until_landed(sim: MatchSim, move: Vector2) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _tick in 3 * Ticks.RATE:
		var stepped := SimFixtures.step(sim, {0: SimFixtures.frame(0, move)})
		events.append_array(stepped)
		for event: SimEvent in stepped:
			if event.kind == SimEvent.Kind.LANDED:
				return events
	return events


func _kinds(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


func test_a_body_lands_on_a_blocker_top() -> void:
	var layout := SimFixtures.steamer()
	var hatch := _blocker(ShipBlocker.Shape.BOX, Vector2(6.0, 0.0))
	assert_not_null(hatch)
	var hatch_top := _top_of(hatch)
	var boat_deck := layout.platforms[SimFixtures.platform_named(layout, &"boat deck")]
	# Off the boat deck's forward edge between its two ramps, at a walk: the hatch
	# stands below, lower than the boat deck and too tall to step onto from the deck.
	var sim := _steamer_sim(2)
	var edge := boat_deck.area.end.x
	SimFixtures.place(sim, 0, Vector3(edge - 0.2, boat_deck.height, hatch.area.get_center().y))
	var events := _walk_until_landed(sim, Vector2.RIGHT)
	var landed := _kinds(events, SimEvent.Kind.LANDED)
	assert_eq(_kinds(events, SimEvent.Kind.FELL).size(), 1, "it fell off the edge")
	assert_eq(landed.size(), 1, "and landed")
	if landed.is_empty():
		return
	assert_eq(landed[0].surface, hatch_top, "on the hatch")
	var walker := sim.state.seats[0]
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(walker.surface, hatch_top)
	assert_almost_eq(walker.pos.y, hatch.top, 0.0001, "on top of it, not through it")
	assert_true(hatch.area.has_point(Vector2(walker.pos.x, walker.pos.z)), "inside its footprint")
	assert_gt(walker.stagger_ticks, 0, "staggered by the drop")
	# Standing still, it stays up there.
	SimFixtures.step(sim, {0: SimFixtures.frame(0)}, Ticks.RATE)
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(walker.surface, hatch_top)
	assert_almost_eq(walker.pos.y, hatch.top, 0.0001)


func test_walking_off_a_blocker_top_falls() -> void:
	var rules := SimFixtures.rules()
	var layout := SimFixtures.steamer()
	var main_deck := SimFixtures.platform_named(layout, &"main deck")
	var hatch := _blocker(ShipBlocker.Shape.BOX, Vector2(6.0, 0.0))
	assert_not_null(hatch)
	var sim := _steamer_sim(2)
	var middle := hatch.area.get_center()
	SimFixtures.place(sim, 0, Vector3(middle.x, hatch.top, middle.y))
	assert_eq(sim.state.seats[0].surface, _top_of(hatch), "standing on the hatch")
	# Aft off its after side at a stroll, toward the open bay before the deckhouse.
	var events := _walk_until_landed(sim, Vector2.LEFT * 0.2)
	var fell := _kinds(events, SimEvent.Kind.FELL)
	var landed := _kinds(events, SimEvent.Kind.LANDED)
	assert_eq(fell.size(), 1, "it fell off the edge")
	assert_eq(landed.size(), 1, "and landed")
	if fell.is_empty() or landed.is_empty():
		return
	assert_gt(landed[0].tick, fell[0].tick)
	assert_eq(landed[0].surface, main_deck, "on the main deck")
	var walker := sim.state.seats[0]
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(walker.pos.y, 0.0, "on the main deck's planks")
	assert_lt(
		walker.pos.x, hatch.area.position.x - rules.body_radius + 0.0001, "clear of the hatch"
	)
	assert_gt(walker.stagger_ticks, 0, "staggered by the drop")


func test_a_body_on_a_blocker_top_can_be_shoved_from_the_deck() -> void:
	var rules := SimFixtures.rules()
	var hatch := _blocker(ShipBlocker.Shape.BOX, Vector2(6.0, 0.0))
	assert_not_null(hatch)
	var middle := hatch.area.get_center()
	# A body on the hatch at its forward edge; a shover on the main deck forward of
	# it, facing aft, within a shove's reach.
	var target := Vector3(hatch.area.end.x - rules.body_radius, hatch.top, middle.y)
	var shover := Vector3(hatch.area.end.x + rules.body_radius + 0.1, 0.0, middle.y)
	var gap := shover.x - target.x - rules.body_radius * 2.0
	assert_lt(gap, rules.shove_reach, "in reach of each other")
	var sim := _steamer_sim(2)
	SimFixtures.place(sim, 0, shover, 180.0)
	SimFixtures.place(sim, 1, target)
	assert_eq(sim.state.seats[1].surface, _top_of(hatch), "the target stands on the hatch")
	var frames := {0: SimFixtures.frame(0, Vector2.ZERO, SHOVE), 1: SimFixtures.frame(1)}
	SimFixtures.step(sim, frames, 10)
	assert_true(sim.state.seats[1].is_staggered(), "the shove lands on it")
