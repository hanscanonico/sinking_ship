extends GutTest
## The sea as a countdown (SH5): swimming, the cold meter, wading and climbing out.

## Just past the starboard edge of the flat deck, outside its hull.
const OUTSIDE_Z := 4.6
const TOWARD_PORT := Vector2(0.0, -1.0)


func _rules() -> BrawlRules:
	return SimFixtures.rules()


## [param events] of [param kind].
func _kinds(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## Two seats on the flat deck standing [param freeboard] out of the sea under
## [param sinking]: seat 0 afloat just outside its starboard edge, seat 1 standing
## well clear of it.
func _beside_the_deck(freeboard: float, sinking: SinkScenario = null) -> MatchSim:
	var sim := SimFixtures.sim(2, sinking, SimFixtures.low_deck(freeboard))
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, OUTSIDE_Z))
	return sim


func test_entering_the_sea_starts_swimming() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.place(sim, 0, Vector3(6.0, 0.0, 4.5))
	var swimmer := sim.state.seats[0]
	var entered: Array[SimEvent] = []
	for _tick in 2 * Ticks.RATE:
		entered.append_array(_kinds(SimFixtures.step(sim), SimEvent.Kind.ENTERED_WATER))
		if not entered.is_empty():
			break
	assert_eq(entered.size(), 1, "it went into the sea")
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
	assert_eq(swimmer.surface, Surfaces.NONE)
	assert_false(swimmer.is_out(), "the sea is no longer a wall")

	# The fall dunks it under before the water floats it back up to rest.
	var deepest := INF
	for _tick in 2 * Ticks.RATE:
		SimFixtures.step(sim)
		deepest = minf(deepest, swimmer.pos.y)
	var sea := sim.pose().water_height(swimmer.pos)
	assert_almost_eq(swimmer.pos.y, sea - rules.swim_depth, 0.0001, "feet swim_depth under")
	assert_eq(swimmer.vel, Vector3.ZERO, "afloat")
	assert_lt(deepest, sea - rules.swim_depth - 0.2, "dunked on the way in")
	assert_gt(swimmer.pos.y + rules.body_height, sea, "the head rides above the sea")

	SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.DOWN)}, Ticks.RATE)
	var planar := Vector2(swimmer.vel.x, swimmer.vel.z)
	assert_almost_eq(planar.length(), rules.swim_speed, 0.0001, "it swims at swim_speed")


func test_cold_meter_puts_you_out_at_zero() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 8.0))
	var swimmer := sim.state.seats[0]
	var outs: Array[SimEvent] = []
	var previous := swimmer.cold
	for _tick in 2 * Ticks.from_seconds(rules.cold_meter):
		outs.append_array(_kinds(SimFixtures.step(sim), SimEvent.Kind.SEAT_OUT))
		if swimmer.is_out():
			break
		assert_lt(swimmer.cold, previous, "it drains every tick in the sea")
		previous = swimmer.cold
	assert_true(swimmer.is_out())
	assert_eq(swimmer.out_cause, PlayerState.Cause.COLD)
	assert_eq(swimmer.cold, 0.0)
	assert_almost_eq(swimmer.out_tick, Ticks.from_seconds(rules.cold_meter), 1)
	assert_eq([outs[0].seat, outs[0].cause, outs[0].place], [0, PlayerState.Cause.COLD, 2])
	assert_eq(sim.state.winner(), 1)


func test_climb_needs_an_edge_within_reach() -> void:
	var rules := _rules()
	var climb_ticks := Ticks.from_seconds(rules.climb_time)
	# The deck 0.4 m out of the sea, its railing along this stretch: in reach, and a
	# railing never stops a climb.
	var sim := _beside_the_deck(0.4)
	var swimmer := sim.state.seats[0]
	var out := _kinds(
		SimFixtures.step(sim, {0: SimFixtures.frame(0, TOWARD_PORT)}, climb_ticks + 1),
		SimEvent.Kind.CLIMBED_OUT
	)
	assert_eq(out.size(), 1, "climbed out")
	assert_eq(out[0].tick, climb_ticks, "over climb_time")
	assert_eq([out[0].seat, out[0].surface], [0, 0])
	assert_eq(swimmer.body, PlayerState.Body.GROUNDED)
	assert_eq(swimmer.pos.y, 0.0, "standing on the deck")
	assert_lt(swimmer.pos.z, 4.0 - rules.body_radius, "the whole circle on it")

	# Pressing away from the edge, or toward one out of reach: no climb.
	var away := _beside_the_deck(0.4)
	SimFixtures.step(away, {0: SimFixtures.frame(0, Vector2.DOWN)}, 3 * climb_ticks)
	assert_eq(away.state.seats[0].body, PlayerState.Body.SWIMMING, "pressing away")
	var high := _beside_the_deck(rules.climb_reach + 0.2)
	SimFixtures.step(high, {0: SimFixtures.frame(0, TOWARD_PORT)}, 3 * climb_ticks)
	assert_eq(high.state.seats[0].body, PlayerState.Body.SWIMMING, "out of reach")
	assert_false(high.state.seats[0].is_climbing())


func test_a_climber_can_be_shoved_back() -> void:
	var rules := _rules()
	var sim := _beside_the_deck(0.4)
	var climber := sim.state.seats[0]
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.4), 90.0)
	var press := {0: SimFixtures.frame(0, TOWARD_PORT), 1: SimFixtures.frame(1)}
	SimFixtures.step(sim, press, 4)
	assert_true(climber.is_climbing(), "it started up")
	var cold := climber.cold
	SimFixtures.step(sim, {0: press[0], 1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)})
	var knocked: Array[SimEvent] = []
	for _tick in Ticks.from_seconds(rules.climb_time):
		var events := SimFixtures.step(sim, press)
		knocked.append_array(_kinds(events, SimEvent.Kind.KNOCKED_BACK_IN))
		assert_true(_kinds(events, SimEvent.Kind.CLIMBED_OUT).is_empty(), "it never got up")
		if not knocked.is_empty():
			break
	assert_eq(knocked.size(), 1, "the shove landed on the climb")
	assert_eq([knocked[0].seat, knocked[0].credit], [0, 1])
	assert_false(climber.is_climbing())
	assert_eq(climber.body, PlayerState.Body.SWIMMING)
	assert_true(climber.is_staggered())
	assert_almost_eq(
		climber.cold, cold - rules.climb_penalty, 0.0001, "climb_penalty colder, held in the stop"
	)
	SimFixtures.step(sim, {0: SimFixtures.frame(0), 1: SimFixtures.frame(1)}, Ticks.RATE)
	var sea := sim.pose().water_height(climber.pos)
	assert_lt(climber.pos.y, sea, "back in the sea")
	assert_gt(climber.pos.z, 4.0, "off the edge it was climbing")


func test_cold_regenerates_slowly_on_deck() -> void:
	var rules := _rules()
	var sim := SimFixtures.sim(2)
	SimFixtures.place(sim, 0, Vector3.ZERO)
	SimFixtures.place(sim, 1, Vector3(-10.0, 0.0, 0.0))
	var dried := sim.state.seats[0]
	dried.cold = 1.0
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_almost_eq(dried.cold, 1.0 + rules.cold_regen, 0.0001, "cold_regen a second")
	dried.cold = rules.cold_meter - 0.01
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_eq(dried.cold, rules.cold_meter, "never past a full meter")

	# Back in the sea before the meter has refilled, it lasts only what it got back.
	dried.cold = 1.0 + rules.cold_regen
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 8.0))
	SimFixtures.step(sim, {}, Ticks.from_seconds(1.0 + rules.cold_regen) + 1)
	assert_true(dried.is_out(), "a second dunking soon after the first is shorter")


func test_wading_slows_and_deep_water_swims() -> void:
	var rules := _rules()
	var speeds := {}
	for sink: float in [0.4 + rules.stand_depth, 0.4 + rules.wade_depth + 0.6]:
		# Alone: with the whole deck awash, two swimmers would be the sea's to settle.
		var flooded := SimFixtures.scenario([[0.0, sink, 0.0, 0.0]])
		var sim := SimFixtures.sim(1, flooded, SimFixtures.low_deck(0.4))
		SimFixtures.place(sim, 0, Vector3(-4.0, 0.0, 0.0))
		var walker := sim.state.seats[0]
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.RIGHT)}, Ticks.RATE)
		speeds[sink] = [walker.body, Vector2(walker.vel.x, walker.vel.z).length(), walker.cold]
	var shallow: Array = speeds.values()[0]
	var deep: Array = speeds.values()[1]
	assert_eq(shallow[0], PlayerState.Body.GROUNDED, "wading under wade_depth")
	assert_almost_eq(shallow[1], rules.wade_speed, 0.0001, "slowed to wade_speed")
	assert_eq(shallow[2], rules.cold_meter, "wading is not swimming")
	assert_eq(deep[0], PlayerState.Body.SWIMMING, "swimming past wade_depth")
	assert_almost_eq(deep[1], rules.swim_speed, 0.0001)
	assert_lt(deep[2], rules.cold_meter)


func test_swimmers_cannot_shove() -> void:
	var sim := SimFixtures.sim(2)
	SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 8.0), 90.0)
	SimFixtures.swim(sim, 1, Vector3(0.0, 0.0, 8.9), -90.0)
	var swimmer := sim.state.seats[0]
	var presses := [InputFrame.SHOVE, 0, InputFrame.BRACE, InputFrame.SHOVE, 0, InputFrame.JUMP]
	for buttons: int in presses:
		var events := SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)}, 4)
		assert_eq(swimmer.action, PlayerState.Action.IDLE, "no windup")
		assert_false(swimmer.bracing, "no brace")
		assert_true(_kinds(events, SimEvent.Kind.SHOVE_LANDED).is_empty())
		assert_eq(swimmer.body, PlayerState.Body.SWIMMING, "no jump out of the water")
		assert_false(swimmer.jumped)
	assert_false(sim.state.seats[1].is_staggered(), "and nobody pushed")


func test_a_shove_still_pushes_a_swimmer() -> void:
	# A deck awash enough that a body on it can reach the swimmer beside it.
	var sim := _beside_the_deck(0.2)
	var swimmer := sim.state.seats[0]
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.4), 90.0)
	SimFixtures.step(sim, {1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)})
	SimFixtures.step(sim, {1: SimFixtures.frame(1)}, 5)
	assert_true(swimmer.is_staggered(), "the shove landed")
	assert_eq(swimmer.last_hit_by, 1)
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
	assert_gt(SimFixtures.sent(swimmer).y, 0.0, "sent away from the deck")
	SimFixtures.step(sim, {1: SimFixtures.frame(1)}, Ticks.RATE)
	assert_gt(swimmer.pos.z, OUTSIDE_Z + 1.0)


func test_a_swimmer_frozen_in_a_hit_stop_holds_its_cold() -> void:
	var sim := _beside_the_deck(0.2)
	var swimmer := sim.state.seats[0]
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.4), 90.0)
	var frames := {1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)}
	var landed := false
	for _tick in Ticks.RATE:
		var cold := swimmer.cold
		landed = not _kinds(SimFixtures.step(sim, frames), SimEvent.Kind.SHOVE_LANDED).is_empty()
		frames = {1: SimFixtures.frame(1)}
		if landed:
			assert_eq(swimmer.cold, cold, "held on the tick the shove lands")
			break
	assert_true(landed, "the shove landed")
	assert_true(swimmer.is_frozen())
	var held := swimmer.cold
	while swimmer.is_frozen():
		SimFixtures.step(sim, frames)
		if swimmer.is_frozen():
			assert_eq(swimmer.cold, held, "held through the stop")
	assert_lt(swimmer.cold, held, "and draining again the tick it ends")


func test_a_shove_on_a_climber_knocks_it_back_in_through_the_hit_stop() -> void:
	var sim := _beside_the_deck(0.4)
	var climber := sim.state.seats[0]
	SimFixtures.place(sim, 1, Vector3(0.0, 0.0, 3.4), 90.0)
	var press := {0: SimFixtures.frame(0, TOWARD_PORT), 1: SimFixtures.frame(1)}
	SimFixtures.step(sim, press, 4)
	assert_true(climber.is_climbing(), "it started up")
	var frames := {0: press[0], 1: SimFixtures.frame(1, Vector2.ZERO, InputFrame.SHOVE)}
	var knocked: Array[SimEvent] = []
	for _tick in Ticks.RATE:
		knocked = _kinds(SimFixtures.step(sim, frames), SimEvent.Kind.KNOCKED_BACK_IN)
		frames = press
		if not knocked.is_empty():
			break
	assert_eq(knocked.size(), 1, "knocked back in on the tick the shove lands")
	assert_true(climber.is_frozen(), "the hit stops it")
	assert_false(climber.is_climbing(), "its climb is over at once")
	assert_eq(climber.vel, Vector3.ZERO, "held still")
	assert_gt(SimFixtures.sent(climber).y, 0.0, "the knock waits, away from the deck")
	var where := climber.pos
	while climber.is_frozen():
		SimFixtures.step(sim, press)
		assert_false(climber.is_climbing(), "pressing on starts no climb in the stop")
		assert_eq(climber.pos, where, "nor moves it")
	SimFixtures.step(sim, press)
	assert_gt(climber.vel.z, 0.0, "the knock lands as the stop ends")
	SimFixtures.step(sim, {}, 5)
	assert_eq(climber.body, PlayerState.Body.SWIMMING)
	assert_gt(climber.pos.z, where.z, "back out into the sea")


func test_a_swimmer_crosses_a_submerged_deck_edge() -> void:
	# The flat deck's whole edge under the sea, anywhere from too deep to climb out
	# onto to too deep to stand on: swimming in from the open sea, it floats over the
	# edge and onto the deck rather than meeting it as a wall.
	var rules := _rules()
	for under: float in [0.4, 0.7, 1.0]:
		var layout := SimFixtures.deck()
		var flooded := SimFixtures.scenario([[0.0, layout.freeboard + under, 0.0, 0.0]])
		var sim := SimFixtures.sim(1, flooded, layout)
		SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
		var swimmer := sim.state.seats[0]
		SimFixtures.step(sim, {0: SimFixtures.frame(0, TOWARD_PORT)}, 2 * Ticks.RATE)
		assert_lt(swimmer.pos.z, 4.0 - rules.body_radius, "%s m under: over the edge" % under)
		assert_eq(swimmer.body, PlayerState.Body.SWIMMING, "%s m under: still swimming" % under)
		assert_almost_eq(swimmer.pos.y, 0.0, 0.0001, "%s m under: on the flooded deck" % under)


func test_a_swimmer_under_a_flooding_deck_stays_inside_the_hull() -> void:
	# The steamer's lower deck filling to over the main deck above it: a swimmer in a
	# port cabin, pressed against the hull, swims for the hull side all the while.
	var rules := _rules()
	var layout := SimFixtures.steamer()
	var rising := SimFixtures.scenario(
		[[0.0, layout.freeboard - 0.6, 0.0, 0.0], [2.0, layout.freeboard + 0.3, 0.0, 0.0]]
	)
	var sim := SimFixtures.sim(2, rising, layout)
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 0.0))
	SimFixtures.swim(sim, 0, Vector3(-11.0, 0.0, -4.25))
	var swimmer := sim.state.seats[0]
	swimmer.cold = 100.0
	for _tick in 3 * Ticks.RATE:
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2(0.0, -1.0))})
		assert_gt(swimmer.pos.z, -4.7 + rules.body_radius - 0.001, "never through the hull")
		assert_lte(swimmer.pos.y + rules.body_height, 0.0001, "its head under the deck")
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
	var sea := sim.pose().water_height(swimmer.pos)
	assert_lt(swimmer.pos.y + rules.body_height, sea, "the sea closed over its head")


## The steamer level with the sea a metre over her main deck: her hold, its bilge and
## wings and her forepeak full; under the forecastle the air trapped in the space over
## the hold, its water 0.2 m over the hold's open top, its air 0.8 m of sea over the
## atmosphere's (SH29); her engine room flooding, its air free; seat 1 dry on the bridge.
func _bow_under() -> MatchSim:
	var layout := SimFixtures.steamer()
	var sim := SimFixtures.sim(2, null, layout)
	var full := [1.0]
	var pose := (
		HeldPose
		. flooded(
			layout,
			1.0,
			{
				&"hold": full,
				&"hold_bilge": full,
				&"hold_wing_p": full,
				&"hold_wing_s": full,
				&"forepeak": full,
				&"hold_fwd_top": [0.2, 0.8],
				&"engine_room": [-1.0],
			}
		)
	)
	HeldPose.hold(sim, pose)
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	return sim


## Whether [param player]'s head is in trapped air under [param sim]'s pose.
func _breathes_pocket_air(sim: MatchSim, player: PlayerState) -> bool:
	return sim.pose().in_pocket(player.pos + Vector3.UP * _rules().head_height())


func test_swimmer_surfaces_in_a_pocket() -> void:
	# Deep in the flooded hold under the forecastle, it floats up through the hold's open
	# top into the pocket over it and rests at that water, not the sea's.
	var rules := _rules()
	var sim := _bow_under()
	SimFixtures.swim(sim, 0, Vector3(13.5, 0.0, 0.0))
	var swimmer := sim.state.seats[0]
	swimmer.pos.y = -2.4
	swimmer.cold = 100.0
	SimFixtures.step(sim, {}, 3 * Ticks.RATE)
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
	assert_almost_eq(swimmer.pos.y, 0.2 - rules.swim_depth, 0.0001, "afloat at the pocket's water")
	assert_true(_breathes_pocket_air(sim, swimmer), "its head in the trapped air")
	assert_lt(swimmer.pos.y + rules.body_height, 1.8, "under the forecastle deck")


func test_swimmer_waits_in_a_pocket_longer_than_the_cold_meter() -> void:
	var rules := _rules()
	var sim := _bow_under()
	SimFixtures.swim(sim, 0, Vector3(13.5, 0.0, 0.0))
	var swimmer := sim.state.seats[0]
	SimFixtures.step(sim, {}, Ticks.from_seconds(rules.cold_meter + 1.0))
	assert_false(swimmer.is_out(), "a full meter and more, still in")
	var lasts := rules.cold_meter / rules.pocket_cold_rate
	assert_almost_eq(lasts, 16.0, 1e-9, "the 4 s meter lasts 16 s there")
	var outs: Array[SimEvent] = []
	for _tick in Ticks.from_seconds(lasts):
		outs.append_array(_kinds(SimFixtures.step(sim), SimEvent.Kind.SEAT_OUT))
		if swimmer.is_out():
			break
	assert_true(swimmer.is_out(), "but the cold takes it in the end")
	assert_eq(swimmer.out_cause, PlayerState.Cause.COLD)
	assert_almost_eq(swimmer.out_tick, Ticks.from_seconds(lasts), 1, "at the pocket rate")


func test_pocket_rate_applies_only_with_the_head_in_trapped_air() -> void:
	# Four swimmers, a second each: in the pocket, under the flooded hold's deck, in the
	# engine room's free air over its water, and in the open sea.
	var rules := _rules()
	var places := {
		"in the pocket": Vector3(13.5, 0.0, 0.0),
		"under the hold's deck": Vector3(7.0, -1.9, 0.0),
		"in free air over the engine room's water": Vector3(-2.0, -2.0, 3.0),
		"in the open sea": Vector3(0.0, 0.0, 8.0),
	}
	for place: String in places:
		var sim := _bow_under()
		SimFixtures.swim(sim, 0, places[place])
		var swimmer := sim.state.seats[0]
		# Under a full cell's deck its head is pressed against the deck, under water.
		swimmer.pos.y = minf(swimmer.pos.y, places[place].y)
		SimFixtures.step(sim, {}, Ticks.RATE)
		var rate := rules.pocket_cold_rate if place == "in the pocket" else 1.0
		assert_eq(swimmer.body, PlayerState.Body.SWIMMING, place)
		assert_eq(_breathes_pocket_air(sim, swimmer), place == "in the pocket", place)
		assert_almost_eq(
			rules.cold_meter - swimmer.cold, rate, 0.0001, "%s: %s a second" % [place, rate]
		)


func test_swimmer_crosses_a_flooded_doorway_to_the_next_pocket() -> void:
	# The sea 2.4 m over her main deck: the deckhouse's rooms flooded over their door
	# lintels, 2.1 m up, each trapping the air between them and its ceiling. From the
	# hall's pocket a swimmer ducks under the saloon door's lintel and surfaces in the
	# saloon's.
	var rules := _rules()
	var layout := SimFixtures.steamer()
	var sim := SimFixtures.sim(2, null, layout)
	var rooms := {}
	for room: StringName in [&"deckhouse_hall", &"saloon", &"deckhouse_cabins"]:
		rooms[room] = [2.25, 0.15]
	HeldPose.hold(sim, HeldPose.flooded(layout, 2.4, rooms))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.swim(sim, 0, Vector3(-1.5, 0.0, 2.15))
	var swimmer := sim.state.seats[0]
	swimmer.cold = 100.0
	# Under the ceiling, as it would float up to it.
	swimmer.pos.y = 0.5
	SimFixtures.step(sim, {}, Ticks.RATE)
	var cells := sim.pose().cells
	var structure := layout.structure
	assert_eq(cells.cell_at(swimmer.pos), structure.cell_named(&"deckhouse_hall"))
	assert_true(_breathes_pocket_air(sim, swimmer), "in the hall's pocket")
	var lowest := swimmer.pos.y
	var press := {0: SimFixtures.frame(0, Vector2.RIGHT)}
	for _tick in 2 * Ticks.RATE:
		SimFixtures.step(sim, press)
		lowest = minf(lowest, swimmer.pos.y)
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
	assert_gt(swimmer.pos.x, rules.body_radius, "through the doorway")
	assert_eq(cells.cell_at(swimmer.pos), structure.cell_named(&"saloon"), "in the saloon")
	assert_lte(lowest + rules.body_height, 2.1, "ducked under the lintel")
	assert_true(_breathes_pocket_air(sim, swimmer), "surfaced in the saloon's pocket")


func test_swimmer_climbs_onto_a_dry_face_in_a_pocket() -> void:
	# The deckhouse hall's air held as a pocket by the pose, its water half a metre deep,
	# and a bench in it 0.75 m up — test data: the steamer upright has no dry face in a
	# pocket, an upturned hull's old floors are its (SH32). A swimmer beside the bench
	# climbs onto it as onto a deck edge, stands dry there, and its meter refills.
	var rules := _rules()
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.platforms = layout.platforms.duplicate()
	var bench := ShipPlatform.new()
	bench.name = &"bench"
	bench.area = Rect2(-3.0, -3.0, 1.0, 1.0)
	bench.height = 0.75
	layout.platforms.append(bench)
	var sim := SimFixtures.sim(2, null, layout)
	HeldPose.hold(sim, HeldPose.flooded(layout, 2.4, {&"deckhouse_hall": [0.5, 1.9]}))
	SimFixtures.place(sim, 1, Vector3(-2.5, 4.7, 0.0))
	SimFixtures.swim(sim, 0, Vector3(-2.5, 0.0, -1.5))
	var swimmer := sim.state.seats[0]
	swimmer.cold = 2.0
	# Its feet on the hall's floor, the water too shallow to float it.
	swimmer.pos.y = 0.0
	SimFixtures.step(sim, {}, Ticks.RATE / 2)
	assert_eq(swimmer.body, PlayerState.Body.SWIMMING)
	assert_true(_breathes_pocket_air(sim, swimmer), "in the hall's pocket")
	var climbed := _kinds(
		SimFixtures.step(sim, {0: SimFixtures.frame(0, TOWARD_PORT)}, Ticks.RATE),
		SimEvent.Kind.CLIMBED_OUT
	)
	assert_eq(climbed.size(), 1, "climbed out")
	assert_eq(swimmer.body, PlayerState.Body.GROUNDED)
	assert_eq(SimFixtures.name_of(layout, swimmer.surface), &"bench", "onto the bench")
	assert_almost_eq(swimmer.pos.y, 0.75, 0.0001, "standing dry over the pocket's water")
	var cold := swimmer.cold
	SimFixtures.step(sim, {}, Ticks.RATE)
	assert_almost_eq(swimmer.cold, cold + rules.cold_regen, 0.0001, "refilling as on any deck")
